---
layout: post
category: docker
title: 视频笔记：Containerd - 构建容器 Supervisor - Michael Crosby
date: 2016-07-11
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Containerd - Building a Container Supervisor
by Michael Crosby

{% owl youtube VWuHWfEB6ro %}

<https://www.youtube.com/watch?v=VWuHWfEB6ro>

{% owl tencent q0314svqva0 %}

<http://v.qq.com/x/page/q0314svqva0.html>

# > whoami

* 自 Docker 0.3 开始就是介入开发，0.5开始就是 maintainer （就是从绑定 localhost 变成绑定 socket，嗯，结果所有人的环境都出问题了）
* dockerui 的作者
* libcontainer 的作者
* nsinit 的作者
* runc 的作者
* containerd 的作者
* OCI 的maintainer

# > man containerd

* 非常轻量级的容器 supervisor

  * 很多人说这是在取代 systemd，不是这样的，这个专注于容器

* runC (OCI) multiplexer

  * 虽然叫containerd，但是真正创建容器的是runC(OCI)层

* 容器生存周期操作

# > why

* 集成 runc
* 支持多个 runtime
* Execution v2
* 分离执行机构和文件系统
* daemonless 容器
* 更干净的开发环境

# Benchmarks

```bash
$ ./benchmark -count 100
INFO[0001] 1.149902846 seconds
```

测试containerd:

```bash
sudo containerd —debug` 然后另一边运行 `sudo ./benchmark -count 100
```

# events

* 无锁 event loop

* 并发控制

  * 一次并发10个可能会比并发100个更快。

# > daemonless

这是一个非常常见的需求，Docker升级非常快，但是每次升级所有的容器都会被kill掉然后重新运行。所以需要更平滑的升级方式，升级Docker不会让容器死掉。

## > container state

* 最简单的管理状态的办法就是让容器没有状态
* 内存里什么都不保存
* /run 是你的好朋友

容器只是个进程，所以只需要 pid 和 path 指向对应的位置即可恢复所有的东西，而不需要在内存中有一个复杂的结构去保存这些状态信息。

## > daemonless problems

* 退出代码和wait4()
* tty / stdio
* reparenting
* facilitated by a shim

### > containerd-shim

> `containerd` → `多个 shim` → `每个 shim` 对应 `一个 runc`

`shim` 解决了 `tty` / `stdio` 和 `reparenting` 问题

### > exit status

* FIFO for blocking + file

  * fifo (Pipe with inode) for exit event
  * file for exit status

* O_CLOEXEC

* RDONLY/WRONLY

```c
if (mkfifo(“exit-fifo”, 0666) != 0) {
    printf(“%s\n”, strerror(errno));
    exit(EXIT_FAILURE);
}
int fd = open(“exit-fifo”, O_WRONLY | O_CLOEXEC, 0);
```

### > stdio

* FIFOs for data

* fifos have a buffer (default 64k)

  * /proc/sys/fs/pipe-max-size

### > re-parenting

> `shim` → `runc` → `container`

当 `runc` 退出后，`container` 可以 `reparent` 到 `shim`。

#### > re-parenting rules

* 你的 `parent` 是 `fork` 你的进程
* 如果你的 `parent` die，你新的`parent`是 `PID 1`

在 3.4 之前，是这样的，但是 3.4 之后，增加了个 `subreaper`

* `prctl` - `PR_SET_CHILD_SUBREAPER`
* “In effect, a subreaper fulfills the role of init(1) for its descendant processes.”

所以像刚才说的情况，`shim` → `runc` → `container`，如果`runc`退出，正常情况，`container` 将会成为 `init` (`pid:1`) 的`child`，而`shim`使用了`subreaper` 后，将会截断这个收养进程的上溯过程，`shim` 将成为 `container` 的新 `parent`。

## > The OOM problem

如何在用户进程启动前连接到 OOM (`Out of Memory`) 通知

### > runtime workflow

* `create`

  * 初始化`namespace`和配置

* `start`

  * 执行用户进程

* `delete`

  * 删除容器

这样在 `create` 和 `start` 中间，可以有很多处理事务的机会，包括处理 `OOM` 的情况。

```bash
runc create test
runc list
runc start test
```

# 演示代码

<https://github.com/crosbymichael/dockercon-2016>
