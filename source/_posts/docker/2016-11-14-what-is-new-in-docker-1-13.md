---
layout: post
category: docker
title: Docker 1.13 新增功能
date: 2016-11-14
tags: [docker, blog]
---

<!-- toc -->

# 前言

`Docker 1.13` 马上就要发布了。从 7 月 29 日发布 `1.12` 发布以来，已经过去 4 个多月了，对于活跃的 Docker 社区来说，已经很久了，让我们看看都 `1.13` 都新增了什么内容吧。

`1.13` 有[一千二百多个 issue/pull request](https://github.com/docker/docker/milestone/56)，四千多个 commits，是历史上最高的。这并不是一个简单的小版本变化，里面有大量的更新。

*要想测试 `1.13.0` 的新功能，可以起一个新的机器，然后在里面运行：`curl -fsSL https://test.docker.com/ | sh`，这样会安装最新的测试版本。*

## Top 10 新增功能

* 1、正式支持服务栈 `docker stack`
* 2、正式支持插件：`docker plugin`
* 3、添加在 Swarm 集群环境下对密码、密钥管理的 `secret` 管理服务：`docker secret`
* 4、增加 `docker system` 命令
* 5、可以直接使用 `docker-compose.yml` 进行服务部署
* 6、添加 `docker service` 滚动升级出故障后回滚的功能
* 7、增加强制再发布选项 `docker service update --force`
* 8、允许 `docker service create` 映射宿主端口，而不是边界负载均衡网络端口
* 9、允许 `docker run` 连入指定的 swarm mode 的 `overlay` 网络
* 10、解决中国 `GFW` 墙掉 `docker-engine` `apt`/`yum` 源的问题

# Docker 镜像构建

## 从已有镜像取得缓存

我们都知道使用 `Dockerfile` 构建镜像的时候，会充分利用分层存储的特性进行缓存，之前构建过的层，如果没有变化，那么会直接使用缓存的内容，避免没有意义的重复构建。不过使用缓存的前提条件是曾经在本地构建过这个镜像。这在 CI 进行集群构建时是一个比较麻烦的问题，因为构建任务可能会被分配到不同的机器上，而该机器没有构建过该镜像，因此缓存总是用不上，因此大量的时间浪费在了重复构建已经构建过的层上了。

在 `1.13` 中，为 `docker build` 增加了一个新的参数 `--cache-from`，利用镜像中的 History 来判断该层是否和之前的镜像一致，从而避免重复构建。

比如我们先下载获取作为缓存的镜像：

```bash
$ docker pull mongo:3.2
3.2: Pulling from library/mongo
386a066cd84a: Pull complete
524267bc200a: Pull complete
476d61c7c43a: Pull complete
0750d0e28b90: Pull complete
4bedd83d0855: Pull complete
b3b5d21a0eda: Pull complete
7354b6c26240: Pull complete
db792d386b51: Pull complete
a867bd77950c: Pull complete
Digest: sha256:532a19da83ee0e4e2a2ec6bc4212fc4af26357c040675d5c2629a4e4c4563cef
Status: Downloaded newer image for mongo:3.2
```

然后我们使用更新后的 `Dockerfile` 构建镜像时，如果加上 `--cache-from mongo:3.2` 后，会发现如果是已经在 `mongo:3.2` 中存在并没有修改的层，就会用 `mongo:3.2` 中的该层做缓存。

```bash
$ docker build --cache-from mongo:3.2 -t mongo:3.2.1 .
Sending build context to Docker daemon 4.608 kB
Step 1/18 : FROM debian:jessie
 ---> 73e72bf822ca
Step 2/18 : RUN groupadd -r mongodb && useradd -r -g mongodb mongodb
 ---> Using cache
 ---> 0f6297900a5e
Step 3/18 : RUN apt-get update 	&& apt-get install -y --no-install-recommends 		numactl 	&& rm -rf /var/lib/apt/lists/*
 ---> Using cache
 ---> a465f2e906fc
Step 4/18 : ENV GOSU_VERSION 1.7
 ---> Using cache
 ---> d448ddca2126
...
```

## 压扁(`squash`)镜像（实验阶段）

对于总是把 `Dockerfile` 当做 `bash` 文件来用的人，会发现很快由于太多的 `RUN` 导致镜像有特别多的层，镜像超级臃肿，而且甚至会碰到超出最大层数限制的问题。这些人往往不从自身找问题，反而去寻找旁门左道，比如导出镜像做一些特殊处理，合并为一层，然后再导入等等，这种做法是很错误的，除了导致构建缓存失败外，还导致 `docker history` 丢失，导致镜像变为黑箱镜像。其实正确的做法是遵循 `Dockerfile` 最佳实践，应该把多个命令合并为一个 `RUN`，每一个 `RUN` 要精心设计，确保安装构建最后进行清理。这样才可以降低镜像体积，以及最大化的利用构建缓存。

在 Docker 1.13 中，为了应对这群用户，实验性的提供了一个 `--squash` 参数给 `docker build`，其功能就是如上所说，将 `Dockerfile` 中所有的操作，压缩为一层。不过，与旁门左道不同，它保留了 `docker history`。

比如如下的 `Dockerfile`：

```Dockerfile
FROM busybox
RUN echo hello > /hello
RUN echo world >> /hello
RUN touch remove_me /remove_me
ENV HELLO world
RUN rm /remove_me
```

如果我们正常的构建的话，比如 `docker build -t my-not-squash .`，其 `history` 是这样子的：

```bash
$ docker history my-not-squash
IMAGE               CREATED              CREATED BY                                      SIZE                COMMENT
305297a526e2        About a minute ago   /bin/sh -c rm /remove_me                        0 B
60b8e896d443        About a minute ago   /bin/sh -c #(nop)  ENV HELLO=world              0 B
a21f3c75b6b0        About a minute ago   /bin/sh -c touch remove_me /remove_me           0 B
038bca5b58cb        About a minute ago   /bin/sh -c echo world >> /hello                 12 B
f81b1006f556        About a minute ago   /bin/sh -c echo hello > /hello                  6 B
e02e811dd08f        5 weeks ago          /bin/sh -c #(nop)  CMD ["sh"]                   0 B
<missing>           5 weeks ago          /bin/sh -c #(nop) ADD file:ced3aa7577c8f97...   1.09 MB
```

而如果我们用 `--squash` 构建：

```bash
docker build -t mysquash --squash .
```

其 `history` 则是这样子：

```bash
$ docker history mysquash
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
a557e397ff56        15 seconds ago                                                      12 B                merge sha256:305297a526e218e77f1b4b273442f8ac6283e2907e6513ff36e9048aa130dea6 to sha256:e02e811dd08fd49e7f6032625495118e63f597eb150403d02e3238af1df240ba
<missing>           15 seconds ago      /bin/sh -c rm /remove_me                        0 B
<missing>           15 seconds ago      /bin/sh -c #(nop)  ENV HELLO=world              0 B
<missing>           15 seconds ago      /bin/sh -c touch remove_me /remove_me           0 B
<missing>           16 seconds ago      /bin/sh -c echo world >> /hello                 0 B
<missing>           16 seconds ago      /bin/sh -c echo hello > /hello                  0 B
<missing>           5 weeks ago         /bin/sh -c #(nop)  CMD ["sh"]                   0 B
<missing>           5 weeks ago         /bin/sh -c #(nop) ADD file:ced3aa7577c8f97...   1.09 MB
```

我们可以注意到，所有层的层ID都 `<missing>` 了，并且多了一层 `merge`。

**要注意，这并不是解决懒惰的办法，撰写 Dockerfile 的时候，依旧需要遵循最佳实践，不要试图用这种办法去压缩镜像。**

# 安装

## 解决 `GFW` 影响 `Docker` 安装问题

官方的 `apt`/`yum` 源使用的是 `AWS` 的服务，并且为了确保安全使用了 `HTTPS`，因此伟大的墙很乐于干扰大家使用。没办法的情况下，各个云服务商纷纷建立自己官方源镜像，阿里云、DaoCloud、Azura 等等，并且自己做了个修订版的 `https://get.docker.com` 的脚本来进行安装。

现在这个发生改变了，官方的 `https://get.docker.com` 将支持 `--mirror` 参数，你可以用这个参数指定国内镜像源，目前支持微软的 Azure 云，（[或阿里云？](https://github.com/docker/docker/pull/28858)）。使用方法如下，将原来官网安装命令：

```bash
curl -sSL https://get.docker.com/ | sh
```

替换为：

```bash
curl -sSL https://get.docker.com/ | sh -s -- --mirror AzureChinaCloud
```

如果是阿里云的话，将 `AzureChinaCloud` 替换为 `Aliyun`。

*此时，<https://get.docker.com/> 尚未更新，所以暂时无法使用，在 1.13 正式发布后，即可使用。*

## 增加更多的系统支持

在这次发布中，增加了 `Ubuntu 16.10` 的安装包，而且对 `Ubuntu` 系统增加了 `PPC64LE` 和 `s390x` 构架的安装包。此外，还正式支持了 `VMWare Photon OS` 系统的 `RPM` 安装包，以及在 `https://get.docker.com` 的支持。并且支持了 `Fedora 25`。同时也由于一些系统生命周期的结束，而被移除支持，比如 `Ubuntu 15.10`、`Fedora 22` 都不在支持了。

# 网络

## 允许 `docker run` 连入指定的 `swarm mode` 的网络

在 Docker 1.12 发布新的 Swarm Mode 之后，很多人都问过这样的问题，怎么才能让 `docker run` 连入服务的 `overlay` 网络中去？答案是不可以，因为 `swarm` 的 `overaly` 是为了 `swarm service` 准备的，相对更健壮，而直接使用 `docker run`，会破坏了这里面的安全模型。

但是由于大家需求很多，于是提供了一种折衷的办法。1.13 允许建立网络的时候，设定该网络为 `attachable`，允许之后的 `docker run` 的容器连接到该网络上。

我们创建一个不允许之后 `attach` 的网络：

```bash
$ docker network create -d overlay mynet1
xmgoco2vfrtp0ggc5r0p5z4mg
```

然后再创建一个允许 `attach` 的网络，这里会使用 1.13 新加入的 `--attachable` 参数：

```bash
$ docker network create -d overlay --attachable mynet2
yvcyhoc6ni0436jux9azc4cjt
```

然后我们启动一个 `web` 服务，连入这两个网络：

```bash
$ docker service create \
    --name web \
    --network mynet1 \
    --network mynet2 \
    nginx
vv91wd7166y80lbl833rugl2z
```

现在我们用 `docker run` 启动一个容器连入第一个网络：

```bash
$ docker run -it --rm --network mynet1 busybox
docker: Error response from daemon: Could not attach to network mynet1: rpc error: code = 7 desc = network mynet1 not manually attachable.
```

由于 `mynet1` 不允许手动 `attach` 所以这里报错了。

在 1.12 的情况下，会报告该网络无法给 `docker run` 使用：

```bash
docker: Error response from daemon: swarm-scoped network (mynet1) is not compatible with `docker create` or `docker run`. This network can only be used by a docker service.
See 'docker run --help'.
```

**不过，`--attachable` 实际上是将网络的安全模型打开了一个缺口，因此这不是默认设置，而且并不推荐使用。用户在使用这个选项建立网络的时候，一定要知道自己在做什么。**

## 允许 `docker service create` 映射宿主端口，而不是边界负载均衡网络端口

首先，`docker service create` 中的 `--publish` 将改为 `--port`（缩写还是 `-p` 不变）。之所以这么做，是因为对映射开放端口有了更进一步的发展，原来的 `--publish 1234:1234` 的格式已无法满足需求。

在 1.12 中，`docker service create` 允许使用参数 `--publish 80:80` 这类形式映射**边界(ingress)网络**的端口，这样的映射会享受边界负载均衡，以及 routing mesh。

从 1.13 开始，增加另一种映射模式，被称为 `host` 模式，也就是说，用这种模式映射的端口，只会映射于容器所运行的主机上。这就和一代 Swarm 中一样了。虽然失去了边界负载均衡，但是确定了映射点，有的时候更方便管理。

现在新的 `--port` 的参数形式和 `--mount` 差不多。参数值为 `,` 逗号分隔的键值对，键值间以 `=` 等号分隔。目前支持 4 项内容：

* `protocol`： 支持 `tcp` 或者 `udp`
* `mode`： 支持 `ingress` 或者 `host`
* `target`： 容器的端口号
* `published`： 映射到宿主的端口号

比如，与 `-p 8080:80` 等效的 `--port` 选项为：

```bash
--port protocol=tcp,mode=ingress,published=8080,target=80
```

当然我们可以继续使用 `-p 8080:80`，但是新的选项格式增加了更多的可能。比如，使用 1.13 开始加入的 `host` 映射模式：

```bash
ubuntu@d1:~$ docker service create --name web \
    --port mode=host,published=80,target=80 \
    nginx
```

运行成功后，查看一下服务容器运行的节点：

```bash
ubuntu@d1:~$ docker node ls
ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
ntjybj51u6zp44akeawuf3i05    d2        Ready   Active
tp7icvjzvxla2n18j3nztgjz6    d3        Ready   Active
vyf3mgcj3uonrnh5xxquasp38 *  d1        Ready   Active        Leader
ubuntu@d1:~$ docker service ps web
NAME                IMAGE         NODE  DESIRED STATE  CURRENT STATE               ERROR  PORTS
web.1.ey0mw8o8h2tx  nginx:latest  d3    Running        Running about a minute ago
```

我们可以看到，集群有3个节点，而服务就一个副本，跑到了 `d3` 上。如果这是以前的使用边界负载均衡的网络 `ingress` 的话，那么我们访问任意节点的 `80` 端口都会看到页面。

但是，`host` 模式不同，它只映射容器所在宿主的端口。因此，如果我们 `curl d1` 的话，应该什么看不到网页，而 `curl d3` 的话就会看到页面：

```bash
root@d1:~$ curl localhost
curl: (7) Failed to connect to localhost port 80: Connection refused
```

```bash
root@d3:~$ curl localhost
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

## `iptables` 的转发规则将默认拒绝

从默认允许改为默认拒绝，从而避免容器外露的问题。

## 在 `docker network inspect` 里显示连入节点

Show peer nodes in docker network inspect for swarm overlay networks #28078

## 允许 `service` `VIP` 可以被 `ping`

在 1.12 的二代 Swarm 排障过程中，常见的一个问题就是跨节点的服务 VIP 不可以 `ping`，所以很多时候很多时候搞不懂是 `overlay` 网络不通呢？还是服务没起来？还是服务发现有问题？这个问题在 1.13 解决了，VIP 可以随便 `ping`，跨宿主也没关系。

# 插件

## 插件功能正式启用

在 1.12 引入了插件概念后，作为试验特性得到了很多关注。包括服务端的 [Docker Store](https://store.docker.com/) 开始准备上线，以及第三方的插件的开发。现在 1.13 插件作为正式功能提供了。

```bash
$ docker plugin

Usage:	docker plugin COMMAND

Manage plugins

Options:
      --help   Print usage

Commands:
  create      Create a plugin from a rootfs and config
  disable     Disable a plugin
  enable      Enable a plugin
  inspect     Display detailed information on one or more plugins
  install     Install a plugin
  ls          List plugins
  push        Push a plugin to a registry
  rm          Remove one or more plugins
  set         Change settings for a plugin

Run 'docker plugin COMMAND --help' for more information on a command.
```

相比于 1.12 的试验版本而言，增加了 `docker plugin create` 命令，指定 `rootfs` 和 `config.json` 即可创建插件。

# 命令行

## 试验 `checkpoint` 功能

可以将运行的容器保存 checkpoint，在将来可以 restore。因此引入 `docker checkpoint` 命令。

(experimental) Implement checkpoint and restore #22049

# 运行时

## 不在分别构建试验可执行文件，直接使用 `--experimental` 参数

以前我们如果希望测试当前试验功能，必须添加试验分支源，重装 `docker`。这给测试试验分支带来了困难。现在变得简单了，不在分为两组可执行文件构建，合并为一个。如果需要测试试验功能，直接在 `dockerd` 后添加 `--experimental` 即可。

## 在 `overlay2` 存储驱动使用于 `xfs` 时可以添加磁盘配额

在 1.13 之前，只有块设备文件系统驱动（如 `devicemapper`, `xfs`, `zfs`等）支持磁盘配额能力，而所有 `Union FS` 的驱动，都不支持配额。现在针对使用 `XFS` 为后端的 `overlay2` 驱动支持了磁盘配额，理论上同样的方式可以在将来移植到 `AUFS`。

## 增加 `docker system` 命令

很多人在以前搞不懂自己的镜像到底占了多少空间、容器占了多少空间，卷占了多少空间。怎么删除不用的东西以释放资源。从 1.13 开始，Docker 提供了一组 `system` 命令来帮助系统管理上的问题。

```bash
$ docker system

Usage:	docker system COMMAND

Manage Docker

Options:
     --help   Print usage

Commands:
 df          Show docker disk usage
 events      Get real time events from the server
 info        Display system-wide information
 prune       Remove unused data

Run 'docker system COMMAND --help' for more information on a command.
```

`docker system df` 是显示磁盘使用情况：

```bash
$ docker system df
TYPE                TOTAL               ACTIVE              SIZE                RECLAIMABLE
Images              3                   3                   700.3 MB            123 MB (17%)
Containers          3                   3                   15 B                0 B (0%)
Local Volumes       1                   1                   219.4 MB            0 B (0%)
```

显示的列表中列出了镜像、容器、本地卷所占用的磁盘空间，以及可能回收的磁盘空间。比如，我们看到镜像有 123MB 的空间可以回收，从 1.13 开始，`docker` 提供了一组 `prune` 命令，分别是：

* `docker image prune`：删除无用的镜像
* `docker container prune`：删除无用的容器
* `docker volume prune`：删除无用的卷
* `docker network prune`：删除无用的网络
* `docker system prune`：删除无用的镜像、容器、卷、网络

还记得之前删除这些资源所用的 `docker rmi $(docker images -f dangling=true -aq)` 这种命令么？现在可以简单地 `docker image prune` 即可删除。

此外，从上面已经可以看到，从 1.13 开始，命令都开始归类于各个子命令了。之前默认的 `docker info`，`docker ps`，`docker rm`，`docker run` 都开始归类于对应的 `docker image`, `docker container`, `docker system` 下了。目前之前的命令依旧可以使用，会继续保持一段时间。但是从 1.13 开始，推荐使用各个子命令的版本了。

## 提升 `overlay2` 的优先级

由于 `overlay2` 在 4.+ 内核的系统上趋于稳定，因此将其优先级提到 `devicemapper` 之上（优先级最高的依旧是 `aufs`）

## `docker exec -t` 自动添加 TERM 环境变量

对于在容器中使用 `vi`、`htop` 之类工具的人来说是比较方便的。之前由于默认没有定义 `TERM`，这些需要终端页面布局的程序执行可能会不正常。比如：

```bash
$ htop
Error opening terminal: unknown.
```

现在直接为 `docker exec -t` 选项添加了继承自当前的 `TERM` 变量，可以让这类工具可以正常使用。

# Swarm Mode

## 正式支持 `docker stack`

从 1.13 开始，正式支持 `docker stack`，并支持直接从 `docker-compose.yml` 文件部署二代 Swarm 集群服务。

1.12 中引入了二代 Swarm，也就是 Swarm Mode。由于基础理念变化很大，因此先行实现比较基本的服务(`service`)，但是针对应用/服务栈(`stack`)没有成熟的方案。只是试行使用 `DAB` 文件进行集群部署。但是 `DAB` 是 `JSON` 文件，而且撰写较为复杂。相对大家已经习惯的 `docker-compose.yml` 却无法在 `docker stack` 中直接使用。只可以用 `docker-compose bundle` 命令将 `docker-compose.yml` 转换为 `.dab` 文件，然后才能拿到集群部署，而且很多功能用不了。

从 1.13 开始，将允许直接使用 `docker-compose.yml` 文件来进行部署，大大方便了习惯了 `docker compose` 的用户。不过需要注意的是，由于概念差异，原有的 `docker-compose.yml` `v2` 格式无法使用，必须使用 `v3` 格式。幸运的是 `v3` 和 `v2` 格式差距不大。

首先，显然第一行的 `version: '2'` 需要换成 `version: '3'`，其次，服务里的 `build` 显然用不了了。以我写的 LNMP 为例，改成 `v3` 格式，就应该是：

```yaml
version: '3'
services:
    nginx:
        image: "twang2218/lnmp-nginx:v1.2"
        ports:
            - "80:80"
        networks:
            - frontend
        depends_on:
            - php
    php:
        image: "twang2218/lnmp-php:v1.2"
        networks:
            - frontend
            - backend
        environment:
            MYSQL_PASSWORD: Passw0rd
        depends_on:
            - mysql
    mysql:
        image: mysql:5.7
        volumes:
            - mysql-data:/var/lib/mysql
        environment:
            TZ: 'Asia/Shanghai'
            MYSQL_ROOT_PASSWORD: Passw0rd
        command: ['mysqld', '--character-set-server=utf8']
        networks:
            - backend
volumes:
    mysql-data:
networks:
    frontend:
    backend:
```

如果在 swarm 环境部署该服务栈的话，使用命令：

```bash
$ docker stack deploy --compose-file docker-compose.yml lnmp
Creating network lnmp_frontend
Creating network lnmp_backend
Creating network lnmp_default
Creating service lnmp_mysql
Creating service lnmp_nginx
Creating service lnmp_php
```

然后可以用 `docker stack ls` 或 `docker stack ps` 来查看服务栈状态：

```bash
$ docker stack ls
NAME  SERVICES
lnmp  3
$ docker stack ps lnmp
NAME                       IMAGE                      NODE  DESIRED STATE  CURRENT STATE           ERROR  PORTS
lnmp_mysql.1.hfz88yeej0ve  mysql:5.7                  d2    Running        Running 9 seconds ago
lnmp_php.1.kqk4xgr7ajn4    twang2218/lnmp-php:v1.2    d1    Running        Running 10 seconds ago
lnmp_nginx.1.arrrnbuzgq9t  twang2218/lnmp-nginx:v1.2  d2    Running        Running 5 seconds ago
```

由于默认使用的就是 `ingress` 边界负载均衡网络映射的 `80` 端口，因此我们可以访问任意节点来查看页面，享受二代 Swarm 给我们带来的好处。

删掉 `stack`，只需要简单地 `docker stack rm lnmp` 即可。不过需要注意的是，所有的命名卷不会被删除，如需删除，需要手动的去各个容器所在节点去 `docker volume rm` 卷。

## 添加 `secret` 管理

从 1.13 开始，Docker 提供了集群环境的 `secret` 管理机制，从而可以更好地在集群环境中管理密码、密钥等敏感信息。

```bash
docker secret --help

Usage:	docker secret COMMAND

Manage Docker secrets

Options:
     --help   Print usage

Commands:
 create      Create a secret using stdin as content
 inspect     Inspect a secret
 ls          List secrets
 rm          Remove a secret

Run 'docker secret COMMAND --help' for more information on a command.
```

`docker secret create` 从标准输入读取信息，并且存入指定名称：

```bash
$ echo "MySuperSecretPassword" | docker secret create mysql_password
```

在将来启动服务的时候，就可以通过 `--secret` 选项来指定需要使用哪些 `secret`。

```bash
$  docker service create --name privateweb --secret mysql_password nginx
```

所指定的 `secret` 会以文件形式挂载于 `/var/run/secrets/` 目录下：

```bash
root@d5cec6381df8:/# ls -al /var/run/secrets/
total 8
drwxrwxrwt 2 root root   60 Dec  6 03:16 .
drwxr-xr-x 4 root root 4096 Dec  6 03:16 ..
-r--r--r-- 1 root root   22 Dec  6 03:16 mysql_password
```

`secret` 的权限是 `444` 因此容器中的非 `root` 用户也可以访问其内容，读取所需的密码或者密钥，这对于非 root 用户启动的服务很重要。

```bash
root@d5cec6381df8:/# cat /var/run/secrets/mysql_password
MySuperSecretPassword
```

## 添加负载均衡和DNS记录对新增的健康检查的支持

Docker 1.10 开始引入了 DNS 服务发现，然后在 1.11 进一步支持了 DNS 负载均衡，1.12 开始引入了 VIP 负载均衡。而 1.12 同时还提供了 `HEALTHCHECK` 容器健康检查的能力。但是这两组功能在 1.12 时并没有结合起来。因此可能会出现，容器启动过程中，负载均衡就已经将流量开始导流给这个容器了，从而导致升级过程中部分服务会访问失败。

在 1.13 开始，将利用 `Dockerfile` 中定义的健康检查功能，来检查容器健康情况。如果容器尚未处于健康状况，所有的负载均衡以及 DNS 服务发现将不会把流量转发给这个新启动的容器，它们会一直等到容器确实已经可以提供服务时，再更新负载均衡以及服务发现。

## 添加滚动升级回滚的功能

当 Docker 1.12 提供了 Swarm Mode 的滚动升级后，大家都很兴奋，内置的滚动升级让持续发布变得更为轻松。1.12 提供了当服务升级出现故障时，超过重试次数则停止升级的功能，这也很方便，避免让错误的应用替代现有正常服务。但是有一个问题虽然提出，但并未能在 1.12 解决，就是出故障后回滚的问题。当发生故障后，如何让服务回滚到之前的版本？难道是再发布一个更新，不过更新的是旧版本么？那么旧版本到底是哪个版本？这些问题在自动化处理的时候，是一些比较麻烦的问题。

在 1.13 里，开始支持 `docker service update --rollback` 功能，当发生故障停止后，可以由管理员执行该命令将服务回滚到之前的版本：

```bash
$ docker service update \
  --rollback \
  --update-delay 0s \
  my_web
```

## 添加命令 `docker service logs` 以查看服务日志

Swarm Mode 启动服务还有一个麻烦的问题就是查看日志很麻烦。在 `docker-compose` 中，可以直接 `docker-compose logs <服务名>` 即可查看日志，即使服务是跑在不同节点上，甚至是多个服务副本。但是 `docker service` 不支持 `logs` 命令。因此，现在查看日志比较麻烦，需要 `docker service ps` 查看各个容器都在哪些节点上，然后再一个个进去先 `docker ps` 找到容器 ID，然后在 `docker logs <容器ID>` 查看具体日志。非常繁琐。

从 1.13 开始，实验性的提供了 `docker service logs` 命令，用以达到类似的功能。不过这是试验功能，因此必须在启用试验模式后(`dockerd --experimental`)，才可以使用。

## 增加强制再发布选项 `docker service update --force`

在生产环境使用 `docker swarm mode` 的过程中，很可能会碰到这样的问题，当一个节点挂掉了，修复重启该节点后，发现原来该节点跑的服务被调度到了别的节点上。这是正常的，swarm manager 的介入保证了服务的可用性。可是节点恢复后，除非运行新的服务，或者某个别的节点挂掉，否则这个新修复的节点就一直闲着，因为服务副本数满足需求，所以 swarm manager 不会介入重新调度。

这个问题在集群扩容后，问题就更加明显，新扩容的节点，最初都是空闲的。在 1.12 唯一的解决办法就是我们改点儿什么东西，从而触发 swarm 的升级行为。但是这显然不是好办法。

在 1.13，引入了 `docker service update --force` 功能，可以在服务未发生改变时，强制触发再发布的流程，也就是强制重新 `pull` 该镜像、停止容器，重新调度运行容器。这样会让由于各种维护导致的集群负载不平衡的情况得到缓解，再次平衡集群。由于这是 `docker service update` 命令，因此也会遵循所指定的 `--update-parallelism` 和 `--update-delay` 的设置，进行滚动更新。

Add force option to service update #27596

# 废弃

* 废弃 `docker daemon` 命令，用 `dockerd` 取代。其实 1.12 已经换了
* 移除对 Ubuntu 15.10、Fedora 22 的支持，因为这两个都 EOL 了。
* 废弃 `Dockerfile` 中的 `MAINTAINER` 指令，如果需要可以用 `LABEL maintainer=<...>` 代替
