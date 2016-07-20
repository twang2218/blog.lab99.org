---
layout: post
category: docker
title: 视频笔记：在容器内思考 - 一个持续部署的故事 - Maxfield Stewart
date: 2016-07-07
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Thinking Inside the Container - A Continuous Delivery Story
by Maxfield Stewart, Riot Games

{% owl youtube YViFZBoKqjg %}

<https://www.youtube.com/watch?v=YViFZBoKqjg>

{% owl tencent h03148603la %}

<http://v.qq.com/x/page/h03148603la.html>

# League Legends

* 67 millions player/ month, 27 m/daily, 7.5 m at peak.
* 1.25 Milions Build / Year
* 10 - 14 k containers / week
* 120 build jobs / hour

# A Containerized Build Farm

`Jenkins` → (`Docker API`) → `Swarm` → (`Docker API`) → `Build Hosts` → (`Docker API`) → `DryDock`

`Jenkins` 还会直接通过SSH连接`Build Host`

每一个Build Host都是 `CentOS 7.2`/`Docker 1.10.3` + `cAdvisor` + `Docker-GC` + `Container Metrics`, 4 core/32GB RAM/120GB LVS

# Story Time

两年前，2013，在一个 Jenkins 服务器上，运行3500+ unique build jobs ，换句话说就是每小时 650+ 个build。90+ Build slave

`Engineers` → `Ticket(s)` → `Build Team`

实际上基本都被`Ticket`埋了……

## 我们到底想要什么？

* 团队必须有快速行动的能力
* 产品必须拥有自己的技术栈
* 配置可以像代码一样，希望需求方可以用code定义环境

曾经考虑过很多种方案： `Packer`, `Vagrant`, `Openstack`, `AWS EC2`, `Azure`, `vmware`

2014年的时候，突然`docker`出现了，由于团队太过繁忙，没有意识到这个东西的重要性。直到有一天，有一个`ticket`出现说，你们能够在build环境中部署`Docker`么？如果可以就太赞了。

第一反应，会觉得WTF，又有一个新的东西想部署了？但是turns out, it’s great。

# Jenkins Primer

`Jenkins` 是主从结构，在 Jenkins 眼中，其它的从构建主机是各种`label`而已，比如 `Win32` + `Java` + `TeamA`,或者 `CentOS7` + `Java` + `TeamB` …

而开发人员在写构建需求的时候，只需要`label`上自己所需的环境：`Win32` + `Java` + `TeamA`之类的即可，`Jenkins`会根据这些`Label`决定如何调度构建任务

# Docker Container as Jenkins Slave

现在 `Jenkins` 上估计有很多 `Docker` 的插件了，但是在1-2年前什么都没有，需要找出一种办法让 `Jenkins` 以为容器就是 `Build Slave`，而且还可以让开发人员提供 Dockerfile 的途径，并且可以扩展。

后来通过google在Docker Hub上找到了一个Dockerfile，可以让容器启动后模拟 Jenkins Build Slave。基本上是构建一个包括了 `ssh`, `jdk`, `git`, `jenkins`的容器

# 容器非常臃肿

由于他们构建了一个肥镜像，前面几层还好，最后一层构建开发人员所需的镜像时，非常臃肿。

# Provisioning and Plugins

* Docker Plugin: <中选>
* Mesos Plugin:
* Kubernetes Plugin:

Jenkins Docker Plugin UI非常基本，URL, Docker Image, 容器选项等等。

然后设法用`Groovy`做了个结合二者API的脚本。现在开发人员可以直接提供`Dockerfile`，然后Jenkins自动识别构建。

# We Created a Monster

`Garbage In-Gabage out` Paradigm

不是所有开发人员都理解这种构架，所以有的时候开发人员提供的`Dockerfile`，或许本地构建没问题，但是在 `Jenkins` 构建 `Slave` 上会出问题，然后 `Jenkins` 会非常尽职的去努力工作，也就是创建很多的容器去满足这个需求，最后面对的是巨大的`docker rmi`的job。

# We Need to Ispect Our Containers

“Infrastructure as Code” Managing Servers in the Cloud

最开始是手动检查`Docker Image`，很快就意识到这是错误的做法。于是创建了个脚本 `./harbormaster` ，使用`Go`写的，非常简单，就是检查这个`Image`是不是满足各种需求，比如`ssh`啊之类的。

# But it needs to Scale

所有这些最开始会只在一个`Docker Host`上跑，因为`Docker Plugins`只支持一个`Docker API`。当时就在想，要是有一个办法，可以使用一个`Docker API` 然后它理解负载均衡任务调度之类的事情，然后它去控制一群服务器多好。恰好这个时候`Docker Swarm 0.1`发布了，所以他们立即开始进行尝试，他们第一次试用的时间估计是`Swarm 0.2`。

# Putting It All Together

开发人员用 `Dockerfile` 构建了一个镜像，扔给 `Registry`，并且通知 `Harbor Master` ，然后 `Harbor Master` 开始检查这个镜像，如果通过，会通知 `Swarm Master` 下达任务，`Swarm Master` 会调度任务到集群中的某个节点。节点开始从 `Registry` 下载任务。

听起来很美好，他们让开发人员尝试，可是现实很残酷。开发人员构建的镜像大约`3GB`左右，用了很久`push`到了`registry`后，测试并没有开始。原因是，`Swarm` 中的 `Docker Host` 同样需要很久去下载这个`3GB`的镜像，下载后才可能测试。所以开发人员抱怨说你这个东西不好用，提交了任务许久都没有开始测试。

## Grovvy 写的 Jenkins 构建 Job

内容很简单

```groovy
node ('Awesome-Build-Label') {
    git branch: "master", url: "git@github.com:maxfields2000/awesome.git"
    sh "./buildme.sh"
}
```

# Dockerception

很快就出新的麻烦了，因为Docker很好用，于是大家开始都用Docker了。所以很快有人需要Docker in Docker。因为很多人希望能够用Jenkins测试构建Docker 镜像是否成功。

最终，他们独立出来了一个机器，称为`DRYDOCK`，然后所有那些需要构建Docker镜像的任务，都指向这个机器，这样就不会出现DIND的问题，而且也不会把Build Slave集群搞崩了。真出了什么问题，直接把这个机器的清空重新部署即可。

# How do you actually build it

<http://engineering.riotgames.com>
<https://github.com/maxfields2000/dockerjenkins_tutorial>

# 听起来很简单

举了两步画猫头鹰的例子：第一步花两个圆；第二步画剩下的部分……

两年前我们就开始使用`Docker`了，但是今天我们才来这里给大家演讲，显然中间发生了写什么事情，不然我们去年就来了。

# Lesson 1 - Docker Isn’t “Simple”

* Dockerfile 的撰写需要有良好的系统管理知识背景

好多人的问题实际上是 `Dockerfile` 的书写问题，然后就转化为认为这东西不可能在 Docker 里构建。其实 Docker 用户都知道事实并非如此。他们的解决办法就是Teaching。

* 用来构建 Docker Images 的 Docker Images 是 Dockerception
* Docker “Voodoo and Black Magic” 问题

# Lesson 2 - 容器 != 虚拟机

虽然看起来很像虚拟机，比如你可以在里面 `apt-get install`，但是Docker不是虚拟机。很多事情是不可以在里面做的。

* 无法挂载远程文件系统
* 容器不保存状态
* 对于构建时和运行时有不同的规矩

# Lesson 3 - Garbage Collection

docker build → docker run → docker pull → volume

github: `spotify/docker-gc`

# Lesson 4 - Maintenance/Failure

* Pull hosts on/offline

Docker 经常升级，当然我们都想使用最新的版本，所以这就必须涉及一个如何升级维护、上线下线服务的流程。

* Update All Images
* Rolling Restarts

Docker 和其它程序一样，会 Crash，所以需要一些机制去发现维护这些故障。

# Lesson 5 - 到底怎么升级？

升级一定要有计划，升级需要考虑很多细节，比如如果Swarm升级了，那么现有的使用Docker API的插件是否还会继续支持？一般悬。

# Lesson 7 - Credentials & Security

* 什么应该放到 `Base Image` 里？
* 把`SSH key`扔到registry里？
* 源代码中的password？
* 所有密码类的东西都用环境变量？

现有的做法是在 Jenkins Master 上存储所有 Credentials，然后通过它以环境变量的形式发送给测试部署环节，只需要确保 Jenkins Master 安全即可。目前还有别的方法，他们暂时采用的是这种办法。

# 我们成功了吗？

* Over 1200 New Build Jobs Created
* 30% 的环境是容器
* 构建环境变化、创建、修复的Ticket消失了
* 我们不只再是 Build Team 了

因为他们所有的构建过程都自动化了，而构建环境都 Docker 化了，所以不再需要他们了。但是并不是说他们都被开了，而是都成为了开发团队的一部分，因为他们都成了 Docker 专家，帮助开发人员构建Docker镜像。
