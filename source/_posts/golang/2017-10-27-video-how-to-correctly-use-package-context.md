---
layout: post
category: golang
title: 视频笔记：如何正确使用 Context - Jack Lindamood
date: 2017-10-27
tags: [golang, golang-uk-2017, youtube, notes]
---

<!-- toc -->

# 视频信息

**How to correctly use package context**
by Jack Lindamood
at Golang UK Conf. 2017

{% owl youtube -_B5uQ4UGi0 %}

* 视频：<https://www.youtube.com/watch?v=-_B5uQ4UGi0>
* 博文：<https://medium.com/@cep21/how-to-correctly-use-context-context-in-go-1-7-8f2c0fafdf39>


# 自我介绍

Jack Lindamood [Github: @cep21](https://github.com/cep21), [Medium: @cep21](https://medium.com/@cep21)， email: cep221 at gmail.com

* 已经写了 4 年 Go 了
* 目前是 Twitch 的软件工程师
* Twitch 的主要后端都是用 Go 写的
* 有几百个项目 repo

# 为什么需要 `Context`

* 每一个**长请求**都应该有个_超时限制_
* 需要在调用中传递这个超时
  * 比如开始处理请求的时候我们说是 3 秒钟超时
  * 那么在函数调用中间，这个超时还剩多少时间了？
  * 需要在什么地方存储这个信息，这样请求处理中间可以停止

如果进一步考虑。

![rpc fails](../pics/golang/context/rpc-fails-1.svg)

如上图这样的 RPC 调用，开始调用 `RPC 1` 后，里面分别调用了 `RPC 2`, `RPC 3`, `RPC 4`，等所有 RPC 调用成功后，返回结果。

这是正常的方式，但是如果 `RPC 2` 调用失败了会发生什么？

![rpc fails](../pics/golang/context/rpc-fails-2.svg)

`RPC 2` 失败后，如果没有 Context 的存在，那么我们可能依旧会等所有的 RPC 执行完毕，但是由于 `RPC 2` 失败了，所以其实其它的 RPC 结果意义不大了，我们依旧需要给用户返回错误。因此我们白白的浪费了 10ms，完全没必要去等待其它 RPC 执行完毕。

那如果我们在 `RPC 2` 失败后，就直接给用户返回失败呢？

![rpc fails](../pics/golang/context/rpc-fails-3.svg)

用户是在 30ms 的位置收到了错误消息，可是 `RPC 3` 和 `RPC 4` 依然在没意义的运行，还在浪费计算和IO资源。

![rpc fails](../pics/golang/context/rpc-fails-4.svg)

所以理想状态应该是如上图，当 `RPC 2` 出错后，除了返回用户错误信息外，我们也应该有某种方式可以通知 `RPC 3` 和 `RPC 4`，让他们也停止运行，不再浪费资源。

所以解决方案就是：

* 用信号的方式来通知请求该停了
* 包含一些关于什么时间请求可能会结束的提示（超时）
* 用 channel 来通知请求结束了

那干脆让我们把变量也扔那吧。😈

* 在 Go 中没有线程/go routine 变量
  * 其实挺合理的，因为这样就会让 goroutine 互相产生依赖
* _非常容易被滥用_

# `Context` 实现细节

`context.Context`：

* 是不可变的(immutable)树节点
* Cancel 一个节点，会连带 Cancel 其所有子节点 （_从上到下_）
* Context values 是一个节点
* Value 查找是回溯树的方式 （_从下到上_）

## 示例 `Context` 链

```go
package main

func tree() {
  ctx1 := context.Background()
  ctx2, _ := context.WithCancel(ctx1)
  ctx3, _ := context.WithTimeout(ctx2, time.Second * 5)
  ctx4, _ := context.WithTimeout(ctx3, time.Second * 3)
  ctx5, _ := context.WithTimeout(ctx5, time.Second * 6)
  ctx6 := context.WithValue(ctx5, "userID", 12)
}
```

如果这样构成的 `Context` 链，其形如下图：

![context chain](../pics/golang/context/context-chain-1.svg)

那么当 3 秒超时到了时候：

![context chain](../pics/golang/context/context-chain-2.svg)

可以看到 `ctx4` 超时退出了。

当 5秒钟 超时到达时：

![context chain](../pics/golang/context/context-chain-3.svg)

可以看到，不仅仅 `ctx3` 退出了，其所有子节点，比如 `ctx5` 和 `ctx6` 也都退出了。

## `context.Context` API

基本上是两类操作：

* 3个函数用于_限定什么时候你的子节点退出_；
* 1个函数用于_设置请求范畴的变量_

```go
type Context interface {
  //  啥时候退出
  Deadline() (deadline time.Time, ok bool)
  Done() <-chan struct{}
  Err() error
  //  设置变量
  Value(key interface{}) interface{}
}
```

## 什么时候应该使用 `Context`？

* 每一个 RPC 调用都应该有_超时退出_的能力，这是比较合理的 API 设计
* _不仅仅_ 是超时，你还需要有能力去结束那些不再需要操作的行为
* `context.Context` 是 Go 标准的解决方案
* 任何函数可能被阻塞，或者需要很长时间来完成的，都应该有个 `context.Context`

## 如何创建 `Context`？

* 在 RPC 开始的时候，使用 `context.Background()`
  * 有些人把在 `main()` 里记录一个 `context.Background()`，然后把这个放到服务器的某个变量里，然后请求来了后从这个变量里继承 context。这么做是**不对的**。直接每个请求，源自自己的 `context.Background()` 即可。
* 如果你没有 context，却需要调用一个 context 的函数的话，用 `context.TODO()`
* 如果某步操作需要自己的超时设置的话，给它一个独立的 sub-context（如前面的例子）

## 如何集成到 API 里？

* 如果有 Context，**将其作为第一个变量**。
  * 如 `func (d* Dialer) DialContext(ctx context.Context, network, address string) (Conn, error)`
  * 有些人把 context 放到中间的某个变量里去，这很不合习惯，不要那么做，放到第一个去。
* 将其作为**可选的**方式，用 `request` 结构体方式。
  * 如：`func (r *Request) WithContext(ctx context.Context) *Request`
* Context 的变量名请用 `ctx`（不要起一些诡异的名字😓）

## `Context` 放哪？

* 把 `Context` 想象为一条河流流过你的程序（另一个意思就是说不要喝河里的水……🙊）
* 理想情况下，`Context` 存在于调用栈（Call Stack） 中
* 不要把 `Context` 存储到一个 `struct` 里
  * 除非你使用的是像 `http.Request` 中的 `request` 结构体的方式
* `request` 结构体应该以 Request 结束为生命终止
* 当 RPC 请求处理结束后，应该去掉对 Context 变量的引用（Unreference）
* Request 结束，Context 就应该结束。（这俩是一对儿，不求同年同月同日生，但求同年同月同日死……💕）

## `Context` 包的注意事项

* 要养成关闭 Context 的习惯
  * _特别是_ 超时的 Contexts
* 如果一个 context 被 GC 而不是 cancel 了，那一般是你做错了

```go
ctx, cancel := context.WithTimeout(parentCtx, time.Second * 2)
defer cancel()
```

* 使用 Timeout 会导致内部使用 `time.AfterFunc`，从而会导致 context 在计时器到时之前都不会被垃圾回收。
* 在建立之后，立即 `defer cancel()` 是一个好习惯。

## 终止请求 (Request Cancellation)

当你不再关心接下来获取的结果的时候，有可能会 Cancel 一个 Context？

以 `golang.org/x/sync/errgroup` 为例，`errgroup` 使用 Context 来提供 RPC 的终止行为。

```go
type Group struct {
	cancel  func()
	wg      sync.WaitGroup
	errOnce sync.Once
	err     error
}
```

创建一个 `group` 和 `context`：

```go
func WithContext(ctx context.Context) (*Group, context.Context) {
  ctx, cancel := context.WithCancel(ctx)
  return &Group{cancel: cancel}, ctx
}
```

这样就返回了一个可以被提前 cancel 的 `group`。

而调用的时候，并不是直接调用 `go func()`，而是调用 `Go()`，将函数作为参数传进去，用高阶函数的形式来调用，其内部才是 `go func()` 开启 goroutine。

```go
func (g *Group) Go(f func() error) {
  g.wg.Add(1)
  go func() {
    defer g.wg.Done()
    if err := f(); err != nil {
      g.errOnce.Do(func() {
        g.err = err
        if g.cancel != nil {
          g.cancel()
        }
      })
    }
  }()
}
```

当给入函数 `f` 返回错误，则使用 `sync.Once` 来 cancel `context`，而错误被保存于 `g.err` 之中，在随后的 `Wait()` 函数中返回。

```go
func (g *Group) Wait() error {
  g.wg.Wait()
  if g.cancel != nil {
    g.cancel()
  }
  return g.err
}
```

注意：这里在 `Wait()` 结束后，调用了一次 `cancel()`。

```go
package main

func DoTwoRequestsAtOnce(ctx context.Context) error {
  eg, egCtx := errgroup.WithContext(ctx)
  var resp1, resp2 *http.Response
  f := func(loc string, respIn **http.Response) func() error {
    return func() error {
      reqCtx, cancel := context.WithTimeout(egCtx, time.Second)
      defer cancel()
      req, _ := http.NewRequest("GET", loc, nil)
      var err error
      *resp, err = http.DefaultClient.Do(req.WithContext(reqCtx))
      if err == nil && (*respIn).StatusCode >= 500 {
        return errors.New("unexpected!")
      }
      return err
    }
  }

  eg.Go(f("http://localhost:8080/fast_request", &resp1))
  eg.Go(f("http://localhost:8080/slow_request", &resp2))

  return eg.Wait()
}
```

在这个例子中，同时发起了两个 RPC 调用，当任何一个调用超时或者出错后，会终止另一个 RPC 调用。这里就是利用前面讲到的 `errgroup` 来实现的，应对有很多并非请求，并需要集中处理超时、出错终止其它并发任务的时候，这个 pattern 使用起来很方便。

## `Context.Value` - Request 范畴的值

### `context.Value` API 的万金油（duct tape)

胶带（duct tape) 几乎可以修任何东西，从破箱子，到人的伤口，到汽车引擎，甚至到NASA登月任务中的阿波罗13号飞船（Yeah! True Story)。所以在西方文化里，胶带是个“万能”的东西。在中文里，恐怕万金油是更合适的对应词汇，从头疼、脑热，感冒发烧，到跌打损伤几乎无所不治。

当然，_治标不治本_，这点东西方文化中的潜台词都是一样的。这里提及的 `context.Value` 对于 API 而言，就是这类性质的东西，啥都可以干，但是治标不治本。

* `value` 节点是 Context 链中的一个节点

```go
package context

type valueCtx struct {
  Context
  key, val interface{}
}

func WithValue(parent Context, key, val interface{}) Context {
  //  ...
  return &valueCtx{parent, key, val}
}

func (c *valueCtx) Value(key interface{}) interface{} {
  if c.key == key {
    return c.val
  }
  return c.Context.Value(key)
}
```

可以看到，`WithValue()` 实际上就是在 Context 树形结构中，增加一个节点罢了。

Context 是 immutable 的。

### 约束 key 的空间

为了防止树形结构中出现重复的键，建议约束键的空间。比如使用私有类型，然后用 `GetXxx()` 和 `WithXxxx()` 来操作私有实体。

```go
type privateCtxType string

var (
  reqID = privateCtxType("req-id")
)

func GetRequestID(ctx context.Context) (int, bool) {
  id, exists := ctx.Value(reqID).(int)
  return id, exists
}

func WithRequestID(ctx context.Context, reqid int) context.Context {
  return context.WithValue(ctx, reqID, reqid)
}
```

这里使用 `WithXxx` 而不是 `SetXxx` 也是因为 Context 实际上是 immutable 的，所以不是修改 Context 里某个值，而是产生新的 Context _带某个值_。

### `Context.Value` 是 immutable 的

再多次的强调 `Context.Value` 是 **immutable** 的也不过分。

* `context.Context` 从设计上就是按照 immutable （不可变的）模式设计的
* 同样，`Context.Value` 也是 immutable 的
* 不要试图在 `Context.Value` 里存某个可变更的值，然后改变，期望别的 Context 可以看到这个改变
  * 更别指望着在 `Context.Value` 里存可变的值，最后多个 goroutine 并发访问没竞争冒险啥的，因为自始至终，就是按照不可变来设计的
  * 比如设置了超时，就别以为可以改变这个设置的超时值
* 在使用 `Context.Value` 的时候，一定要记住这一点

### 应该把什么放到 `Context.Value` 里？

* 应该保存 Request 范畴的值
  * 任何关于 Context 自身的都是 Request 范畴的（这俩同生共死）
  * 从 Request 数据衍生出来，并且随着 Request 的结束而终结

#### 什么东西不属于 Request 范畴？

* 在 Request 以外建立的，并且不随着 Request 改变而变化
  * 比如你 `func main()` 里建立的东西显然不属于 Request 范畴
* 数据库连接
  * 如果 `User ID` 在连接里呢？(稍后会提及)
* 全局 `logger`
  * 如果 `logger` 里需要有 `User ID` 呢？（稍后会提及）

### 那么用 `Context.Value` 有什么问题？

* 不幸的是，好像所有东西都是由请求衍生出来的
* 那么我们为什么还需要函数参数？然后干脆只来一个 Context 就完了？

```go
func Add(ctx context.Context) int {
  return ctx.Value("first").(int) + ctx.Value("second").(int)
}
```

曾经看到过一个 API，就是这种形式：

```go
func IsAdminUser(ctx context.Context) bool {
  userID := GetUser(ctx)
  return authSingleton.IsAdmin(userID)
}
```

这里API实现内部从 `context` 中取得 `UserID`，然后再进行权限判断。但是从函数签名看，则完全无法理解这个函数具体需要什么、以及做什么。

> 代码要以可读性为优先设计考虑。

别人拿到一个代码，一般不是掉进函数实现细节里去一行行的读代码，而是会先浏览一下函数接口。所以清晰的函数接口设计，会更加利于别人（_或者是几个月后的你自己_）理解这段代码。

一个良好的 API 设计，应该从函数签名就清晰的理解函数的逻辑。如果我们将上面的接口改为：

```go
func IsAdminUser(ctx context.Context, userID string, authenticator auth.Service) bool
```

我们从这个函数签名就可以清楚的知道：

* 这个函数很可能可以提前被 cancel
* 这个函数需要 `User ID`
* 这个函数需要一个`authenticator`来
* 而且由于 `authenticator` 是传入参数，而不是依赖于隐式的某个东西，我们知道，测试的时候就很容易传入一个模拟认证函数来做测试
* `userID` 是传入值，因此我们可以修改它，不用担心影响别的东西

所有这些信息，都是从函数签名得到的，而无需打开函数实现一行行去看。

### 那什么可以放到 `Context.Value` 里去？

现在知道 `Context.Value` 会让接口定义更加模糊，似乎不应该使用。那么又回到了原来的问题，到底什么可以放到 `Context.Value` 里去？换个角度去想，什么不是衍生于 Request？

* `Context.Value` 应该是告知性质的东西，而不是控制性质的东西
* 应该永远都不需要写进文档作为必须存在的输入数据
* 如果你发现你的函数在某些 `Context.Value` 下无法正确工作，那就说明这个 `Context.Value` 里的信息不应该放在里面，而应该放在接口上。因为已经让接口太模糊了。

#### 什么东西不是控制性质的东西？

* Request ID
  * 只是给每个 RPC 调用一个 ID，而没有实际意义
  * 这就是个数字/字符串，反正你也不会用其作为逻辑判断
  * 一般也就是日志的时候需要记录一下
    * 而 `logger` 本身不是 Request 范畴，所以 `logger` 不应该在 `Context` 里
    * 非 Request 范畴的 `logger` 应该只是利用 `Context` 信息来修饰日志
* User ID （如果仅仅是作为日志用）
* Incoming Request ID

#### 什么显然是控制性质的东西？

* 数据库连接
  * 显然会非常严重的影响逻辑
  * 因此这应该在函数参数里，明确表示出来
* 认证服务(Authentication)
  * 显然不同的认证服务导致的逻辑不同
  * 也应该放到函数参数里，明确表示出来

### 例子

#### 调试性质的 `Context.Value` - `net/http/httptrace`

* <https://medium.com/@cep21/go-1-7-httptrace-and-context-debug-patterns-608ae887224a>

```go
package main

func trace(req *http.Request, c *http.Client) {
  trace := &httptrace.ClientTrace{
    GotConn: func(connInfo httptrace.GotConnInfo) {
      fmt.Println("Got Conn")
    },
    ConnectStart: func(network, addr string) {
      fmt.Println("Dial Start")
    },
    ConnectDone: func(network, addr string, err error) {
      fmt.Println("Dial done")
    },
  }
  req = req.WithContext(httptrace.WithClientTrace(req.Context(), trace))
  c.Do(req)
}
```

##### `net/http` 是怎么使用 `httptrace` 的？

* 如果有 `trace` 存在的话，就执行 `trace` 回调函数
* 这只是**告知性质**，而不是**控制性质**
  * `http` 不会因为存在 `trace` 与否就有不同的执行逻辑
  * 这里只是告知 API 的用户，帮助用户记录日志或者调试
  * 因此这里的 `trace` 是存在于 Context 里的

```go
package http

func (req *Request) write(w io.Writer, usingProxy bool, extraHeaders Header, waitForContinue func() bool) (err error) {
  //  ...
  trace := httptrace.ContextClientTrace(req.Context())
  //  ...
  if trace != nil && trace.WroteHeaders != nil {
    trace.WroteHeaders()
  }
}
```

#### 回避依赖注入 - `github.com/golang/oauth2`

* 这里比较诡异，使用 `ctx.Value` 来定位依赖
* **不推荐这样做**
  * 这里这样做基本上只是为了满足测试需求

```go
package main

import "github.com/golang/oauth2"

func oauth() {
  c := &http.Client{Transport: &mockTransport{}}
  ctx := context.WithValue(context.Background(), oauth2.HTTPClient, c)
  conf := &oauth2.Config{ /* ... */ }
  conf.Exchange(ctx, "code")
}
```

### 人们滥用 `Context.Value` 的原因

* 中间件的抽象
* 很深的函数调用栈
* 混乱的设计

> `context.Value` 并没有让你的 API 更简洁，那是假象，相反，它让你的 API 定义更加模糊。

## 总结 `Context.Value`

* 对于调试非常方便
* 将必须的信息放入 `Context.Value` 中，会让接口定义更加不透明
* 如果可以尽量明确定义在接口
* 尽量不要用 `Context.Value`

# 总结 `Context`

* 所有的长的、阻塞的操作都需要 `Context`
* `errgroup` 是构架于 `Context` 之上很好的抽象
* 当 Request 的结束的时候，Cancel `Context`
* `Context.Value` 应该被用于**告知性质**的事物，而不是**控制性质**的事物
* 约束 `Context.Value` 的键空间
* `Context` 以及 `Context.Value` 应该是不可变的（immutable），并且应该是线程安全
* `Context` 应该随 `Request` 消亡而消亡

# Q&A

## 数据库的访问也用 Context 么？

之前说过长时间、可阻塞的操作都用 Context，数据库操作也是如此。不过对于超时 Cancel 操作来说，一般不会对写操作进行 cancel；但是对于读操作，一般会有 Cancel 操作。
