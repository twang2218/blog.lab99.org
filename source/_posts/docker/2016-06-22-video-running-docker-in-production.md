---
layout: post
category: docker
title: 视频笔记：生产环境中使用 Docker 必需有一个很好地私有 Registry
date: 2016-06-22
tags: [docker, Sonatype, youtube, notes]
---

<!-- toc -->

# 视频信息

Running Docker in Production? A Premium Private Registry is a must!
by Sonatype, 2015/11/3

{% owl youtube qlsGHSFJ2ss %}

<https://www.youtube.com/watch?v=qlsGHSFJ2ss>

{% owl tencent c0314lz1iu6 %}

<http://v.qq.com/x/page/c0314lz1iu6.html>

# 公共registry

没有管理，不信任image

软件开发并不新鲜，开发就是生产，Docker Image 是供应链的一个环节而已。

# 企业需要一个 Private Registry/Repository

可以使用 `docker registry`，但是没有用户界面。
不是为了你的供应链环境设计的

# 一个健壮的 private registry 是必要的

* 可以本地并且共享
* 必须一致性
* 管理性：基于角色的访问控制允许保存私有信息，并且避免重复
* 集成能力：目录服务、编排、发布自动化、其它registries

# Nexus 3 Docker Private Registry

* Docker push/pull
* browse, search
* proxy of docker hub

```bash
docker search 192.168.1.4:18075/redis
```

这样可以直接搜索 Registry 内容，而且可以在 Nexus 设置 Docker Hub proxy，这样同时也会搜索 docker hub

# 相关信息

<http://www.sonatype.com/download-oss-sonatype>
<http://bitly.com/nexusanddocker>
<https://hub.docker.com/r/sonatype/nexus/>
