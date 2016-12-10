---
layout: post
category: docker
title: 视频笔记：Docker 在线 Meetup 42 - 使用 Docker 1.12 的技巧
date: 2016-12-10
tags: [docker, meetup, youtube, notes]
---

<!-- toc -->

# 视频信息

Docker Online Meetup #42: Docker Captains Share Tips & Tricks for Using Docker 1.12
by Ajeet Singh Raina, Viktor Farcic, Bret Fisher （Docker 队长）
2016-08-31

{% owl youtube 2ihqKMDRkxM %}

<https://www.youtube.com/watch?v=2ihqKMDRkxM>

# Docker 1.12 的服务发现

## 自我介绍

`Ajeet Singh Raina` 曾在 VMWare 工作，现在在 Dell 工作。

## Docker 1.12 新增内容

* 内置 Swarm Mode
* `SwarmKit` 独立出来称为编排的基础库
* 三个主要的 `Swarm API` / `CLI` 被加进来
	* `docker swarm init/join`
	* `docker node`
	* `docker service`
* 服务(`Service`)称为主要成员

## Docker 服务发现的发展

* Docker `1.9`
	* 使用 `/etc/hosts` 和 `/etc/resolv.conf` 来对集群服务解析
	* 很容易导致 `/etc/hosts` 被破坏
	* 缺乏负载均衡能力
	* 使得服务发现很复杂
* Docker `1.10/1.11`
	* 使用嵌入式 DNS
		* `--network-alias=ALIAS`
		* `--link=CONTAINER_NAME:ALIAS`
		* `--dns=[IP_ADDRESS...]`
		* `--dns-search=DOMAIN`
	* 集群服务发现使用外置后端服务，如 `etcd`, `consul`, `zookeeper` 等
* Docker `1.12`
	* 不在需要外置键值库
	* 服务发现直接和 `docker service` 结合在一起
	* `Service` 成为 `First Class Citizen`
	* `Network` 是服务发现范畴(`Scope`)
	* 服务发现使用`非 FQDN` 名称
	* 由内置 DNS 提供
	* HA 高可用
	* 可以用于发现 `Service` 以及 `Task`

## 什么是服务？

是用户使用 Swarm 系统的核心结构。定义了在工作节点上的任务 `Task`，`Task` 现在主要是容器，将来会扩展到 `Unikernel` 和 `VM`。

服务类型：

* `Global` 全局服务： `docker service create --mode=global`
* `Replicated` 副本服务： `docker service create --replicas=3`

曾经**以容器为中心**的操作，如 `docker run -d nginx`，转变为**以服务为中心**的 `docker service create --replicas 5 nginx`

## 理解服务发现

* 容器内产生域名（这里指非 FQDN 域名）请求，
* 检查容器内的 `/etc/resolv.conf` 文件，其内容是 `nameserver 127.0.0.11`
* 容器命名空间内，和这个 DNS 建立连接、发送请求
* 这个请求被 `iptables` 截获，转发给嵌入式 DNS
* 嵌入式 DNS 则根据容器所在网络，以及所查询服务情况返回地址信息

## 在 Swarm Mode 下演示服务发现

* 创建 `overlay network`

```bash
docker network create \
	-d overlay collabnet \
	--subnet 10.0.3.0 \
	--opt encrypted
```

* 创建服务

创建 `DNSRR` 服务

```bash
docker service create \
	--endpoint-mode dnsrr \
	--name wordpressapp \
	--replicas 5 \
	--network collabnet \
	nginx
```

创建 `VIP` 服务

```bash
docker service create \
	--name wordpressapp \
	--replicas 5 \
	--publish 80:80/tcp \
	--network collabnet \
	nginx
```

* 查看服务对应的 `VIP`

```bash
$ docker service inspect \
	--format="{{json .Endpoint.VirtualIPs}}" \
	wordpressapp
[{"NetworkID":"34fjvx3s4zz6uzg54jtu63ven","Addr":"10.255.0.6/16"},{"NetworkID":"8za5qtqs8r0nz8309lopnp6fg","Addr":"10.0.0.2/24"}]
```

* 每个服务的 DNS 别名，对应一个 VIP
* DNS 信息通过 `GOSSIP` 协议在集群节点间共享
* 然后任何容器请求服务名称解析时，节点就负责解析

# 设置 Swarm 集群以及集成 HAProxy

by `Viktor Farcic`

## 自我介绍

**[《The DevOps 2.0 Toolkit》](https://leanpub.com/the-devops-2-toolkit)** 的作者，在 CloudBee 工作

## 网络拓扑

`3`节点集群，`swarm-1`, `swarm-2`, `swarm-3`。其中 `swarm-1` 为`manager`。

## 创建网络

创建两个 `overlay network`

```bash
docker network create -d overlay proxy
docker network create -d overlay go-demo
```

## 创建服务

创建 `MongoDB` 服务

```bash
docker service create \
	--name go-demo-db \
	--network go-demo \
	--reserve-memory 100m \
	mongo
```

创建 `go-demo` 服务

```bash
docker service create \
	--name go-demo \
	-e DB=go-demo-db \
	--network go-demo \
	--network proxy \
	--reserve-memory 50m \
	vfarcic/go-demo
```

## 调试

为了调试，可以创建一个全局的调试服务。

```bash
docker service create \
	--name util \
	--network go-demo \
	--network proxy \
	--mode global \
	alpine
		sleep 1000000000
```

通过 `docker service ps util` 来确保服务已经在每个节点上运行了。

然后可以通过下面的命令来在不同的节点连入本节点的 `util` 容器进行调试。

```bash
ID=$(docker ps -q --filter label=com.docker.swarm.service.name=util)
docker exec -it $ID apk add --update drill
docker exec -it $ID drill go-demo
docker exec -it $ID drill go-demo-db
```

这里得到的 `go-demo` 和 `go-demo-db` 对应的IP地址是服务地址，是 `VIP`，而不是容器实际地址。

## 调整服务

Scale Up

```bash
docker service scale go-demo=5
```

## 添加反向代理服务

首先运行一个 `consul` 服务

```bash
wget https://raw.githubusercontent.com/vfarcic/docker-flow-proxy/master/docker-compose.yml
export DOCKER_IP=$(docker-machine ip swarm-1)
```

然后运行 `haproxy`

```bash
docker service create \
	--name proxy \
	-p 80:80 \
	-p 443:443 \
	-p 8080:8080 \
	--network proxy \
	-e MODE=swarm \
	--replicas 3 \
	-e CONSUL_ADDRESS=$(docker-machine ip swarm-1):8500 \
	vfarcic/docker-flow-proxy
```

## 升级服务

```bash
docker service update \
	--image vfarcic/go-demo:1.1 \
	--update-delay 5s \
	go-demo
```

# Docker 1.12 命令选项和别名技巧

by `Bret Fisher`

## 利用命令补全

显示 `my` 开头的镜像用来删除

`docker rmi my<tab><tab>`

显示 `--a` 开头的参数
`docker --a<tab><tab>`

## 使用 `volume` 的时候，尽量使用命名卷

使用命名卷才可能通过 `docker volume ls` 列表中区别出不同的卷是什么。

## 要学会使用 `-onbuild` 镜像

像 `ruby`, `node`, `python` 这类镜像，一般都有 `onbuild` 版本，这个版本里面内置了常用的构建镜像的步骤，可以在基本不写 `Dockerfile` 的情况下使用。开发的时候非常有用。

## 要学会使用 `Docker Compose`

特别是学会 `docker-compose down`，很多人用的时候，直接前台 `docker-compose up`，然后开始开发，开发到一个阶段，`Ctrl-C` 退出，这样 `docker-compose` 会 `kill` 掉这些运行容器。可问题是这些容器还在，`docker ps -a` 还会看到它们，而且 `docker network ls` 也会看到这些网络。如果需要更干净的环境，应该使用 `docker-compose down`。

可以利用 `docker-compose down` 的 `-v` 参数来明确清除卷，也可以利用 `--rmi local` 来清除自己构建的本地镜像。

## 使用 `alias` 来预定义比较长的命令

比如：

```bash
alias drmai='docker rmi $(docker images -a)'
alias drdefault='eval "$(docker-machine env default)"'
alias drit="docker exec -it"
```
