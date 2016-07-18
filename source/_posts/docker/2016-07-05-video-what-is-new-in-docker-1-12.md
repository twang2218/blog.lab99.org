---
layout: post
category: docker
title: 视频笔记：Docker 1.12 新功能
date: 2016-07-05
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - What’s New in Docker 1.12
by Mike Goelzer, Andrea Luzzardi from Docker

{% owl youtube FgXJKw37po8 %}

<https://www.youtube.com/watch?v=FgXJKw37po8>

{% owl tencent b0314l51xc7 %}

<http://v.qq.com/x/page/b0314l51xc7.html>

# Swarm Mode

在Keynote 演讲时，是3个虚拟机来做的演示。

在第一个机器上执行：

```bash
docker swarm init
```

这个第一台`swarm`主机就自动变为 `manager`。

在第二台机器上执行：

```bash
docker swarm join <ip of manager>:2377
```

第二台主机就作为普通节点加入进了这个 swarm。

然后，可以重复这个过程，在不同的主机上执行该命令，加入这个swarm。非常简单的两条命令，就可以构建一个集群。

# Services

创建服务

```bash
docker service create \
    --replicas 3 \
    --name frontend \
    --network mynet \
    --publish 80:80/tcp \
    frontend_image:latest
```

这是 1.12 开始的概念，在 swarm 中创建一个服务，声明服务的状态，然后 swarm 引擎会负责维护调度来保持这个状态。

创建第二个服务也很简单，为了让这两个服务之间可以通讯，只需要指定该服务处于同一个网络中即可。

```bash
docker service create \
    --name redis \
    --network mynet \
    redis:latest
```

这两个服务可以通过<服务名>来互相通讯，通过的是内置的DNS进行的服务发现。

# Node Failure

Docker Swarm Mode 没有单点故障

当swarm中的一个节点挂了后，其上运行的所有容器就都挂了。这个时候服务的实际状态就发生了改变，当初设定服务的时候，所指定的状态（比如`--replicas=3`）不再满足，这时 swarm engine 就会介入进来，试图在其他节点上启动对应容器来恢复服务。

# Scaling

这个操作和 `docker-compose scale` 的方法一样。

```bash
docker service scale frontend=6
```

# Global Services

这是 DockerCon16 的 keynote 中没有涵盖的部分。

`Global Service` 是说这个服务希望在 `Swarm` 中每一个主机上运行。

比如我们需要日志收集统计之类的工具，这些容器我们希望在每一个 Swarm 主机上都运行。创建 Global Service 的方式和前面的做法基本一样，只需要增加 `--mode=global` 参数即可。

```bash
docker service create \
    --mode=global \
    --name prometheus \
    prom/prometheus
```

# Constraints

有时候我们需要某些容器运行在特定主机上，比如数据库的服务器我们希望跑在SSD的主机上，而前端服务器跑在有公网IP的主机上，某些服务我们希望跑在内存比较大的服务器上。这些需求，我们通过docker daemon的`label`来实现。

```bash
docker daemon —label=com.mycompany.storage=“ssd”
```

在建立服务的时候，我们可以通过 `--constraint` 参数来指定服务运行的节点的`label`。

```bash
docker service create \
    --replicas 3 \
    --name frontend \
    --network mynet \
    --publish 80:80/tcp \
    --constraint com.mycompany.storage=“ssd” \
    frontend_image:latest
```

# `Services` → `Tasks` → `Containers`

创建一个 `redis` 服务；假设我们需要3个副本，这就有3个`Tasks`；而每个`Task`则去运行一个容器。三级的概念。

最初的理解可能会认为服务是一群容器的集合，不太理解为什么会有中间的Task这一层。这是为了将来的扩展而考虑的，目前Task只包含有容器。但是将来 `Task` 或许除了可以运行`容器`外，还可能运行一个`Unikernel`，运行一个`VM`等等。

# `Stack` 是 `Service` 的集合

一个 `Stack`，也就是一个 `App`，实际上是由一群`服务`组成。比如我们有个 Web app，必然包括前端 Web 服务、中间件服务、数据库服务，可能还有其它的如 `Redis` 之类的缓存服务，还包括日志服务等等。这些服务的集合，是 `Stack`。

# Distributed Application Bundle (.dab) 声明了一个 Stack

现在处于比较前沿的试验阶段，需要社区的关注和反馈。目前已经集成进 `Docker 1.12` 以及 `docker-compose`中。

# Swarm mode is optional

可以选择用或者不用，`Docker 1.12` 向后兼容，过去的用法没有问题。这只是提供另一种选择。

# Routing Mesh

还是之前的3个副本的前端服务的例子，服务设定的是监听 `80` 端口。这样的声明会让 `swarm` 中所有的节点（包括 `manager`）都监听`80`端口（`swarm-wide ingress port`）。而3个副本，假设`worker 1`上跑了一个，`worker 2`上跑了2个（都守护80端口不冲突么？以前端口属于资源，这样声明的服务必然不会在一个`worker`上）

假设用户访问了负载均衡服务然后转到了 `worker 2` 的80端口上，恰好 `worker 2` 上有两个 `frontend` 容器。 所以这个访问肯定没有问题。会由` worker 2` 上的两个容器中的一个负责处理。

那么如果负载均衡将用户的请求转移到了 `worker 3` 呢？`worker 3` 上没有任何 `frontend` 容器在运行。过去这会失败，而现在有了 `routing mesh` 后， `worker 3` 会将请求转发到拥有 `frontend` 的容器的 `worker 2` 身上，于是请求得到了处理。

是的，这会增加一跳，但是由于使用的是内核技术(`IPVS`, `kernel space package routing`)，效率是非常高的。

这样的做法会有一种概念，让整个的 Swarm 集群表现的像一个服务器一样是个整体。

# Security by default

Cryptographic Node Identity

没有 insecure mode，在 1.12 的 Swarm mode 情况下，没有关闭安全的选项，这是有意如此。Docker的理念是安全不应该是累赘，应该简单易用，没有关闭的必要性。

* TLS 是互相认证
* TLS 加密
* Certificate rotation

# Container Health Check in `Dockerfile`

可以在 `Dockerfile` 中指定如何检查这个镜像生成的容器是否正常。比如，对于一个提供 Web 服务的镜像，其 `HEALTHCHECK` 命令可能如下：

```bash
HEALTHCHECK —interval=5m —timeout=3s —retries 3 CMD curl -f http://xxx || exit 1
```

这是说每过5分钟看一下是不是能够通过80端口取得 index 页面，如果连续3次都失败了，那就说明该服务出问题了。将健康状态设为`broken`，然后由 `swarm` 之类的上层编排工具负责删除这个容器、重新启动等调度工作。

# New Plugin Subcommands

```bash
docker plugin install mylovelyuser/no-remove
docker plugin enable no-remove
docker plugin disable no-remove
```

Docker engine 将会去 Docker Hub 取得对应的 plugin。

而且 Plugin 有一个 manifest 来指定其所需的权限。

用户安装的时候将会提示用户是否赋予该 plugin 对应权限。

# Orchestration Deep Dive - Andrea Luzzardi

## Swarm Topology

在Swarm中，所有节点都是一样对待的。节点分为两种角色，`Manager` 和 `Worker`。角色动态的，二者可以互相转换(`promote`/`demote`)。

## Docker Swarm Communication Internals

`Manager` 和 `Worker` 属于不同的网络，`Manager` 属于一个 `Raft consensus` 组，有自己通讯的网络渠道；而 `Worker` 同属于 `Gossip` 网络，二者之间用`gRPC`通讯。

## Quorum Layer

内置了 `Datastore`，所以不需要外置 `key-value store` (`etcd`, `consul`, `zookeeper`,…)

# Node Breakdown

```text
API
Orchestrator: Check the difference of state
Allocator
Scheduler
Dispatcher
    ⬆️
Worker
Executor
```

## 内置负载均衡

每个服务都有一个 `Virtual IP`，内置的服务发现将`<服务名>`解析为 `Virtual IP`，而 `IPVS` 将会进行负载均衡到容器 `IP`。

## Ingress 负载均衡

`ELB`, `HAProxy`, `Nginx`拥有`公共IP`，并将请求转发到集群中的各个主机上，主机内通过服务发现指向服务的`Virtual IP`，`IPVS` 则在跨宿主的 `Ingress Network` 上负载均衡到其它提供该服务的容器上。

所有节点通讯默认安全全部加密，`manager`内置CA，`certificate rotation`。
