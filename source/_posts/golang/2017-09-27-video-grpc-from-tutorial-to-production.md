---
layout: post
category: golang
title: 视频笔记：gRPC 从学习到生产 - Alan Shreve
date: 2017-09-23
tags: [golang, gophercon2017, youtube, notes]
---

<!-- toc -->

# 视频信息

**grpc: From Tutorial to Production**
by Alan Shreve
at GopherCon 2017

{% owl youtube 7FZ6ZyzGex0 %}

<https://www.youtube.com/watch?v=7FZ6ZyzGex0>

博文：<https://about.sourcegraph.com/go/grpc-in-production-alan-shreve/>

## 演讲者

Alan Shreve, <https://ngrok.com> & <https://equinox.io>
Github: [@inconshreveable](https://github.com/inconshreveable) & Twitter: [@inconshreveable](https://twitter.com/inconshreveable?lang=en)

## 微服务之间应该如何通讯？

答案就是：**[SOAP](https://en.wikipedia.org/wiki/SOAP)**……好吧，开个玩笑，当然不可能是 SOAP 了。

现在流行的做法是 **HTTP + JSON ([REST API](https://en.wikipedia.org/wiki/Representational_state_transfer))**

Alan 说“如果这辈子再也不写另一个 REST 客户端库的话，那就可以很幸福的死去了……😂”，因为这是最无聊的事情，一遍一遍的在做同样的事情。

## 为什么 REST API 不好用？

* 实现 Stream 太难了
* 而双向的流就根本不可能
* 很难对操作建立模型
* 效率很差，文本表示对于网络来说并不是最好的选择
* 而且，其实服务内部根本不是 RESTful 的方式，这只是 HTTP endpoint
* 很难在一个请求中取得多个资源数据 （反例看 [GraphQL](http://graphql.org/learn/)）
* 没有**正式的**（机器可读的）API约束
  * 因此写客户端需要人类
    * 而且因为👷很贵，而且不喜欢写客户端

## 什么是 gRPC

> [gPRC](https://grpc.io) 是高性能、开源、通用的 RPC 框架。

与其讲解定义，不如来实际做个东西更清楚。

## 建一个缓存服务

使用 gRPC 这类东西，我们并非开始于写 Go 代码，我们是从撰写 gRPC 的 [IDL](https://developers.google.com/protocol-buffers/docs/overview) 开始的。

### app.proto

```protobuf
syntax = "proto3"
package rpc;

service Cache {
  rpc Store(StoreReq) returns (StoreResp) {}
  rpc Get(GetReq) returns (GetResp) {}
}

message StoreReq {
  string key = 1;
  bytes val = 2;
}

message StoreResp {
}

message GetReq {
  string key = 1;
}

message GetResp {
  bytes val = 1;
}
```

当写了这个文件后，我们立刻拥有了**9**种语言的客户端的库。

* C++
* Java(and Android)
* Python
* Go
* Ruby
* C#
* Javascript(node.js)
* Objective-C (iOS!)
* PHP

同时，我们也拥有了**7**种语言的服务端的 API Stub：

* C++
* Java
* Python
* Go
* Ruby
* C#
* Javascript(node.js)

### server.go

```go
func serverMain() {
  if err := runServer(); err != nil {
    fmt.Fprintf(os.Stderr, "Failed to run cache server: %s\n", err)
    os.Exit(1)
  }
}

func runServer() error {
  srv := grpc.NewServer()
  rpc.RegisterCacheServer(srv, &CacheService{})
  l, err := net.Listen("tcp", "localhost:5051")
  if err != nil {
    return err
  }
  //  block
  return srv.Serve(l)
}
```

暂时先不实现 `CacheService`，先放个空的，稍后再实现。

```go
type CacheService struct {
}

func (s *CacheService) Get(ctx context.Context, req *rpc.GetReq) (*rpc.GetResp, error) {
  return nil, fmt.Errorf("unimplemented")
}

func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  return nil, fmt.Errorf("unimplemented")
}
```

### client.go

```go
func clientMain() {
  if err != runClient(); err != nil {
    fmt.Fprintf(os.Stderr, "failed: %v\n", err)
    os.Exit(1)
  }
}

func runClient() error {
  //  建立连接
  conn, err := grpc.Dial("localhost:5053", grpc.WithInsecure())
  if err != nil {
    return fmt.Errorf("failed to dial server: %v", err)
  }
  cache := rpc.NewCacheClient(conn)
  //  调用 grpc 的 store() 方法存储键值对 { "gopher": "con" }
  _, err = cache.Store(context.Background(), &rpc.StoreReq{Key: "gopher", Val: []byte("con")})
  if err != nil {
    return fmt.Errorf("failed to store: %v", err)
  }
  //  调用 grpc 的 get() 方法取回键为 `gopher` 的值
  resp, err := cache.Get(context.Background(), &rpc.GetReq{Key: "gopher"})
  if err != nil {
    return fmt.Errorf("failed to get: %v", err)
  }
  //  输出
  fmt.Printf("Got cached value %s\n", resp.Val)
  return nil
}
```
### 这不就是 WSDL 么？

或许有些人会认为这和 [WSDL](https://en.wikipedia.org/wiki/Web_Services_Description_Language) 也太像了，这么想没有错，因为 gRPC 在借鉴之前的 SOAP/WSDL 的错误基础上，也吸取了他们优秀的地方。

* 和 XML 关系没那么紧(grpc 是可插拔式的，可以换成各种底层表述)
* 写过 XML/XSD 的人都知道这些服务定义太繁重了，gRPC 没有这个问题
* WSDL这类有完全不必要的复杂度、和基本不需要的功能（两步 commit）
* WSDL 不灵活、而且无法前向兼容（不像 [protobuf](https://developers.google.com/protocol-buffers/)）
* SOAP/WSDL 性能太差，以及无法使用流
* 但是WSDL中的机器可以理解的API定义确实是个好东西

### 实现具体的 CacheService

**server.go**

```go
type CacheService struct {
  store map[string][]byte
}

func (s *CacheService) Get(ctx context.Context, req *rpc.GetReq) (*rpc.GetResp, error) {
  val := s.store[req.Key]
  return &rpc.GetResp{Val: val}, nil
}

func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  s.store[req.Key] = req.Val
  return &rpc.StoreResp{}, nil
}
```

注意这里没有锁，你可以想想他们中有，因为将来他们会被并发的调用的。

### 错误处理

当然，gRPC 支持错误处理。假设改写上面的 `Get()`，对不存在的键进行报错：

```go
func (s *CacheService) Get(ctx context.Context, req *rpc.GetReq) (*rpc.GetResp, error) {
  val, ok := s.store[req.Key]
  if !ok {
    return nil, status.Errorf(code.NotFound, "Key not found %s", req.Key)
  }
  return &rpc.GetResp{Val: val}, nil
}
```

### 加密传输

如果这样的代码打算去部署的话，一定会被 [SRE](https://en.wikipedia.org/wiki/Site_reliability_engineering) 拦截下来，因为所有通讯必须加密传输。

在 gRPC 中添加 TLS 加密传输很容易。比如我们修改 `runServer()` 添加 TLS 加密传输。

```go
func runServer() error {
  tlsCreds, err := credentials.NewServerTLSFromFile("tls.crt", "tls.key")
  if err != nil {
    return err
  }
  srv := grpc.NewServer(grpc.Creds(tlsCreds))
  ...
}
```

同样，我们也需要修改一下 `runClient()`。

```go
func runClient() error {
  tlsCreds := credentials.NewTLS(&tls.Config(InsecureSkipVerify: true))
  conn, err := grpc.Dial("localhost:5051", grpc.WithTransportCredentials(tlsCreds))
  ...
}
```

## 生产环境如何使用 gRPC

* HTTP/2
* protobuf serialization (pluggable)
* 客户端会和 grpc 服务器打开一个长连接
  * 对于每一个 RPC 调用都将是一个新的 HTTP/2 stream
  * 允许模拟飞行模式的 RPC 调用
* 允许客户端*和*服务端 Streaming

### gRPC 的实现

现在有3个高性能的、事件驱动的实现

* C
  * Ruby, Python, Node.js, PHP, C#, Objective-C, C++ 都是对这个 C core 实现的绑定
  * PHP 则是通过 PECL 和这个实现的绑定
* Java
  * Netty + BoringSSL 通过 JNI
* Go
  * 纯 Go 实现，使用了 Go 标准库的 `crypto/tls`

### gRPC 从哪来的

* 最初是 Google 的一个团队创建的
* 更早期的是 Google 一个内部项目叫做 `stubby`
* 这个 gRPC 是其下一代开源项目，并且现在不仅仅是 Google 在使用，很多公司都在贡献代码
  * 当然，Google 还是主要代码贡献者

### 生产环境案例：多租户

上线生产后，发现有一部分客户产生了大量的键值，询问得知，有的客户希望对所有东西都缓存，这显然不是对我们这个缓存服务很好的事情。

我们希望限制这种行为，但对于当前系统而言，无法满足这种需求，因此我们需要修改实现，对每个客户发放客户 token，那么我们就可以约束特定客户最多可以建立多少键值，避免系统滥用。这就成为了多租户的缓存服务。

和之前一样，我们还是从 IDL 开始，我们需要修改接口，增加 `account_token` 项。

```protobuf
message StoreReq {
  string key = 1;
  bytes val = 2;
  string account_token = 3;
}
```

同样，我们需要有独立的服务针对账户服务，来获取账户所允许的缓存键数：

```protobuf
service Accounts {
  rpc GetByToken(GetByTokenReq) return (GetByTokenResp) {}
}

message GetByTokenReq {
  string token = 1;
}

message GetByTokenResp {
  Account account = 1;
}

message Account {
  int64 max_cache_keys = 1;
}
```

这里建立了一个新的 `Accounts` 服务，并且有一个 `GetByToken()` 方法，给入 `token`，返回一个 `Account` 类型的结果，而 `Account` 内有 `max_cache_keys` 键对应最大可缓存的键值数。

现在我们进一步修改 **client.go**

```go
func runClient() error {
  ...
  cache := rpc.NewCacheClient(conn)

  _, err = cache.Store(context.Background(), &rpc.StoreReq{
    AccountToken: "inconshreveable",
    Key:          "gopher",
    Val:          []byte("con"),
  })
  if err != nil {
    return fmt.Errorf("failed to store: %v", err)
  }
  ...
}
```

服务端的改变要稍微大一些，但不过分。

```go
type CacheService struct {
  accounts      rpc.AccountsClient
  store         map[string][]byte
  keysByAccount map[string]int64
}
```

注意这里的 `accounts` 是一个 grpc 的客户端，因为我们这个服务，同时也是另一个 grpc 服务的客户端。所以在接下来的 `Store()` 实现中，我们需要先通过 `accounts` 调用另一个服务取得账户信息。

```go
func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  //  调用另一个服务取得账户信息，包含其键值限制
  resp, err := s.accounts.GetByToken(context.Background(), &rpc.GetByTokenReq{
    Token: req.AccountToken,
  })
  if err != nil {
    return nil, err
  }
  //  检查是否超量使用
  if s.keysByAccount[req.AccountToken] >= resp.Account.MaxCacheKeys {
    return nil, status.Errorf(codes.FailedPrecondition, "Account %s exceeds max key limit %d", req.AccountToken, resp.Account.MaxCacheKeys)
  }
  //  如果键不存在，需要新加键值，那么我们就对计数器加一
  if _, ok := s.store[req.Key]; !ok {
    s.keysByAccount[req.AccountToken] += 1
  }
  //  保存键值
  s.store[req.Key] = req.Val
  return &rpc.StoreResp{}, nil
}

```

### 生产环境案例：性能

上面的问题解决了，我们服务又恢复了正常，不会有用户建立过多的键值了。但是很快，我们就又收到了其他用户发来的新的 issue，很多人反应说新系统变慢了，没有达到 [SLA](https://en.wikipedia.org/wiki/Service-level_agreement) 的要求。

可是我们根本不知道到底发生了什么，于是意识到了，我们的程序没有任何可观察性（Observability），换句话说，我们的程序没有任何计量系统来统计性能相关的数据。

我们先从最简单的做起，添加日志。

我们先从 **client.go** 开始，增加一些测量和计数以及日志输出。

```go
  ...
  //  开始计时
  start := time.Now()

  _, err = cache.Store(context.Background(), &rpc.StoreReq{
    AccountToken: "inconshreveable",
    Key:          "gopher",
    Val:          []byte("con"),
  })

  //  计算 cache.Store() 调用时间
  log.Printf("cache.Store duration %s", time.Since(start))

  if err != nil {
    return fmt.Errorf("failed to store: %v", err)
  }

  //  再次开始计时
  start = time.Now()

  //  调用 grpc 的 get() 方法取回键为 `gopher` 的值
  resp, err := cache.Get(context.Background(), &rpc.GetReq{Key: "gopher"})

  //  计算 cache.Get() 调用时间
  log.Printf("cache.Get duration %s", time.Since(start))

  if err != nil {
    return fmt.Errorf("failed to get: %v", err)
  }
```

同样，在服务端也这么处理。

```go
func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  //  开始计时
  start := time.Now()

  //  调用另一个服务取得账户信息，包含其键值限制
  resp, err := s.accounts.GetByToken(context.Background(), &rpc.GetByTokenReq{
    Token: req.AccountToken,
  })

  //  输出 account.GetByToken() 的调用时间
  log.Printf("accounts.GetByToken duration %s", time.Since(start))

  ...
}
```

经过这些修改后，我们发现一样的事情在反反复复的做，那么有什么办法可以改变这种无聊的做法么？查阅 grpc 文档后，看到有一个叫做 **Client Interceptor** 的东西。

这相当于是一个中间件，但是是在客户端。当客户端进行 rpc 调用的时候，这个中间件先会被调用，因此这个中间件可以对调用进行一层包装，然后再进行调用。

为了实现这个功能，我们创建一个新的文件，叫做 `interceptor.go`：

```go
func WithClientInterceptor() grpc.DialOption {
  return grpc.WithUnaryInterceptor(clientInterceptor)
}

func clientInterceptor(
  ctx context.Context,
  method string,
  req interface{},
  reply interface{},
  cc *grpc.ClientConn,
  invoker grpc.UnaryInvoker,
  opts ...grpc.CallOption,
) error {
  start := time.Now()
  err := invoker(ctx, method, req, reply, cc, opts...)
  log.Printf("invoke remote method=%s duration=%s error=%v", method, time.Since(start), err)
  return err
}
```

我们有了这个 `WithClientInterceptor()` 之后，可以在 `grpc.Dial()` 的时候注册进去。

**client.go**

```go
func runClient() error {
  ...
  conn, err := grpc.Dial("localhost:5051",
    grpc.WithTransportCredentials(tlsCreds),
    WithClientInterceptor())
  ...
}
```

注册之后，所有的 grpc 调用都会经过我们注册的 `clientInterceptor()`，因此所有的时间就都有统计了，而不用每个函数内部反反复复的添加时间、计量、输出。

添加了客户端的这个计量后，自然而然就联想到服务端是不是也可以做同样的事情？经过查看文档，可以，有个叫做 **Server Interceptor** 的东西。

同样的做法，我们在服务端添加 `interceptor.go`，并且添加 `ServerInterceptor()` 函数。

```go
func ServerInterceptor() grpc.ServerOption {
  return grpc.UnaryInterceptor(serverInterceptor)
}

func serverInterceptor(
  ctx context.Context,
  req interface{},
  info *grpc.UnaryServerInfo,
  handler grpc.UnaryHandler,
) (interface{}, error) {
  start := time.Now()
  resp, err := handler(ctx, req)
  log.Printf("invoke server method=%s duration=%s error=%v",
    info.FullMethod,
    time.Since(start),
    err)
  return resp, err
}
```

和客户端一样，需要在 `runServer()` 的时候注册我们定义的这个中间件。

```go
func runServer() error {
  ...
  srv := grpc.NewServer(grpc.Creds(tlsCreds), ServerInterceptor())
  ...
}
```

### 生产环境案例：超时

添加了日志后，我们终于在日志中发现，`/rpc.Accounts/GetByToken/` 花了好长的时间。我们需要对这个操作设置超时。

**server.go**

```go
func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  accountsCtx, _ := context.WithTimeout(context.Background(), 2 * time.Second)
  resp, err := s.accounts.GetByToken(accountsCtx, &rpc.GetByTokenReq{
    Token: req.AccountToken,
  })
  ...

}
```

这里操作很简单，直接使用标准库中 `context.WithTimeout()` 就可以了。

### 生产环境案例：上下文传递

经过上面修改后，客户依旧抱怨说没有满足 SLA，仔细一想也对。就算这里约束了 2 秒钟，客户端调用还需要时间，别的代码在中间也有时间开销。而且有的客户说，我们这里需要1秒钟，而不是2秒钟。

好吧，让我们把这个时间设定推向调用方。

首先我们要求在客户端进行调用时间约束的设定：

**client.go**

```go
func runClient() error {
  ...
  ctx, _ := context.WithTimeout(context.Background(), time.Second)
  _, err = cache.Store(ctx, &rpc.StoreReq{Key: "gopher", Val: []byte("con")})

  ...

  ctx, _ = context.WithTimeout(context.Background(), 50*time.Millisecond)
  resp, err := cache.Get(ctx, &rpc.GetReq{Key: "gopher"})
  ...
}
```

然后在服务端，我们将上下文传递。直接取调用方的 `ctx`。

```go
func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  resp, err := s.accounts.GetByToken(ctx, &rpc.GetByTokenReq{
    Token: req.AccountToken,
  })
  ...

}
```

### 生产环境案例：GRPC Metadata

上面的问题都解决了，终于可以松一口气了。可是客户又提新的需求了……😅，说我们能不能增加一个 `Dry Run` 的标志，就是说我希望你做所有需要做的事情，除了真的修改键值库。

GRPC metadata，也称为 GRPC 的 Header。就像 HTTP 头一样，可以有一些 Metadata 信息传递过来。使用 metadata，可以让我们的 Dry Run 的实现变得更简洁，不必每个 RPC 方法内都实现一遍检查 Dry Run 标志的逻辑，我们可以独立出来。

```go
func (s *CacheService) Store(ctx context.Context, req *rpc.StoreReq) (*rpc.StoreResp, error) {
  resp, err := s.accounts.GetByToken(ctx, &rpc.GetByTokenReq{
    Token: req.AccountToken,
  })

  if !dryRun(ctx) {
    if _, ok := s.store[req.Key]; !ok {
      s.keysByAccount[req.AccountToke] += 1
    }
    s.store[req.Key] = req.Val
  }
  return &rpc.StoreResp{}, nil
}

func dryRun(ctx context.Context) bool {
  md, ok := metadata.FromContext(ctx)
  if !ok {
    return false
  }
  val, ok := md["dry-run"]
  if !ok {
    return false
  }
  if len(val) < 1 {
    return false
  }
  return val[0] == "1"
}
```

当然，这么做是有妥协的，因为通用化后就失去了类型检查的能力。

在客户端调用的时候，则需要根据情况添加 `dry-run` 参数给 metadata。

```go
func runClient() error {
  ...
  ctx, _ := context.WithTimeout(context.Background(), time.Second)
  ctx = metadata.NewContext(ctx, metadata.Pairs("dry-run", "1"))
  _, err = cache.Store(ctx, &rpc.StoreReq{Key: "gopher", Val: []byte("con")})
  ...
}
```

### 生产环境案例：Retry

实现了 Dry Run 以为可以休息了，之前抱怨慢的客户又来抱怨了，虽然有超时控制，满足 SLA，但是服务那边还是慢，总超时不成功。检查了一下，发现是网络上的事情，我们没有太多可以做的事情。为了解决客户的问题，我们来添加一个重试的机制。

我们可以对每一个 gRPC 调用添加一个 Retry 机制，我们也可以像之前计时统计那样，使用 Interceptor 吧？

```go
func clientInterceptor(...) error {
  var (
    start     = time.Now()
    attempts  = 0
    err       error
    backoff   retryBackOff
  )

  for {
    attempts += 1
    select {
    case <-ctx.Done():
      err = status.Errorf(codes.DeadlineExceeded, "timeout reached before next retry attempt")
    case <-backoff.Next():
      startAttempt := time.Now()
      err = invoker(ctx, method, req, reply, cc, opts...)
      if err != nil {
        log.Printf(...)
        continue
      }
    }
    break
  }
  log.Printf(...)
  return err
}
```

看起来还不错，然后就打算发布这个代码了。结果提交审核的时候被打回来了，说这个代码不合理，因为如果是**非幂等（non-idempotent）** 的操作，这样就会导致多次执行，改变期望结果了。

看来我们得针对幂等和非幂等操作区别对待了。

```go
silo.FireZeMissiles(NotIdempotent(ctx), req)
```

嗯，当然，没这个东西。所以我们需要自己来创造一个标记，通过 context，来标明操作是否幂等。

```go
func NotIdempotent(ctx context.Context) context.Context {
  return context.WithValue(ctx, "idempotent", false)
}

func isIdempotent(ctx context.Context) bool {
  val, ok := ctx.Value("idempotent").(bool)
  if !ok {
    return true
  }
  return val
}
```

然后在我们的 `clientInterceptor()` 实现中加入 `isIdempotent()` 判断：

```go
func clientInterceptor(...) error {
  var (
    start     = time.Now()
    attempts  = 0
    err       error
    backoff   retryBackOff
  )

  for {
    attempts += 1
    select {
    case <-ctx.Done():
      err = status.Errorf(codes.DeadlineExceeded, "timeout reached before next retry attempt")
    case <-backoff.Next():
      startAttempt := time.Now()
      err = invoker(ctx, method, req, reply, cc, opts...)
      if err != nil && isIdempotent(ctx) {
        log.Printf(...)
        continue
      }
    }
    break
  }
  log.Printf(...)
  return err
}
```

这样当调用失败后，客户端检查发现是幂等的情况，才重试，否则不重试。避免了非幂等操作的反复操作。

### 生产环境案例：结构化错误

感觉没啥问题了，于是部署上线了。可是运行一段时间后，发现有些不对劲。所有成功的RPC调用，也就是说这个操作本身是正确的，都没有问题，超时重试也正常。但是所有失败的 RPC 调用都不对了，所有失败的 RPC 调用，都返回超时，而不是错误本身。这里说的失败，不是说网络问题导致超时啥的，而是说请求本身的失败，比如之前提到的，`Get()` 不存在的键，应该返回错误；或者 `Store()` 超过了配额，应该返回错误，这类错误在日志中都没看到，反而都对应了超时。

经过分析发现，服务端该报错都报错，没啥问题，但是客户端不对，本应该返回错误给调用方的地方，客户端代码反而又开始重试这个操作了。看来之前重试的代码还有问题。

```go
      err = invoker(ctx, method, req, reply, cc, opts...)
      if err != nil && isIdempotent(ctx) {
        log.Printf(...)
        continue
      }
```

如果仔细观察这部分代码，会发现，无论 `err` 是什么，只要非 `nil`，我们就重试。其实这是不对的，我们只有针对某些错误重试，比如网络问题之类的，而不应该对我们希望返回给调用方的错误重试，那没有意义。

那么问题就变成了，我们到底应该怎么对 `err` 判断来决定是否重试？

* 可以使用不同的 Error Code，特定的 Code 需要 Retry，其它的不需要，那就需要自定义 gRPC 错误码；
* 我们也可以定义一个 `Error` 类型的数据，里面包含了某种标志位，来告知是否值得 retry
* 或者干脆把错误码放到 Response 的消息里，确保每个消息都有一个我们定义的错误码，来标明是否需要 retry。

所以，我们需要的是一个完整的结构化的错误信息，而不是简单的一个 Error Code 和字符串。当然这条路不好走，但是我们已经做了这么多了，坚持一下还是可以克服的。

这里我们还是从 IDL 开始：

```protobuf
message Error {
  int64 code = 1;
  string messsage = 2;
  bool temporary = 3;
  int64 userErrorCode = 4;
}
```

然后我们实现这个 Error 类型。

**rpc/error.go**

```go
func (e *Error) Error() string {
  return e.Message
}
func Errorf(code codes.Code, temporary bool, msg string, args ..interface{}) error {
  return &Error{
    Code:      int64(code),
    Message:   fmt.Sprintf(msg, args...),
    Temporary: temporary,
  }
}
```

有这两个函数，我们可以显示和构造这个 `Error` 类型的变量了，但是我们该怎么把错误消息传回客户端呢？然后问题就开始变的繁琐起来了：

**rpc/error.go**

```go
func MarshalError (err error, ctx context.Context) error {
  rerr, ok := err.(*Error)
  if !ok {
    return err
  }
  pberr, marshalerr := pb.Marshal(rerr)
  if marshalerr == nil {
    md := metadata.Pairs("rpc-error", base64.StdEncoding.EncodeToString(pberr))
    _ = grpc.SetTrailer(ctx, md)
  }
  return status.Errorf(codes.Code(rerr.Code), rerr.Message)
}
func UnmarshalError(err error, md metadata.MD) *Error {
  vals, ok := md["rpc-error"]
  if !ok {
    return nil
  }
  buf, err := base64.StdEncoding.DecodeString(vals[0])
  if err != nil {
    return nil
  }
  var rerr Error
  if err := pb.Unmarshal(buf, &rerr); err != nil {
    return nil
  }
  return &rerr
}
```

**interceptor.go**

```go
func serverInterceptor (
  ctx context.Context,
  req interface{},
  info *grpc.UnaryServerInfo,
  handler grpc.UnaryHandler,
) (interface{}, error) {
  start := time.Now()
  resp, err := handler(ctx, req)
  err = rpc.MarshalError(err, ctx)
  log.Print(...)
  return resp, err
}
```

it's ugly，but works.

这是在 gRPC 不支持高级 `Error` 的情况下，怎么去 work around 这个问题，并且凑合用起来。现在这么做，错误就可以跨主机边界传递了。

### 生产环境案例：Dump

又有客户前来提需求了，有的客户说我们可以存、也可以取，但是如何才能把里面所有的数据都获取下来？于是有了需求，希望实现 `Dump()` 操作，可以取回所有数据。

现在已经轻车熟路了，我们先改 IDL，添加一个 `Dump()` 函数。

```go
service Cache {
  rpc Store(StoreReq) returns (StoreResp) {}
  rpc Get(GetReq) returns (GetResp) {}
  rpc Dump(DumpReq) returns (DumpResp) {}
}

message DumpReq{
}

message DumpResp {
  repeated DumpItem items = 1;
}

message DumpItem {
  string key = 1;
  bytes val = 2;
}
```

这里 `DumpResp` 里面用的是 `repeated`，因为 protobuf 里面不知道为啥不叫 array。

### 生产环境案例：流量控制

新功能 Dump 上线了，结果发现大家都很喜欢 Dump，有很多人在 Dump，结果服务器的内存开始不够了。于是我们需要一些限制手段，可以控制流量。

查阅了文档后，发现我们可以控制同时最大有多少并发可以访问，以及可以多频繁的来访问服务。

**server.go**

```go
func runServer() error {
  ...
  srv := grpc.NewServer(grpc.Creds(tlsCreds),
    ServerInterceptor(),
    grpc.MaxConcurrentStreams(64),
    grpc.InTapHandle(NewTap().Handler))
  rpc.RegisterCacheServer(srv, NewCacheService(accounts))
  l, err := net.Listen("tcp", "localhost:5051")
  if err != nil {
    return err
  }
  l = netutil.LimitListener(l, 1024)
  return srv.Serve(l)
}
```

这里使用了 `netutil.LimitListener(l, 1024)` 控制了总共可以有多少个连接，然后用 `grpc.MaxConcurrentStreams(64)` 指定了每个 grpc 的连接可以有多少个并发流(stream)。这两个结合起来基本控制了并发的总数。

但是 gRPC 里没有地方限定可以多频繁的访问。因此这里用了 `grpc.InTapHandle(NewTap().Handler))` 来进行定制，这是在更靠前的位置执行的。

**tap.go**

```go
type Tap struct {
  lim *rate.Limiter
}
func NewTap() *Tap {
  return &Tap(rate.NewLimiter(150, 5))
}
func (t *Tap) Handler(ctx context.Context, info *tap.Info) (context.Context, error) {
  if !t.lim.Allow() {
    return nil, status.Errorf(codes.ResourceExhausted, "service is over rate limit")
  }
  return ctx, nil
}
```

### 生产环境案例：Streaming

之前的方案部署后，内存终于降下来了，但是还没休息，就发现大家越来越喜欢用这个缓存服务，内存又不够用了。这个时候我们就开始思考，是不是可以调整一下设计，不是每次 Dump 就立即在内存生成完整的返回数组，而是以流的形式，按需发回。

**app.proto**

```go
syntax = "proto3";
package rpc;

service Cache {
  rpc Store(StoreReq) returns (StoreResp) {}
  rpc Get(GetReq) returns (GetResp) {}
  rpc Dump(DumpReq) returns (stream DumpItem) {}
}

message DumpReq{
}

message DumpItem {
  string key = 1;
  bytes val = 2;
}
```

这里不再使用数组性质的 `repeated`，而是用 `stream`，客户端请求 `Dump()` 后，将结果以流的形式发回去。

**server.go**

```go
func (s *CacheService) Dump(req *rpc.DumpReq, stream rpc.Cache_DumpServer) error {
  for k, v := range s.store {
    stream.Send(&rpc.DumpItem{
      Key: k,
      Val: v,
    })
  }
  return nil
}
```

我们修改 `Dump()` 的实现，对于每个记录，利用 `stream.Send()` 发送到流。

注意这里我们没有 `context`，只有个 `stream`。

**client.go**

```go
func runClient() error {
  ...
  stream, err := cache.Dump(context.Background(), &rpc.DumpReq{})
  if err != nil {
    return fmt.Errorf("failed to dump: %v", err)
  }
  for {
    item, err := stream.Recv()
    if err == io.EOF {
      break
    }
    if err != nil {
      return fmt.Errorf("failed to stream item: %v", err)
    }
  }
  return nil
}
```

### 生产环境案例：横向扩展、负载均衡

使用流后，服务器性能提高了很多，但是，我们的服务太吸引人了，用户越来越多，结果又内存不够了。这时候我们审查代码，感觉能做的事情都做了，或许是时候从单一服务器，扩展为多个服务器，然后之间使用负载均衡。

gRPC 是长连接性质的通讯，因此如果一个客户端连接了一个 gRPC Endpoint，那么他就会一直连接到一个固定的服务器，因此多服务器的负载均衡对同一个客户端来说是没有意义的，不会因为这个客户端有大量的请求而导致分散请求到不同的服务器上去。

如果我们希望客户端可以利用多服务器的机制，我们就需要更智能的客户端，让客户端意识到服务器存在多个副本，因此客户端建立多条连接到不同的服务器，这样就可以让单一客户端利用负载均衡的横向扩展能力。

### 生产环境案例：多语言协作

在复杂的环境中，我们 gRPC 的客户端（甚至服务端）可能是不同语言平台的。这其实是 gRPC 的优势，可以比较容易的实现跨语言平台的通讯。

比如我们可以做一个 Python 客户端：

```python
import grpc
import rpc_pb2 as rpc

channel = grpc.insecure_channel('localhost:5051')
cache_svc = rpc.CacheStub(channel)

resp = cache_svc.Get(rpc.GetReq(
  key="gopher",
))

print resp.val
```

一个不是很爽的地方是虽然 gRPC 的跨语言通讯很方便，但是各个语言的实现都比较随意，比如 Go 中叫做 `CacheClient()`，而 Python 中则叫做 `CacheStub()`。这里没有什么特别的原因非不一样的名字，就是由于不同的作者实现的时候按照自己的想法命名的。

## gRPC 尚不完美的地方

* 负载均衡
* 结构化的错误信息
* 还不支持浏览器的 JS （某种角度上讲，这是最常用的客户端）
* 还经常发生 API 改变（即使都1.0了）
* 某些语言实现的文档非常差
* 没有跨语言的标准化的做法

## gRPC 在生产环境中的用例

* ngrok，所有内部20多个通讯都走的是 gRPC
* Square，将内部的通讯都换成了 gRPC，是最早使用 gRPC 的用户和贡献者
* CoreOS，etcd v3 完全走的是 gRPC
* Google，Google Cloud Service（PubSub, Speech Rec）走的是 gRPC
* Netflix, Yik Yak, VSCO, Cockroach, ...

## gRPC 未来的变化

* 想了解未来的变化可以查看：
  * [grpc/proposal](https://github.com/grpc/proposal)
  * [grpc-io 邮件列表](https://groups.google.com/forum/#!forum/grpc-io)
* 新的语言支持（[Swift](https://github.com/grpc/grpc-swift) 和 [Haskell](https://github.com/grpc/grpc-haskell)正在试验阶段）
* 稳定性、可靠性、性能的提高
* 增加更多细化的 API 来支持自定义的行为（连接管理、频道跟踪）
* 浏览器的 JS
