---
layout: post
category: docker
title: 视频笔记：Fluentd 和 Docker 架构 2015 - Kiyoto Tamura
date: 2016-07-04
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

Fluentd and Docker Infrastructure 2015
by Kiyoto Tamura, Treasure Data (VP)
(2015/08/03)

{% owl youtube udUr0pB_x-U %}

<https://www.youtube.com/watch?v=udUr0pB_x-U>

{% owl tencent y0314bwhvwk %}

<http://v.qq.com/x/page/y0314bwhvwk.html>

在Docker demo中，Kiyoto 使用了一个实现安装好 Docker 和 `td agents` 的计算机。先给大家展示了一下 `td-agent`的配置，位于 `/etc/td-agent/td-agent.conf`：

```xml
<source>
    type forward
</source>

<match td.*.*>
    type tdlog
    apikey ….
    auto_create_table
    buffer_type file
    buffer_path /var/log/….

    <secondary>
        type file
        path /var/log/…
    </secondary>
</match>
```

重启 `td-agent` 服务后，开始运行 docker，并指定日志输出到 `fluentd`。

```bash
docker run -it --name test \
    --log-driver=fluentd \
    --log-opt fluentd-tag=td.docker.{{.Name}} \
    ubuntu /bin/bash
```

注：参考 fluentd logging driver 文档，可能现在不需要这样了，容器名会自动作为tag输出。

<https://docs.docker.com/engine/admin/logging/fluentd/>

fluentd会自动加上 `container_id`, `container_name` 以及 `source`。

如果像示例中那样不指定 `fluentd-address` 参数，默认会连接 `localhost:24224`

`--log-driver` 可以加载 `docker daemon` 后，也可以加在 `docker run` 后使用。换句话说，可以记录 docker daemon的日志，也可以记录容器日志。

示例中，Kiyoto 使用的是本机的`td-agents`，而实际上可以在本机安装 fluentd，或者更好的做法，在本机运行一个 fluentd 的 docker 容器来跑这个服务。

<https://hub.docker.com/r/fluent/fluentd/>

演示中为了清空缓存，用kill发送`--USR1`信号给`td-agent`。然后打开了 <https://console.treasuredata.com> 使用Web UI来看日志中的记录。
