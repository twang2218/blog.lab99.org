---
layout: post
category: docker
title: 视频笔记：介绍 Raft 算法 (CoreOS Fest 2015) - Diego Ongaro
date: 2016-06-23
tags: [docker, coreos, youtube, notes]
---

<!-- toc -->

# 视频信息

An Introduction to Raft (CoreOS Fest 2015)
by Diego Ongaro, Stanford University (2015/05/27)

{% owl youtube 6bBggO6KN_k %}

<https://www.youtube.com/watch?v=6bBggO6KN_k>

{% owl tencent f0314bj1m5j %}

<http://v.qq.com/x/page/f0314bj1m5j.html>

# Raft Consensus Algorithm (etcd based on it)

# 目的

一个共享的键值Store（state machine）
简单地办法是用一个主机放到网络上，好处是很简单，但是缺点是单点故障；
使用Raft，可以保持一致性并且可以应对故障

# 什么是 Consensus

Agreement on shared state
自动从服务器故障中恢复：小规模故障没问题，大规模的话失去可用性，但是依旧保持一致性。

Replicated State Machines

Replicated log 送给 replicated state machine，这样所有服务器都会以同样顺序执行这些命令。
Consensus 模块确保正确的 log 复制
System makes progress as long as any majority of servers up

# PAXOS Protocol

by Leslie Lamppost, 1989

过于复杂。

RAFT 设计目的包括要易于理解

# RAFT overview

## Leader election

* 从一群服务器中选出一个作为 cluster leader
* 监测宕机并重新选择新的leader

## 日志复制

* leader从client接受命令，并附着到 log上
* leader 复制这个log到其它服务器上

##安全

只有拥有最新 log 的服务器可以成为 leader

# RAFT Visualization

有5个服务器，服务器期望在一个时间内会收到服务器的心跳，如果超时，就会重新选举新的 leader。

`S3`超时后，它自己升为`Term 3`，并且发出`message（Request Vote RPC）`；而其它服务器尚处于原先的 `Term 2`。其它服务收到 `T3` 的message后，都会更新自己的状态进入`T3`，而升级到`T3`后，他们将会拒绝接受T2的消息。

`Request Vote message`，现在是`先到先得`的机制，先发起请求的服务器，先成为Leader。

如果 `S1` 和 `S5` 同时Time out，他们同时发起`request vote RPC`。如果`s3`，`s4` 各选择了一个leader，则`S1`和`S5`都无法得到大多数选票，所以他们都没有办法成为leader。

这时 `RAFT` 的策略是干脆等待好了，进入的`Term 5`，看之后谁第一个timeout，因为下一个服务器timeout的时候，不大可能出现上面同时超时的情况（超时本身是随机的）。这时架设`S3`首先超时，开始发起 `request vote RPC`，那么s3就成为了`Term 5`的leader。

只有在多数服务工作时，才会接受新的日志请求。

如果新启动的服务器发现日志不一致，或者步调不对，会和新的leader进行交流，一步步后退，退到之前可以达成一直的index，然后再前进到当前index.

如果之前宕机的leader拥有更新的index，但是没来的及发给其他服务器，现在其他服务器已经移到下一个term了，那么旧leader上线后，它的index会被新term的index所覆盖。

如果一个服务器的index比所有服务器都旧，然后发送`request vote RPC`，所有的服务器都不会同意，只有拥有最新的index的服务器，才可以成为 leader。

# 总结

* Consensus 注重于推广而不是复杂

要容易在学校教，而且容易更好的构建实际系统的实现
实际系统中还需要一些额外的部分：

* 集群成员管理
* 日志压缩
* 客户端交互
* evaluation
