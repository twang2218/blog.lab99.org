---
layout: post
category: docker
title: 视频笔记：Docker 开发环境 - 第一讲 - David Gageot
date: 2016-07-11
tags: [docker, youtube, video, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Docker for Developer - Part 1
by David Gageot

{% owl youtube SK0sqfVn7ls %}

<https://www.youtube.com/watch?v=SK0sqfVn7ls>

{% owl tencent l03143jinsh %}

<http://v.qq.com/x/page/l03143jinsh.html>

# 演示

`docker-compose up -d` 后，所启动的服务会出现在 `localhost` 上，这是在 Linux 世界很正常的事情，因为是运行在本机上。而在过去的 Docker Toolbox 中，我们只能使用 boot2docker 这个virtualbox 虚拟机的IP - `192.168.99.100` 来访问，现在经过很复杂的底层处理 (VPNkit)，一切都变得像 Linux 一样，可以通过本机地址操作了。

挂载宿主目录也是一样，以前虽然也可以挂载，但是由于中间隔了一层 Virtualbox ，很多功能，如 fs notification 无法工作，比如 Live Reload。现在通过 `OSXfs`，这些都可以了。现在浏览器上开启 Live Relaod 后，可以在苹果上，用习惯的编辑器编辑代码，比如CSS，然后保存，浏览器可以直接看到变化后的结果。

现在同样可以做的是动态调试。之前`Keynote`中演示了用 `Visual Studio Code` 调试 `Docker` 内运行的 `Node.js` 应用。这次 David 演示了调试 Java 程序，并且演示了如何具体设置。

Java 程序动态调试中，需要开启一个端口允许IDE来连接运行的应用来进行调试，这里使用 5005 端口。如何知道是这个端口的？打开 IDE (`IntelliJ`) `Run/Debug Configuration`，点左上角➕添加新的调试配置 - `Remote`，然后自动的配置中会显示主机和端口，这里默认的是 `localhost` `5005`。

因此首先要做的就是在 `words-java` 这个服务中，开启端口映射。然后`stop`, `rm -f`, `up -d` 重启这个服务。在 `IntelliJ` 中点击 `Debug` 按钮。这时就连接上了容器内部的Java程序，然后重新刷新页面，触发程序执行，然后会发现IDE成功的停止在了断点处。

```bash
docker-compose scale words-java=20
```

在这个例子中，David 使用了 Go 请求Docker 内置DNS解析 `words-java`，然后内置DNS返回了`50`个对应的IP地址。`Go` 内部进行随机选择其中一个，以此达到了负载均衡的目的。

# Application Bundle

`Docker Compose` with `Docker 1.12` 支持 `Docker Application Bundle` 特性，可以将一个`docker-compose`所描述的app打包成一个`.dab`文件，方便分发部署。

打包 `DAB` 文件有一些需求，这些需求和 `Docker Compose` + `Swarm` 基本一致，比如，不然可以绑定宿主目录等。

执行 `docker-compose bundle` 后，Docker Compose 会执行 `build` 指令，并且根据文件的 `image` 部分，将构建的镜像 `push` 到 Docker Hub 上。然后生成一个项目名(默认为目录名) 的 `xxxx.dab` 文件。

所生成的 .dab 文件实际上只是一个 JSON 文件，里面像 `docker-compose.yml` 一样定义了一系列的服务，以及使用的`Image`，及其 `SHA256` 的校验码。

接下来可以尝试部署这个`.dab`文件。和 `docker-compose.yml` 所不同的是，`DAB` 要求运行在 `Docker Swarm Mode` 上。所以演示的时候，David 使用 `docker swarm init` 开启了一个本地的单节点 Swarm。然后开始部署之前打包 `xxxx.dab` 文件，`docker deploy xxxx`，然后docker 会在 `swarm` 中创建了网络，并且创建各种服务，并启动。

然后 David 做了个很大胆的举动，重启了自己的 Mac 笔记本。来给大家现场演示重启后，所有部署的 Docker service 会处于自动运行状态。

# 问答

**Q: 可以自己定义 Bundle 文件么？还是必须经过 Compose 一次转手？**

A: 可以自己写 .dab 文件，那只是个 JSON 文件。但是显然使用 docker-compose.yml 会更简单。

**Q: 演示代码会放在 github 上么？**

A: 是的，所有代码都已经在 github 上了。

<https://github.com/dgageot/dockercon16>

**Q: Docker for Mac 是运行在一个Linux VM 上？还是直接运行在 Mac 上？**

A: 是运行在一个非常精简的 Linux VM 上，这个VM是运行在 OSX 内置的 `Hypervisor` 框架上的(`Hyperkit`)。

**Q: 刚才的例子中，如果Java代码修改了，你怎么确保容器内的代码跟着改变？再次构建？**

A: `Java` 要比 `Node.js` 复杂一些，在`Node.js`中，只要修改了`JS`代码，保存即可，服务端就可以感知变化重新运行。而Java要复杂一些，需要重新构建以及重新运行。所以在刚才的例子中，使用 `stop`, `rm -f`, `up -d` 的方式确保容器内的代码重新构建并运行。

**Q: 在刚才的例子中，每一个 microservice 都是一个独立的文件夹，如果不是3个，而是20多个，每个都来自于不同的 repository，那么怎么组织这些文件？是把 docker-compose.yml 放到一个独立的 repository 么？**

A: 对于小的项目来说，一般是顶层目录放置 docker-compose.yml 文件，而每个 micro service 放置于各自的子目录中。如果很复杂的话，可以使用 git sub-module 功能，不过一般情况之前的做法就够了。

**Q: 之前的 DNS 负载均衡的例子中，是谁负责解析的这个DNS地址？因为在启用 Swarm 之前，似乎就已经支持负载均衡了。**

A: DNS 负载均衡是内置的网络功能，不需要 Swarm 的介入，在代码中直接使用对方的服务名即可。

**Q: 作为开发人员，我已经开始使用 Docker Compose了，那么还有什么必要使用 Application Bundle？它们二者的区别是什么？**

A: 如果我们观察 `docker-compose.yml` 文件的话，会发现在每个服务定义中，并没有具体指定那个镜像版本，所以compose基本上是开发工具，定义了构成应用的服务，但是并没有具体限定服务的镜像版本。在之前的话，我们的做法是 `tag` 每一个 `image`，然后改变 `docker-compose` 文件，然后再进行部署。而现在则不需要，可以直接进行`bundle`，就会把当前特定的版本信息打包。

**Q: 会把镜像一同打包么？还是说必须 `push` 到 docker hub？**

目前只打包的是镜像信息，是个JSON文件，不包含镜像tarball，将来有可能这么做。

**Q: 当 deploy 一个 bundle 后，这东西是存哪了？为什么 docker engine会重启这个服务？**

A: 这属于 `Swarm Mode` 的功能，当 `docker deploy` 一个 `bundle` 后，实际上是告诉 `docker engine` 建立一系列的服务，当系统重启后，`docker engine` 会检查当前的服务状态以及期望的服务状态。发现确实或者没有启动，会进行调度建立服务或者启动。

**Q: `docker bundle` 可不可以 `push` 到 private registry？**

A: 不知道，虽然觉得应该可以，但是不清楚这部分的情况，应该问一下 Docker Engine 的team。
