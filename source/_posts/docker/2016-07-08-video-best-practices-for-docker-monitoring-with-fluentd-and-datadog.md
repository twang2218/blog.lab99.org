---
layout: post
category: docker
title: 视频笔记：用 Fluentd 和 Datadog 监视 Docker 的最佳实践 - John Hammink
date: 2016-07-08
tags: [docker, fluentd, vimeo, notes]
---

<!-- toc -->

# 视频信息

Best Practices for Docker monitoring with Fluentd and Datadog
by John Hammink
(2015/08/11)

{% owl vimeo 137998663 %}

<https://vimeo.com/137998663>

{% owl tencent d0314vikb0b %}
<http://v.qq.com/x/page/d0314vikb0b.html>

# Fluentd: Unified Logging Layer

# 自我介绍

恢复软件和QA工程师，后来由于对分形的痴迷成了Digital Artist。而现在则是喜欢使用GPU对大规模数据直接进行数据视觉化渲染。

github: `jammink2`

# 什么是 Fluentd？

一个 **可扩展的** ， **可靠的** ， **数据收集** 工具

* 可扩展：一个很简单的核心 + 很强大的插件
* 可靠的：Buffering, HA (failover), load balancing
* 数据收集工具：像 `syslogd`

统一的日志数据收集工具，基于 `Ruby` 写的，有一部分`C`的代码。数据流使用统一的`JSON`格式。

# Extensible

## Core

* Divide and Conqure
* 缓存、重试
* 错误处理
* 消息路由
* 并行

## Plugins

* 读
* 解析
* Buffer
* 写数据
* 格式化数据

# 内部架构

1. Input
2. Parser
3. Filter
4. Buffer
5. Format
6. Output

简化结构： 输入 → Buffer → 输出

Fluentd 将 M x N 的复杂度，降为 M + N。

# Use Cases

## 简单的转发

{`Web`, `Mobile`} → `Fluentd` → `MongoDB`

```xml
# log from a file
<source>
    @type tail
    path /var/log/httpd.log
    format apache2
    tag backend.apache
</source>

# log from client libraries
<source>
    @type forward
    port 24224
</source>

# store logs to ES and HDFS
<match backend.*>
    @type mongo
    database fluent
    collection test
</match>

```

## 略复杂一些的例子

{`mobile`, `web`} → `第一级 fluentd` → `第二级 fluentd` → `ElasicSearch`

## Lambda 架构

{`mobile`, `web`} → `Fluentd` → {`ElasticSearch`, `Hadoop`}

```xml
# logs from a file
<source>
    @type tail
    path /var/log/httpd.log
    format apache2
    tag web.access
</source>

# logs from client library
<source>
    @type forward
    port 24224
</source>

# store logs to ES and HDFS
<match *.*>
    @type copy
    <store>
        @type elasticsearch
        logstash_format true
    </store>

    <store>
        @type webhdfs
        host namenode
        port 50070
        path /path/on/hdfs
    </store>
</match>
```

## Fluentd + Docker 的例子

环境是`3`个Docker容器{`Rails`, `PostgreSQL`, `RabbitMQ`}在运行，日志通过`Fluentd`日志驱动输出给 `Fluentd` ，`Fluentd` 进而发送给 `S3`, `MongoDB`, `ElasticSearch`, `Treasure Data`等等。

下面是接收日志的 `fluentd` 的配置

```xml
<source>
    @forward
</source>

<match td.*.*>
    @type tdlog
    apikey xxxxx
    auto_create_table
    buffer_type file
    buffer_path /var/log/td-agent/buffer/td
    flush_interval 5s

    <secondary>
        @type file
        path /var/log/td-agent/failed_records
    </secondary>
</match>

<match td.*.*>
    @type stdout
</match>
```

```bash
docker run -it \
    --name test \
    --log-driver=fluentd \
    --log-opt fluentd-tag=td.docker.{{.Name}} \
    ubuntu /bin/bash
```

然后去`Treasure Data`可以看到数据

# Docker Toolbox

by Michael Chiang

## Docker Toolbox 内容

* Docker client
* Machine
* Compose
* Kitematic
* Virtualbox

# Future of Boot2Docker

`Boot2Docker CLI` 废弃了，被 `Docker Machine` 替代了
下一代的版本将会代替当前的 `TinyCore Linux` 版本

# Monitoring Docker at Scale (Datadog)

by Matt Williams

## Steps to working with Docker

* 创建一个 Docker Host (`docker-machine`)
* 从一个镜像创建 Docker 容器
* 多个容器协作 `Docker Compose`

## docker-machine

可以帮助创建 `Docker Host`，{`Mac`, `Windows`}:(boot2docker), `Google`, `AWS`, `Digital Ocean` …

```bash
docker-machine create -d vmwarefusion fusiondkr

eval $(docker-machine env fusiondkr)
```

用`vmware`, `virtualbox`非常容易，用其他的云服务则需要很多配置。

比如Openstack

```bash
docker-machine create -d openstack \
    --openstack-flavor-name standard.large \
    --openstack-image-id “xxxxxxx” \
    --openstack-floatingip-pool “Ext-Net” \
    --openstack-ssh-user ubuntu \
    hpdocker

eval $(docker-machine env hpdocker)
```

再比如 AWS：

```bash
docker-machine create -d amazonec2 \
    --amazonec2-access-key $AWS_ACCESS_KEY_ID \
    --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
    --amazonec2-ami $ami \
    --amazonec2-instance-type $instance_size \
    --amazonec2-vpc-id $vpc_id \
    --amazonec2-security-group $security_group \
    --amazonec2-region $aws_region \
    <machine name>
```

> `docker build` → `docker run`

前端一个 load balancer，用的是`nginx` + `consul-template`
后端是各种应用。`Dockerfile`太多无畏的层，而且使用了 `Supervisord`，其实是把容器当做虚拟机了。

```bash
docker-compose scale web=20
```

download demo:  <http://dtdg.co/dkron>

监测 docker 状态

两种命令形式，一种是

```bash
docker stats
```

这样会只显示容器ID，一串数，估计一般都不知道是啥

另一种是尾坠容器名

```bash
docker stats \
    nginxredisdocker_datadog_1 \
    nginxredisdocker_loadbalancer_1 \
    nginxredisdocker_registrator_1 \
    nginxredisdocker_consol_1 \
    nginxredisdocker_web_1
```

另一种方式查看状态的形式，通过 `REST API`

```bash
http --stream -f --verify=no \
    --cert=$DOCKER_CERT_PATH/cert.pem \
    --cert-key=$DOCKER_CERT_PATH/key.pem \
    https://172.16.88.129:2376/containers/xxxxxxx/stats

docker-machine ls
docker-machine ip

docker ps
```

# Monitoring at Scale

## Operational Complexity

* 平均每个主机的容器数量：N ( `2014年10月`时，N是`5`，今年`2016`，统计同样是`5`）
* N * 主机数量 = 多少个“主机”来管理
* provision, configuration, orchestration, monitoring.

## 需要去测量的东西

* 一个虚拟主机

  * `10`个左右的东西

* 一个操作系统

  * 大约`100`个测量点

* `N`个容器

  * `100` * `N` 个测量点

* `110` + `100` * `N` 个测量点/虚拟机

如果我们以前每个主机需要`160`个测量点，现在就得需要`610`个测量点

如果我们有`100`个主机，就得需要`61K`个测量点。

和虚拟机不同，容器的生存周期更短

虚拟机的生存周期可能是小时、天、月为单位，而容器则是分钟、小时，天为单位。

用 `Tag` 去监测，而不是用主机IP之类的。这样可以忽略不同容器的生死变化。
