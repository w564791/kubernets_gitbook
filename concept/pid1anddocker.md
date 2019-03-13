FROM https://www.fpcomplete.com/blog/2016/10/docker-demons-pid1-orphans-zombies-signals

在使用docker时需要考虑很多极端的情况,例如多进程,信号,关于这个问题可能最著名的帖子来自[ Phusion blog](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/).在这里我们将看到如何直接看到这些问题的例子,此处基于[fpco/pid1](https://hub.docker.com/r/fpco/pid1/)镜像来探讨.

Phusion博客文章建议使用他们的[baseimage-docker](http://phusion.github.io/baseimage-docker/),此image提供了一个my_init作为entrypoint,用于处理此处描述的问题,以及引入一些额外的OS功能,比如syslog处理.不幸的是，我们遇到了与syslog-ng的的的Phusion的使用问题，特别是与它创建了CPU使用100％并且不能被杀死的进程.我们还在调查根本原因,但实际上我们发现syslog的使用情况远不如简单的一个好的init进程，这就是为什么我们用简单的 [pid1 Haskell package](https://github.com/fpco/pid1#readme)创建了 [pid1/pid1](https://hub.docker.com/r/fpco/pid1/)Docker镜像.

此博客文章旨在互动:通过打开终端和运行命令以及阅读文本,您将获得最大的收益.看到你的Ctrl-C完全无法杀死一个进程会更有动力.

**NOTE**: 我们在Haskell中编写自己的实现的主要原因是能够将它嵌入[到堆栈构建工具中](http://haskellstack.org/)。还有其他可用的轻量级init进程，例如 [dumb-init](https://engineeringblog.yelp.com/2016/01/dumb-init-an-init-for-docker.html)。我也[写过关于使用dumb-init的博客](https://www.fpcomplete.com/blog/2016/08/bitrot-free-scripts)。虽然这篇文章使用了`pid1`，但与其他init进程相比，没有什么特别之处。

## Playing with entrypoints

docker有一个entrypoint的概念,其提供了`docker run`的默认命令,例如考虑与Docker的这种交互：

```
$ docker run --entrypoint /usr/bin/env ubuntu:16.04 FOO=BAR bash c 'echo $FOO'
BAR
```

这是有效的，因为上述内容相当于：

```
$ docker run ubuntu:16.04 /usr/bin/env FOO=BAR bash -c 'echo $FOO'
```

当然我们也能在命令行覆盖`entrypoints `(就像上面我们做的),当然我们也能在dockerfile中指定(我们稍后会做),ubuntu的docker image默认的entrypoint为空,意味着提供的命令将直接运行而不进行任何包装,我们将使用`/usr/bin/env`作为entrypoint模拟该操作,因为在当前发布的docker中尚不支持将entrypoint切回为空,当你run`/usr/bin/env foo bar baz`,env进程将exec 到foo命令,使`foo`成为`pid`1的进程,我们的目的是为其提供与空entrypoint的能力.

`fpco/pid1` 和`snoyberg/docker-testing`镜像都将`/sbin/pid1`作为entrypoint,在例子中,我们明确的使用`--entrypoint /sbin/pid1` ,这只是弄清楚在使用哪个entrypoint,如果没有该选项,那么行为与指定参数无差异.

## Sending TERM signal to process

我们将从[sigterm.hs](https://github.com/snoyberg/docker-testing/blob/master/sigterm.hs)程序开始,运行ps命令(很快就能看到),然后发送`SIGTERM`信号给它自己并且一直循环下去,在Unix系统上,接收到`SIGTERM`信号时的默认进程行为是退出.因此,我们希望我们的进程在运行时才会退出.

```
$ docker run --rm --entrypoint /usr/bin/env snoyberg/docker-testing sigterm
  PID TTY          TIME CMD
    1 ?        00:00:00 sigterm
    9 ?        00:00:00 ps
Still alive!
Still alive!
Still alive!
^C
$
```

进程忽略了`SIGTERM`命令并且保持运行中,直到我使用了Ctrl+C(我们将在后面看发生了什么),sigterm代码库中的另一个特性，如果你给它参数`install-handler`，它将显式安装一个SIGTERM处理程序，它将终止进程。也许令人惊讶的是，这对我们的应用产生了重大影响：

```
$ docker run --rm --entrypoint /usr/bin/env snoyberg/docker-testing sigterm install-handler
  PID TTY          TIME CMD
    1 ?        00:00:00 sigterm
    8 ?        00:00:00 ps
Still alive!
$
```

其原因是一些Linux内核魔术：内核专门处理具有PID 1的进程，并且在接收SIGTERM或SIGINT信号时默认不会终止进程。这可能是非常令人惊讶的行为。有关更简单的示例，请尝试在两个不同的终端中运行以下命令：

```
$ docker run --rm --name sleeper ubuntu:16.04 sleep 100
$ docker kill -s TERM sleeper
```

注意`docker run`命令如何不退出，如果你检查你的`ps aux`输出,你会看到该过程仍在运行.那是因为`sleep`程序不是设计为PID 1，并没有安装特殊的信号处理程序。要解决此问题，您有两个选择:

1. 确保从`docker run`运行的每个命令都明确处理`SIGTERM`.
2. 确保您运行的命令不是PID 1，而是使用旨在正确处理`SIGTERM`的进程.

让我们看看`sigterm`程序如何与我们的`/sbin/pid1`entrypoint一起工作：

```
$ docker run --rm --entrypoint /sbin/pid1 snoyberg/docker-testing sigterm
  PID TTY          TIME CMD
    1 ?        00:00:00 pid1
    8 ?        00:00:00 sigterm
   12 ?        00:00:00 ps
```

该程序立即退出，正如我们所愿.但是看看ps输出:我们的第一个进程现在是pid1而不是`sigterm`,因为`sigerm`是作为一个不同的PID启动的(此处为pid8),Linux内核的特殊外壳不起作用，默认的SIGTERM处理是活动的.要完全了解我们的情况:

1. 我们创建了容器，并在其中运行命令`/usr/sbin/pid1 sigterm`.
2. pid1程序以PID-1开始，执行其业务，然后`fork / execs sigterm`可执行文件.
3. `sigterm`将`SIGTERM`信号发送给到自身，导致它退出.
4. pid1看到它的子进程于SIGTERM信号退出（==信号15）并退出，退出代码为143（== 128 + 15）。
5. 由于我们的PID1已退出了，我们的容器也会退出。

这不仅仅是`sigterm`的一些魔力，你可以用sleep命令做同样的事情：

```
$ docker run --rm --name sleeper fpco/pid1 sleep 100
$ docker kill -s TERM sleeper
```

与上面ubuntu图像结果不同,这将立即杀死容器,这是由于`fpco/pid1`镜像使用了`/sbin/pid1`作为entrypoint.

**NOTE** : 在sigterm的情况下,它将TERM信号发送给自己,事实证明,你不需要一个带信号处理的特殊PID1过程，任何事情都可以.例如,`docker run --rm --entrypoint /usr/bin/env snoyberg/docker-testing /bin/bash -c "sigterm;echo bye"`但是使用sleep将证明需要一个真正的信号感知PID1过程.

### Ctrl-C: sigterm vs sleep

