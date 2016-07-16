---
layout: post
category: docker
title: 视频笔记：Docker 在线交流会 13 - 介绍 Machine, Swarm, Compose
date: 2016-06-20
tags: [docker, youtube, video, notes]
---

<!-- toc -->

{% owl youtube H-fwxUeFZdQ %}

<https://www.youtube.com/watch?v=H-fwxUeFZdQ>

{% owl tencent l03144vdr1m %}

<http://v.qq.com/page/l/1/m/l03144vdr1m.html>

# Docker Machine

* `docker-machine create -d virtualbox dev` → 创建 virtualbox 虚拟机的 docker host ，命名为 `dev`
* `docker-machine ls` → 列出所有 docker-machine 建立的主机
* `eval $(docker-machine env dev)` → 当前环境换到指定的 docker host
* `docker ps` → 这样列出的是 `dev` 这个主机下的所有运行容器
* `docker-machine ssh dev` → 进入这个 docker host。

# Docker Compose

配置文件都写入 `docker-compose.yml`

* `docker-compose up -d` → 构建、启动这组容器
* `docker-compose ps` → 列出项目内的容器
* `docker-compose kill` → 删掉容器
* `docker-compose run web python test.py` → 指定运行指定服务的不同命令，比如这里是测试。

# Docker Swarm

docker swarm 是 Docker host 集群，可以把一群hosts变成一个docker host的感觉，它负责调度部署。

# 演示

`docker run swarm create`
则创建一个swarm id

创建 swarm-master

```bash
docker-machine create -d digitalocean \
    --swarm --swarm-master \
    --swarm-discovery=token://xxxxx \
    swarm-master
```

然后就可以创建swarm节点

```bash
docker-machine create -d digitalocean \
    --swarm \
    --swarm-discovery=token://xxxxx \
    swarm-01
```

然后把环境换到 swarm

```bash
eval $(docker-machine env —swarm swarm-master)
```

这样 `docker info`, `docker ps`, `docker run` 之类的就是直接在docker swarm集群上运行了。

而且由于 `docker-compose` 使用的是docker标准API，所以`docker-compose`会直接在swarm上执行

而且，可以使用 `docker-compose scale worker=5` 来横向扩展。
