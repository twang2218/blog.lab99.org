---
layout: post
category: docker
title: 视频笔记：对于 OpenStack 日志管理而言 Fluentd 和 Logstash 对比 - Masaki Matsushita
date: 2016-07-05
tags: [fluentd, logstash, youtube, video, notes]
---

<!-- toc -->

# 视频信息

Fluentd vs. Logstash for OpenStack Log Management
by Masaki Matsushita from NTT
(2015/10/28)

{% owl youtube 1ye0-sityBw %}

<https://www.youtube.com/watch?v=1ye0-sityBw>

{% owl tencent b0314dpog04 %}

<http://v.qq.com/x/page/b0314dpog04.html>

# Fluentd

* Written in CRuby
* Used in Kubernetes
* by Treasure Data

# Logstash

* Written in JRuby
* by elastic.co

# 处理分流及聚合日志

Fluentd在`<source>`中会打上`tag`，后面的操作通过`<match >`其中的`tag`来决定如何执行。

Logstash 中没有 `tag`，因此只有在输出的时候通过条件判断去决定应该送给谁。

所以，Logstash 更适合默认聚合的流，而 Fluentd 更适合灵活的流。

# 插件

* Fluentd: 300+
* Logstash: 200+

Logstash的大多流行插件由 Logstash 项目维护，集成于 logstash 中。
而 Fluentd 只包含最基本的东西，大部分插件由个人维护。

# 传输协议

Fluentd 使用 `forward` protocol，可以`负载均衡`(甚至可以配置`weight`)，或者`active-standby`
Logstash 使用 `Lumberjack` protocol，只可以 `active-standby`
