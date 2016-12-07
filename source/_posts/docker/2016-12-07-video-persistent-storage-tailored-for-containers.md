---
layout: post
category: docker
title: 视频笔记：为容器定制的持久化存储方案 - Infinit - Quentin Hocquet
date: 2016-12-07
tags: [docker, docker summit, youtube, notes]
---

<!-- toc -->

视频笔记：为容器定制的持久化存储方案 - Infinit - Quentin Hocquet

# 视频信息

Persistent storage tailored for containers
by Quentin Hocquet
@ mefyl
CTO @ Infinit
在 Docker Distributed System Summit 2016 上的讲座
2016-10-10

{% owl youtube k0m-XwCoxo0 %}

<https://www.youtube.com/watch?v=k0m-XwCoxo0>

视频链接：<https://www.youtube.com/watch?v=k0m-XwCoxo0>

幻灯链接：<http://www.slideshare.net/Docker/persistent-storage-tailored-for-containers>

# 容器和存储

容器非常快捷、可扩展、很灵活

* 非常快速的启动、停止
* 非常快速和容易的横向扩展
* 统一的开发和生产环境
* 而且还可以非常灵活的定制各种需求

但是容器更倾向于**无状态化**，对于无状态的服务，在容器世界里更容易使用。但是并不意味着我们的服务都是无状态的，而且服务有状态是很重要的，因此我们需要**持久化存储**。

理想化的持久化存储应该可以做到：

* 可以像容器一样容易的创建、启动
* 可以跟容器的横向扩展同时进行扩展
* 应该和容器一样对于开发、测试、生产环境以同样的方式工作
* 而且应该和容器一样可以使用各种需求

# Infinit 存储平台

Infinit 存储在设计初期就考虑了容器的应用场景。提供了多种 API，从 POSIX 文件系统，Object （如AWS S3，OpenStack Swift）到 Block （iSCSI）。它将所有节点的本地存储聚合在一起，成为统一的存储池。

# Infinit 是完全分布式的

没有 Leader，没有 follower，所有的节点都是平等的。

* 在一个节点和一万个节点上，工作方式一样
* 没有单点故障，没有瓶颈
* 节点很容易添加和删除，无论是容量还是速度
* 拥有面向开发和生产环境统一的 API
* 每个设置都可以定制

因此 Infinit 可以：

* 和容器一样轻松的创建和运行。
* 可以伴随容器池的扩容而扩容
* 确保开发、测试、生产环境一致
* 对于各种需求都可配置：加密、冗余、压缩等

# 如何做到的？

Infinit 的基本原则：

* 将所有节点至于**一个 overlay network** 下进行查询和路由
* 将数据以块(block)的形式存储于**Distribute Hashtable (DHT)** （可以视为分布式键值库），并且确保每个块是一致的。
* 使用**密码学的访问控制**来执行任何 Leader 的命令
* 使用**[symmetrical operations](https://zh.wikipedia.org/wiki/%E5%B0%8D%E7%A8%B1#.E9.82.8F.E8.BC.AF.E4.B8.AD.E7.9A.84.E5.B0.8D.E7.A8.B1)**来确保稳定性和灵活性

这里的 overlay network 并非 docker overlay network，而是指将上千节点联系起来，可以互相查询、发现、路由的一组算法和实现。

[密码访问控制](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.58.889&rep=rep1&type=pdf)非常强大，利用密钥机制，确保能访问该 Block 的节点，必然拥有密钥，所以必然可以读取信息，以及解密，而无需去询问第三方机构获得权限。

因为我们是 symmetirc 的，并且使用了密码学访问控制，因此所有的块必须自签名以及加密。

# 深入：DHT Blocks

DHT Blocks 分为两大类 `Mutable blocks` 和 `Immutable blocks`。

可变更的块(`mutable block`)：

* 这就很容易产生冲突
* 而且很容易出现过期和失效，需要经常检查
* 很难去验证以及加密解密

不可变的块(`immutable block`)：

* 不会有冲突
* 不会失效，可以一直缓存
* 非常容易去验证，因为每个块是 addressable 的：`address = hash (content)`

**不可变的块** 可以从任意节点获取，然后在本地磁盘用 LRU 缓存。

由于 `Immutable Block` 的特性很赞，所以在设计 Infinit 的时候会尽可能的使用 `Immutable Block`。

# 深入：文件系统层

文件基本上就是一个带元数据的 `Mutable Block` 和一个 `Immutable Block` 组成的`FAT (File Allocation Table)`。

文件的内容是使用 `Immutable Block` 进行存储的，可以随意缓存。因为每次文件变更，会先上传一个替代的 `Immutable Block`，结束后只需要很短暂的修改 `inode`，即可完成版本替换。因此可以轻易的确保原子读写。

POSIX 的 API 是顺序的，而 Infinit 是高度并行的。因此提供了目录预读、以及文件信息预读的功能，可以让后台以高度并行批量的方式获取信息，降低前台响应时间。

# 深入：Consensus

由于是基于 Block 的 Consensus，因此每个 Block 都有一组 Quorum，使用 Paxos 算法。这样的设计导致没有单点故障，而且由于每个 Block 的 quorum 都不同，也没有单一瓶颈问题。

这里没有使用 Raft，而使用了更复杂的 Multipaxos 的算法。

# 深入：Overlay

overlay 层是 Infinit 平台中很重要的一个定制点：

比如，算法的选择：

* 几千个节点的话：[`kelips`](https://github.com/papers-we-love/papers-we-love/blob/master/distributed_systems/kelips-building-an-efficient-and-stable-p2p-dht-through-increased-memory-and-background-overhead.pdf), [`kademlia`](https://pdos.csail.mit.edu/~petar/papers/maymounkov-kademlia-lncs.pdf), [`chord`](https://pdos.csail.mit.edu/papers/chord:sigcomm01/chord_sigcomm.pdf),
* 几百个节点几十个TB 的话：`global knowledge`, `Kouncil`

数据存储位置：`rack-aware` 机架，`zone-aware` 区域，`reliability-aware` 可靠性、`ensure local` 本地存储。
