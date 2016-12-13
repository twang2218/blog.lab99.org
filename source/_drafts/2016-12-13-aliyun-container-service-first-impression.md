---
layout: post
category: docker
title: 阿里云容器服务怎么样？
date: 2016-12-13 00:00:00
tags: [docker, blog]
---

# 阿里云容器服务怎么样？

具体云服务商的支持问题不属于问答录的范畴，但是很多人询问，在这里给出一些信息。

这是一个刚建立的阿里云容器服务 2 节点集群中其中一个节点的 `docker info`：

```bash
$ docker info
Containers: 7
Running: 7
Paused: 0
Stopped: 0
Images: 7
Server Version: 1.12.3
Storage Driver: aufs
Root Dir: /var/lib/docker/aufs
Backing Filesystem: extfs
Dirs: 58
Dirperm1 Supported: false
Logging Driver: json-file
Cgroup Driver: cgroupfs
Plugins:
Volume: acd ossfs local nas
Network: overlay bridge null host
Swarm: inactive
Runtimes: runc
Default Runtime: runc
Security Options: apparmor
Kernel Version: 3.13.0-86-generic
Operating System: Ubuntu 14.04.5 LTS
OSType: linux
Architecture: x86_64
CPUs: 1
Total Memory: 992.5 MiB
Name: c2b22ab1967f64a2db5982966977b354b-node1
ID: FEY5:75QX:AXXD:7EIC:FGAG:BAGC:EYSO:LJB2:RYUF:CQAX:Q642:X665
Docker Root Dir: /var/lib/docker
Debug Mode (client): false
Debug Mode (server): false
Registry: https://index.docker.io/v1/
WARNING: No swap limit support
Labels:
provider=aliyunecs
aliyun.zone=cn-beijing-b
aliyun.instance_id=i-2zeikqrgj1kqxeq38ixc
aliyun.cluster=c2b22ab1967f64a2db5982966977b354b
aliyun.node=c2b22ab1967f64a2db5982966977b354b-node1
aliyun.network_mode=classic
aliyun.region=cn-beijing
aliyun.node_index=1
com.docker.network.driver.overlay.vxlan.port=5789
aliyun.tunnel_server=tunnel-cn-beijing.aliyun-inc.com
Cluster Store: etcd://service2.cs-cn-beijing.aliyun-inc.com:2379/c2b22ab1967f64a2db5982966977b354b
Cluster Advertise: 10.44.204.215:2376
Insecure Registries:
127.0.0.0/8
```

* Docker 版本是 1.12.3，但阿里云容器集群用是阿里改造后的一代 Swarm，既不是 Docker 官方的一代 Swarm，也不是二代的 Swarm Mode。而且和官方的一代 Swarm 有兼容性问题，所以 Docker 生态环境的东西没法用，最重要的是**Docker Compose 无法使用**。

```bash
Kernel Version: 3.13.0-86-generic
```

* 虽然系统软件更新到了 `14.04.5`，但是内核并未更新，过于古老，**还在使用 `3.13` 系列**。

或许阿里工程师不理解什么是 Ubuntu，以为和 CentOS 一样，发布时是 `3.13`，就永远是 `3.13`。其实不然，每半年 Ubuntu 官方都会发布新版本的内核分支，并且新的小版本发布时会自动使用高版本内核。目前 Ubuntu 14.04.5 的内核是 `4.4`。一些功能需要 `4.0` 以上的内核才可以运行，比如 `overlay2`；而一些功能只有 `4.0` 以上的内核才可以稳定，比如 `overlay network`。如果不能理解 `Docker` 对高版本内核的需求，那么这样的工程师应该没有真正理解 `Docker`。

除此以外，还有一个相当严重的问题，这个内核版本是 `3.13.0-86`，凡是低于 `3.13.0-100` 的内核都存在著名的 `Dirty COW` 内核安全漏洞。这件事情已经过去很久了，阿里工程师竟然还没有升级其服务器内核，让这么高危的漏洞就这么摆着，非常不专业。不要说阿里可能会悄悄打补丁，我已经测试过了，**可以成功用 Dirty COW 从容器突破入侵到系统，阿里没有打补丁**，这是相当危险的。万幸的是可以自己登录进服务器去升级内核修复漏洞，所以如果真的使用阿里云的容器服务，千万不要忘记了修复这个高危漏洞。

```bash
Containers: 7
 Running: 7
 Paused: 0
 Stopped: 0
Images: 7
```

* 什么都没运行的情况下，每个节点已经跑了 `7` 个容器了。

使用 `docker ps` 可以看到都是阿里云容器配套服务所需的东西，感觉有些臃肿，因为一些功能其实 Docker 有内置。

```bash
$ docker ps
CONTAINER ID        IMAGE                                                    COMMAND                  CREATED             STATUS              PORTS                                            NAMES
ed6547b660f1        registry.aliyuncs.com/acs/logspout:0.1-1158379           "/bin/logspout"          3 hours ago         Up 3 hours                                                           acslogging_logspout_1
b6c6aed4e2b5        registry.aliyuncs.com/acs/ilogtail:0.11.1                "/usr/local/ilogtail/"   3 hours ago         Up 3 hours                                                           acslogging_logtail_1
ff99670da8bc        registry.aliyuncs.com/acs/monitoring-agent:0.8-a5026d8   "acs-mon-run.sh --hel"   3 hours ago         Up 3 hours                                                           acsmonitoring_acs-monitoring-agent_2
907d22b206b2        registry.aliyuncs.com/acs/volume-driver:0.8-78ec404      "acs-agent volume_exe"   3 hours ago         Up 3 hours                                                           acsvolumedriver_volumedriver_1
e5b94ce3231f        registry.aliyuncs.com/acs/routing:0.8-7977c5b            "/opt/run.sh"            3 hours ago         Up 3 hours          127.0.0.1:1936->1936/tcp, 0.0.0.0:9080->80/tcp   acsrouting_routing_2
8384f2f5b8fd        registry.aliyuncs.com/acs/agent:0.8-855f48f              "acs-agent join --nod"   3 hours ago         Up 3 hours                                                           acs-agent
960f9266a2e6        registry.aliyuncs.com/acs/tunnel-agent:0.21              "/acs/agent -config=c"   3 hours ago         Up 3 hours                                                           tunnel-agent
```

如果查看内存占用会发现这些东西已经占用了几十兆内存了：

```bash
CONTAINER                              CPU %               MEM USAGE / LIMIT       MEM %               NET I/O               BLOCK I/O             PIDS
acslogging_logspout_2                  0.15%               2.43 MiB / 992.5 MiB    0.24%               0 B / 0 B             0 B / 0 B             0
acslogging_logtail_1                   0.22%               8.266 MiB / 992.5 MiB   0.83%               0 B / 0 B             0 B / 28.67 kB        0
acsmonitoring_acs-monitoring-agent_2   0.02%               30.02 MiB / 992.5 MiB   3.02%               0 B / 0 B             4.129 MB / 0 B        0
acsvolumedriver_volumedriver_2         0.00%               4.703 MiB / 992.5 MiB   0.47%               0 B / 0 B             688.1 kB / 8.192 kB   0
acsrouting_routing_2                   0.00%               7 MiB / 992.5 MiB       0.71%               5.099 MB / 1.981 MB   49.15 kB / 0 B        0
acs-agent                              0.00%               8.469 MiB / 992.5 MiB   0.85%               0 B / 0 B             1.548 MB / 0 B        0
tunnel-agent                           0.01%               3.781 MiB / 992.5 MiB   0.38%               0 B / 0 B             409.6 kB / 0 B        0
```

```bash
WARNING: No swap limit support
```

* 没有针对 `Docker` 配置内核启动参数。

这说明阿里云工程师没有为 `Docker` 配置 `Grub` 参数。应该在 `/etc/default/grub` 中配置内核启动参数：`cgroup_enable=memory swapaccount=1`。

* 虽然是一代 Swarm，但是无法创建 `overlay` 网络

如果试图在 Swarm 环境中运行 `docker network create -d overlay` 则会报错：

```bash
$ docker network create -d overlay mynet2
Error response from daemon: This action is disabled in Container Service.
```

解决办法是直接登录到宿主里面去建立 `overlay` 网络，而且还不能 `IP` 地址冲突。

同样的问题也发生在 `docker volume create` 上，只能进宿主操作。

> 基本上阿里云的容器服务给我个人的感觉是比较业余、不成熟、不稳定。如果打算使用，需要自行进行大量生产准备工作，而这些应该是容器服务提供商负责维护的。此外，阿里自己改造的 `Docker` 以及 `Swarm` 非常不完善，很多功能无法在 Swarm 环境操作，只能直接登录宿主去操作，而且有的时候这样也有问题。所以，如果说建议的话，我建议自己搭建容器集群，要比用这个容器服务好。
