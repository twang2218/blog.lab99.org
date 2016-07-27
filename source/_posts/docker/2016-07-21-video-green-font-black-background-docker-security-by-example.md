---
layout: post
category: docker
title: 视频笔记：绿字黑屏 - Docker 安全示例 - Diogo Mónica
date: 2016-07-21
tags: [docker, dockercon15-eu, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon15 EU - Green Font, Black Background - Docker Security by Example
by Diogo Mónica, Security Lead, Docker
(2015-12-04)

{% owl youtube blNIreAq6hc %}

<https://www.youtube.com/watch?v=blNIreAq6hc>

{% owl tencent k03143nuw7k %}

<http://v.qq.com/x/page/k03143nuw7k.html>

# 介绍

Diogo Mónica，Docker 安全 Lead，喜欢 GPG 和 Perl

首先声明，题目虽然是绿字黑屏，实际上我的字是白的，那种屏幕乱翻的东西只有好莱坞电影中才有。其次是整个演示没有 PPT，全部依赖互联网，如果网断了……那估计是全 DockerCon 最长的解答session了。

而且，全部操作都是现场完成，从建立一个空白虚拟机开始。

# 创建 Digital Ocean 服务器

创建了一个 $10/month 的伦敦位置的 Droplet，Ubuntu 15.10

初始化准备工作

```bash
# 安装必要软件
apt-get install vim tree curl golang-go
```

然后编辑 `.bashrc` 配置 GOPATH 和 PATH。

然后安装 `experimental` 分支的 docker

```bash
curl -ssL https://experimental.docker.com | sh
```

安装后，启用 Content Trust

```bash
export DOCKER_CONTENT_TRUST=1
```

# AppArmor

运行一个 Alpine 容器，并且执行 `top` 命令

```bash
docker run alpine top
```

执行后一切正常，但是 `Ctrl-C` 无法退出。于是决定重新登录这个服务器，并且 kill 掉这个容器。

```bash
docker kill 容器名
```

可是失败了，报错：

```bash
Error response from daemon: Cannot kill thirsty_pasteur: permission denied
```

 于是开始检查日志：

```bash
tail /var/log/syslog
```

在日志中，看到了一行说 `apparmor="DENIED"`，看来是 AppArmor 阻止了这个行为。

那么继续 debug，使用 `aa-status` 可以查看 AppArmor 的状态，这个状态中会包含所使用的 `profile`。在例子中，有6个profiles 是 enforce的，14个是complain的。其中一个 enforce 的是 `docker-default`。

打开 AppArmor 的 docker 配置文件 `/etc/apparmor.d/docker` 以及 `/etc/apparmor.d/docker-engine`。

由于之前是 kill 操作被禁止了，那么可能是关于 signal 的。

```bash
grep signal docker-engine
```

注意到 `docker-engine` 中有 `signal` 控制，而 `docker` 中没有。于是，将 `docker-engine` 中的 `signal (receive) ...` 那一行复制粘贴到  `docker` 文件，并且，重载这个 AppArmor，`systemctl reload apparmor`。然后就可以 `docker kill` 掉这个容器了。

# Bane

由于 AppArmor 语法看着很难理解，于是打算装个 Go 插件来帮助做安全管理控制。

```bash
go get github.com/jfrazelle/bane
go install github.com/jfrazelle/bane
```

使用 bane 定义的示例安全规则 `sample.toml`

```bash
$ bane sample.toml
Profile installed successfully you can now run the profile with
`docker run --security-opt="apparmor:docker-nginx"`
```

这样就生成了一个 AppArmor profile，然后就可以根据提示使用 `--security-opt` 选项使用这个 profile 了。比如：

```bash
docker run --security-opt="apparmor:docker-nginx" -it nginx bash
```

然后会发现，`ping` 无法工作因为没有网络, 而 `top`, `dash`, `sh` 也都无法工作，这些都是生成的 AppArmor profile 控制的结果。

# Capabilities

我们还可以通过 `--cap-drop` 参数来取消掉某些能力。比如，

```bash
docker run -it alpine sh
```

然后我们可以 ping, traceroute。但是我们可以取消其网络能力：

```bash
docker run --cap-drop=NET_RAW -it alpine sh
```

这样 traceroute 就无法工作了。除了 `NET_RAW` 之外，还有很多有意思的功能可以控制，比如 `CHOWN`，这样用户就不可以使用 `chown` 命令了。

# 只读文件系统

我们还可以将文件系统变成只读，比如：

```bash
docker run --read-only -it alpine sh
```

这样，`touch` 之类的所有文件操作都无法用了。

# user namespace

当前(*1.10之前*)，docker 内的 `uid 0` 就是docker 外的 `uid 0`，目前没有使用 user namespace。

由于内部和外部的UID是一致的，因此容器内的`root`，就是容器外的root。

```bash
docker run -it \
    -v /bin:/data/bin \
    alpine sh
```

那么上面这个例子中，如果容器内修改了 `/data/bin` 里面的内容，宿主的对应位置的文件就被改动了，这是非常危险的。

启用 user namespace 很容易，通过修改 docker daemon 启动参数既可以：

```ini
ExecStart=/usr/bin/docker daemon --userns-remap=default -s overlay -H fd://
```

这里的 `overlay` 是使用 overlay fs，没什么特别的，只不过讨厌 aufs 而已……

然后重启 docker

```bash
systemctl daemon-reload
systemctl restart docker
```

验证：

```bash
# 使用 docker info 可以看到新启用的 overlayfs
docker info

# 使用 ps 查看 docker 配置
ps -ef | grep docker
```

可以看到配置生效了。

然后我们可以去 `/var/lib/docker/` 看到几个新的目录：`0.0` 和 `10000.10000`。

前面的 `0.0` 就是之前 UID 为 0 的namespace，而 `10000.10000` 则是我们使用了 `userns-remap=default` 后建立的新的 UID=10000的namespace。可以直接查看具体的uid,gid的mapping的范围可以：

```bash
cat /etc/subgid
cat /etc/subuid
```

所有该namespace的镜像都会被放置在该目录下的 `repositories-overlay` 文件中。目前是空的，在我们执行了 `docker pull alpine` 后，其镜像信息就会出现在这个文件中。

如果我们再次执行刚才 `-v /bin:/data/bin` 的 `docker run` 命令，就会看到，虽然 `id` 显示还是 `uid=0, root`，但是，我们到 `/data/bin` 后，无法修改其文件了。

# Content Trust

最开始定义了 `DOCKER_CONTENT_TRUST=1` ，因此所有的 `docker pull` 都会验证每一个部分是否可信任。一切都是透明的，用户是感知不到的。这里要对其进行解析。

清空所有容器和镜像

```bash
docker rm -f $(docker ps -a -q)
docker rmi -f $(docker images -q)
```

我们可以用下面的命令，禁用 Content Trust，

```bash
docker pull --disable-content-trust alpine
```

但是如果我们不加这个参数，默认（之前设置了环境变量），就会启用 Content Trust，Docker 就会使用 Notary 来进行镜像的验证。

实际上后面的做法是通过 Notary 对镜像名字 `alpine:latest` 进行解析，解析为一个经过签名认证的校验值，而 docker 实际上 pull 的是这个校验值，而不是那个镜像名字。

```bash
docker pull alpine@sha256:xxxxxxxx
````

docker 会对 pull 下来的内容进行校验，使用的是 Markle Hash Tree 进行校验，所以一个数值可以校验镜像全部层的完整性。

使用带 Content Trust 后，`repositories-overlay` 文件中除了默认的 latest 对应值外，多了一个 sha256的校验数值。

在安装了 notary 的机器上可以查看相关信息：

```bash
notary list docker.io/library/alpine
```

可以使用 `tree ~/.docker/trust/` 来显示 Content Trust 的所有配置信息和数据。

# 对抗 fork bomb

常见的方法是，修改 `docker.service` 文件，将 `LimitNPROC` 改为 `100`。可实际上这是每用户级别的限制，以为所有的docker容器都会受限，那么要是跑1000个容器，可是实际上只能跑100个进程……

演示中使用了最简单的一个 bash 命令进行 `fork bomb`

```bash
:(){ :|: & };:
```

貌似很好，因为限制了用户的 `nproc` 所以不用担心 `fork bomb` 了。可实际上由于这不是容器范围的限制，而是整个用户的限制，所以其它容器也会因为之前的这个 fork bomb 的容器，而无法建立新的进城了。

举个简单的例子

```bash
docker run -itd -u daemon --ulimit nproc=3 ubuntu bash
docker run -itd -u daemon --ulimit nproc=3 ubuntu bash
docker run -itd -u daemon --ulimit nproc=3 ubuntu bash
docker run -itd -u daemon --ulimit nproc=3 ubuntu bash
```

第四个容器会出错，因为这是用户范围的限制，而不是容器内部的限制，所以前三个容器中的bash已经占了3个进程，第4个就超出了限制了。

## Kernel Memory

我们还可以限制 `kernel-memory`，

```bash
docker run -it --kernel-memory=1m ubuntu bash
```

如果这次运行 fork bomb 的话，会发现主机这地挂了。现在有两个 PR 关于控制容器内 fork 数量的，将会解决这个问题。

# 文件系统

演示建立了一个 PHP 网站，存在执行远程命令的漏洞。于是通过利用这个漏洞开始篡改主机文件。利用了 `curl` 下载了个web shell，并且通过 `echo` 篡改了 `index.html`。

好了，运维凌晨接到了电话，说网站被黑了，需要修复。于是先通过 `docker logs` 注意到了一些奇怪的东西。但是由于任务紧急，不可能给你几个小时的时间去分析入侵过程。于是需要先修复。先看看容器自运行后都修改了哪些文件好了：

```bash
docker diff 容器名
```

这个命令很清晰的显示了哪些文件被修改，哪些文件被添加了。一眼就看到了 `shell.php` 文件。

为了保存现场，使用 `docker commit 容器名`，这样我们就有了这个变化结果的镜像 ID。这个镜像可以之后进行分析，我们现在需要恢复网站运行。

重新运行网站：

```bash
docker run -d -p 80:80 --link db:db website
```

好了，网站就此恢复了。使用 Docker 可以让恢复工作异常轻松。

然后我们需要响应这次入侵，看看到底发生了什么。刚才我们commit了镜像，我们现在则需要进入这个镜像看看到底发生了什么。

```bash
docker run -it xxxxxx bash
```

使用刚才 `commit` 的校验值运行容器，进来看看到底发生了些什么事情。

当然，要是 docker 可以在最开始阻止这次入侵，那么什么都不会发生。可以么？可以。比如使用之前的 `--read-only` 参数，使文件系统只读。

```bash
docker run -p 80:80 \
    --link db:db \
    -v /tmp/apacherun:/var/run/apache2/ \
    -v /tmp/apachelock:/var/lock/apache2/ \
    --sig-proxy=false \
    --read-only \
    website
```
