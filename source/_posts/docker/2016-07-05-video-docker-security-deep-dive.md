---
layout: post
category: docker
title: 视频笔记：Docker 安全探究
date: 2016-07-05
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Docker Security Deep Dive

{% owl youtube tL4IYSKu7ZU %}

<https://www.youtube.com/watch?v=tL4IYSKu7ZU>

{% owl tencent m0314drzxnd %}

<http://v.qq.com/x/page/m0314drzxnd.html>

Docker 1.12 中集成的 Swarm mode 集成了CA，所以自动确保所有证书类的东西是安全的。

Docker 提供了一个 Docker bench security 的工具，自动根据 CIS Docker Benchmark 来进行系统安全分析。

<https://github.com/docker/docker-bench-security>

受这个视频的启发，Linux 的安全审查工具： <https://cisofy.com/lynis/>  用于主机审查也是不错的。
