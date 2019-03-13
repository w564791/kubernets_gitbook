关于kube-controller-manager以及kube-scheduler的HA实现方式

参考文档 http://liubin.org/blog/2018/04/28/how-to-build-controller-manager-high-available/

本人代码菜鸟,本文为首次看源码协作,思路大多来自参考文献,经过本人二次验证,再次感谢参考文献的大牛

在聊这个话题之前,我们需要先了解下分布式锁,详见原文:

[分布式锁原文,点我达](https://infoq.cn/article/how-to-implement-distributed-lock)

分布式锁，是用来控制分布式系统中互斥访问共享资源的一种手段，从而避免并行导致的结果不可控。基本的实现原理和单进程锁是一致的，通过一个共享标识来确定唯一性，对共享标识进行修改时能够保证原子性和和对锁服务调用方的可见性。由于分布式环境需要考虑各种异常因素，为实现一个靠谱的分布式锁服务引入了一定的复杂度。

分布式锁服务一般需要能够保证：

1. 同一时刻只能有一个线程持有锁
2. 锁能够可重入
3. 不会发生死锁
4. 具备阻塞锁特性，且能够及时从阻塞状态被唤醒
5. 锁服务保证高性能和高可用

在K8S中(以controller-manager为例),部署高可用的`controller-manager`,需要在每个`controller-manager`里添加`--leader-elect`参数,告知该`controller-manager`运行模式,当参数设置为`false`时,`controller-manager`以直接运行run函数,以单机模式运行. 当一个集群中存在>1个`controller-manager`并且均设置`leader-elect=false`时,集群中所有的`controller-manager`均能参与到集群控制,然后这样存在非常严重的资源抢占情况,当然我们并不建议这么做,我们这里只是为了说明其工作原理;代码如下:

```go
	
	run := func(ctx context.Context) {
		rootClientBuilder := controller.SimpleControllerClientBuilder{
			ClientConfig: c.Kubeconfig,
		}
		var clientBuilder controller.ControllerClientBuilder
		if c.ComponentConfig.KubeCloudShared.UseServiceAccountCredentials {
			if len(c.ComponentConfig.SAController.ServiceAccountKeyFile) == 0 {
				// It'c possible another controller process is creating the tokens for us.
				// If one isn't, we'll timeout and exit when our client builder is unable to create the tokens.
				klog.Warningf("--use-service-account-credentials was specified without providing a --service-account-private-key-file")
			}
			clientBuilder = controller.SAControllerClientBuilder{
				ClientConfig:         restclient.AnonymousClientConfig(c.Kubeconfig),
				CoreClient:           c.Client.CoreV1(),
				AuthenticationClient: c.Client.AuthenticationV1(),
				Namespace:            "kube-system",
			}
		} else {
			clientBuilder = rootClientBuilder
		}
		controllerContext, err := CreateControllerContext(c, rootClientBuilder, clientBuilder, ctx.Done())
		if err != nil {
			klog.Fatalf("error building controller context: %v", err)
		}
		saTokenControllerInitFunc := serviceAccountTokenControllerStarter{rootClientBuilder: rootClientBuilder}.startServiceAccountTokenController

		if err := StartControllers(controllerContext, saTokenControllerInitFunc, NewControllerInitializers(controllerContext.LoopMode), unsecuredMux); err != nil {
			klog.Fatalf("error starting controllers: %v", err)
		}

		controllerContext.InformerFactory.Start(controllerContext.Stop)
		close(controllerContext.InformersStarted)

		select {}
	}
	//...部分省略
	if !c.ComponentConfig.Generic.LeaderElection.LeaderElect {
		run(context.TODO())
		panic("unreachable")
	}
```

当`--leader-elect=true`时,`controller-manager`被告知以高可用方式运行,只有在抢到锁,成为leader才能作为集群控制组件,抢不到锁的只能在周期的去观察锁状况,在leader因为异常终止不能维护锁时,剩余的其他节点才能再次获得锁.

分布式锁的实现方式有很多,K8S使用了资源锁的概念(目前支持configMap和Endpoint),说的简单点就是通过维护这些资源来维持锁的状态,leader抢到锁后会将自己标记为锁持有者(`holderIdentity`字段),通过维护`renewTime`确保持续持有该锁,其他人则需要对比锁的更新时间以及持有者来判断自己能否成为leader.支持的资源锁代码如下:

```go
func New(lockType string, ns string, name string, client corev1.CoreV1Interface, rlc ResourceLockConfig) (Interface, error) {
	switch lockType {
	case EndpointsResourceLock:
		return &EndpointsLock{
			EndpointsMeta: metav1.ObjectMeta{
				Namespace: ns,
				Name:      name,
			},
			Client:     client,
			LockConfig: rlc,
		}, nil
	case ConfigMapsResourceLock:
		return &ConfigMapLock{
			ConfigMapMeta: metav1.ObjectMeta{
				Namespace: ns,
				Name:      name,
			},
			Client:     client,
			LockConfig: rlc,
		}, nil
	default:
		return nil, fmt.Errorf("Invalid lock-type %s", lockType)
	}
}

```

当`--leader-elect=true`时,`controller-manager`运行时进入如下代码:

```go
	id, err := os.Hostname()
	if err != nil {
		return err
	}

	// add a uniquifier so that two processes on the same host don't accidentally both become active
	id = id + "_" + string(uuid.NewUUID())
	rl, err := resourcelock.New(
        c.ComponentConfig.Generic.LeaderElection.ResourceLock,//资源锁类型
		"kube-system", //资源锁所在的命名空间
		"kube-controller-manager",//资源锁名称
		c.LeaderElectionClient.CoreV1(),
		resourcelock.ResourceLockConfig{
			Identity:      id, //锁持有者标记
			EventRecorder: c.EventRecorder,
		})
	if err != nil {
		klog.Fatalf("error creating lock: %v", err)
	}


	leaderelection.RunOrDie(context.TODO(), leaderelection.LeaderElectionConfig{
		Lock:          rl,//对资源锁的操作
		LeaseDuration: c.ComponentConfig.Generic.LeaderElection.LeaseDuration.Duration,//当其不是leader时对资源锁等待时间,这是根据上一次观察到的ack时间来测量的
		RenewDeadline: c.ComponentConfig.Generic.LeaderElection.RenewDeadline.Duration,//当其为leader时为资源锁的维护周期
		RetryPeriod:   c.ComponentConfig.Generic.LeaderElection.RetryPeriod.Duration,//
		Callbacks: leaderelection.LeaderCallbacks{ //资源锁抢占回调
			OnStartedLeading: run, // 在获取锁时,执行run方法
			OnStoppedLeading: func() { //在失去锁时打印错误日志并退出回调
				klog.Fatalf("leaderelection lost")
			},
		},
		WatchDog: electionChecker, //watchDog是关联的状况检查程序,如果不配置则为null
		Name:     "kube-controller-manager",
	})
```

在K8S1.10之前,`id=os.Hostname()`笔者当时偷懒,将3台master的hostname设置成相同,造成了一定的后果(记不清了),在1.10以后的版本中,id新加了uuid字段,以避免此种问题.如上代码,`rl(resouce lock)`变量被用于leader资源抢占,更详细说明见如上代码注释

再来看看对资源锁能做的操作:

```go
type Interface interface {
	// Get returns the LeaderElectionRecord
	Get() (*LeaderElectionRecord, error)

	// Create attempts to create a LeaderElectionRecord
	Create(ler LeaderElectionRecord) error

	// Update will update and existing LeaderElectionRecord
	Update(ler LeaderElectionRecord) error

	// RecordEvent is used to record events
	RecordEvent(string)

	// Identity will return the locks Identity
	Identity() string

	// Describe is used to convert details on current resource lockinto a string
	Describe() string
}

```



leader维护的资源锁结构代码如下:

```go
type LeaderElectionRecord struct {
	HolderIdentity       string      `json:"holderIdentity"`
	LeaseDurationSeconds int         `json:"leaseDurationSeconds"`
	AcquireTime          metav1.Time `json:"acquireTime"`
	RenewTime            metav1.Time `json:"renewTime"`
	LeaderTransitions    int         `json:"leaderTransitions"`
}

```



我们再来看看一个非leader的节点是如果成为leader的

//首先是入口

```go

leaderelection.RunOrDie(...)

```

//查询该函数

```go

func RunOrDie(ctx context.Context, lec LeaderElectionConfig) {
	le, err := NewLeaderElector(lec)
	if err != nil {
		panic(err)
	}
	if lec.WatchDog != nil {
		lec.WatchDog.SetLeaderElection(le)
	}
	le.Run(ctx)
}

```

//再看看run方法,可以看到其有使用acquire以及renew方法

```go

func (le *LeaderElector) Run(ctx context.Context) {
	defer func() {
		runtime.HandleCrash()
		le.config.Callbacks.OnStoppedLeading()
	}()
	if !le.acquire(ctx) {
		return // ctx signalled done
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	go le.config.Callbacks.OnStartedLeading(ctx)
	le.renew(ctx)
}

```

//先看看acquire方法,其使用了`wait.JitterUntil`函数无限循环,运行周期为`le.config.RetryPeriod`,通过调用`le.tryAcquireOrRenew()`方法来获取锁,获取到锁返回true,没获取到返回false,以及超时返回false
```//JitterUntilWithContext loops until context is done, running f every period.
//If jitterFactor is positive, the period is jittered before every run of f. If jitterFactor is //not positive, the period is unchanged and not jittered.
//If sliding is true, the period is computed after f runs. If it is false then period includes the runtime for f.
//Cancel context to stop. f may not be invoked if context is already expired```.
```

//acquire中已经持有资源的后续操作,调用`le.config.Lock.RecordEvent`()方法打印event

```go

func (le *LeaderElector) acquire(ctx context.Context) bool {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	succeeded := false
	desc := le.config.Lock.Describe()
	klog.Infof("attempting to acquire leader lease  %v...", desc)
	wait.JitterUntil(func() {
		succeeded = le.tryAcquireOrRenew()
		le.maybeReportTransition()
		if !succeeded {
			klog.V(4).Infof("failed to acquire lease %v", desc)
			return
		}
		le.config.Lock.RecordEvent("became leader")
		klog.Infof("successfully acquired lease %v", desc)
		cancel()
	}, le.config.RetryPeriod, JitterFactor, true, ctx.Done())
	return succeeded
}



```

//renew方法只有在其`OnStartedLeading`时才会调用,实现方式和acquire差不多,Until也是调用了`JitterUntil`函数

```go

func (le *LeaderElector) renew(ctx context.Context) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	wait.Until(func() {
		timeoutCtx, timeoutCancel := context.WithTimeout(ctx, le.config.RenewDeadline)
		defer timeoutCancel()
		err := wait.PollImmediateUntil(le.config.RetryPeriod, func() (bool, error) {
			done := make(chan bool, 1)
			go func() {
				defer close(done)
				done <- le.tryAcquireOrRenew()
			}()

			select {
			case <-timeoutCtx.Done():
				return false, fmt.Errorf("failed to tryAcquireOrRenew %s", timeoutCtx.Err())
			case result := <-done:
				return result, nil
			}
		}, timeoutCtx.Done())

		le.maybeReportTransition()
		desc := le.config.Lock.Describe()
		if err == nil {
			klog.V(5).Infof("successfully renewed lease %v", desc)
			return
		}
		le.config.Lock.RecordEvent("stopped leading")
		klog.Infof("failed to renew lease %v: %v", desc, err)
		cancel()
	}, le.config.RetryPeriod, ctx.Done())

```

//最后当renew中将对资源锁进行更新,其调用了`le.maybeReportTransition()`方法

```go

func (le *LeaderElector) maybeReportTransition() {
	if le.observedRecord.HolderIdentity == le.reportedLeader {
		return
	}
	le.reportedLeader = le.observedRecord.HolderIdentity
	if le.config.Callbacks.OnNewLeader != nil {
		go le.config.Callbacks.OnNewLeader(le.reportedLeader)
	}
}
    
 
    

```

上文中`tryAcquireOrRenew()`函数示例如下:

```go

func (le *LeaderElector) tryAcquireOrRenew() bool {
    //省略部分代码
    //超时返回false
	if le.observedTime.Add(le.config.LeaseDuration).After(now.Time) &&
		!le.IsLeader() {
		klog.V(4).Infof("lock is held by %v and has not yet expired", oldLeaderElectionRecord.HolderIdentity)
		return false
	}
    //抢占失败
	if err = le.config.Lock.Update(leaderElectionRecord); err != nil {
		klog.Errorf("Failed to update lock: %v", err)
		return false
	}
    //自身已经占有资源锁或者抢占成功
	if le.IsLeader() { //自身为资源持有者
		leaderElectionRecord.AcquireTime = oldLeaderElectionRecord.AcquireTime
		leaderElectionRecord.LeaderTransitions = oldLeaderElectionRecord.LeaderTransitions
	} else { //本身非资源持有者
		leaderElectionRecord.LeaderTransitions = oldLeaderElectionRecord.LeaderTransitions + 1
	}

	le.observedRecord = leaderElectionRecord
	le.observedTime = le.clock.Now()
	return true
}

```
















