---
layout: post
category: golang
title: 视频笔记：Go 包管理的新时代 - Sam Boyer
date: 2017-10-09
tags: [golang, gophercon2017, youtube, notes]
---

<!-- toc -->

# 视频信息

**The New Era of Go Package Management**
by Sam Boyer
at GopherCon 2017

{% owl youtube 5LtMb090AZI %}


* 视频：<https://www.youtube.com/watch?v=5LtMb090AZI>
* 幻灯：<https://speakerdeck.com/sdboyer/the-new-era-of-go-package-management>
* 博文：<https://about.sourcegraph.com/go/the-new-era-of-go-package-management/>
* 材料：<https://github.com/gophercon/2017-talks/tree/master/samboyer-TheNewEraOfGoPackageManagement>


# 什么包（依赖）管理？

1. 我们写自己的代码
2. 我们开始使用其他人的代码
3. 然后就是痛苦的开端了……😹
    * 开发环境没问题，到了生产环境就出错
    * 开发的时候依赖是一个版本，等构建的时候，上游升级了，就是另一个版本了
    * 有的时候很粗暴的挂了（这是好事儿）
    * 而有的时候暂时没问题，而很久之后才发现是这次升级导致的bug。（这种问题排障就很痛苦）

这就是需要包管理，或者依赖管理（虽然这是两个东西，但是我们这里基本会换着用来表示一个东西）

# pidgin 语言

**pidgin语言** 是指混杂语言，其词汇源头是来自于[洋泾浜英语](https://zh.wikipedia.org/wiki/%E6%B4%8B%E6%B3%BE%E6%B5%9C%E8%8B%B1%E8%AF%AD)，就是早年的租界区之类的中式英语，很多说法都简化了。比如 `pidgin` 实际上是来自于 `business` 这个词，在早年的中国人中，简化为类似于 `皮钦` 这种发音。有些英语的人，误以为是说 `pigeon`。所以也有称 `pidgin` 语言为 `pigeon` 语言的。

后来就用 `pidgin语言` 来描述双方都不懂对方的语言，由于这种情况下无法交流。于是双方会想办法创建或使用一种中间语言，来进行交流。这种语言一般都是简化的版本，而且经常容易出现误解。而且，`pidgin语言` 一般都是过渡期的语言，随着文明交流的深入，这类语言就会被废弃。

虽然该词出现在现代，但是这类的方式出现在很久以前。比如自古以来的丝绸之路，中间经过的国家和文明有太多了，各自都只说自己的语言，于是商人在这条路上走动，要使用很多个应对不同交流的 `pidgin语言`。

Go 的社区里，缺乏一种共同的可以交流的语言，用于共享代码、共享项目。因此这个过程中，诞生了很多用于共享代码的 “pidgin 语言”。而现在，Go 终于要官方支持共享代码的方式了，将来这些 “pidgin 语言" 就会像其它 ”pidgin 语言” 一样被废弃掉。

# 包管理的历史

`GOPATH` 存在的问题：

* `GOPATH` 只允许一个版本
* 没有办法可以重现。因为每个人 `go get` 得到的都是不同的版本，都是当前最新的那个版本。
* 由于依赖无法确定，发布，变得非常没有意义。
* 更新，更加随机性了，因为依赖的版本完全取决于更新是几点钟的那个版本

由于这些问题，产生了很多最佳实践的要求。比如，依赖不应该随意拽进来改变，而必须要通过争取的形式产生；不要轻易的 break API。这类原则在新的管理系统下**依旧适用**。

## 工具的崛起

在这些年间，产生了很多用于依赖管理的工具。有些解决了部分问题，有些是别的工具的一部分。不同的工具对不同的场景有不同的权衡和选择，而且在不同系统下的环境的兼容性也有差异。

* **2013**
  * [Godep](https://github.com/tools/godep)
    * `Godeps/Godeps.json` → `vender/`
  * [gom](https://github.com/mattn/gom): Go Manager - bundle for go
    * 以 Ruby 的 bundler 为原型
    * `Gomfile` → `_vendor/`
* **2014**
  * [glide](https://github.com/Masterminds/glide)：Vendor Package Management for Golang
    * 以 node.js 的 npm/yarn 为原型
    * `glide.yaml`/`glide.lock` → `vendor/`
  * [gopkg.in](http://labix.org/gopkg.in): Stable APIs for the Go language
    * `go get gopkg.in/yaml.v1`
* **2015**
  * [gb](https://getgb.io/): A project based build tool for the Go programming language.
    * `$PROJECT/src/`
    * `$PROJECT/vendor/src/`
  * [govendor](https://github.com/kardianos/govendor): The Vendor Tool for Go
    * `vendor.json` → `vendor/`

## vendor/ 目录

* `Go 1.5`: 添加了 `vendor/` 目录支持，但是默认是关闭的（2015年8月）
  * 所以从这个版本后，`Godep` 可以不用再 `-r` 重写 `import` 了。
* `Go 1.6`: `vendor/` 目录默认启用，但可以关闭（2016年2月）
* `Go 1.7`: `vendor/` 目录永远启用（2016年8月）

当然，这也连带的有嵌套依赖、多重版本的问题。

# go dep

![Moving Gopher](https://github.com/ashleymcnamara/gophers/raw/master/MovingGopher.png)

2016年将 `vendor/` 默认开启后，有了对依赖管理更深入的讨论。大家都认为 Go 官方应该做一个依赖管理工具，但是同时希望避免出现“又一个标准”的情形。

![Another Standard](https://d33wubrfki0l68.cloudfront.net/c67e6c813d332cd436018855e78c5f8d458efd53/02a7a/blog-images/boyer-15.png)

为了避免这种问题，Go 团队的 [Peter Bourgon](https://peter.bourgon.org/) 在 2016 年 5 月的时候，建立了一个委员会，有很多大牛参加，来广泛讨论各方面的问题：

* 争取涵盖现有工具的主要使用场景
* 设计假象工作流，以确保设计具有可扩展性
* 实现一个原型，吸取社区的反馈
* 尽量减少所必须的使用需求，这样可以更广泛的兼容现有工具，并且可以更方便的从现有工具移植

在 2017 年 1 月的时候，Go 团队发布了 `https://github.com/golang/dep`，作为**官方试验**。所有这些都离不开 Go 社区的参与和支持，大量的 Go 开发社区的人都参加进来，讨论、实现、提交修改来完善 `dep`。

## `dep` 基础

* 从其它包管理中借鉴，但是专门为 Go 定制；
* `import` 是老大
* 双文件系统：`Gopkg.toml` 和 `Gopkg.log`
* 面向项目的
* 使用 [SemVer](http://semver.org/lang/zh-CN/) 标签
* `vendor/` 为中心，_基本上_不需要 `GOPATH`

## 三个主要命令

* `dep status`
  * 查看文件依赖状态
  * 是否有需要更新的依赖
  * `vendor/` 目录下是不是缺东西
  * 一些安全问题的检查等等
* `dep init`
  * 和 `npm init` 一样，建立依赖管理的环境
  * 建立 `Gopkg.toml`、`Gopkg.lock` 文件，以及 `vendor/` 目录
  * 并且可以通过其它依赖工具的配置文件、`GOPATH` 内容来猜测所使用的依赖管理方法，并把信息读取，转换为 `dep` 的方式。
    * 目前支持读取 `godep` 和 `glide` 的配置
    * `govendor` 或者 `gb` 的支持在计划中了，还会支持更多的包管理工具
    * 而且大家可以贡献代码支持其它工具，有个框架可以做这件事情，不复杂
* `dep ensure`
  * 这是最主要的命令

## `dep ensure`

`ensure` 的目的就是确保整个依赖系统的一致性。

<https://speakerdeck.com/sdboyer/the-new-era-of-go-package-management?slide=27>

{% mermaid %}
graph LR
  subgraph ""
    Project("项目代码 (imports)") ==> Gopkg.lock
    Gopkg.toml ==> Gopkg.lock
    Gopkg.lock ==> Deps("依赖 (vendor)")
  end
  classDef box fill:#e3f2fd,stroke:#333,stroke-width:2px;
  class Project,Gopkg.lock,Gopkg.toml,Deps box;
{% endmermaid %}

基本逻辑就是：

1. 静态分析项目的文件的 `import` 语句得出所有依赖
2. 根据 `Gopkg.toml` 的内容加上约束
3. 确保约束和 `Gopkg.lock` 的锁定版本一致
4. 最后确保 `vendor/` 目录下的内容和 `Gopkg.lock` 的要求一致（有且仅有）

* 这一步确保同步 `Gopkg.lock` 和 `vendor/` 还不太健全，但是正在努力完善
* 但是现在可以很好地提示说 `Gopkg.lock` 和 `vendor` 不一致
* 这种 `sync-based` 模型 npm 现在也开始在用了

为了庆祝这个 `dep` 项目，还专门请 [Ashley McNamara](http://www.ashleymcnamara.com/) 画了一个 Avatar：

![Moving Gopher](https://github.com/ashleymcnamara/gophers/raw/master/NERDY.png)

## 进入工具链

现在 `dep` 是一个独立工具，但是肯定不会一直如此，最终的目的是要被集成到 `go` 的工具中去。这也是为什么将现在的项目，称其为 **官方试验** 的原因。

现在的项目不是终点。将来在集成到 `go` 工具链的时候，会精心的分析和迁移现有的 `dep` 工具的特性。

所以，`dep` 和最终集成到 `go` 工具链上后不一定会一一对应，可能对应也可能不对应。比如 `dep ensure` 或许就会不存在，而直接集成到其它工作流中了，比如 `go list`、`go run`、`go build` 之类的里面去了。

所以 `dep` 是未来的一块基石，希望将来在集成到 `go` 工具链后，`dep` 就可以渐渐退出舞台了。

仅仅是 Go Team 做这件事情已经比较难了，而现在更大的问题是将第一次大规模的接纳社区大量的代码进入 Go 核心。

将来的工具链依旧会继承今天 `dep` 里面的特性：

* 双文件系统
* `import` 为王
* 依旧是基于同步
* SemVer 标签
* `vendor/`（_或类似的_）
  * 将来 `vendor` 很可能会改变，现在还在讨论中
  * 可能会使用第三个位置，而不在项目目录里
  * 但是和 `GOPATH` 不同的是，这次有版本信息
  * 这样将来可能就不需要项目里存在 `vendor/` 目录，所有需要的信息从文件读取后，直接去第三个位置获取特定版本的包（这点就更像 npm 的 `node_modules` ，但是不局限于某个项目）

## TODOs

* 多项目的工作流
  * 第三个位置存放依赖可以解决部分这类问题
* SemVer 的建议工具
  * 像 `elm-package` 那样
* 包注册中心，(像 npm 那种，但是是可选的)
* 编辑器集成方式
* 安全模型
* 性能！
* 更好的错误反馈
* 私有库/企业环境的使用方式

## TODOs for Developers

* 请务必用 SemVer tag 你的项目
  * 将来可能会根据 API 变化情况来建议下一个 SemVer 的版本是什么。
  * Dave Cheney 写了一篇博客希望大家都使用 SemVer：<https://dave.cheney.net/2016/06/24/gophers-please-tag-your-releases>

* 转换项目依赖工具到 `dep`（是的，现在已经可以用了！）
  * `Gopkg.toml` 和 `Gopkg.lock` 格式已经稳定，2个月前就固定下来了
  * 但是命令以及参数可能还会改变，所以建议暂时不要写脚本来依赖命令格式
* 有时间来 `dep` 贡献你的力量（我们**超级友善**！）
* 第二天有 Hackathon，一定要来。
* 跟踪最新进展，请查看 <https://sdboyer.io/dep-status/>
