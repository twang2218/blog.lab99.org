---
layout: post
category: docker
title: 视频笔记：使用 Node.js 和 Docker 构建微服务 - 第一讲
date: 2016-06-19
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

Building a Microservice using Node.js and Docker #1
by NodeJSFan
2015-07-15

{% owl youtube PJ95WY2DqXo %}
<https://www.youtube.com/watch?v=PJ95WY2DqXo>

{% owl tencent  %}
<http://v.qq.com/page/o/8/j/.html>

视频笔记：

# 步骤

1. 创建基础镜像： Ubuntu + Node.js
2. 创建微服务镜像： Base Image + Service

(**注意，这是一年多前的文章，使用的是黑箱镜像制作办法，不推荐，现在都用 Dockerfile，所以不要模仿**)

# 创建基础镜像

```bash
# 看看有没有啥本地镜像
$ docker images

# 到 Docker Hub 上搜索 Ubuntu image
$ docker search ubuntu

# 返回结果很多，限定一下只要 1000 星以上的
$ docker search -s 1000 ubuntu

# 找到了，然后运行这个镜像
$ docker run -it ubuntu

# 没啥问题，试试后台运行这个ubuntu 持续15秒
$ docker run -d --name=my-container ubuntu sleep 15

# 创建一个 Ubuntu 的黑箱镜像，进去安装好 node.js 然后commit
$ docker commit -a razielt 22d ubuntu-node:1.0
```

# 创建 Express.js 微服务

```bash
# 安装 express 生成器
$ npm i -g express-generator

# 生成 express.js 应用模板
$ express my_microservice
```

编辑 `routes/api.js` 来建立最简单的 API

```bash
# 使用卷绑定来集成这个 express 应用
$ docker run -it -v $(pwd):/host -p 9000:3000 ubuntu-node:0.1 /bin/bash

# 然后将当前代码复制到对应目录，commit 一个黑箱镜像
$ docker commit -a razielt b4e node-microservice:0.1

# 运行该镜像
$ docker run -d -w /microservice -p 9000:3000 node-microservice:0.1 npm start

# 然后附着到这个docker进程上观看输出
$ docker attach 3d61
```

镜像制作好后可以推送到 Docker Hub 上。

```bash
# 登录 Docker Hub
$ docker login
$ docker tag node-microservice:0.1 node-microservice:latest
$ docker tag node-microservice razielt/node_microservice
$ docker push
```

这样镜像就准备好了，可以部署了。
