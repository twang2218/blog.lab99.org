---
layout: post
category: golang
title: 视频笔记：容器是什么？让我们用 Go 写一个吧！ - Liz Rice
date: 2017-10-13
tags: [golang, golang-uk-2016, youtube, notes]
---

<!-- toc -->

# 视频信息

**What is a container, really? Let's write one in Go from scratch**
by Liz Rice
at Golang UK Conf. 2016

{% owl youtube HPuvDm8IC-4 %}

* 视频：<https://www.youtube.com/watch?v=HPuvDm8IC-4>

# 什么是容器？

很多人最开始的时候搞不清楚容器是什么，所以经常听到有人问，容器到底是啥？Docker 到底是啥？

* “容器就是轻量级虚拟机”
* “容器就是 Jail”
* “容器就和 chroot 一样”
* “容器就是 namespace、cgroups……”
* “容器就是隔离的进程”

听了这些解释后，还是不清楚到底容器是啥。直到看了 [Julian Friedman](https://github.com/julz) 写的博文[《百行以内实现一个容器》](https://www.infoq.com/articles/build-a-container-golang) 后，才恍然大悟，觉得每个人都应该读一读，希望把这里的内容分享给所有人。所以这个 talk 就是主要基于 Julian 的博文的，当然，有些改变。

# 启动一个 docker 容器

我们先运行一个简单的 docker 容器，来对容器有一个基本的认识。

我们可以启动一个容器，只是简单的执行一条命令，比如：

```bash
$ docker run alpine echo "Hello GopherCon"
Hello GopherCon
```

我们也可以启动容器进入交互式模式：

```bash
$ docker run -it alpine
/ #
```

这样我们就启动了一个 `alpine` 的镜像。然后我们可以列目录，看到和我们当前环境不同的文件列表：

```bash
/ # ls
bin    etc    lib    mnt    root   sbin   sys    usr
dev    home   media  proc   run    srv    tmp    var
/ # ls -al
total 60
drwxr-xr-x    1 root     root          4096 Oct 18 11:56 .
drwxr-xr-x    1 root     root          4096 Oct 18 11:56 ..
-rwxr-xr-x    1 root     root             0 Oct 18 11:56 .dockerenv
drwxr-xr-x    2 root     root          4096 Jun 25 17:52 bin
drwxr-xr-x    5 root     root           360 Oct 18 11:56 dev
drwxr-xr-x    1 root     root          4096 Oct 18 11:56 etc
drwxr-xr-x    2 root     root          4096 Jun 25 17:52 home
drwxr-xr-x    5 root     root          4096 Jun 25 17:52 lib
drwxr-xr-x    5 root     root          4096 Jun 25 17:52 media
drwxr-xr-x    2 root     root          4096 Jun 25 17:52 mnt
dr-xr-xr-x  130 root     root             0 Oct 18 11:56 proc
drwx------    1 root     root          4096 Oct 18 11:56 root
drwxr-xr-x    2 root     root          4096 Jun 25 17:52 run
drwxr-xr-x    2 root     root          4096 Jun 25 17:52 sbin
drwxr-xr-x    2 root     root          4096 Jun 25 17:52 srv
dr-xr-xr-x   13 root     root             0 Oct 18 11:56 sys
drwxrwxrwt    2 root     root          4096 Jun 25 17:52 tmp
drwxr-xr-x    7 root     root          4096 Jun 25 17:52 usr
drwxr-xr-x   12 root     root          4096 Jun 25 17:52 var
```

我们还可以 `ps` 显示进程，但是看到的只是容器内的进程。

```bash
/ # ps
PID   USER     TIME   COMMAND
    1 root       0:00 /bin/sh
    7 root       0:00 ps
```

我们还可以看容器内的网络环境，也和宿主不同：

```bash
/ # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN qlen 1
    link/ipip 0.0.0.0 brd 0.0.0.0
3: gre0@NONE: <NOARP> mtu 1476 qdisc noop state DOWN qlen 1
    link/gre 0.0.0.0 brd 0.0.0.0
4: gretap0@NONE: <BROADCAST,MULTICAST> mtu 1462 qdisc noop state DOWN qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
5: ip_vti0@NONE: <NOARP> mtu 1332 qdisc noop state DOWN qlen 1
    link/ipip 0.0.0.0 brd 0.0.0.0
6: ip6_vti0@NONE: <NOARP> mtu 1500 qdisc noop state DOWN qlen 1
    link/tunnel6 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 brd 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
7: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN qlen 1
    link/sit 0.0.0.0 brd 0.0.0.0
8: ip6tnl0@NONE: <NOARP> mtu 1452 qdisc noop state DOWN qlen 1
    link/tunnel6 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 brd 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
9: ip6gre0@NONE: <NOARP> mtu 1448 qdisc noop state DOWN qlen 1
    link/[823] 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 brd 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
32: eth0@if33: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
/ #
```

我可以查看容器内的 `hostname`，会发现也和宿主不同：

```bash
/ # hostname
1faa496601e8
```

# 用 Go 实现一个容器

从上面的 docker 使用看，基本上的格式是，`docker run <容器> <命令> <参数>`，那么我们接下来就来模拟这个过程。

## 启动一个 Linux 系统

这里我们用 Vagrant 启动一个 Linux 系统，因为接下来我们将使用一些 Linux 内核相关的技术，这些将只存在于 Linux 中。不熟悉 Vagrant 可以先去学习如何使用 Vagrant。熟悉的继续，我们建立一个 `Vagrantfile`，内容为：

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"
  config.vm.provision "shell", inline: <<-SHELL
    curl -fsSL https://get.docker.com/ | sh
    usermod -aG docker vagrant
    apt-get update
    apt-get dist-upgrade -y
    snap install --classic go
    wget http://dl-cdn.alpinelinux.org/alpine/v3.6/releases/x86_64/alpine-minirootfs-3.6.2-x86_64.tar.gz
    mkdir /var/lib/alpine
    tar -xzvf alpine-minirootfs-3.6.2-x86_64.tar.gz -C /var/lib/alpine
  SHELL
end
```

这是配置了一个 Ubuntu Server 16.04 LTS 版本的虚拟机，并且安装了 Docker 和 Go，而且准备了一个 alpine 的 `rootfs` 以备后用。

然后我们用  `vagrant up` 来启动这个虚拟机，并且用 `vagrant ssh` 进入这个虚拟机。

```bash
$ vagrant ssh
Welcome to Ubuntu 16.04.3 LTS (GNU/Linux 4.4.0-92-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

0 packages can be updated.
0 updates are security updates.


vagrant@vagrant:~$
```

## 最简单的运行命令

我们先来模拟运行命令，我们希望达到的效果是 `go run docker.go run <命令> <参数>` 可以达到之前一样的效果。

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	switch os.Args[1] {
	case "run":
		run()
	default:
		panic("what?")
	}
}

func run() {
	fmt.Printf("Running %v\n", os.Args[2:])
	cmd := exec.Command(os.Args[2], os.Args[3:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	must(cmd.Run())
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
```

然后我们就可以运行：

```bash
$ go run docker.go run echo "Hello, our container"
Running [echo Hello, our container]
Hello, our container
```

可以看到，和之前的 `docker run` 一样，我们可以收到命令，并且执行。

我们也可以交互式的使用：

```bash
$ go run docker.go run /bin/sh
Running [/bin/sh]
sh-3.2$ ls
Vagrantfile     docker.go
sh-3.2$ ps
  PID TTY           TIME CMD
44316 ttys000    0:01.89 /bin/zsh -l
45926 ttys000    0:00.01 vagrant up
45927 ttys000    1:46.53 ruby /opt/vagrant/embedded/gems/gems/vagrant-2.0.0/bin/vagrant up
45212 ttys002    0:01.48 /bin/zsh -l
45372 ttys002    0:00.21 go run docker.go run /bin/sh
45379 ttys002    0:00.01 /var/folders/wc/9tzsn1hd7c38tvc54kctn4100000gn/T/go-build882908294/command-line-arguments/_obj/exe/docker r
45380 ttys002    0:00.02 /bin/sh
```

不过这里不要高兴太早，因为我们只是可以执行命令而已，并没有真的进入隔离的容器环境，在这里我们可以看到，我们依旧是处于宿主的文件系统，以及宿主的进程空间，甚至可以修改宿主的 hostname。嗯，因为这个命令就是在宿主的 namespace （命名空间）中运行的，所以没差。

## 隔离出 hostname 的命名空间

我们希望我们写的 `docker.go` 可以真的在独立的命名空间中执行命令，而不是原有的命名空间。这里我们先来解决 hostname 命名空间。

```go
func run() {
  ...
  cmd.Stderr = os.Stderr

	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS,
	}

  must(cmd.Run())
  ...
}
```

这次我们在 `cmd.Run()` 之前，设置了 `SysProcAttr` 属性，指定了 `CLONE_NEWUTS`，基本上的意思就是在说启动的命令，要在一个新的 hostname 的命名空间中执行，并且初始值从父进程克隆。

```bash
vagrant@vagrant:/vagrant$ hostname
vagrant
vagrant@vagrant:/vagrant$ sudo go run docker.go run /bin/sh
Running [/bin/sh]
# hostname
vagrant
# hostname golang
# hostname
golang
# exit
vagrant@vagrant:/vagrant$ hostname
vagrant
```

看到了吧，这次我们的进程在新的 hostname 命名空间中执行了，这个进程已经可以说是在一个（部分）新的容器中运行了。我们在容器中修改了 hostname，回到宿主后，可以看到 hostname 并未发生改变，两个命名空间是独立的。

## 隔离 PID 命名空间

上面的程序只是隔离了 hostname，没有隔离进程空间，所以在容器中还是可以看到宿主的进程：

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run /bin/sh
Running [/bin/sh]
# ps
  PID TTY          TIME CMD
 3173 pts/0    00:00:00 sudo
 3174 pts/0    00:00:00 go
 3199 pts/0    00:00:00 docker
 3203 pts/0    00:00:00 sh
 3205 pts/0    00:00:00 ps
#
```

我们希望和 `docker run` 一样，进程也是隔离的，容器内只能看到自己的命名空间的进程。

```go
func run() {
  ...
  	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS | syscall.CLONE_NEWPID,
	}
  ...
}
```

那看来和上面一样，是不是再增加一个标志位 `CLONE_NEWPID`，以建立一个新的 PID 命名空间给即将运行的程序不就行了？让我们来执行一下看看：

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run /bin/sh
Running [/bin/sh]
# ps
  PID TTY          TIME CMD
 3274 pts/0    00:00:00 sudo
 3275 pts/0    00:00:00 go
 3299 pts/0    00:00:00 docker
 3303 pts/0    00:00:00 sh
 3305 pts/0    00:00:00 ps
#
```

奇怪了，这还是宿主的进程空间啊。

## 排障 PID 命名空间

命名已经是新的 PID 命名空间了，为什么 `ps` 看到的还是宿主进程呢？

为了帮助排障，我们输出一下新启动的进程的 PID，看看到底是不是出于新的 PID 命名空间了。为了输出新的进程的 PID，这里我们修改一下程序结构，增加一层，并增加一个命令，`child`。

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func main() {
	switch os.Args[1] {
	case "run":
		run()
	case "child":
		child()
	default:
		panic("what?")
	}
}

func run() {
	cmd := exec.Command("/proc/self/exe", append([]string{"child"}, os.Args[2:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS | syscall.CLONE_NEWPID,
	}

	must(cmd.Run())
}

func child() {
	fmt.Printf("Running %v as pid: %d\n", os.Args[2:], os.Getpid())
	cmd := exec.Command(os.Args[2], os.Args[3:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	must(cmd.Run())
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
```

当我们用 `run` 一个命令的时候，实际上会再次运行自己(fork)，并加入命令 `child`，然后 `child()` 函数会实际的执行启动用户需求的命令。这样有了一层 `child()`，我们就可以取得更多的进程信息了。

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run echo hello
Running [echo hello] as pid: 1
hello
```

注意到了么，这里的 `pid: 1`，说明我们建立 PID 命名空间成功了的。

为了确信，可以删除上面的 `CLONE_NEWPID` 标志位，再次执行这个程序：

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run echo hello
Running [echo hello] as pid: 3528
hello
```

看到了吧，如果没有 `CLONE_NEWPID` 建立新的 PID 命名空间，那么我们将处于宿主的 PID 命名空间，新启动的进程 ID 是原来的空间的 `3528`。但是一旦启用了新的 PID 命名空间，那么新启动的进程将成为该命名空间的第一个进程，因此 PID 就为 `1` 了。

好吧，这说明我们确实已经在新的 PID 命名空间里了，那为什么 `ps` 不对呢？

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run /bin/sh
Running [/bin/sh] as pid: 1
# ps
  PID TTY          TIME CMD
 3534 pts/0    00:00:00 sudo
 3535 pts/0    00:00:00 go
 3559 pts/0    00:00:00 docker
 3562 pts/0    00:00:00 exe
 3566 pts/0    00:00:00 sh
 3568 pts/0    00:00:00 ps
#
```

实际上，这是由于 `ps` 只是简单地观察 `/proc` 的内容而给出的信息，而此时容器内的 `/proc` 还是宿主的，所以虽然已经位于新的 PID 命名空间了，但是 `ps` 还无法正常工作。

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run /bin/sh
Running [/bin/sh] as pid: 1
# ls /proc
1     157    23     27805  3     376  48   59   80         consoles     ioports      meminfo       softirqs           vmallocinfo
10    158    23167  27808  30    396  49   6    813        cpuinfo      irq          misc          stat               vmstat
1070  159    235    27809  31    404  490  60   814        crypto       kallsyms     modules       swaps              zoneinfo
11    16     24     28     313   407  5    602  816        devices      kcore        mounts        sys
1130  17     257    28057  314   416  50   66   850        diskstats    keys         mtrr          sysrq-trigger
1146  18     261    2851   3207  431  51   7    9          dma          key-users    net           sysvipc
1147  19     262    286    3569  434  52   776  907        driver       kmsg         pagetypeinfo  thread-self
119   2      2650   2873   3570  435  53   779  acpi       execdomains  kpagecgroup  partitions    timer_list
12    20     2683   2875   3594  439  54   780  asound     fb           kpagecount   sched_debug   timer_stats
1213  21     271    2877   3597  442  55   79   buddyinfo  filesystems  kpageflags   schedstat     tty
13    22     273    29     360   447  56   791  bus        fs           loadavg      scsi          uptime
14    22497  27794  2910   3601  449  57   795  cgroups    interrupts   locks        self          version
15    22504  27799  2911   3603  47   58   8    cmdline    iomem        mdstat       slabinfo      version_signature
#
```

## 隔离 File System 命名空间

经过前面的试验，我们已经知道了是由于 `/proc` 还是宿主的 `/proc`，所以 `ps` 无法正常工作。那么我们所需要的就是挂载一个容器内的 `/proc`。而且，我们其实一直都在宿主的文件系统的命名空间里，所以这里我们还可以建立一套独立的 rootfs 给容器。

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func main() {
	switch os.Args[1] {
	case "run":
		run()
	case "child":
		child()
	default:
		panic("what?")
	}
}

func run() {
	cmd := exec.Command("/proc/self/exe", append([]string{"child"}, os.Args[2:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWUTS | syscall.CLONE_NEWPID | syscall.CLONE_NEWNS,
	}

	must(cmd.Run())
}

func child() {
	fmt.Printf("Running %v as pid: %d\n", os.Args[2:], os.Getpid())
	cmd := exec.Command(os.Args[2], os.Args[3:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	must(syscall.Chroot("/var/lib/alpine"))
	must(os.Chdir("/"))
	must(syscall.Mount("proc", "proc", "proc", 0, ""))
	must(cmd.Run())
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
```

这里我们做了两个改动。

其一，在 `run()` 中增加 `CLONE_NEWNS` 标志位，以增加新的文件系统命名空间（也被称为 mount 命名空间）。这里之所以叫 `NEWNS`，实际的意思是 `New Namespace`，这是因为最初实现 namespace 的时候，只想到了文件系统，so……😓

其二，在 `child()` 中，`chroot` 到我们新的 rootfs：`/var/lib/alpine`，并且切换到根目录，然后挂载 `/proc`。

```go
func child() {
  ...
	must(syscall.Chroot("/var/lib/alpine"))
	must(os.Chdir("/"))
  must(syscall.Mount("proc", "proc", "proc", 0, ""))
  ...
}
```

然后让我们再次运行自己的容器：

```bash
vagrant@vagrant:/vagrant$ sudo go run docker.go run /bin/sh
Running [/bin/sh] as pid: 1
/ # ps
PID   USER     TIME   COMMAND
    1 root       0:00 /proc/self/exe child /bin/sh
    4 root       0:00 /bin/sh
    5 root       0:00 ps
/ #
```

Yeah! 💪 这次终于看到 `ps` 正常工作了，这是我们自己的进程空间，PID 从 1 开始了。😸

# 总结

这很神奇，我们从零开始做出了自己的容器，有了自己的 hostname、PID、mount 的命名空间，看起来都和 Docker 容器一样。经过这个实现的过程后，我们可以看到，所谓启动一个容器，其实就是启动了一个进程，没有别的特殊的东西。就是启动了一个进程，指定了一些命名空间、挂载等。仅此而已。**容器，就是进程。**

## 命名空间（Namespace）

从上面的例子中，其实我们已经可以感觉到了。**`namespace`决定你能看到什么**

* UNIX Timesharing System （别看名字很忽悠，就是 hostname）
* Process IDs
* File system (就是 mount)
* Users
* IPC
* Networking

## 控制组（Control groups）

**`cgroups` 控制你能用什么**

* CPU
* Memory
* Disk I/O
* Network
* Device permissions (`/dev`)

## Images （rootfs）

之前我们所用到的 `rootfs`，`/var/lib/alpine` 是来自于 alpine 网站的，对于 Docker 而言，Docker Hub 的那些镜像在下载下来后，就会被作为容器的 `rootfs` 所使用。当然实际的细节要更加复杂，比如引入了分层存储 Union FS 的概念、元数据等等。

Liz Rice 的团队制作了 <https://microbadger.com/> 来帮助查看和分析位于 Docker Hub 上的镜像。

## 进一步阅读

可以看一下 Julien Friedman 的 gist：<https://bit.ly/1nDqpDI>。他的实现略有不同，比如里面没有使用 `chroot`，而是直接使用 `mount` 挂载 `rootfs`等。
