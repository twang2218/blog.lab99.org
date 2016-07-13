# Docker 问答录


## 挂在宿主目录，结果 Permission denied，没权限

原因是 CentOS/RHEL中的 SELinux 限制了目录权限。需要添加规则。

```bash
$ man docker-run
...
When  using  SELinux,  be  aware that the host has no knowledge of container SELinux policy. Therefore, in the above example, if SELinux policy  is enforced,  the /var/db directory is not  writable to the container. A "Permission Denied" message will occur and an avc: message in the host's syslog.

To  work  around  this, at time of writing this man page, the following command needs to be run in order for the  proper  SELinux  policy  type label to be attached to the host directory:

# chcon -Rt svirt_sandbox_file_t /var/db
```

参考：http://www.projectatomic.io/blog/2015/06/using-volumes-with-docker-can-cause-problems-with-selinux/

## 安装 Docker

无论是CentOS还是Ubuntu，都不要使用系统源里面的Docker，版本太古老，没法用。

官方正式的安装Docker方法：

```bash
curl -fsSL https://get.docker.com/ | sh
```

如果访问官方源太慢，可以使用国内的源安装：

使用DaoCloud的Docker安装脚本：
```bash
curl -sSL https://get.daocloud.io/docker | sh
```

使用阿里云的安装脚本：
```bash
curl -sSL http://acs-public-mirror.oss-cn-hangzhou.aliyuncs.com/docker-engine/internet | sh -
```

## 国内使用docker下载镜像很慢

要感恩伟大的墙，所以使用阿里云或者DaoCloud的加速器（也就是代理、镜像）吧：

参考：http://www.imike.me/2016/04/20/Docker%E4%B8%8B%E4%BD%BF%E7%94%A8%E9%95%9C%E5%83%8F%E5%8A%A0%E9%80%9F/

```bash
 echo "DOCKER_OPTS=\"\$DOCKER_OPTS –registry-mirror=http://your-id.m.daocloud.io -d\"" >> /etc/default/docker
```

https://jxus37ac.mirror.aliyuncs.com

### Ubuntu 16.04

编辑 `systemd` 的服务配置文件 `docker.service`

```bash
sudo vi /etc/systemd/system/multi-user.target.wants/docker.service
```

在 `ExecStart` 中的行尾添加上所需的配置，如：

```
ExecStart=/usr/bin/docker daemon -H fd:// --registry-mirror=https://jxus37ac.mirror.aliyuncs.com
```

保存退出后，重新加载配置并启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

确认一下配置是否已经生效：

```bash
sudo ps -ef | grep docker
```

生效后这里会看到自己的配置。

## 如何在Docker内使用docker命令(比如jenkins)

首先，不要在Docker中安装Docker服务，也就是所谓的Docker In Docker，参考文章：
https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/

为了让容器内可以构建镜像，应该使用 Docker API 的客户端，可以是原生的Docker CLI，也可以是其它语言的库。

### Docker CLI
```bash
# 下载安装Docker CLI
curl -O https://get.docker.com/builds/Linux/x86_64/docker-latest.tgz \
    && tar zxvf docker-latest.tgz \
    && cp docker/docker /usr/local/bin/ \
    && rm -rf docker
# 使用宿主API
export DOCKER_HOST=tcp://172.17.0.1:2376 \
# 然后就可以docker操作了
docker info
```

其中宿主需要去监听指定`IP:PORT`位置，并且把上面的`172.17.0.1:2376`换成实际绑定地址和端口组合。

## Dockerfile 怎么写

最直接也是最简单的办法是看官方文档。

这篇文章讲述具体`Dockerfile`的命令语法：https://docs.docker.com/engine/reference/builder/

然后，学习一下官方的`Dockerfile`最佳实践：https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/

最后，去 Docker Hub 学习那些Official的镜像`Dockerfile`咋写的。

## 怎么指定容器 IP 地址？每次重启容器都要变化IP地址怎么办？

一般情况是不需要指定容器IP地址的。这不是虚拟主机，而是容器。其地址是供容器间通讯的，容器间则不用ip直接通讯，而使用主机名、服务名、网络别名。

为了保持向后兼容，`docker run` 在不指定`--net`时所在的网络是`default bridge`，在这个网络下，需要使用 `--link` 参数才可以让两个容器找到对方。

这是有局限性的，因为这个时候使用的是 `/etc/hosts` 静态文件来进行的解析，比如一个主机挂了后，重新启动IP可能会改变。虽然说这种改变Docker是可能更新`/etc/hosts`文件，但是这有诸多问题，可能会因为竞争冒险导致 `/etc/hosts` 文件损毁，也可能还在运行的容器在取得 `/etc/hosts` 的解析结果后，不再去监视该文件是否变动。种种原因都可能会导致旧的主机无法通过容器名访问到新的主机。

参考官网文档：https://docs.docker.com/engine/userguide/networking/default_network/dockerlinks/

如果可能不要使用这种过时的方式，而是用下面说的自定义网络的方式。

而对于新的环境（Docker 1.10以上），应该给容器建立自定义网络，同一个自定义网络中，可以使用对方容器的容器名、服务名、网络别名来找到对方。这个时候帮助进行服务发现的是Docker 内置的DNS。所以，无论容器是否重启、更换IP，内置的DNS都能正确指定到对方的位置。

参考官网文档：https://docs.docker.com/engine/userguide/networking/work-with-networks/#linking-containers-in-user-defined-networks

## Docker 多宿主网络怎么配置？

我写了一个配置的例子，可以在这里看。
https://gist.github.com/twang2218/def4097648deac398a949b58e2a31610

其中两个脚本:

 * 带swarm一起玩 overlay：`build-overlay-with-swarm.sh`
 * 不带swarm玩，直接构建overlay：`build-overlay-without-swarm.sh`

## Docker 容器如何随系统一同启动

```bash
--restart=always
```

参考官网文档：https://docs.docker.com/engine/reference/commandline/run/#restart-policies-restart

## 怎么映射宿主端口？Dockerfile 中的EXPOSE和 docker run -p 中有啥区别？

大写-P和小写-p含义不同，不是等价替代。

大写 -P是说把所有EXPOSE的端口都映射到随机端口去，而不是同端口映射。
小写 -p 必须跟参数如 <宿主端口>:<容器端口>，是明确指定宿主端口映射，而不是生成随机宿主端口去映射。

## 我要映射好几百个端口，难道要一个个`-p`么？

-p 是可以用范围的：
```bash
-p 8001-8010:8001-8010
```

## 我怎么修改了 `/etc/default/docker` 后不起作用？

最近两年处于 Upstart/SysinitV 到 systemd 的过渡期，所以配置服务的方式对于不同的系统是不一样的，要看自己使用的是什么操作系统，以及什么版本。

对于 Upstart 的系统（Ubuntu 14.10或以前的版本，Debian 7或以前的版本，CentOS/RHEL 6），配置文件可能在

 * Ubuntu/Debian: `/etc/default/docker`
 * CentOS/RHEL: `/etc/sysconfig/docker`

而对于 systemd 的系统(Ubuntu 15.04及以后的版本，Debian 8及以后的版本，CentOS/RHEL 7)，配置文件则一般在 `/etc/systemd/system/` 下的 `docker.service` 中，如：

 * `/etc/systemd/system/multi-user.target.wants/docker.service`

具体位置不同系统不同，而且 Upstart 的服务配置文件和 systemd 的配置文件的格式也不同，不要混淆乱配：

参考官网文档：
https://docs.docker.com/engine/admin/configuring/#ubuntu
https://docs.docker.com/engine/admin/systemd/

## Docker的 `/var/lib/docker/devicemapper` 占用空间不断增长, 怎么破?

这类问题一般是 CentOS/RHEL 红帽系的问题，CentOS 这类红帽系统中，由于不像 Ubuntu 那样有成熟的 Union FS实现(如`aufs`)，所以只能使用 `devicemapper`，而默认使用的是`lvm-loop`，也就是用一个稀疏文件来当成一个块设备，给`devicemapper`用，作为Docker镜像容器文件系统。这是非常不推荐使用的，性能很差不说，不稳定，还有很多bug，如果没办法换Ubuntu/Debian系统，那么最起码应该建立块设备（分区、卷）给 `devicemapper`用。

参考官网文档：https://docs.docker.com/engine/userguide/storagedriver/device-mapper-driver/#for-a-direct-lvm-mode-configuration

严格来说 CentOS/RHEL 7 中实际上有一个 Union FS 实现，虽然 CentOS/RHEL 7 的内核是3.10，不过红帽从 Linux 3.18 backport 回来了 `overlay` fs 的驱动。但是，红帽自己都在官方的发布声明中说能不要用就不用。

https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/7.2_Release_Notes/technology-preview-file_systems.html

## 多个 Docker 容器之间共享数据怎么办？NFS？

如果是同一个宿主，那么可以绑定同一个数据卷，当然，程序上要处理好并发问题。

如果是不同宿主，则可以使用分布式数据卷驱动，让分布在不同宿主的容器都可以访问到的分布式存储的位置。如S3之类：

https://docs.docker.com/engine/extend/plugins/#volume-plugins

## 我用的是阿里云Ubuntu 14.04 主机，内核还是3.13，怎么办？

其实 Ubuntu 14.04 官方维护的内核已经到 4.4了，可以通过下面的命令升级内核：

```bash
sudo apt-get install --install-recommends linux-generic-lts-xenial
```

## Docker 资料好少啊？网上的命令怎么不能用？

首先，做技术工作，请珍惜生命，远离百度；
其次，不翻墙、不用Google、不看英文资料，那请转行，没法混。

然后是回答问题，Docker的资料其实很丰富，特别是官方文档讲解非常详细。

https://docs.docker.com/

另外，Docker有丰富的镜像库，Docker Hub，特别是官方(Official)的镜像可以直接在生产环境中使用，制作比较精良。

https://hub.docker.com/explore/

所有的官方镜像都有 `Dockerfile`，以及在github上有全部生成镜像的配套文件，遵循了`Dockerfile`的最佳实践，这些也是很好地学习资料。

另外，在 YouTube 的 Docker 官方频道下有几百个视频讲座，从初级到高级用户都能从里面学到很多东西。

https://www.youtube.com/user/dockerrun

## `Dockerfile` 中的`VOLUME`和`docker run -v`，以及`docker-compose.yml`中的`volumes`都有什么区别？

先明白几个概念，挂载分为挂载本地宿主目录，或者挂载数据卷，而数据卷又分为匿名数据卷和命名数据卷。

那么，在`Dockerfile`中定义的是挂载是指匿名数据卷。这个设置可以在运行时覆盖。通过 `docker run` 的 `-v` 参数或者 `docker-compose.yml` 的 `volumes` 指定。使用命名卷的好处是可以复用，其它容器可以通过这个命名数据卷的名字来指定挂载，共享其内容（不过要注意并发访问的竞争问题）。

数据卷一般会保存于 `/var/lib/docker/volumes`，不过一般不需要，也不应该访问这个位置。

## 问一句 Kubernetes 为啥叫 `k8s`？

是因为发音接近么……好吧，实话说了吧，是因为犯懒，数数 k 和 s 中间多少个字母？8个吧，这个8 的意思就是省略8个字母，懒得敲了…… 其实这类用法很多，比如 i18n (internationalization), l11n (localization) 等等，老外也懒得打字啊。

## 容器磁盘可以限制配额么？

对于 `devicemapper`, `btrfs`, `zfs` 来说，可以通过 `--storage-opt size=100G` 这种形式限制 `rootfs` 的大小。

```bash
docker create -it --storage-opt size=120G fedora /bin/bash
```

参考官网文档：https://docs.docker.com/engine/reference/commandline/run/#/set-storage-driver-options-per-container

## 使用国内镜像还是慢，公司内好多 docker 主机，都需要去重复下载镜像，咋办？

在局域网内，本地架设个 Docker Registry mirror，作为缓存即可。

建立一个空目录，并且添加 Registry 的配置文件 `config.yml`，其内容为：

```yaml
version: 0.1
log:
    fields:
        service: registry
storage:
    cache:
        blobdescriptor: inmemory
    filesystem:
        rootdirectory: /var/lib/registry
http:
    addr: :5000
    headers:
        X-Content-Type-Options: [nosniff]
health:
    storagedriver:
        enabled: true
        interval: 10s
        threshold: 3
proxy:
    remoteurl: https://registry-1.docker.io
```

并且，建立个 `docker-compose.yml` 文件方便启动这个服务：

```yml
version: '2'
services:
    mirror:
        image: registry:2
        ports:
            - "5000:5000"
        volumes:
            - ./config.yml:/etc/docker/registry/
```

然后用 Docker Compose 启动这个镜像服务：`docker-compose up -d`

然后在局域网中的所有 Docker 主机中的 Docker Daemon 配置中，都添加一条 `--registry-mirror=<这个镜像服务器的地址>`


首先用docker pull下载一个本地不存在的镜像，看一下时间：

```bash
$ time docker pull php:7-fpm-alpine
7-fpm-alpine: Pulling from library/php
e110a4a17941: Pull complete
d9f63633faf6: Pull complete
ac309a5bc5d5: Pull complete
4523ec888a62: Pull complete
6a77f79ab9b5: Pull complete
27243562b67c: Pull complete
33e1803456c2: Pull complete
a1219b0a1418: Pull complete
Digest: sha256:f7d6f6844df64f8f615fa50ca28b3f1ad82be0a2dcde0b55205d31c1bb9f4820
Status: Downloaded newer image for php:7-fpm-alpine
docker pull php:7-fpm-alpine  0.07s user 0.07s system 0% cpu 2:30.43 total
```

上面我们下载了 php:7-fpm-alpine，用时 2 分 30秒，然后我们删掉镜像：

```bash
$ docker rmi php:7-fpm-alpine
Untagged: php:7-fpm-alpine
Deleted: sha256:b80ca1f4f99d13e00ac6ef13aca7c1ef6e2fb83ec2fe6a035e8beeeb05afb4b6
Deleted: sha256:69ee0f31988504dc3e3b068476f11d06b43fc34465a1c58d351406b9d2368e7a
...
```
然后重新下载镜像，测试时间：
```bash
$ time docker pull php:7-fpm-alpine
7-fpm-alpine: Pulling from library/php
e110a4a17941: Pull complete
d9f63633faf6: Pull complete
ac309a5bc5d5: Pull complete
4523ec888a62: Pull complete
6a77f79ab9b5: Pull complete
27243562b67c: Pull complete
33e1803456c2: Pull complete
a1219b0a1418: Pull complete
Digest: sha256:f7d6f6844df64f8f615fa50ca28b3f1ad82be0a2dcde0b55205d31c1bb9f4820
Status: Downloaded newer image for php:7-fpm-alpine
docker pull php:7-fpm-alpine  0.05s user 0.04s system 0% cpu 13.778 total
```

这次由于该 docker image 本地 mirror 缓存了，所以用时约14秒，速度大大提高了。

参考官网文档：

服务端：https://docs.docker.com/registry/configuration/#/proxy

客户端：https://docs.docker.com/engine/reference/commandline/dockerd/

## 我的配置文件传群文件了，帮忙看看？这是我的配置…(省略几千字)

配置文件这类文本东西，应该用这类剪贴板网站，不要使用群文件或者直接大段刷屏，格式混乱而且没有语法高亮：

http://pastebin.com/
http://paste.ubuntu.com/

## `docker stats` 显示的只有容器ID，怎么才能显示容器名字？

```bash
docker stats $(docker ps --format={{.Names}})
```

## 我 `docker push` 了很多镜像到我私有的 registry 上，怎么才能查看上面都有啥？或者搜索？

两种办法，一种是使用 Registry V2 API。可以列出所有镜像：

```bash
curl http://<私有registry地址>/v2/_catalog
```

如果私有 Registry 尚支持 V1 API（已经废弃），可以使用 `docker search`

```bash
docker search <私有registry地址>/<关键字>
```

## 你那个LNMP例子中的 `docker-compose.yml` 中有好多 `networks`，都是什么意思啊？

我写的LNMP多容器互通的例子：https://coding.net/u/twang2218/p/docker-lnmp/git

前面`services`下的每个服务下面的`networks`，是说这个服务要接到哪个网络上。
而最后的那个总的`networks`下面的，是这几个网络的定义。

也就是说，`nginx` 接到了名为 `frontend` 的前端网络；`mysql` 接到了名为 `backend` 的后端网络；而作为中间的 `php` 既需要和 `nginx` 通讯，又需要和 `mysql` 通讯，所以同时连接了 `frontend` 和 `backend` 网络。由于 `nginx` 和 `mysql` 不处于同一网络，所以二者无法通讯，起到了隔离的作用。

关于Docker自定义网络，你可以看一下官方文档的介绍：
https://docs.docker.com/engine/userguide/networking/dockernetworks/#/user-defined-networks

关于在Docker Compose中使用自定义网络的部分，可以看官方这部分文档：
https://docs.docker.com/compose/networking/

## `docker images` 命令显示的镜像是真的占了那么大的空间么？每次都是下载这么大的镜像？感觉好像很多有不少重复的东西。

这个显示的大小是计算后的大小，要知道docker image是分层的，在`1.10`之前，不同镜像无法共享同一层，所以基本上确实是下载大小。但是从`1.10`之后，已有的层（通过SHA256来判断），不需要再下载。只需要下载变化的层。所以实际下载大小比这个数值要小。而且本地硬盘空间占用，也比`docker images`列出来的东西加起来小很多，很多重复的部分共享了。

## `Dockerfile` 就是 shell 脚本吧？那我懂，一行行把需要装的东西都写进去不就行了。

不是这样的。`Dockerfile` 不等于 `.sh` 脚本

`Dockerfile` 确实是描述如何构建镜像的，其中也提供了 `RUN` 这样的命令，可以运行 shell 命令。但是和普通 shell 脚本还有很大的不同。

Dockerfile 描述的实际上是镜像的每一层要如何构建，所以每一个`RUN`是一个独立的一层。所以一定要理解“分层存储”的概念。上一层的东西不会被物理删除，而是会保留给下一层，下一层中可以指定删除这部分内容，但实际上只是这一层做的某个标记，说这个路径的东西删了。但实际上并不会去修改上一层的东西。每一层都是静态的，这也是容器本身的`immutable`特性，要保持自身的静态特性。

所以很多新手会常犯下面这样的错误，把 `Dockerfile` 当做 shell 脚本来写了：

```Dockerfile
RUN yum update
RUN yum -y install gcc
RUN yum -y install python
ADD jdk-xxxx.tar.gz /tmp
RUN cd xxxx && install
RUN xxx && configure && make && make install
```

这是相当错误的。除了无畏的增加了很多层，而且很多运行时不需要的东西，都被装进了镜像里，比如编译环境、更新的软件包等等。结果就是产生非常臃肿、非常多层的镜像，不仅仅增加了构建部署的时间，也很容易出错。

正确的写法应该是把一个任务放到一个 `RUN` 下，多条命令应该用 `&&` 连接，并且在最后要打扫干净所使用的环境。比如下面这段摘自官方 redis 镜像 `Dockerfile` 的部分：

```Dockerfile
RUN buildDeps='gcc libc6-dev make' \
	&& set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" \
	&& echo "$REDIS_DOWNLOAD_SHA1 *redis.tar.gz" | sha1sum -c - \
	&& mkdir -p /usr/src/redis \
	&& tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 \
	&& rm redis.tar.gz \
	&& make -C /usr/src/redis \
	&& make -C /usr/src/redis install \
	&& rm -r /usr/src/redis \
	&& apt-get purge -y --auto-remove $buildDeps
```

## CentOS 7 的内核太老了 3.10，是不是很多Docker功能不支持？

之前我也是这样以为的，毕竟很多内核功能需要更高的版本。比如 Overlay FS 需要Linux 3.18，而Overlay network需要Linux 3.16。而CentOS 7内核为3.10，按理说不会支持这些高级特性。

但是，事实并非如此，红帽团队会把一些新内核的功能backport回老的内核。比如 `overlay fs`等。所以一些功能依旧会支持。因此 CentOS 7的Docker Engine同样可以支持 `overlay network`，以及 `overlay fs`。因此在新的 Docker 1.12 中，CentOS/RHEL 7 才有可能支持 Swarm Mode。

## Docker 1.8以后版本都有什么改进么？

每个版本发布时，官方博客 https://blog.docker.com 都会有专门文章描述这个版本最主要的改进。

https://blog.docker.com/2015/11/docker-1-9-production-ready-swarm-multi-host-networking/
https://blog.docker.com/2016/02/docker-1-10/
https://blog.docker.com/2016/04/docker-engine-1-11-runc/
https://blog.docker.com/2016/06/docker-1-12-built-in-orchestration/

## `docker-machine create -d virtualbox dev` 创建的 Docker Host 下载镜像速度太慢，是不是需要进去修改什么配置文件？

从根本找原因，最初创建虚拟机的时候就忘记（或者默认）没有加入中国特色的配置。没必要进去修改配置，正确的做法是创建时就指定好各种应对伟大的墙的各种策略。比如指定`--registry-mirror`之类的。

```bash
docker-machine create -d virtualbox \
     --engine-registry-mirror=https://jxus37ac.mirror.aliyuncs.com \
     --engine-storage-driver overlay2 \
     dev
```
