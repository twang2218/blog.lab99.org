---
layout: post
category: docker
title: 视频笔记：使用 Node.js 和 Docker 构建微服务 - 第二讲 - Raziel Tabib
date: 2016-06-19
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

Building a Microservice using Node.js and Docker #2
by Raziel Tabib
2015-08-15

{% owl youtube lss2rZ3Ppuk %}
<https://www.youtube.com/watch?v=lss2rZ3Ppuk>

{% owl tencent  %}
<http://v.qq.com/page/o/8/j/.html>

* `Dockerfile`
* `Images`
* `Container`
* `Daemon`
* `Client`
* `Hub`

# 构建 `Dockerfile`

## 默认名为： `Dockerfile`

```Dockerfile
FROM ubuntu:latest
MAINTAINER 姓名 <邮件地址>

RUN ...
```

## 构建

```bash
docker build -t nodejs:0.1 .
```

注意最后的 `.`，这是上下文(context)的意思，这里应该包含的是构建所需的最小内容。

## 构建缓存机制

* 如果存在该层，则用缓存，没有就 rebuild
* 如果某一层需要 rebuild，其后的所有层都需要 rebuild
* `COPY`/`ADD` 会检查对应文件的校验值，文件内容改变，校验值即发生改变，改变就会 rebuild
* 其它的命令，看命令的字符串是否有改变，而不去查看命令执行结果是否变化。（**这点很重要，比如 apt-get update，其实每次都会不一样，但因为其命令没变化，就不再 rebuild 了**）

## Dockerfile 应当进入版本控制的 repo 里

这样镜像对应的Dockerfile也会在版本控制下，需要可以随时查看该文件的变动情况，以及修正原因。

## 缓存机制对 `npm install` 的影响

```Dockerfile
COPY . /src/
RUN npm install
```

如果像这样，将 `COPY` 置于 `RUN` 之前，那么就会导致，每一次代码的变动，都会触发 `npm install` 这一层的 rebuild，每次都会重复下载安装。因此效率很差。

所以比较好的做法是这样：

```Dockerfile
COPY ./package.json /src/
RUN npm install
COPY . /src/
```

这样分为3层，只有 `package.json` 变化，才会触发 `npm install`，而 `/src` 中的其它文件变化则只会触发最后一层。

## 创建 Digital Ocean 的 Docker 主机

使用 `docker-machine`

```bash
docker-machine create -d digitalocean server
```

## 将镜像放到主机上

**这里使用的是 `save`/`load`，比较好的方法应该是 `push` 到 registry 上。**

```bash
# 先保存镜像
$ docker save -o 文件名 镜像名:tag

# 使用 Digital Ocean 的 Docker 环境
$ eval $(docker-mahine env server)

# 加载该镜像
$ docker load -i 镜像文件名
```
