[原文地址](https://coreos.com/flannel/docs/latest/alicloud-vpc-backend.html)

## 1.创建共有子网网络或私有网络（通过nat进行公网访问）

本例直接使用共有子网的VPC作为例子

![](/assets/import333.png)

查看该VPC下的公有子网

![](/assets/import12345.png)![](/assets/impo123rt.png)

查看路由表：

![](/assets/import-luyou.png)

## 2.创建IAM策略，需要的策略包含：

```
ec2:CreateRoute
ec2:DeleteRoute
ec2:ReplaceRoute
ec2:DescribeRouteTables
ec2:DescribeInstances
```

json示例如下：

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
          "Effect": "Allow",
          "Action": [
              "ec2:CreateRoute",
              "ec2:DeleteRoute",
              "ec2:ReplaceRoute"
          ],
          "Resource": [
              "*"
          ]
    },
    {
          "Effect": "Allow",
          "Action": [
              "ec2:DescribeRouteTables",
              "ec2:DescribeInstances"
          ],
          "Resource": "*"
    }
  ]
}
```

## 

## 3.创建IAM角色

## ![](/assets/import-role.png)4.启动实例

启动实例时需注意添加相应的IAM角色，以及对应的网络关系

![](/assets/import-ec2.png)5.

