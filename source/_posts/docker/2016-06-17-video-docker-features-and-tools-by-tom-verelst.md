---
layout: post
category: docker
title: 视频笔记：Docker 特性及其相关工具 - Tom Verelst
date: 2016-06-17
tags: [docker, youtube, notes]
---

<!-- toc -->

{% owl youtube heBI7oQvHZU %}
<https://www.youtube.com/watch?v=heBI7oQvHZU>

{% owl tencent o03134mlm8j %}
<http://v.qq.com/page/o/8/j/o03134mlm8j.html>

# 基本介绍

Docker 很像(**但不是**)一个轻量级的虚拟机，有自己的shell, namespace, network interface，可以以root运行东西，有自己的服务和软件包

虚拟机有虚拟硬件层和一个运行其上的完整系统。而容器则是直接将进程运行于现有内核上。所以启动Docker非常轻量级，启动非常快速。

Docker组成部分，简单来看，分为三个角色，客户端、docker 主机、docker registry。
客户端运行 `docker run`, `build`, `pull`等命令；
`docker host` 则有一个`docker daemon` 在运行，它维护着本地的container和image；
`docker registry`则是集中管理所有image的地方，docker host将从docker registry取得image。

Docker 文件系统是分层的，这是基于Union FS的概念，在Ubuntu上使用的是`aufs`，可以很自然的支持这种概念。而在CentOS/RHEL上则只能使用DeviceMapper去模拟，性能和稳定性以及一些功能会有问题。在 Linux 3.18 以后，可以使用 Overlay FS，这也是 Union FS 的实现。

Docker 文件系统分层，最底层是 bootfs(kernel)，然后是镜像中的各种层，最后是运行期的容器的层。容器的存储层在容器停止后，即被废弃。

严格来说并不是在容器停止后就被销毁。容器停止后，其存储层依然附属于停止掉的容器。如果利用 docker start 将容器启动后，会发现其内文件系统的变动依然存在。而这种容器存储层被废弃的概念则是指另一个层面的事情。

**容器应当被视为 immutable 的**，因此容器内部的变动应该可以随时被抛弃，不希望丢失的变化部分应该存储于挂载的数据卷中。

所以docker的工作流是 `docker run`, `stop`, `rm`, 再次`run`。每一次`run`都是从image建立的新鲜的container，所以里面的内容永远是image的状态，而没有上一次container中的修改。所以从这个工作流程理解，container中的变动被废弃了。

Docker 1.10 发布更新了Layer的ID问题，曾经使用的是随机UUID，但是发生过冲突，而且很难判断相同UUID的layer到底是哪个。所以从1.10开始，将其升级为密码学 Hash 值，SHA256。这样可以确保其内容统一，而且Image将会更小。在 1.10 以前，Image 和 Layer 基本是一个完整的东西，但是 1.10 之后，由于使用了 SHA256，Image 和 Layer 可以分开复用重复的Layer，这样Image可以更小。由于这种变化，如果从 1.10 以前的版本过来，必须要升级所有 images。

Docker 容器文件层会在停止后被废弃，那么数据应该存储于挂载的卷中。而挂载卷可以是数据卷也可以是本地文件，注意是“本地”，不可以使用NFS, SMB之类的位置进行挂载，这样Docker会认为其不安全。如果需要类似的云存储，可以使用volume的driver，可以支持AWS S3之类的存储。

docker run 一个容器，容器可以定义 EXPOSE 某些端口，而这些端口是容器之间可以访问的，而不是从外部访问，如果需要这些端口暴露于外部，那么应该用 -p 或 --publish，将该端口发布于宿主，可以映射不同端口。

# `Dockerfile`, `docker build`, `images`, `run`

`Dockerfile` 是分步骤的，而每一步都会被缓存，所以重新构建非常快。

`ENTRYPOINT` 和 `CMD` 不同，一般 `ENTRYPOINT` 是要运行的命令，而 `CMD` 则是参数，`docker run` 后面所跟随的实际上是 `CMD`，也就是参数。有些镜像把 `ENTRYPOINT` 设为了 `sh -c`，这样 `CMD` 可以跟 bash 命令和脚本，所以一些人误以为 `CMD` 就是命令。其实它们只是作为参数送给了 `ENTRYPOINT` 中指定的 `sh -c`。

基本命令：`build`, `run`, `stop`, `start`, `ps`, `ps -a`, `images`, `rmi`
将镜像`push`到registry，`docker login`, `docker push`

# Docker 历史

Docker 的历史是和 Linux 内核发布历史紧密相关的。

## 2007年 Linux 发布内核 `2.6.24`

有个特性被添加进来，Control Groups(`cgroups`)。随后，使用 `cgroups` 的 Linux Containers (`lxc`) 发布。`cgroups` 是今天 Docker 的基础。

`cgroups` ，可以限制资源使用，设置优先级，会计，控制。

距演讲者说，Linux 中的 `nice`，实际上就是使用 `cgroups` 中优先级的功能。
<https://en.wikipedia.org/wiki/Nice_(Unix)>
不过应该不是。

控制的部分包括`freeze`和`restart`。

(*这部分的内容演讲者讲的有些错误，我查询了一下，进行修正。*）

## 2013年2月 Linux 发布了内核 `3.8`

<http://kernelnewbies.org/Linux_3.8#head-fc2604c967c200a26f336942caee2440a2a4099c>

这次完整的实现了 namespace 的隔离，包括了 pid, network, hostname, mount pic, user 的namespace。

正是这次发布构成了Docker的基础，同年3月份 Docker 项目正式成为开源项目。最开始基于 `lxc`，现在抽象出来了 `libcontainer`，统一接口，下面可以支持多种容器组合，默认使用的是 `runC`，不过可以换。

## 2014年8月 Linux 发布了内核 `3.16`

对 `cgroups` 进行了重新设计。 <http://lwn.net/Articles/601840/>

Docker Networking 中的 `overlay network` 所依赖的就是这次内核的改进。

## 2014年12月 Linux发布了内核 `3.18`

经过多年的努力，这次终于第一次在内核中加入了 Union FS的实现，这次是 `Overlay fs`。（Ubuntu中的`aufs`争取了好多年，最后作者懒得争取了，放弃了）。这样对于红帽系将来的服务器，也就终于有可能有Union FS可用了。以前只能凑合用 Device Mapper，而且本地loop还是不适合在生产环境使用的。所以要使用 `overlay` 存储层，需要内核在 `3.18` 以上。

## 2015年4月 Linux发布了内核 `4.0`

docker 1.12 中的 `overlay2` 存储层就依赖的是这次的内核对 `overlay` 驱动的改进。

## 2016年 Linux 发布了内核 `4.5`

更加彻底的改造了 `cgroups`，称为 `cgroups2`，并且认可其已经稳定。
<http://kernelnewbies.org/Linux_4.5#head-621383bcd8bc104aed825c9ebc08a0b986690f8a>

# 使用 Docker 的好处

非常容易扩展，由于所有东西都打包在一个容器里了，所以部署的时候不需要在服务器上进行安装了，所以很适合扩展。

Docker 容器是 `immutable` 的，可以将其视为乐高积木，如果哪个坏了，扔了换个新的，而不是在旧的上面修修补补。

DevOps，开发人员(Dev)只需要考虑容器内的东西即可，而运营人员(Ops)则只需负责容器外部即可。

## 持续集成(Continuous Integration)

确保所有环境完全一样，不会出现“我的机器上没问题啊”这种情况。运行、测试都在容器内。

## 编排(Orchestration)工具

Compose, Machine, Swarm, Networking

### Compose

定义运行多容器应用，单机没问题，多主机还在试验中。

实例中，值得注意的是，他的目录结构。`docker-compose.yml` 在项目根目录，每个应用都有自己独立目录，以及其目录下存在 `Dockerfile`。这种感觉更干净。（或许在LNMP示例项目中，我不应该把`conf`都存在于同一个目录下，而是应该分应用建立目录，对应的配置放在各自目录下。）

另外需要注意的是，在仅有几台的应用环境下，他依然定义了前端网络和后端网络，让两个网络独立。

在启动示例的过程中，Tom Vereist 提到了这个例子写的不好的一点，在 worker 项目中，它在容器里使用 maven 对项目进行了构建。这不是一个好的写法，这会导致maven的安装，编译开发工具的安装、依赖的安装等等，会产生一个非常大的镜像。建议的做法是可以在另一个容器中构建，把构建后的软件包拿到运行的容器中安装使用即可，避免运行时不需要的东西存在于容器中。

### Machine

用于创建、管理 docker host，可以支持多种云平台，提供统一的访问接口。

### Swarm

docker 集群工具，多宿主管理运行。

可以定义 docker host 的 label。通过 docker daemon 的 `--label` 设置；通过 `docker-machine --engine-label`, `--label` 设置；将 docker host 设置上标签。然后在运行的时候可以通过约束标签，来决定该容器运行于那些 docker host 上。

可以定义过滤器，包括两大类，节点(Node)或容器(Container)。节点可能是约束、健康程度等；容器可以是端口、依赖等。

### Networking

创建 `Overlay network`。替代 `link` (bridge)，`link `在一些动态环境下使用会有问题。比如一群容器启动后，`link`的某一个节点挂了，重新运行，使用了新的ip，而还在运行的docker使用的还是旧的ip去联系该节点，导致无法连接。所以只能够把所有节点都down掉，然后重新运行。

尝试了一下，两个没有`link`关系的容器，可以通过容器IP访问对方。所以 `link` 是建立一种识别的办法，而不是安全上的建立通道的概念。看了一下文档，提到了 `--icc=false` 的参数来创建网络隔离。
<https://docs.docker.com/engine/userguide/networking/work-with-networks/#linking-containers-in-user-defined-networks>

`link` (bridge)使用两种方式传递给宿主其link的主机位置，环境变量和`/etc/hosts`文件。
<https://docs.docker.com/engine/userguide/networking/default_network/dockerlinks/#communication-across-links>

而多宿主环境中，使用 docker network 创建 `overlay network`，使用`link`链接主机，则会**有一个内置的DNS进行名字的动态维护**，不再使用 `/etc/hosts`。

在Tom 演示 docker swarm 的时候，我发现他和我一样建立了一个 bash 脚本来启动建立 docker host。我觉得应该考虑做个工具使用 yaml 描述文件来建立 docker-machine，就像 docker-compose做的那样。命令行中有太多的重复信息了。

脚本最后是使用 docker network 创建 `overlay` 网络，Tom 提到一点，需要指定  `--subnet` ，否则将无法连通，特别是跨主机的时候，有的版本有bug，同一个网络不一定使用同一段IP地址。不过现在这个bug已经修复了，不指定地址跨主机没问题。

演示 swarm 的过程中碰到了和我碰到的一样的问题。在单机环境中，在 docker compose 中可以使用 `build` 来构建镜像。但是在 swarm 的多宿主环境中，这样做的结果会导致所有的 service 会扔到同一个 docker host 中去，而如果打算使用多宿主环境（也是为什么要用swarm 的初衷），则必须使用 registry 中的 image。这样宿主可以主动去 registry 下载 image。可以使用 docker hub 的服务，或者自己架设 registry。

并且不可以使用 `link` 了，而必须使用 `自定义network`。Tom 说这是由于一个 `link` 的bug，现在不知道是否已经解决了，需要试验。

通过 `environment:"constraint:type==frontend"` 的形式来指定约束。

Tom 不推荐在生产环境中使用 compose + swarm，因为碰到了太多的问题，他甚至自己还报告了一个bug #2866。

## 其它工具

### Docker Cloud (cloud.docker.com)

创建 node clusters，可以选择AWS, Digital Ocean, Azure，Softlayer等几大云服务商。然后可以使用docker hub上的镜像进行部署。建立 Stack 需要脚本，很像compose，其实他们应该支持compose脚本更合适，建立service。

Docker Cloud 适合小规模云的部署。

### Kubernetes

由 Google 开发，用 Go 语言写的。Google 每周用这个运行2百万个containers。

一个 kubernetes 集群由 master 和 minions 组成。master 含有 etcd、scheduler；而每个 minon 含有 kubelet，proxy 和一群 pod。

### CoreOS

不需要安装 docker，它包含了 linux container。它也使用 etcd，所不同的是它每一个 host都运行etcd，这样避免了单点故障。`fleetd`，很像是网络多宿主环境下的 `systemd`，它负责开启停止分布在宿主中的服务。

### Lattice

### Flocker

# Docker Security

## Container Security

container 本身很安全，由于 isolation，只使用必要的依赖。
可以使用 `--security-opt sec comp:xxx.json`，来指定安全策略。
Unikernel，可以非常灵活定制的内核，只选择所必须的组件使用，其它的都抛弃，信任域更小。

## Node Security

现在 docker daemon 必须以 root 运行。现在的授权机制是 all or nothing，或者可以管理所有 docker，或者完全没有权限管理。这点将来可能会改变。
