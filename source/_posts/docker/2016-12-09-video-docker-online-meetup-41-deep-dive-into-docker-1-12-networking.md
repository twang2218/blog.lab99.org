---
layout: post
category: docker
title: 视频笔记：Docker 在线 Meetup 41 - 深入 Docker 1.12 网络 - Madhu Venugopal
date: 2016-12-09
tags: [docker, meetup, youtube, notes]
---

<!-- toc -->

# 视频信息

Docker Online Meetup #41: Deep Dive into Docker 1.12 Networking
by Madhu Venugopal

{% owl youtube nXaF2d97JnE %}

<https://www.youtube.com/watch?v=nXaF2d97JnE>

# 自我介绍

Madhu Venugopal 以前是 DockerPlane 的 CEO，后来被 Docker 收购了。

# 什么是 `libnetwork`？

`libnetwork` 是网络部分的框架，不仅仅是驱动接口，还包括了数据层、控制层等等。

* Docker 网络互连
* 定义容器网络模型
* 提供内置IP地址管理（可以通过插件使用外部地址管理）
* 提供原生多宿主网络互联
* 提供原生服务发现以及负载均衡
* 允许通过插件扩展，形成生态环境

# 设计思想

用户是第一位的

* 应用开发人员
* IT/网络运维人员

插件 API 设计

* 思想是：`内置电池，但是可以更换`

# Docker 网络发展

* Docker `1.7`:
	* 独立出 `libnetwork` 项目
	* 设计 `CNM` (容器网络模型)
	* 迁移旧的 `bridge`, `host`, `none` 到 `CNM` 下。
* Docker `1.8`:
	* 通过 `/etc/hosts` 实现服务发现
* Docker `1.9`:
	* 实现多宿主网络互联
	* 网络插件
	* `IPAM` (IP 地址管理) 插件
	* 网络 `UX/API`
* Docker `1.10`:
	* 内置分布式 `DNS` 进行服务发现
* Docker `1.11`:
	* 添加网络别名 `alias`
	* 实现 DNS 轮询负载均衡
* Docker `1.12`:
	* 实现基于`IPVS`的负载均衡
	* 加密控制层和数据层
	* Mesh 路由
	* 内置 Swarm Mode 集群网络互联

# `CNM` 容器网络模型

<https://github.com/docker/libnetwork/blob/master/docs/design.md>

* `Endpoint`
* `Network`
* `Sandbox`
* `Driver` & `Plugins`

# 网络驱动

## Case 1: 默认桥接网络 (`bridge0`)

容器内的 `eth0` 连接到桥接接口 `docker0`，然后宿主的 `iptables` 来负责 `NAT/port-mapping` 进行容器内和容器外的转换互联，最后数据通过宿主的 `eth0` 连接到交换机上。交换机可以是普通的 `ToR(Top-of-Rack) 交换`，也可以是虚拟框架的 `Hypervisor 交换`。

## Case 2: 用户自定义桥接网络

在每个宿主上执行：

```bash
$ docker network create \
	-d bridge \
	-o com.docker.network.bridge.name=brnet \
	brnet
$ docker run --net=brnet -it busybox ifconfig
```

这种拓扑情况下，是容器内 `eth0` 接口访问 `brnet` 接口，而 `brnet` 通过宿主 `iptables` 进行转换映射，通过宿主的 `eth0` 访问交换。

## Case 3: 桥接网络连入下层网络并使用`IPAM` (没有NAT/端口映射)

在每个宿主执行下列指令：

```bash
$ docker network create \
	-d bridge \
	--subnet=192.168.57.0/24 \
	--ip-range=192.168.57.32/28 \
	--gateway=192.168.57.11 \
	--aux-address DefaultGatewayIPv4=192.168.57.1 \
	-o com.docker.network.bridge.name=brnet \
	brnet
$ brctl addif brnet eth2
$ docker run --net=brnet -it busybox ifconfig
```

注意其它主机的 `--ip-range` 和 `--gateway` 需要做对应调整。

这种拓扑是，容器内 `eth0` 连接 `brnet` 接口，该接口直接通过 `eth2` 访问交换。

## Case 4: Overlay Networking

每个容器通过容器内 `eth0` 连接 `ov-net1` 接口，该接口通过`VXVLAN-VNI 100` 进行宿主间互连，宿主间通过 `Gossip` 协议得知各自网络信息。

同时，每个容器还通过容器内 `eth1` 连接 `docker_gwbridge` ，再通过 `iptables` 进行NAT以及端口映射，最后通过宿主 `eth0` 连接交换。

## Case 5: Macvlan (1.12新增)

在 `VLAN 10` 上

```bash
$ docker network create \
	-d macvlan \
	--subnet=10.1.10.0/24 \
	--gateway=10.1.10.1 \
	-o parent=eth0.10 \
	mcvlan10
$ docker run --net=mcvlan10 -it --rm alpine /bin/sh
```

在 `VLAN 20` 上

```bash
$ docker network create \
	-d macvlan \
	--subnet=10.1.20.0/24 \
	--gateway=10.1.20.1 \
	-o parent=eth0.20 \
	mcvlan20
$ docker run --net=mcvlan20 -it --rm alpine /bin/sh
```

容器通过容器内 `eth0` 访问宿主 `eth0.10` 接口并附上 `VLAN 10` 标签，通过宿主 `eth0` 走 `802.1Q Trunk` 出宿主接到交换机上去。

# 1.12 新功能

## Swarm Mode 中的新功能

* cluster aware
* 分布式控制层
* 高扩展性

### Swarm mode 中的多宿主互连

* 基于 `VxLAN` 进行数据互连
* 无需外置键值库
* 集中资源分配
* 改进性能
* 高可扩展

### 安全的控制层

* 基于 `Gossip` 协议（*看来八卦还是很强大的*）
* 网络范畴的 `Gossip`
* 快速收敛
* 默认安全
	* 定期密钥轮换
	* Swarm 原生密钥交换
* `Gossip` 控制消息
	* 路由状态
	* 服务发现
	* 插件数据
* 高可扩展性

### 安全的数据层

* 在 `overlay network` 创建时作为选项可以使用
* 使用内核 `IPSec` 模块
* 按需 Tunnel 设置
* Swarm 原生密钥交换
* 定期密钥轮换

### 服务发现

* 由内置 DNS 提供支持
* 高可用(HA)
* 使用网络控制层取得状态信息
* 可以用于发现服务和Task

### 负载均衡

* 包括内部`internal`负载均衡，和边界`ingress`负载均衡
* 支持 `VIP` 和 `DNS-RR`
* 高可用
* 使用网络控制层获取状态信息
* 最小性能损耗

### Mesh 路由

* 在边界路由内置 routing mesh
* 工作节点也参加边界 routing mesh
* 所有节点都接受发送给 `PublishedPort` 的请求
* 端口转换发生在工作节点。
* 内部和边界负载均衡使用相同的机制
