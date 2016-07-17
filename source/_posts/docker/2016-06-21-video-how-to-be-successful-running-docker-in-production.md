---
layout: post
category: docker
title: 视频笔记：如何成功在生产环境中运行 Docker - John Fiedler
date: 2016-06-21
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

How to be successful running Docker in Production
by John Fiedler
Senior Director of Engineering @ SalesforeceIQ

{% owl youtube j6Ge4wP1yH0 %}

<https://www.youtube.com/watch?v=j6Ge4wP1yH0>

{% owl tencent f0314wy9h49 %}

<http://v.qq.com/x/page/f0314wy9h49.html>


# 定义生产环境

* Production != test dev
* 要考虑隔离、安全、性能、监控、日志等等
* 要扩展、模板、自动化

# 定义成功

* >99% uptime？
* 快速代码部署
* 0 安全事件？

100% 的web infrastructure 使用docker

# 放入容器的东西：

* 越多依赖、越多的改变，就越适合

  * 比如Web服务，内容结构会经常变化，而且依赖非常多；
  * 而数据库则一旦部署几年不变动，而且依赖很少；

* 越是无状态(`stateless`)、越短生命周期的

# docker化的场景

## 创建

* Dev/Ops是完全Docker化的；

## 部署

* CI/CD是部分Docker化的；

## 运行

* Web、中间件、任务、脚本是完全Docker化的
* 批处理和流处理是部分Docker化的；
* 固定存储则不是Docker化的。

## 运维

* 监控、日志、安全是部分docker化的。

曾经尝试过 Docker in Docker，但是发现很想扩展能力太差。

现在70%的东西都在docker里。

# 经验

Docker 现在生产环境稳定。但是周边的工具不一定生产环境可用，要谨慎。

可以配合docker使用`chef`, `ansible`, `saltstack`等工具，这些东西一样用，而且配合用起来很好。

现在在 AWS AMI 上用`Chef`来设置生产环境的web server，用`cron`控制脚本来编排容器。

## 第一个问题

你一定会碰到 disk/file system问题

* 最开始使用的 `aufs`，但是很快就碰到了42层限制
* 然后换到了 `device mapper`，结果非常悲惨，围绕着`CentOS`碰到了很多问题；
* 换到ubuntu好一些，换回 `aufs`，解除了42层限制，但还有问题，分层、绑定；
* 升级到 `Docker 1.7` 后，或许会换回 CentOS 和 Device mapper，因为 dynamic binaries。

推荐理解容器存储的可视化链接：
<http://merrigrove.blogspot.com/2015/10/visualizing-docker-containers-and-images.html?m=1>

## 内核版本很重要

## 找个好的registry

比如

* <https://hub.docker.com>
* <https://quay.io>
* Docker Trusted Registry

最开始尝试了`registry`，很多bug，很多fail pull/push
然后尝试了 `quay.io`，happy但是很慢(有些image得700多MB)，而且花钱啊……
后来又回到了 `docker registry 0.9`，目前稳定多了。
横向扩展，非常好；
目前在升级到 `registry 2.1`

## 在AWS部署

用的是`Beanstalk`， `ELB`进行负载均衡横向扩展，使用`Elasticcache(redis)`做cache，用`S3`做存储。

## 每个主机有越少的容器越好

如果某个容器的CPU, DISK IO，网络IO，内存出现了使用峰值，其它的容器都会被干扰。安全问题。

## CI/CD with Docker

huge ROI with docker

GitHub.com → Teamcity → agents → Registry → Server

从前 agents 是在docker里的，docker in docker，现在是使用`chef`和`packer`。

推荐文章，为什么不要使用Docker in docker：
<https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/>

## Beanstalk architecture

## 一年前

CoreOS刚推出，觉得超酷，然后用了，结果失败的很惨

# 总结

刚开始的时候，用你熟悉的工具
你需要考虑横向扩展
安全不难，但是一定要考虑
许多软件供应商进入到了容器领域
向 PaaS 的方向构建
要知道你要解决的问题
