---
layout: post
category: docker
title: 视频笔记：Docker 在线交流会 28 - Docker Swarm 可以用于生产环境了 - Alexandre Beslic
date: 2016-06-22
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

Docker Online Meetup #28 - Production Ready Docker Swarm
  by Alexandre Beslic (2015/11/11)

{% owl youtube 3I6hWb24_qE %}

<https://www.youtube.com/watch?v=3I6hWb24_qE>

{% owl tencent y0314wpg13e %}

<http://v.qq.com/x/page/y0314wpg13e.html>

# 多 Docker Engines == Swarm

CLI → Swarm (Managers) → Agents (Docker Nodes)
Managers → machine discovery (etcd, consul, zookeeper)

# Timeline

* 2014年10月  Proof of Concept
* 2015年1月   First RC
* 2015年2月   swarm beta
* 2015年4月   0.2.0
* 2015年10月  1.0.0 release (stable)

# Swarm in General

将一群Docker Engins变成一个资源池

使用标准的Docker REST API
资源管理（CPU、内存、网络）
Service Discovery (`etcd`, `consul`, `zookeeper`)
TLS
multi-tenancy

# 新版本特点

改进调度器、多主机网络、卷管理、更好的Compose集成

1.1 → container rebalancing, global scheduling

# 多主机网络

DockerCon SF 2015 June 发布的，现在稳定了

允许使用 `vxlan` 创建 `overlay` 网络

每一个连接到同一个`overlay network`的主机都可以看到对方，并且可以通过对方名字定位到对方。

# `docker network`

{`rm`, `create`, `connect`, `disconnect`, `inspect`, `ls`}

# Demo

在 GCE, Azure, EC2, 3个 Digital Ocean 总共6个主机

## `docker run`

先创建`overlay`网络

```bash
docker network create -d overlay overlay_test
```

然后在Swarm上运行三个节点，都使用overlay_test网络

```bash
docker run -it --name=app1 --net=overlay_test busybox
```

然后在各个节点上都可以通过名字`ping`同对方。

## `docker-compose`

*该版本需要使用 `--x-networking` 来启用建立网络的功能，之后不需要了*

```bash
docker-compose --x-networking up -d
```

其中需要注意的是，在demo的python worker中所写的`redis`主机名，使用的是生成的容器名，`jobdoer_redis_1`，也就是`<项目名>_<服务名>_序号`。

那么这只是链接到一个容器，要是redis是个集群的话，则使用`redis`服务名即可。

## 卷管理

```bash
docker volume {create, ls, inspect, rm}
```

可以使用分布式存储的驱动，比如使用`Ceph`集群，创建一个`Ceph`上的`volume`，然后在Docker上挂载这个分布式的`volume`。

# `swarm` + `machine` + `compose`
