---
layout: post
category: docker
title: 视频笔记：runC - 一个可以运行 Docker 容器的小引擎 - Phil Estes
date: 2016-07-11
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - runC - The little engine that could (run Docker containers)
by Phil Estes from IBM Cloud (@estesp)

{% owl youtube ZAhzoz2zJj8 %}

<https://www.youtube.com/watch?v=ZAhzoz2zJj8>

# 自我介绍

* 已经参与开发Docker项目2年了，是Docker engine maintainer
* 是 Docker Captains 成员
* 已经参与 Linux/OSS 10+ 年的经验
* 实现 Docker engine 的User namespace
* 帮助设计 `v2.2` image spec 多平台支持
* 实现第一个工具用于创建多平台image （v2.3 registry & Docker Hub)

# 什么是 OCI？

`OCI` → `Open Container Initiative`

* OCI 是一个 Linux foundation 协作项目

* 不受任何厂商所控制

* 定义了一系列标准

  * 包括容器 `runtime specification`
  * 参考运行时
  * `image format specificaiton`

* 宣布于 2015/06/20

* 签署于 2015/12/08

* 当前大约有46个公司

* 今年6月 `runtime specification` 将会到 `1.0.0-rc1`, `image format specification` 将会到 0.3.0

<https://github.com/opencontainers/>

# 什么是 `runC`？

## Introduction to `runc`

runc 是一个 libcontainer 的wrapper
Libcontainer 则是操作系统的接口

runc 需要两部分信息：

* 一个 OCI 配置(JSON)
* 一个 root 文件系统

所以，

```bash
docker run -it —read-only -v /host:/hostpath alpine sh
```

命令将会被翻译为 `config.json`

```json
{
    "ociVersion": "0.6.0-dev",
    "platform": {
        "os": "linux",
        "arch": "amd64"
    },
    "process": {
        "terminal": true,
        "args": [
            "sh"
        ],
        "env": [
            "PATH=/usr/local/sbin:/usr/local/bin:/bin",

        ]
    }
}
```

## runC: An open innovation platform

* 实现底层容器特性

  * 操作系统级别的特性应该定义于 `OCI runtime specification`
  * 新的功能 (`PID cgroup controls`, `checkpoint`/`restore`, `seccomp`) 应该在`runC`中实现

* OCI 兼容/可插接的执行引擎

  * 通过 OCI spec 兼容的代码为容器实现OS环境
  * 比如：`runz` (Solaris zones), `runv`(hypervisor-based), `Intel Clear Containers`

* 迭代式的容器配置测试/调试

  * 简单的 "Docker-like" 变种，更少的 friction 和快速变化
  * 降低依赖门槛：单一的binary + 物理 r`ootfs bundle` + `JSON config`

前十贡献 `opencontainers/runc` 的公司：

Docker, OpenVZ, Huawei, Redhat, Google, IBM, SuSE, Pivotal, Fujitsu, Microsoft

# Demo

## Some tools

```bash
/usr/bin/runc           https://github.com/opencontainers/runc
/usr/bin/ocitools       https://github.com/opencontainers/ocitools
/usr/local/bin/riddlers https://github.com/jfrazelle/riddler
/usr/local/bin/netns    https://github.com/jfrazelle/netns
/usr/local/bin/uidmapshift  http://bazzar.launchpad.net/~serge-hallyn/+junk/nsexec/view/head:/uidmapshift.c
```

> `jfrazelle` - Jessica Frazelle - Queen of Container

## ocitools

`ocitools generate` 会立刻产生一个 JSON 文件，即使没有指定任何东西，也会产生一个具有基本能力的 JSON 配置文件。

`ocitools generate --help` 会显示很多配置信息，有些像 `docker run` 的命令。

## 创建基本的`alpine`容器

```bash
# 运行一个简单的 docker container
$ docker run --name alpine alpine date

# 运行 riddler，会将指定容器的配置保存为 config.json
$ mkdir alpine
$ riddler -idlen 65535 -idroot 100000

# 运行 runc
$ runc start alpine
```

什么结果都没有返回，命令不工作，原因是我们需要两部分信息，这里只提供了 `config.json`，还缺 `rootfs`

```bash
# 使用这个脚本提取 alpine 容器的rootfs到指定目录以及更换uid
$ exportrootfs -u 10000 -r 65536 alpine

# 可以看一下这个目录，里面是标准alpine的目录结构
$ ls -l rootfs

# 然后再次尝试运行 runc
$ runc start alpine
could not synchronise with container process: device or resource busy
```

这是由于 Ubuntu 14.04 内核升级后和 Docker `user namespace` 冲突的一个`bug`，已经修复了，将在在 `4.4.0-25` 发布后解决(现在是`4.4.0-28`)。

由于使用的是 `runc` 所以并不是说就没救了，由于这个问题是 `mqueue` 导致的，而在 `config.json` 文件中，我们可以找到使用 `mqueue` 的地方，我们可以直接把 `/dev/mqueue` 部分删除。然后再次尝试。

```bash
$ runc start alpine
Tue Jun 21 20:51:54 UTC 2016
```

而且我们可以修改 `config.json` 来进行别的事情，比如把其中的 `Terminal` 改为 `true`，把`args`中的`/bin/date`改为`sh`。

```bash
$ runc start alpine
/ # ls -l
...
```

这里显示的文件所有信息是 `root`，而在外界 `uid` 则是 `100000`。

此时的网络部分还是不工作的，因为 `runc` 不负责网络部分

```bash
$ ifconfig
lo  ...
```

我们可以用 `riddler` 修复这个问题
使用 `hook`，在 `prestart` 的时候执行 `netns`
当然不要忘了去掉 `mqueue`

```bash
riddler -idlen 65535 -idroot 100000 -hook prestart:netns alpine
```

此时再运行 runc，就有了网络接口，并且可以访问外部了。

```bash
$ runc start alpine
/ # ifconfig
eth0 ...
lo ...
```

`runc`, `docker` 已经定义限制了很多 `syscall`，主要是在于那些管理性质的
比如 `get_hostname` 可以，但是 `set_hostname` 就不可以。

如果查看 `config.json` 会看到，配置 `Hostname` 所需的 `SYS_ADMIN` 权限并不在列表中。
如果我们添加了 `CAP_SYS_ADMIN` 到 `capabilities` 中，再次运行就可以修改 `hostname` 了

```bash
/ # hostname
alpine
/ # hostname foo
/ # hostname
foo
/ #
```

我们可以进一步的利用 `seccomp` 精调这部分权限，比如我们可以将 `config.json` 中的 `sethostname` 的权限从 `SCMP_ACT_ALLOW` 改为 `SCMP_ACT_KILL`，然当我们再次执行 `hostname` 设置主机时就会报错

```bash
/ # hostname
alpine
/ # hostname foo
Bad system call
```

## 更加复杂的容器 `nginx`

使用 `runc` 在一个地方运行了 `nginx`，在另一个地方运行了`lynx`来访问页面。

运行 `ps aux | grep nginx` 会发现 `nginx` 实际上是以`root`身份运行的，因为最初导出的时候忘记了设置 `uid`。所以现在可以重新做一个`nginx`容器。

```bash
docker run --name nginx nginx
riddler -idlen 65536 -idroot 200000 -hook prestart:netns nginx
exportrootfs -u 200000 -r 65536 nginx
```

这次再 `ps aux | grep nginx` 就可以看到这个以 `200000` id 运行的 nginx 容器了。

由于知道了 `rootfs` 的位置，所以可以直接进到这个位置替换文件。

这个运行在用户 `namespace` 的 `nginx pid` 是 `24252`，可以 `ls -l /proc/24252/ns` 看到 `namespace` 的信息。

现在如果想创造一个网络共享的 `alpine`，那么必须`user namespace`一致。

```bash
mkdir alpine2
cd alpine2
riddler -idlen 65536 -idroot 200000 alpine
exportrootfs -u 200000 -r 65536 alpine
```

在 `config.json` 中找到 `"type": "network"`，添加一行`path`，既：

```json
{
    "type": "network",
    "path": "/proc/24252/ns/net"
}
```

同样修改 `user namespace`：

```json
{
    "type": "user",
    "path": "/proc/24252/ns/user"
}
```

然后这次我们运行这个 `alpine2`

```bash
$ runc start alpine2
/ # ifconfig
eth0    ...
        inet addr: 172.19.0.11 ...
...
```

`alpine2` 运行在了刚才 `nginx` 的网络里。
