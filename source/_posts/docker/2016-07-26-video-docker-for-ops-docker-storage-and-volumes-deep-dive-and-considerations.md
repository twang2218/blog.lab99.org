---
layout: post
category: docker
title: 视频笔记：Docker 运维 - Docker Storage 和 Volumes 进阶指南 - Brian Goff
date: 2016-07-26
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon16 - Docker for Ops - Docker Storage and Volumes Deep Dive and Considerations
by Brian Goff, Core Engineer, @cpuguy83

{% owl youtube X_q2l8hotAc %}

<https://www.youtube.com/watch?v=X_q2l8hotAc>

{% owl tencent m03195b0m96 %}

<http://v.qq.com/x/page/m03195b0m96.html>

# 自我介绍

在 GitHub 上叫 [cpuguy83](https://github.com/cpuguy83)。已经使用 Docker 3 年了。曾经部署失败，因为`yaml`的依赖问题，所以后来开始接触 Docker，甚至学习 Go，然后逐步的变为很深入的 Docker 开发人员。

# Image 与 Container 存储

Docker 称其为 `Storage Driver` ，内部叫它 `Graph Driver`。

每次当 `docker pull` 或 `docker run` 之后，Docker 从 Hub 之类的取回 Image，而 **Image 是一堆文件系统层的集合**。`Storage Driver` 负责把这些层整合成一个文件系统提供给容器。

## 我应该选择哪个 `storage driver`？

| 存储驱动 | 类型 | 内核支持 | 空间配额 | 问题指数 |
|---------|-----|---------|--------|---------|
| `AUFS`  | FS  | No      | No     | 1       |
| `BTRFS` | Block | Yes   | No     | 5       |
| `DeviceMapper`|Block|Yes| Yes    | 6       |
| `Overlay`| FS | Yes     | No     | 5       |
| `Overlay2`| FS| Yes     | No     | 3       |
| `ZFS`   |Block| No      | Yes    | 1       |

`AUFS` 存在很久了，到今天已经很稳定了，特别是对于 docker 使用而言，不大会出什么问题。

`DeviceMapper`是比较老的技术了，总会有很多问题。

`Overlay` 第一个版本是使用 `3.18` 以上的内核，由于一些功能的欠缺，使用了很多 `hard link`，从而可能导致 `inode` 过多的问题。在 `4.0` 内核以上，解决了这个问题，所以在 `Docker 1.12` 有了 `Overlay2` 以解决这个问题。

`ZFS` 很老牌的存储介质，很稳定，只不过 Linux Kernel 是不会支持了。

这里所有的 `Block` 文件系统都支持`磁盘配额`，但是 `FS` 的都不支持。`Docker 1.12` 以后支持 配额 了。

## 如何指定 Storage Driver？

`1.10` 以后，`Docker Daemon` 可以使用 `JSON` 文件配置 `Docker Daemon` 了。所以可以用下面的命令直接指定 `storage driver`：

```bash
echo '{ "storage-driver": "overlay2" }' > /etc/docker/daemon.json
```

改变 `storage driver` 后，会发现机器上所有的 `image`、容器都不见了，很多人 freaking out 了。其实东西没丢，还在那里，但问题是 Docker 同一个时间只能支持一个 Storage Driver。如果需要之前的镜像，可以把 Storage driver 再换回来，然后导出、保存镜像啥的，然后在放到新的 storage driver 中去。

# Persistent Storage

在 Docker 中被称为 `Volumes`，这是在容器生存周期之外，存储数据的地方。

## Docker 是为无状态应用准备的！

**这说法其实不对**。

严格来说，如果是无状态的应用，确实更容易迁移到 Docker 上，因为完全不用考虑存储问题。但是这并不是说 Docker 就局限于无状态应用了。

Brian 自己所在公司就没有任何一个无状态的应用，所有都在 Docker 里，从数据库、Web apps、Redis 到VPN tunnel。

## 我要怎么在 Docker 里 XX ？

比如如何在 Docker 里存数据库？如何备份数据？如何迁移数据？

这些问题的第一反应是，如果没有 Docker，这些事情怎么做的？因为Docker非常的简单，平时shell下如何操作的，Docker就如何操作。平时操作系统如何做，Docker里面就如何做。一切都很自然。

Docker 并没有改变计算环境。

容器的意义不在于容器本身，容器的意义在于抽象架构，并且关注于应用，而不是关注于构建本身。

## Storage 非常困难

Brian 问大家谁丢失过数据，即使有备份，但是可能备份的设备失败了，坏了，之前没注意到；或者之前以为工作，等需要恢复的时候发现不能用了。

## Create a volume

```bash
docker volume create --name important_data
docker run -d -v important_data:/var/lib/postgresql/data --name pgdb postgres
docker rm -f pgdb
# 不用担心，因为数据还在
docker run -d -v important_data:/var/lib/postgresql/data --name pgdb postgres
```

## Create a volume - NFS

`docker volume` 其实支持绑定很多文件系统，比如 `NFS` 的。

```bash
docker volume create \
    --name important_data \
    --opt type=nfs \
    --opt device=1.2.3.4:/export/path
```

这样的话你的数据文件就在 `NFS`了，你可以在任何 docker host 上运行 `postgresql` 数据库了，因为这是 `NFS`；你的 `postgressql` 会变得超慢，因为这是 `NFS`……

## Create a volume - BTRFS

```bash
docker volume create \
    --name important_data
    --opt type=btrfs \
    --opt device=/dev/sdb
```

这样就支持 `snapshot`, `clone` 了。

## Create a volume - Gluster

Docker Volume 还支持大量的插件，几乎各种云服务商都有支持。比如支持 `glusterfs` 分布式文件系统

```bash
docker volume create \
    --name important_data
    --driver glusterfs
```

## Create a volume - Swarm Mode

在 1.12 集成进来的 `Docker Swarm Mode` 下使用 Volume

```bash
docker service create \
    --mount type=volume,source=important_data,target=/var/lib/postgresql/data,volume \
    --driver=local \
    postgres
```

> Docker is for anything you are crazy enough to try - Brian Goff

* 不要挂载到宿主目录，大多数情况是不需要的。
* 不要共享状态（我们通过交流来共享状态，而不要通过共享状态来交流），比如 `volumes_from` 基本是个很差的做法，一方面这在集群中无法工作，另一方面两个容器等于锁定了这个卷的路径，在某些文件系统下可能能工作，但是在某些系统下会产生崩溃。实际上这样会产生很麻烦的 `race condition` 的问题。

# QA

#### Q: Docker 等于提供了一个统一的卷接口，那么是不是可以说其实备份更容易了，我只需要告诉 IT guy 备份 Volume 就完了？而不用关心具体是什么数据之类的？

Docker确实提供了统一的接口访问不同的文件系统，这基本上是基于 VFS 机制的。备份可以有两种做法，一种是选择那些支持备份机制的 Storage；另一种是手动备份，起个容器加载这些卷然后备份。关于数据库，备份非常重要，现在做 Replication 非常容易，所以如果要提供HA，尽量通过 Replication，而不要通过本地备份的形式。

#### Q: 1. AUFS 开始被一些发行版去掉了，那么将来默认的 Storage Driver会是什么？2. Spotify 提供了 docker-gc 来清理垃圾，要是 Docker 有原生的解决方案会更好，这方面有什么计划没有？

虽然说要去掉 `AUFS`，但是很多最后没有去掉，特别是 `Ubuntu 16.04` 内置了 `AUFS`，这个LTS版本会持续很多年，所以不是太大的问题。`Overlay` 是将来的希望，但是现在还有一些 kernel bug需要去处理，Brian 从来没有向人推荐使用过 `Overlay FS`，除非是开发环境。但是希望这个将来能成熟起来。

至于垃圾回收问题，是的，一直在考虑这个问题。在 `Docker 1.10` 之前这是不可能的，现在好很多了，但是还在考虑具体怎么去做这个事情，GC这东西放到哪里都是比较难以解决的问题，要做就得做对，不能把运行中的，或者即将运行的 image 给删掉。

#### Q: 对于 Swarm Mode 而言，推荐使用什么 Volume driver 来共享卷？

这依赖于具体使用情况。有一些插件可以支持分布式块存储。不同的云服务商有其特定的云存储插件，如果是私有云，可能会推荐用 `gluster`或者`ceph`。

#### Q: Docker 的 Overlay Network 非常方便，对用户透明，可以在感知不到的情况下实现集群跨主机访问。那么将来有没有可能做一个类似的 Overlay Storage 的东西，也能够这么方便的使用存储？

`Storage is Hard`. 这是我唯一能说的。这次大会展台上有一半都是 Storage 厂商，推荐去看一下他们的技术。

#### Q: 如果我有个 Python app，我现在想用 Swarm 去scale，那么数据库怎么scale？

首先是不要共享数据库存储的形式，而使用 `replicas`。

#### Q: 我们在解决一个分发数据的问题，我们希望封装数据库进镜像，这样用户启动镜像的时候可以不用下载或者生成这些数据，但是分发一个10GB的 image 显然不咋样，有什么好建议么？

首先是不推荐将数据封装到镜像里，应该设法是分发数据。通过`FTP`, `HTTP`, `S3` 之类的分发手段。

#### Q: 你说不要使用绑定宿主目录，我的理解是不要绑定特定宿主目录，那么有没有别的原因不使用绑定宿主目录呢？

首先我并不认为绑定宿主目录是 Volume，我特意回避了将其说为 Volume 的做法。我们实际上有 Volume 对象，和 Host Path，这是两个不同的东西。比如现在的如果-v一个路径到容器，如果路径不存在就会建立一个目录去挂载，但是如果你实际的意图是个文件，那么这个目录会绑进容器，让容器内产生混乱。这不是可靠性的问题不推荐，而是绑定宿主目录的做法等于是出现了一个Docker控制范围外的东西，相当于在构架上打了一个洞的概念。

#### Q: 什么 Storage driver 速度最快？

现在的话，`overlay2` 最快，它有很巧妙的缓存机制，甚至可以让不同的容器共享同一个page。

#### Q: 可不可以将 device 传进容器内，然后在里面创建 Soft RAID，然后使用他们？

在 `docker cli` 可以通过 `--device` 来指定某个 `device` 或者某个目录的 `device` 给容器。
