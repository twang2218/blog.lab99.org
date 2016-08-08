---
layout: post
category: docker
title: 视频笔记：Docker 运维 - Docker Networking 进阶指南 - Madhu Venugopal
date: 2016-08-08
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon16 - Docker for Ops - Docker for Ops - Docker Networking Deep Dive, Considerations and Troubleshooting
by Madhu Venugopal, Jana Radhakrishnan

{% owl youtube Gwdo3fo6pZg %}

<https://www.youtube.com/watch?v=Gwdo3fo6pZg>

{% owl tencent o0319rxyutt %}

<http://v.qq.com/x/page/o0319rxyutt.html>

# 自我介绍

他们之前工作于 SocketPlane，2015年初，Docker 收购了 SocketPlane，成为今天 Docker Networking 的一部分。

# 介绍

by Madhu Venugopal

## 什么是 libnetwork？

### Docker 网络互连

许多人认为 `libnetwork` 只是负责 `vlan`, `vxlan` 这些东西驱动部分的东西，其实不然，`libnetwork` 不仅是驱动接口。

网络分管理层面、控制层面和数据层面。

驱动已经可以很好地处理数据层面，所以今天有 `plugins` 接口，`overlay`, `bridge`，以及新的 `macvlan` 等多种驱动。他们可以很好地处理数据层面的事物。

### 定义容器网络模型

### 提供内置IP地址管理

可以指定IP，指定子网，指定地址范围，甚至可以将`DHCP` pipe out给外面的 `DHCP` 服务器来给容器内分配IP地址。

### 提供内置的多宿主网络互连

多宿主互连主要是两个层面，控制层面和数据层面。

数据层面现在通过 `overlay` 驱动，或者可以通过 plugin 提供的其它驱动。
控制层面在 `1.12` 中使用的是 `gossip` 协议进行通信，每一个数据层的驱动（`macvlan`, `ipvlan`, 或者通过插件机制支持的 `ovs` 等）都可以使用这种管理机制，这种通信是可扩展的，而且是安全的（TLS）。

### 提供内置的服务发现以及负载均衡

从 `1.10` 后引入了 `DNS` 的服务发现，可以用服务名、容器名，网络别名来实现服务发现。在 `1.12` 中引入了基于 `Virtual IP` 的负载均衡，之前是可以使用 `DNS轮询`(`dnsrr`) 进行负载均衡。

### 允许生态系统扩展

## Docker 1.12 Swarm Mode 的新的特性

* Cluster aware
* 去中心化的控制层
* 高度可扩展

在 `1.12` 中，`CNM` (Container Networking Model) 中提供了很多集群所需的特性：

* 多宿主互连无需外置key-value store

在 `1.9` ~ `1.11` 中，为了提供多宿主网络互联，需要提供一个外置键值库，这个在 `1.12` 的 Swarm Mode 下不需要了。

* `1.12` 中引入了加密的数据层、控制层
* 服务发现
* 负载均衡：`1.10` ~ `1.11` 可以用`DNS轮询`；`1.12`引入了 `VIP`。
* `1.12` 引入了Mesh路由

## Macvlan 驱动

* 从 `1.11` 作为试验驱动引入，现在离开试验状态了
* 和下层集成
* 将容器置于现有`VLan`环境

创建 macvlan 网络

```bash
docker network create -d macvlan \
    --subnet=192.168.0.0/16 \
    --ip-range=192.168.41.0/24 \
    --aux-address="favorite_ip_ever=192.168.41.2" \
    --gateway=192.168.41.1 \
    -o parent=eth0.41 \
    macnet41
```

查看IP地址

```bash
docker run --net=macnet41 -it --rm alpine /bin/sh
```

这意味着这样子运行的容器，网络通讯将会直接送到下层`vlan`。这是目前最高网络效率的驱动。这里没有`NAT`，没有端口映射，通讯直接通过VLan送出。

`Macvlan` 驱动实际上是利用的 Linux `macvlan` 内核驱动，该驱动已经存在于内核很久了，大约从 `Linux 3.2` 开始就在内核里了。

*注：实际上是2007年 `2.6.23` 就加入内核了，后来在 `2.6.33`, `3.9`, `3.16` 等中进行过改进，而之前提到的新的 `ipvlan` 是在 Linux 内核 `3.19` 引入的。*

# 深入

by Jana Radhakrishnan

## 多容器网络

* 基于 VXLAN 的数据路径并未改变
* 无需额外的键值库
* 集中资源分配
* 改进性能
* 高可扩展性

## 网络控制层面

控制层面基本上可以理解为路由协议。我们没有使用 `BGP`，虽然 `BGP` 可以支持非常复杂大型的网络，但是它的问题是无法快速收敛。对于容器网络而言，快速收敛是非常重要的。所以这里基于 `gossip` 协议。

<https://www.cs.cornell.edu/~asdas/research/dsn02-swim.pdf>

* 基于 Gossip 的协议
* 控制 `gossip` 广播控制在某个网络 scope 内（降低流量、快速收敛）
* 快速收敛
* 默认安全
	* 定期密钥轮换
	* swarm 原生密钥交换
* 高可扩展

## 安全数据层

* 在创建 `overlay` 网络的时候作为选项提供，注：`--opt secure`
* 使用 Linux 内核 `IPSec` 驱动
* 按需通道设置
* Swarm 原生密钥交换
* 定期密钥轮换
* 高性能

注意启用后的性能开销。如果容器内的服务自身支持安全通讯机制，可以使用服务内置的安全加密机制；而对于容器内部不存在的安全加密机制的通讯端口，而且服务置于公网之上，则需要考虑使用安全加密通道。

## 服务发现

* 由内置的 DNS 提供（从 `1.10` 开始）
* 高可用
* 使用网络控制层去得知状态
* 可以用于发现服务(`service`)和任务(`task`)

默认使用 `docker service create` 创建的服务，在请求 DNS 解析该服务的时候，会返回其虚拟IP (`Virtual IP`)，因为默认的 `Endpoint` 是 `vip`。但是可以创建服务的时候指定其为 `dnsrr`，也就是 DNS 轮询，这种情况下，请求 DNS 服务时解析到的就是多个 DNS 记录，反应的是容器实际的IP地址。

对于大部分负载均衡的情况，使用 `vip` 模式；不过如果非常希望自己实现负载均衡，（比如利用DNS缓存什么的）那么可以使用 `dnsrr` 来返回多个IP。

目前使用非 FQDN，主要考虑的是可扩展性，如果代码中使用了 `FQDN`，那么更换环境后，`FQDN` 改变会导致扩展性变差。因此目前 Docker实现中使用的是非`FQDN`的形式的服务名进行服务发现。

内置的DNS请求会依据不同容器发来的请求进行不同的解析的，容器发来的时候，内置DNS会知道请求是从谁发来的，以及它所处于哪些网络，因此会根据这些信息返回该容器所需要的结果。

## 内置负载均衡

在 `1.12` 中引入的内置的服务负载均衡。

首先通过`DNS`返回一个`虚拟IP`，这个`虚拟IP`是不会变化的。这个`虚拟IP`是在服务创建是所分配的，即使服务update，这个IP也不会改变。所以不用担心不同的应用层框架是否遵循了`DNS TTL`的约定。而使用`DNS-RR`，每次请求会随机乱序返回结果，已达到不同的IP地址，但是应用层的DNS实现的缺陷可能会无法利用该方法（*注：没错，Java同学，说你呢……*）。所以很多人称 `DNS-RR` 是 **poor man's load balancer**。

`1.12` 引入的 `vip` 的负载均衡，是基于 Linux 内核的 `ipvs` 驱动，是非常稳定的一个驱动，存在于内核十多年了。

在实现中，实际上没有集中式的负载均衡器，每个容器都内置了一个虚拟IP的负载均衡器，容器内和应用访问虚拟IP时，实际上是这个容器内部的虚拟IP负载均衡器去决定该访问服务中的具体哪个容器。因此负载均衡是分布式的，不存在单点故障。

实现上，使用 `iptables` 去trap `虚拟ip`的访问，转到内核 `ipvs` 去选择服务IP列表中的一个，然后转发访问。

## Mesh 路由

Mesh 路由同样也是负载均衡机制

* 为边界路由内置了 mesh 路由
* Worker 节点也参与 `ingress` 的 mesh 路由
* 所有的worker节点都接受来自 `PublishedPort` 的连接请求
* 端口转接发生在工作节点
* 使用的是和之前所述的内置负载均衡一样的机制去接受外部请求

作为用户，使用 mesh 路由，并不需要额外的步骤，只要声明了 `PublishedPort`，也就是 `--publish` 后，各个 worker 节点就会进行 mesh 路由。

# Demo

首先用 `docker swarm init` 和 `docker swarm join` 建立了 `1+2` 三节点集群。

然后查看 `netns`

```bash
$ sudo ls /var/run/docker/netns
1-9cycns5i9w    f681820dbdc5
```

这里有两个网络，第一个是 `overlay network` 沙箱，第二个是 `ingress` 的网络。

检查 `iptables` 规则

```bash
sudo iptables -t nat -nvL
```

注意这里面的 `DOCKER-INGRESS` chain。目前什么都没有，现在创建一个服务。

```bash
docker service create \
	--name sw \
	-p 8080:80 \
	--replicas 3 \
	mrjana/simpleweb
	simpleweb
```

再次检查 `iptables` 中的 `DOCKER-INGRESS` chain。会发现多了2条记录。其中一条记录指定了目标为 `tcp dpt:8080` 的流量转发到 `172.19.0.2:8080`。


```bash
sudo nsenter --net=/var/run/docker/netns/f681820dbdc5 bash
```

😓……很不幸，这机器没装 `nsenter`，于是换个办法。

```bash
mkdir /var/run/netns
touch /var/run/netns/n
mount -o bind /var/run/docker/netns/f681820dbdc5 /var/run/netns/n
ip netns exec n bash
```
然后就进入这个 ingress 的沙箱了(`netns`)，然后可以执行 `ifconfig` 查看其接口信息。

```bash
iptables -t nat -nvL
```

```bash
iptables -t mangle -nvL
```

```bash
ipvsadm -L
```

可以在 `POSTROUTING` 部分看到改变了源IP，原因是当数据包返回的时候，我们还需要经过 `ingress` 网络，由 `ipvs` 来决定送回到哪里，另一方面我们改变了端口，所以还需要从这里经过来将端口换回来。
