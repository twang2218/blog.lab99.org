---
layout: post
category: docker
title: 视频笔记：Moby 的 Cool Hack session
date: 2016-07-12
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Moby’s Cool Hack Session DockerCon
by Mano Marks and Kristie Howard

{% owl youtube 75vm6rRb6K0 %}

<https://www.youtube.com/watch?v=75vm6rRb6K0>

{% owl tencent k03143nuw7k %}

<http://v.qq.com/x/page/k03143nuw7k.html>

# 内容

每年DockerCon结尾都会选出最有创意的项目。

# Entropy: failure injection management API for Docker platforms by Jeff Nickoloff

以前在AWS工作，后来给很多公司做过咨询。在AWS的时候8个人的团队管理300多个服务。

> **If something can fail, it will fail.**

对于运维来说，最好是经常 `fail`，而不是坐在定时炸弹上，然后某天`3am`被叫醒后查了很久，最后在代码中看到一行注释，“这种情况估计不会发生……”

从工程角度看问题，最好是从如何让桥拆掉角度来看，而不是从如何组装这个桥的角度。

## Project Entropy

<https://github.com/buildertools/entropy>

Demo中，用一个`compose`文件，启动一个3节点`swarm cluster`，使用的是Docker In Docker （image: `docker:1.10-dind`)，运行在 `Docker for Mac`, `1.12-rc2`上。

```bash
demo entropy-client create --frequency 10 --probability .50 --failure latency --image allingeek/gremlins --criteria service=PingGoogle
```

利用Docker in Docker，来引入延时，甚至失败。

# Serverless Docker by Ben Firshman

## Serviceless == Docker

```python

# 引入Docker Library
>>> import dockerrun

# 连接 Swarm API
>>> client = dockerrun.from_env()

# 然后运行指定的镜像，给定参数，并且把结果返回
>>> client.run("bfirsh/leftpad", ["foo", "5"])
'  foo\n'
```

`dockerrun` package 是 Ben 写的一个很简单的利用 `docker-py` API的包。可以用函数调用的形式执行 Docker 镜像，并且把结果返回。

在 DockerCon 的例子中，最常见的是 `🐱` vs `🐶` 的投票 app。这个 app 有5个一直在运行的容器而构成。

> `Voting App` → `Message Queue` → `Worker` → `database` → `Result App`

在 Ben 的演示中，他没有持续运行 `Message Queue` 和 `Worker` 这两个容器，而是直接用`dockerrun` 启动一个容器，去记录该投票结果，直接送到数据库。这样只有在有任务的时候才会运行记录投票的容器，没任务的时候就不去运行任何东西。

结构就改变为：

> `Voting App` → `Record Vote Task` → `Database` → `Result App`

然后再观察这个构架，会发现 `Voting App` 和 `Result App` 这是两个 `HTTP` 服务，而这两个服务就是在那里等着用户请求。似乎这个也可以改变 s`erviceless`，`functional` 的方式，只有在需求的时候才运行。幸运的是这种方式已经几十年前就解决了，叫做 `CGI`(*……😓*)。

对于 `Voting App` 来说，很容易，因为 `Python` 中内置了 `CGIHandler()` 可以直接执行应用返回结果。这功能已经存在几十年了。

而对于 `Result App` 有些麻烦，因为它是 `Node.js App`，非常现代，没有这么古老的机制。很遗憾啊，于是 Ben 决定用一个非常好的支持下一代 `Serviceless` 的语言重写了 `Result App` - `Perl` (*……😓还能再古老些么？？*)

然后现在结构就更进一步变化了：

> `Entrypoint` → { `handle_vote` → `process vote`, `handle_result` } → `database`

访问服务 <http://localhost/vote/> 后会看到已经见过很多次的 `vote app`。而下方的 `Container ID`，实际上每次请求，都是运行的一个新的 Container 的 ID，是在变化的，没有一次相同，而不是多个容器的负载均衡。

基本上，除了入口点和数据库，没有任何长期运行的容器/服务。所以这是 `Serviceless`。

这个demo并不是说要推荐大家都放弃现代Web技术，而回去用CGI，而是展示了几个有意思的事情：

* 可以把一系列function封装为容器（更细粒化的微服务？）
* 这些容器是运行于swarm上的，所以可以随意扩展
* 从容器中运行别的容器

## 我们今天Swarm集群环境其实是面临和 90年代`CGI`一样的问题

Ben 引申了一个非常有趣的相似性。

在90年代，CGI是非常吸引人的技术，因为在此之前只能够提供静态页面，而CGI可以提供动态的内容；而今天在Swarm这种集群环境中，其实面临的是同样的问题，这次静态的不是内容，而是服务/容器/服务器，Docker可以让这些静态的东西动态化，不同层次的容器完全可以有某些容器根据需求而动态创建和销毁，从前端到中间件到数据库，都可以在容器技术下实现全动态环境。

<https://github.com/bfirsh/serverless-docker#serverlessdocker>

# In-the-air update of a drone with Docker and Resin.io

* 跨平台构建
* 嵌入式设备最小系统
* 容器 Deltas
* 嵌入式升级 Strategies

## Drone 是运行于 `Resin.io` 架构的。

`Resin.io` → `Linux Kernel` + `yocto` + `Docker` + `Resin.io` Container + `App` Container + `Extensions` Container

## 升级 Handover Strategy

现在 `Drone` 上跑的是 `Version 1`，将要升级到 `Version 2`。策略并非是杀掉 `V1` 然后运行 `V2`，而是 `V2` 容器准备好后，先运行，运行后 `V1` 容器开始向 `V2` 容器交接资源(`rotors`, `camera`, `websocket`)等。交接结束后，`V2` 实际上已经在承载服务了，`V1`没用了，所以此时`V1`会向上级申请说`kill me`。

这样升级过程非常平滑，只有非常小的gap。

现在看到的Web界面是Drone身上跑的一个Web服务器，返回实时的统计数据。

现在代码中有新的功能提交了，`git push resin master` 后，会触发构建镜像，并且`push`到`docker registry`，然后会触发部署流程，Drone会开始下载新版本的镜像准备运行。接下来会在Drone control panel上看到陀螺仪会有些抖动，这些抖动是`V1`和`V2`在交接sensor控制权时产生的gap，非常小。而且升级成功后，会看到新的热成像camera开始工作了。
