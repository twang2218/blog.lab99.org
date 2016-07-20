---
layout: post
category: docker
title: 视频笔记：Docker for Mac and Windows - 深入指南 - Justin Cormack
date: 2016-07-06
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Docker for Mac and Windows - The Insider’s Guide
by Justin Cormack, Docker (Cambridge)

{% owl youtube 7da-B3rY9V4 %}

<https://www.youtube.com/watch?v=7da-B3rY9V4>

{% owl tencent d0314fbp2mx %}

<http://v.qq.com/x/page/d0314fbp2mx.html>

# 自我介绍

他写的书：`Docker in Production - Lessons from the Trenches`，已经有中文版了：`Docker 生产环境 - 实践指南`

# Make it native

就像 `Linux` 环境一样，装上了就在那，想用随时可以用，不需要 `Virtualbox`（没人喜欢vbox），不像 `Toolbox` 那样 intrusive。最关键的，让文件 `notification` 可以正常工作（vbox共享宿主目录不行）

大约花了6个月去开发。有3万人在第一天就注册要测试，而到`DockerCon`的时候已经有7万人了。

# Let’s Go Inside

Justin 显示了一个 `ps` 列表，这是所有 `Docker for Mac` 的相关进程列表，基本反映了其工作原理。

# Hyperkit

这是一个嵌入式 hypervisor toolkit。

* 只在 Mac 上使用，Windows 则使用的是 `Hyper-V`。
* 基于 `xhyve`，这是从 `FreeBSD` 的 `bhyve` 移植过来的。
* 一个 `hypervisor` 只是一个虚拟核的单进程。

几年前 `OSX` 引入了虚拟化框架，单进程启动可以虚拟机一个系统，非常轻量级，但是文档超烂。没人用它，直到 `xhyve` 项目启动，这个项目大约重写了 `bhyve` 一半的代码。

最初的 `Docker for Mac` 的日子就是使用 `xhype` + `Linux`，然后不断打补丁开始的。

由于 OS X 不支持 Sparse 文件，所以在 `Hyperkit` 中使用了 `qcow2` 文件作为 `sparse block device`。今年的`WWDC`上，苹果说将支持 `Sparse` 文件，将来可能会使用。

virtio device: `network`, `block`, `9p`, `socket`, `rng`

内存、CPU核心，都可以配置。

# DataKit

这是一个很有意思的项目，可以理解为是 `git for data structures`。这是一个 `Git database`。

在 `Docker for Mac/Windows` 中的应用是很简单的，只是作为配置的存储而已。但是这个项目本身的功能很强大，可以像 `git` 那样的树型结构，以及分支`fork`, `merge`，但是是对于存储的数据而言的，而且是分布式存储。`9p`

Docker的配置就存储于下面的位置，而且是个 git repository：

```bash
~/Library/Containers/com.docker.docker/Data/database
```

很多配置可以直接在这里修改，比如CPU核，Docker `storage driver`等等。`commit` 后，`Docker for Mac`将会重启使用新的配置。将来会在 GUI 中的 Advanced 里面添加进去。

而且这个配置在VM里也可以看到：`/Database/branch/master/ro/com.docker.driver.amd64-linux/`

Justin 在执行这个VM的时候使用了一个很有意思的命令，他执行了一个 Docker ：

```bash
docker run -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i sh
```

# Plumbing

最后在很多东西中间选择了 `VSock` 和 `HVSock`。用他们来进行 `VM` 间的通讯，就像 `Unix sockets` 一样。

`VSock` 最初是由 `VMWare` 开发，而 `HVSock` 是微软开发的，设计差不多，但是实现方式不同。

这些新的 socket 没有很好地支持，没有 `Go` 的支持，所以只能够通过 `C` 绑定来实现。

通讯由于不是走的网络栈，所以即使网络有故障，通讯也不受影响，除了VM间，也包括宿主和VM的通讯。（提到了VM间，是否意味着可以像 Toolbox 那样有多宿主？）

# Moby

`Moby Dock` 实际上是Docker那只鲸鱼吉祥物的名字。在这里是承载 Docker 主机的 Linux 项目的code name。

<https://youtu.be/9xciauwbsuo>

## 无状态

`Moby` 是基于 `Alpine Linux`，`Alpine Linux` 已经有8年历史了。是安全的轻量级Linux发行版，基于 `musl libc`  以及 `busybox`。

Alpine 的设计意图是**无状态** 的，目的就是可以在 `ramdisk` 之类的地方运行，根本不进行安装，重启之后一切恢复初始状态。这恰好是和Docker容器的短生存周期的理念一致。

`/var` 目录是可以保留的，Docker 负责这个了。

`/Database` 现在挂载上了 `Datakit` 的数据库。

像 `Phoenix` 一样，每次都是重新构建新的 `image`，没有升级更新。

非常精简，只运行 Docker 和所需的东西。

## 没有用户可以修改的部分

* Just works，确保 Docker 运行。
* 所有配置都在 `Datakit` 的`database`里。
* 如果需要任何宿主的改变，都是通过 `--privileged` 的容器来进行，而且通过 `--restart=always` 来保持持久化。
* 比如安装 `sysdig` 内核模块
* root shell: `docker run -it —privileged —pid=host debian nsenter -t 1 -m -u -n -i sh`
* 可以 `apk update` 或者 `apk install gdb`之类的行为，但是重启就都没了。

## 内核

* 当前使用的是 `stable 4.4.x` 系列的内核，外加 `aufs`, `vsock`, `hvsock` 补丁。
* 没有模块，所有东西都内置了，目的是快速启动，当然可以添加模块
* 现在支持 `aufs` 和 `overlay`，默认是 `aufs` 新的 `1.12` 发布带来了新的 `overlay2` 的支持，解决了之前 `overlay` 的很多问题，所以可能不就这里切换到默认 `overlay2`。
* 支持 `NFS`, `SMB`, `CRIU` 之类的
* 支持 `binfmt_misc` 所以可以通过 `QEMU` 运行 `ARM`、`PowerPC`, `MIPS` 或者其他构架的可执行程序（超赞）。

```bash
$ docker run -it justincormack/armdemo uname -a
Linux a764b3418f3d 4.4.14-moby #1 SMP Tue Jul 5 02:07:16 UTC 2016 armv7l Linux
$ docker run -it justincormack/armdemo file /bin/busybox
/bin/busybox: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-armhf.so.1, stripped
```

* 配置在 `/proc/config.gz` 里，补丁在 `/etc/kernel-patches` 里。

## Userspace

* `Alpine 3.4`
* `静态编译`的 Docker 并且带 `seccomp` 支持（暂不支持 `AppArmor`，可能将晚些时候会支持）。
* 还添加了一些如时间同步之类的功能，`Kubernetes` 需要一些东西的支持

# VPNKit

现在是在 Mac 上使用，目前正在 Windows 上测试（可以用，默认是关闭的）。

将所有 Linux VM 中的以太网 traffic 都在 OS X 上重构成**应用**级的traffic，所以在 OS X 上看到的只是一个普通程序在打开网络连接，因此不再需要建立一些奇怪的network interface了。

这样的实现方法可以更好的处理 VPN, 防火墙等这些网络环境环境，解决这些环境中容器无法上网的问题。

VPNKit 使用了 `Mirage Unikernel` 中的网络栈。
`Mirage` 是底层的系统库，使用 `OCaml` 写的 (`functional programming language`)
很容易移植到别的地方使用。

# OSXfs

* 现在是在 Mac 上使用，目前在 Windows上还是通过SMB绑定来实现的（将来可能会在Windows上实现，不过名字恐怕得换）。
* 在 Linux 部分用的是 `FUSE` 来承接系统调用和处理
* 将所有通讯转移到 `VSock` ，并且转换成 OSX 的系统调用
* 监听 OSX 的文件系统通知，然后把它变成 Linux 的事件转发过去。

因此 `inotify` 终于可以用了，还有一些小问题，比如OSX没有读文件事件。

可以看到，从构架上，`OSXfs` 和 `VPNKit` 非常接近，二者都是把不同系统之间的信息进行转换。

所有这些都是以当前用户身份执行的，所以绑定卷之类的事情直接就可以工作。而没有额外的安全隐患，我们都不希望它以root执行。而在 Linux 和容器中，肯定不希望看到某个建立的文件使用的是 Mac 上的 UID。所以在这里就有转换，会显示该容器执行用户的ID。所有这些都是假的。

# Windows file sharing

当前 Linux 到 Windows 之间的文件共享使用的是 SMB
虽然协议上讲 SMB 支持 `FS Notifications`，但是 Linux 实现上没人愿意去实现这一部分，所以无法支持。
我们将来会设法移植 `OSXfs` 到 Windows 上，这样就可以像 Mac 一样了。但是需要时间，Windows 文件系统和 Linux 的差异就更大了。

# 用户界面

* 现在很精简，将来会有更多的功能加进来。
* 是`Native`的代码，在OSX上用的是`Swift`；在Windows上用的是`C#`。
* 通过 `Datakit` 的数据库进行配置
* 计划会把 `Kinematic` 或者其它的界面集成进来。

# Design

一群古怪的鲸鱼，有 Lauro? 设计

# 为什么 XXX 不能用啊？

## `--net=host`的网络不能用

原因是目前使用了 `VPNKit` 后，当容器通过 `--publish` 公开一个端口的时候，实际的通讯是通过 `/port` `9p` 文件系统传递给 Mac 的，然后 Mac 部分会开始在主机上监听这个端口。

这样在 Mac 上当你连接 `localhost:nnn` 的时候，会将这个网络通讯转发给 Linux，并进而转发给容器。同样，在Docker Swarm下也是这么用的。（*将来必然可以支持多宿主*）

但是当使用 `--net=host` 后，监听端口将不会通知 Docker，所以 Docker 没有轻易的办法可以进行上面的操作。将来会想办法修复这个问题。

## 我无法连接到容器端口

不像以前 `Docker Toolbox` 或者 Linux 上那样，Mac 主机和容器之间没有路由通路（`bridge`)，所以无法直接通过容器IP连接到容器。

如果需要调试，可以通过另一个容器，比如 `docker run --net=container:name`

其实应该习惯这么做，毕竟在多宿主网络（`overlay network`）调试中，只能这样调试，宿主是无法和另一台宿主的容器直接通讯的。

曾经有一度能用来着，后来不能了，毕竟宿主不再有`bridge`接口了。将来是不是还会支持……很难说。

## 主机和容器间的 Unix socket 不能用

其实这不怪我们，虽然我们尽量让大家感觉容器是直接在 Mac 上运行，但是 Mac 和 容器不是在一个主机上的，中间还有个 Linux 呢……

不过将来确实打算实现这个功能，通过 `OSXfs` 和 `VSock` 透明代理。当前其实已经部分在这么用了，在 Docker socket 上。

目前，用 TCP 就好了。

## 声音和视频

`X Win`, `RDP`, `VNC`, `HTTP GUI` 应该可以设法让它们能工作，`Audio` 估计也有可能。
目前不是很多人需要这些，所以如果愿意可以帮忙实现这些

# Roadmap

## Stability first, features second

目前更重要的是稳定性，而不是`feature`，但是是用户驱动 feature 的，所以尽情来替自己的想法。

# Team

团队大部分人都在 DockerCon 现场，而且还有很多 Docker 的员工贡献了代码。并且包含了大量的开源软件（特别是 `bhyve`, `xhyve`, `Mirage`, `Alpine Linux`）

幻灯片在：`docker run -d -P justincormack/dockercon2016`
