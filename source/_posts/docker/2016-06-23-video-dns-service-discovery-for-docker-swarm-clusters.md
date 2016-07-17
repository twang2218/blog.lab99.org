---
layout: post
category: docker
title: 视频笔记：为 Docker Swarm 设计的 DNS 服务发现 - Ahmet Alp Balkan
date: 2016-06-23
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

DNS Service Discovery for Docker Swarm Clusters
by Ahmet Alp Balkan, Microsoft (2015/12/7)

{% owl youtube WXESsPqC8to %}

<https://www.youtube.com/watch?v=WXESsPqC8to>

{% owl tencent b03149ny29m %}

<http://v.qq.com/x/page/b03149ny29m.html>

# Service Discovery

帮助一个服务找到另一个服务的地址

不过因为横向扩展，导致实际上是一群地址

而且这些地址可能有的会失效，比如对应的服务挂了

# 通常方法

`Overlay Networks`
服务发现 → `/etc/hosts`，但这不是解决办法，还需要负载均衡。（*注：这个讲座是去年的，讲的是在Docker 1.10之前的实现方式，以及提出的解决方案，而现在已经内置 DNS了*）

反向代理：`HAProxy`, `Nginx`。负载均衡、健康检查、Connection draining。但是所有的traffic都会经过反向代理，这是另一个单点故障，而且会增加延时。

`Interlock`，通过`Docker Events API`来监听容器的建立，从而更新 `HAProxy`。
`Registrator`，也一样通过`Events API`，然后保存到 `consul`，然后利用`consul-template` 来更新 `nginx`反向代理。

`kube-proxy` 处理 `kubenetes` 的负载均衡，做的是比较正确的。

# DNS

DNS诞生就是用来解决名字/服务到IP的解析

`DNS A/AAAA`记录没有端口信息。
`SRV`记录，如果给定 `hostname`，会返回`<ip, port, weight>`

问题是没有什么东西用`SRV`。

使用DNS的话，非常简单，没有额外的部分；
但是不能够使用动态端口分配了（`SRV`的问题）；
可以减少中间件的加载时间(`DNS TTL`)；
问题是有些东西(如`Java`)不遵守`TTL`;
好处是可以使用现有堆栈；
但是没有健康检查；
好处是可以shuffling ip来负载均衡。

# Mesos-DNS

为 Mesos 设计的，部署一次后，就可以忘掉他了。设计非常好。

# SkyDNS

非常像 Mesos 的设计，kubenetes 默认的 DNS

# wagl

受 Mesos-DNS 启发，但是为 `Swarm` 设计。而且还是运行在容器内。

建议 `wagl` 安装在所有的`master`身上。

在 docker engine 中加入 `--dns master01 --dns master02 …`

# 部署 wagl

```bash
docker run -d --restart=always --name=dns \
    -p 53:53/udp \
    --link=swarm-master:swarm \
    ahmet/wagl \
    wagl --swarm tcp://swarm:2375
```

# demo

在三个`master`上运行了`wagl`

然后在`swarm`运行一个容器

运行了3个 `nginx` 容器作为 `API`

```bash
docker run -d -p 80:80 -l dns.service=api nginx
```

在运行一个容器来试图通讯api

```bash
docker run -it —dns master01 busybox

dig _api._tcp.swarm
```

可以看到IP信息，以及SRV记录中的端口信息

因此可以直接访问这个api

```bash
curl -iv http://api.swarm/
```

通过`-v`参数，可以看到这次链接的是 `192.168.0.5`，如果再次运行，可能结果会是另一个ip，因为默认的DNS TTL是0，所以会立刻过期。
