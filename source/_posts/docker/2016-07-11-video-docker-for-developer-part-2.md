---
layout: post
category: docker
title: 视频笔记：Docker 开发环境 - 第二讲 - Borja Burgos
date: 2016-07-11
tags: [docker, dockercon16, youtube, notes]
---

<!-- toc -->

# 视频信息

DockerCon 16 - Docker for Developers - Part 2
by Borja Burgos, Fernando Mayo

{% owl youtube ZsIb5tkyncA %}

<https://www.youtube.com/watch?v=ZsIb5tkyncA>

{% owl tencent j0314zhu619 %}

<http://v.qq.com/x/page/j0314zhu619.html>

# Docker Cloud: 构建、部署、运行

* 构建

  * Docker Builds
  * Integration Tests
  * Privacy controls
  * Parallelism
  * Official Images

* 部署

  * 公共 registry
  * 私有 repositories
  * 安全扫描
  * 多构架

* 运行

  * 构架 agnostic
  * overlay network
  * 服务发现
  * 一键升级
  * 容易扩展

# Automation

使用 `Docker Cloud` ，可以完成从 `CI` 到 `CD` 的全程自动化过程。

# Collaboration

使用 `Docker Cloud` 可以让团队在云环境协作 `CI`/`CD`

# Demo

假设一个场景，一个公司叫做 `Cloudvote`。需要对分步`CI`/`CD`。

## Staging

> `自动构建` → `测试` → `安全扫描` → `重新部署`

代码存储于 `GitHub` 的 `staging` 分支中，{`/worker`, `/result-app`, `/voting-app`}，从 `git push` 开始，自动构建，测试，并且`push`为 `cloudvote`/{`worker`,`result-app`,`voting-app`}:`staging`，然后部署到 D`igital Ocean` 2节点服务器集群中去运行。全部自动化运行。

## Production

> `自动构建` → `测试` → `安全扫描`

代码存储于 `GitHub` 的 `master` 分支，构建测试通过后，标记为 `:latest`，然后部署到 `AWS` 的5节点去运行。

# 开始演示

## 首先赋予新员工 docker cloud 权限

访问 <https://cloud.docker.com> ，登录后选择 `cloudvote app` → `Teams` → `添加用户` 。这样该用户就可以访问 <https://cloud.docker.com> 中对应的项目了。

## Fernando 接手修改工作

Fernando 开始新的工作后，先去 `Github` 看一下 `issue`。 发现了新的 `issue #2`，要求把 `Dog` 和 `Cats` 换为`🐱`和`🐶`两个emoji。好吧，先 `fork` 这个 `repository`，然后 `clone` 到本地。

先检查一下代码是否如期望一般工作，由于已经安装了 `Docker for Mac`，所以直接运行 `docker-compose up ` ，然后访问 `localhost:5000 ` 和 `localhost:5001 ` 看结果，嗯，都能正常工作。

然后开始修改代码，先去 <http://apps.timwhitlock.info/emoji/tables/unicode> 中搜索到 `dog face` 的emoji unicode。然后打开 `instavote-app/result-app/views/index.html` 文件，找到对应的 `Dogs`  和 `Cats` ，改变为 Unicode 中的对应值。

作为额外的工作，Fernando 把 Dog vote 提高了一倍，然后增加了 `libxml2` 作为更好的xml支持。

然后，`git diff` 检查变更，`git add .` 添加修改，`git checkout -b myfeat` `将当前staging` 修改置于 `myfeat` 分支，然后 `git commit -m “Awesome feature”` 来提交修改，然后 `git push origin my feat` 提交变更。

回到 `github`，然后看到新的分支已经上来了，点击 `Compare & Pull Request`，来提交`PR`。 选择 `target` 为 `staging` 分支，点击提交，好了，完事儿了。好像有些什么`test`在运行，无所谓了，不管了，然后 Fernando 通知了boss，工作做完了。

## Boss (Borja) 过来查看工作，发现测试失败

Borja 回来进一步解释 `test` 是怎么回事。打开 `docker-compose.test.yml`文件，可以看到我们定义了一个特殊的服务，叫做 `sut` - system under test，在这个服务中定义了如何构建、测试整个项目。

打开测试项目，`test.sh` 中，可以看到测试用例试图判断vote是否成功。

解释后回到 `github` 页面，发现测试失败了，Borja 质问为啥这么简单的功能都失败了呢？Fernando说，我还加了增强功能，比如给 dog x2 的vote。boss 显然不同意这种不公平的对待，要求删除这部分代码。

## Fernando 修改代码以满足测试需求

于是 Fernando 回到代码编辑器中，删掉这部分 code，然后重新 `git diff`, `git add .`, `git commit —amend`, `git push —force origin my feat`。然后可以看到`docker cloud` 已经被通知有新的更新，于是开始运行新的测试了。

## Docker Cloud 进行镜像构建并自动部署

`Docker cloud` 可以在公有云或者私有云中运行构建。目前支持 `github` 和 `bitbucket`。

测试通过后，点击 `merge` 合并到 `staging` 分支中。由于所有东西都自动化了，所以会触发 Docker Cloud 进行构建。Docker 会自动构建对应镜像。

在 `Staging` 的 `Service Stack` 中，可以看到 `Result-app` 的 `AutoDeploy` 的状态是 `ON`，说明构建成功会自动进行部署。

Docker Cloud 还集成到了 `Slack` 中，所有构建信息等都会在 `slack` 里看到。可以在 `#dockercloud` channel 中看到测试失败、测试成功、构建镜像、部署等信息。

自动部署成功后，可以通过 Docker Cloud 中提供的 url 访问对应应用连接，直接看到结果。

## 在部署到生产环境前，进行安全检查

在 Docker Cloud 中点击 `repository` → `Result-app` → `Tags` （刷新一下界面）

看到新的 Image 被扫描后，发现了 `libxml2` 存在安全隐患，这是 Fernando 添加的新的依赖。由于这个安全隐患，所以不能部署到生产服务去，必须先解决安全隐患问题。

# 问答

## Q: 我想知道你们是怎么解决密钥、密码类的问题，比如在刚才的例子中，Staging 的服务部署相关的密码必然和生产环境不同，而这些肯定不会放到代码中。那么你们怎么解决这个问题的？

A: 所有的 secret 都存储于 docker cloud，镜像类的东西里面不包含密码类信息，他们应该是独立于云服务商的，在任何云服务商都可以工作。

## Q: 例子中演示的可以添加组织及成员，这些功能什么时候可以GA给大家用？

A: 现在是内部 beta 测试，很快会开放出来。
