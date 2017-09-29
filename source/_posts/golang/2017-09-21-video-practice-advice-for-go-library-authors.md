---
layout: post
category: golang
title: 视频笔记：给 Go 库作者的建议 - Jack Lindamood
date: 2017-09-21
tags: [golang, gophercon2016, youtube, notes]
---

<!-- toc -->

# 视频信息

Practical Advice for Go Library Authors
by Jack Lindamood
at GopherCon 2016

{% owl youtube 5v2fqm_8jYI %}

<https://www.youtube.com/watch?v=5v2fqm_8jYI>

幻灯地址：<http://go-talks.appspot.com/github.com/cep21/go-talks/practical-advice-for-go-library-authors.slide#1>

## 命名

包名是将来使用过程中的一部分，所以避免重复包名和结构与函数。比如

```go
var h client.Client → var h http.Client
```

```go
context.NewContext() => context.Background()
```

## Object Creation

golang 没有构造函数，因此创建对象一般有两种办法

* 默认的`0`值
* 单独的构造函数，`NewSomething()`

推荐使用默认 `0` 值的构造方法

在默认`0`值的情况下，各个方法要处理好`0`值，比如有些东西发现是`0`值后，给入一个默认值。

`New()` 构造函数很灵活，可以做任何事情，因此对于代码阅读上不利，意味着隐藏了很多东西。

有些库使用私有 struct，公开接口的方法，`authImpl struct` and `Auth interface`，这是反模式，不推荐使用。

不推荐使用 **Singleton**，虽然标准库中大量使用了 **Singleton** 模式，但是 Jack 个人不喜欢这种模式。

使用高阶函数作为选项这种形式不推荐：`NewSomething(WithThingA(), WithThingB())`

## 日志

一些日志是直接打印到标准输出去，这是非常不好的设计，因为用户如果想关根本关不了。

建议

* 确定一下作为**库**是不是真的需要打印日志，是不是应该把输出日志的工作交给调用方决定？
* 如果一定需要日志，那么使用回调函数方式
* 输出日志到一个 `interface`
* 不要假定传进来的就是标准库的 `log` ，有很多选择。
* 尊重 `stdout` 和 `stderr`
* 不要使用 `singleton`

## `interface` vs `struct`

接受 `interface` ，但返回的是 `struct`

这点和 Java 不同，Java 更倾向于所有东西都是通过 `interface` 操作。而 golang 不需要，golang 使用的是隐性`interface`。

## 什么时候 panic

最好都不 `panic`。如果非要 `panic`，可能最合适的地方是 `init` 的时候，因为刚一运行就能看到挂了，比较容易处理。但即使如此，也尽量不要 `panic`。

## 检查 error

问：我们是需要检查所有的 `error` 么？比如有些似乎不大容易出错。
答：需要，**特别是你说的这些不大容易出错的！！**

我们用 `error` 代替了 `exception`，所以不要忽略这个东西。

处理的办法

* 最好的办法是 Bubble up，也就是传回调用方
* 但有的时候（比如 **go routine**) 不适合，那就：
	* 做日志
	* 或者增加某个计数器

什么时候应该返回错误比较合适？

* 当不满足约定
* 当需要的答案无法得到

## 允许启用库的调试能力

## 为测试而设计

* 为了方便自己测试
* 为了方便库用户测试

## 并发

### channels

虽然 **channel** 是 golang 一个处理并发很好地东西，但是并非所有场合都需要。比如标准库中就很少有在 API 中使用 `channel` 的。

* 将使用 `channel` 的位置向上层移动。
* 可以使用回调函数。
* 不要混合使用 `mutex` 和 `channel`

### 什么时候发起 `goroutine`

* 有一些库的 `New()` 会发起他们的 `goroutine`，这是不好的。
* 标准库使用的是 `Serve()` 函数。以及对应的 `Close()` 函数
* 将 `goroutine` 向上层推

## 什么时候使用 context.Context

* 所有的阻塞、长时间的操作，都应该可以被 `cancel`
* 由于 `context.Context` 很容易存储东西，所以很容易被滥用。要尽力去避免使用 `Context`
* `Singleton` 和 `context.Value()` 是同样性质的东西，像全局变量一样，对于程序状态来说是个黑箱。

## 其它注意事项

* 如果什么东西很难做，嗯，那就让别人去做吧
* 为了效率而升级
  * **但是**，正确性要比效率重要，在正确性的前提下，注意效率
* 不要在库中使用 `/vendor` （在 `main` 包中可以）
* 注意 **build tag**
* 保持干净
  * 尽量使用*所有的*静态分析工具来检查代码。

