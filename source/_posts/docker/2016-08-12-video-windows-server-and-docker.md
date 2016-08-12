---
layout: post
category: docker
title: 视频笔记： Windows Server 和 Docker - John Starks
date: 2016-08-12
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

`DockerCon16`

Windows Server & Docker
(The Internals Behind Bringing Docker and Containers to Windows)
by John Starks & Taylor Brown
Principal Leads in Windows, Microsoft

{% owl youtube 85nCF5S8Qok %}

<https://www.youtube.com/watch?v=85nCF5S8Qok>

{% owl tencent v03145c99ec %}

<http://v.qq.com/x/page/v03145c99ec.html>

# 自我介绍

Taylor Brown 是微软 Windows 服务器部分的 Principal Leads Program Manager。

已经和 Docker 团队合作两年了。开始的时候微软团队飞到Docker总部，然后问，可不可以让Docker 命令行支持微软做的容器API？当时，Solomon Hykes (CTO) 在会议室里就说，这东西是开源的呀，你们想做什么改变的话，自己改呗。然后微软团队一脸茫然……😳 （*显然这帮人完全不理解开源社区的概念*）。两年之后，确实发现这是一个很好地方式，也非常有趣味，完成了很多功能。

John Starks 是微软的容器部分的主要构架师之一。

# 基本概念

## 什么是 Docker on Windows

不要和 `Docker for Windows` 弄混了。`Docker for Windows` 是在 Windows 上运行一个 Linux 虚拟机，里面跑 Linux Docker。

而 `Docker on Windows` 是将 Docker 引擎移植到 Windows，提供 Docker API， 直接在 Windows 系统上通过移植后的 Docker Engine，来运行Windows容器，在里面跑的是 Windows 程序，运行于 Windows 内核（而不是Linux程序运行于Linux内核）。由于使用 Docker API，可以支持 Compose, Swarm 等。

`Docker on Windows` 不是微软的 fork，而是就在 GitHub 的`docker/docker` 的 `master` 分支里。

将来可能会把 `Docker on Windows` 集成到 `Docker for Windows` 中去。

移植的时候发现很多 Linux (*存在很多年的*)特性在 Windows 上都没有类似的东西，所以得现改 Windows 内核才能继续移植。所以过去的 Windows 无法运行，必须是改了内核后的还没发布的 Windows Server 2016 以及最新版的 Windows 10。

（*注：非常怀疑这种临时改的东西的稳定性，Linux 这类东西已经存在近10年了，不断地发现问题和完善，现在很稳定。微软的这东西，现改的，而且没有经过像 Linux 世界那样广泛的生产环境测试，就算实现了也不大靠谱。*)

一定要区别开，这是在 Windows 主机上运行 Windows 容器，里面跑的是 Windows 程序。而不是运行 Linux 容器，里面跑 Linux 程序。(*注：换句话说，今天 Docker Hub 上的大部分镜像，包括所有官方镜像，都用不了。那些都是为 Linux 容器准备的。*)

如果现在想尝试的话，可以访问链接： <http://aka.ms/containers>

## 演示

在一个 `CMD` 窗口里，直接用 `dockerd` 命令起了一个 Docker Engine。

在另一个 `CMD` 窗口就可以使用 `docker` 命令行操作，比如 `docker images` 之类的。（*注：注意视频里的镜像大小……😅*)

```bash
docker run --rm demo cmd /c echo Hello, DockerCon1
```

……等待了大约3秒多后，终于输出了 `Hello, DockerCon1`……*说好的秒起呢？*

## 怎么做到的？

改呗。

* 在 Windows 系统层面，增加namespace, 增加 Resource Controls(模拟 cgroups），增加 Union FS。
* 改造 Docker 本身，将其中默认 *nix 的东西通用化，比如，fork, console, network 插件等等
* 改造 Windows 以适应容器。最开始的时候，微软这帮货打算重复造轮子，想按自己的思路设计容器系统，结果碰了很多钉子后发现自己的做法貌似不大对……和Docker 的交流中，逐步的发现了自己的问题，修正自己的设计思路。

## 构架

对于 Linux 而言，构架上从下往上是， Linux 内核上，运行 `containerd` => `runC` => `libcontainerd` => `Docker Engine` => `REST API`

而 Windows 从 `libcontainerd` 往上构架上没有变化，主要变化在下层。内核支持了类似于 `cgroups`, `namespace`, `Union FS` 之类的东西，但是其上运行的是一个叫做 `Compute Service` 的服务，该服务替代 `containerd` 和 `runc` 来给 `libcontinerd` 提供支持。

### Compute Service

由于现在系统底层这些新加入的功能还处于快速开发阶段，没有办法提供稳定的底层 API，所以加入一层更高层面的 API，给容器，方便容器调用。这里的 `Compute Service` 可以大致理解为 `containerd` on Windows。

负责管理容器，起、停、重启之类的事务。将底层的细节抽象出来。

现在已经有 Compute Service 的 C#, Go 语言封装的调用库了。

### Windows Server Containers 构架

和 Linux 上一样，容器和宿主系统共享内核，当然这里是共享 Windows 内核。

但是如果仔细观察视频中的架构会发现，和 Linux 一个容器一个进程的理念不同。Windows 容器里面有一堆进程，包括系统服务那一群进程，以及应用服务进程。这是 Linux 所不需要的。

### Windows 容器里面包含的东西

Linux 世界很简单，进程直接发 `syscall`，内核帮你调度做事情。

而 Windows 的架构要臃肿的多。Windows 并不暴露系统调用，它用一群 DLL （比如 `kernel32.dll` 等) 将系统调用一层层的封装起来，然后提供一组 Windows API 给应用调用。所以，在 Windows 容器中，必须提供一群 DLL 服务，省不掉……

同样，Windows 要跑一个程序，有太多需要依赖的系统服务了，即使应用感觉不到，因为这些进程间依赖的RPC都被 Win32 API 所掩盖了，Windows 是一个非常紧耦合的系统，导致这些所依赖的服务也省不掉。即使运行一个最简单的程序，也需要跑这么一群服务跑起来，否则即使最简单的 DNS 查询，也可能会因为服务不存在而错误。

所以在 Windows 容器中，没有办法像 Linux 那样，可以理想的只在容器中运行一个进程，很轻量级的做事情。你必须把这一大堆东西扔到容器里，一大堆服务进程跑起来，才可以运行你的应用。

每次启动 Windows 容器的时候，就跟启动完整系统一样，先启动 `smss` （*相当于 Linux/Unix 世界的`init`……😓*)，然后它启动一群服务，最后才是调用你让容器执行的进程。

所以在 Windows 中实际上没有 `FROM scratch` 这东西，因为你必须在里面准备上面所说的所有这一大群东西。

*注：很多人错误的把 Docker 当虚拟机用，还在里面跑 `supervisord` 之类的来想办法支持服务，最后形成了一个超臃肿的镜像、容器，性能、稳定性都不好。微软的这个 Windows Container 就是一个典型的反面教材。*

## 基础镜像

微软发布的镜像中有两个可以选择的基础镜像：

* `windowsservercore`: 比较大(**9.3GB**) (*注：晕，这东西能仅仅叫比较大么？？？*)，高度兼容
* `nanoserver`: 超小，超快，不过更少的API支持。(*注：靠，你家管 600MB~810MB 的镜像叫做超小的镜像？？？还是功能受限版？？*)

他们为了做这个**超小** 的镜像，去除了很多Windows服务器里不大用的东西，比如去除了传真服务……晕，什么年代了这个怎么还是标配呀？

到现在为止还不能 `docker pull` 呢，不过很快会实现，这个实现可能会直接从微软服务器下载。

演示了一下分别使用两个镜像起个 `cmd`，**超小** 镜像大概用了2秒多，`windowsservercore` 那个大概用了3秒多……

```bash
docker run -it --rm nanoserver cmd
```

```bash
docker run -it --rm windowsservercore cmd
```

进入 `cmd` 后，通过列服务可以看出两个镜像差异，相比于 `windowsservercore` 而言，`nanoserver` 中的服务实在是少太多了……（不过依旧很多很多……）

```cmd
powershell get-service
```

可以在容器内查看进程

```cmd
powershell get-process
```

这些进程可以直接在任务管理器 (Task Manager) 里看到容器内进程，所以这不是虚拟机，是真的共享内核的容器。

# Windows Server Container 实现架构

## 命名空间

内部并不称其为 `namespace`，而是称之为 `silo` (谷仓或者导弹发射井）

这东西是对 Windows 的 `Job object` 的扩展，这是一组进程，一组受限进程，新的内核提供了类似于命名空间的能力。

新的命名空间，支持了：

* 注册表
* 进程 ID, 会话
* Object namespace
* 文件系统
* 网络部分

### Object namespace

系统级的 namespace，是对用户隐藏的。其实在 Windows 中，也是存在类似于 Linux 中的 `/` 的概念的。比如，在 NT 内核眼里，`C:\Windows` 映射到 `\DosDevices\C:\Windows` 下。

所以这里面包含了所有的设备所需的 entry point， 如：

* `\DosDevices\C:` ：文件系统
* `\Registry` ： 注册表
* `\Device\Tcp` ： TCP 通讯

而 `silo` 可以模仿 Linux 里面 `chroot` 的概念，来改变上述 entry point 的 root 位置。

* `\Silos\foo\DosDevices\C:`
* `\Silos\bar\DosDevices\C:`

演示了一下查看上述的路径。Windows 驱动开发工具中有一个 `objdir.exe` 的工具可以用来看这些信息。

分别在宿主和 `nanoserver` 容器中执行 `objdir \`，可以看到，所有这些信息。然后用 `objdir \GLOBAL??`，分别查看容器内宿主机，会发现容器内少了很多很多东西 （20 vs 133)。

在宿主上可以直接查看容器内的映射。`objdir \Silos\460\GLOBAL??`，这样显示的就是容器内的记录，20条信息。

## 文件系统

就和前面说的 Windows 容器非常臃肿一样，Windows 文件系统也非常复杂。随着不断的添加新的特性进去，Transactions, File IDs, USN journal 等等，而Windows程序很多依赖于这些特性。

因此如果要基于此去做一个 Linux 世界中的 AUFS，或者 Overlay FS，但是支持上面这些 NTFS 特性的，极为困难。

于是在 Windows Container v1 中，采用了类似于 `Device Mapper` 的办法 (*注：Really?? 甚多 bug 的那个 Device Mapper？？*) ，所不同的是，块设备是虚的，所以是 `虚拟块设备` + `每个容器的NTFS 分区` 的方式。使用 symlink 到宿主文件系统各层，这样让块设备不会过于臃肿。

## 注册表

注册表其实就是个简单的文件系统。由于它很简单，所以针对注册表的文件系统，是真的做了一个 Union FS 在上面。

为每个容器保存一整套注册表的clone。

由于这是 Windows 特有的东西，所以为了避免污染 Docker 代码，他们把注册表这个特例对 Docker 隐藏了。因此从 Docker 视角看注册表的改变就是文件的改变，所以，`docker diff` 的时候，很可能会看到注册表文件改变了，这是正常的。

# Hyper-V 容器架构

Hyper-V 的容器构架就和 Docker 非常不同了。这里等于是跑一个虚拟机，而不是共享内核运行。

动机是因为觉得有些应用需要更好的隔离。比如多租户使用、避免提权限漏洞、有些特别的规定说某些东西必须运行于vm中等等。

所以微软的想法是为什么不用VM来运行容器（*注：微软可不得有这样的想法么，他们已经把容器整的跟个VM差不多了……*），所以他们方法是讲每个容器独立的运行于一个 VM 中，用户是感知不到这种变化的。

```bash
docker run --isolation=hyperv
```

这样容器就运行于 Hyper-V 虚拟机里了。

而 Windows 10 的系统里，默认就是如此。原因是，由于之前提到的那些紧耦合的原因，所以他们没有办法让 Windows 服务器的容器直接运行于客户端，否则会导致内核版本不一致然后出错……所以只能跑个VM来运行服务器内核，然后再到里面跑个Docker……

运行于 Windows Server Container 的镜像和运行于 Hyper-V VM 的镜像是一样的。这是好事情，意味着不需要做两个版本镜像。

## Making it work

首先是让VM尽可能变小，并且无状态。虽然不是最小的Windows，但是很小，而且数据改变不持久化存储。（*注：这点和 Moby 很像*)

存储是基于 SMB的（*注：和 moby 1.12 目前的实现也很像*）， 不过没有真正的走网络，而是走的 `VMBus` （类似于 kvm 中的`virtio`），而且这样的好处是实际操作都是宿主负责的，因此文件缓存共享了，所以多实例的情况下跨容器如果有重复文件层的话，在内存缓存不是多副本，而是单副本，节约内存提高IO效率。

网络和所有VM一样，都是通过虚拟网卡实现的。包括之前不走虚拟机路径，而是共享内核的容器，也都是使用虚拟网卡实现的。(*注：这点和 Linux 下的 Docker 不同*)

## Cloning

即使这样做，启动一个 Hyper-V 的容器也是很慢的，比如花40多秒的时间才可以启动好去运行容器进程。

于是想了个解决办法，运行一次这个 Hyper-V 的容器，然后把它在内存中的状态保留，以后每次在运行 Hyper-V 的时候，直接从Clone这个进程，然后 Copy-on-Write，这样启动速度就很快了（*注：这不就是Linux fork么……*)。

使用 `--isolation` 来运行一个 Hyper-V 虚拟机。

```bash
docker run --rm --isolation=hyperv demo cmd /c echo Help I am trapped in a VM
```

大约10秒后，出结果了……😓

如果这时去看任务管理器，会看到两个奇怪的没有名字的进程。这就是之前说的第一次运行，并Freeze 的 Hyper-V 容器进程。如果我们不退出容器的话，会看到这里又多了一个奇怪的进程。

Taylor 马上补充说我们会修复这个地……然后，John 说，3周前他去度假的时候就听他们说要修复了，今天还没修复……

继续演示，按照之前说的，第二次运行速度会快一些……6秒……

# 问答

## 微软这种 Hyper-V 的技术是不是可以用来跑 Linux ？

John 说，呃，先让 Taylor 从政治角度回答一下吧 😊……。Taylor 这需要看用户的反馈，如果有更多的用户需求的话，我就会给开发团队更多的压力去实现这个东西。

John 补充说，这种想法听起来很赞，我非常希望微软能让我实现这个事情。

## 你们之前提到的 Compute Service 是有了公开的 API 了么？

我之前提到了2个GitHub的repo，分别是 C# 和 Go 包装的这个 API，这是临时的东西，将来可能都放到 MSDN 中去。Taylor 补充说，最终微软未来十几年的，所有关于docker 东西都会放到 <https://dockers.microsoft.com> 中去。

## 我们需要在Windows Docker 中使用 overlay network 来支持 Swarm，你们什么时候能够支持 overlay network？

我们现在主要的注意力是先让 Docker Engine 可以正常运行，之后会考虑 Swarm, Compose 这些能力。

## `Docker for Windows` 和你们这里介绍的 `Docker on Windows` 中的 Hyper-V 容器 的话，从技术层面上有什么不同？

我想有很多东西我们可能有机会共享。当然方式上不同，`Docker for Windows` 中的是运行一个 Hyper-V 虚拟机，里面跑多个 Docker 容器。而 `Docker on Windows` 中的 Hyper-V 容器是每个容器一个独立的 Hyper-V 虚拟机。

## 在第一版中，你们有哪些 Docker 功能不支持？

简单地说，所有 Linux 特定的功能都不支持（*注：那剩下来的还多么？？*)，举例来说，现在正在试图让 `docker top` 能够工作（John 很诧异的问，真的？我都不知道啊），因为机制上和 Linux 很不同，所以像这样简单的命令就需要不少工作去做
