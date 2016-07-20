---
layout: post
category: docker
title: 视频笔记：Docker Registry - Stephen Day
date: 2016-06-20
tags: [docker, dockercon15-sf, youtube, notes]
---

<!-- toc -->

{% owl youtube RnO9JnEO8tY %}

<https://www.youtube.com/watch?v=RnO9JnEO8tY>

{% owl tencent b0314thmzhe %}

<http://v.qq.com/page/b/h/e/b0314thmzhe.html>

# 什么是Docker

Container 是 docker 的运行时，由 image 创建
文件系统是有多个层组成，每层只是个tar文件。层可以由不同的image共享。

把多个层放到一起并且添加描述如何组织这些层，就成了镜像。

# 历史

Docker Registry API v1
面向层的
层id是随机分配的
一个JSON负责一个层，然后指向父层
命名基本都是靠tag

# API v1 的问题

* Abstraction → 暴露image发布机制，暴露内部多层
* Security → Image ID 必须保持秘密，没有审计、验证，而且谁分配 layer id？
* Performance → 性能很慢，取当前层，然后取父层，一步步向上，无法并行。
* 用Python实现 → 不易于部署

# API v2 目标

* 简单：易于部署，适于静态主机
* 安全：Image 可以被验证
* 分布式：分离命名和内容地址
* 性能：避免单线程处理
* 实现：采用 Go 来实现，可以共享更多的Docker Engine的代码

## V2: Content Addressable

使用SHA256，可以确保该层可以从任何地方下载，而且确保内容一致

## V2: Manifests

描述一个image的各个层组件，在一个对象中包含所有东西

```json
{
   "name": <name>,
   "tag": <tag>,
   "fsLayers": [{…}],
    …
}
```

## Content-addressable

```bash
docker pull ubuntu@sha256:xxxxxxxx
```

## Merkle Tree

利用 Merkle Tree 来签名各个层，从而确保各层完整性。（当年在大学的Advanced Computer Security中做的presentation就是这个）

现在所有的内容都属于 named repository 的一部分，image id不再必须保持秘密；

简化认证模型，操作简化为push, pull；

客户端必须通过提供内容给另一个repository来证明内容是可用的，从而证明自己确实拥有其内容，而不会提供给另一个repository而取得不属于自己的layer。

v2放开了两部分的命名空间，不需要再限制于 `<user>/<image>` 了，可以多层。

push/pull 将可以断点续传，尚未实现，不过定义在api了。

# 和v1 API不同的地方

多步上传；

没有Search API、没有显式的Tag API。还在思考如何设计。

# Docker Registry 2.0 构成

不在使用 monolithic 构架

可扩展的，认证可以扩展、索引可以扩展，

会在 Docker 1.6 开始完全支持；

大多数概念都已经在 1.3、1.4 中验证了，比如更快的 pull 的速度。

现在在 Hub 上运行，S3 存储后端。

对比 v1

少了 80% 的Request
少了 60% 的网络带宽

V1 vs V2 错误，V2错误少了很多。

# Docker Registry 2.1

文档、Pull through caching、软删除、基本认证、Catalog API、Storage Driver，2015年7月中旬发布。

# Docker Distribution

目的：

* 改进image分发
* 构建安全稳固的基础

关注的焦点：

* 安全、可靠、性能

释放新的分发模型

* 集成信任系统(notary)
* 点对点大规模分发
