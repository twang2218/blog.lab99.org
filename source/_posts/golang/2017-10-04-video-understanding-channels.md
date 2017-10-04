---
layout: post
category: golang
title: 视频笔记：理解 channels - Kavya Joshi
date: 2017-10-04
tags: [golang, gophercon2017, youtube, notes]
---

<!-- toc -->

# 视频信息

**Understanding Channels**
by Kavya Joshi
at GopherCon 2017

{% owl youtube KBZlN0izeiY %}

<https://www.youtube.com/watch?v=KBZlN0izeiY>

幻灯：<https://github.com/gophercon/2017-talks/blob/master/KavyaJoshi-UnderstandingChannels/Kavya%20Joshi%20-%20Understanding%20Channels.pdf>
博文：<https://about.sourcegraph.com/go/understanding-channels-kavya-joshi>

# Go 的并发特性

* **goroutines**: 独立执行每个任务，并*可能并行*执行
* **channels**: 用于 goroutines 之间的通讯、同步

## 一个简单的事务处理的例子

对于下面这样的非并发的程序：

```go
func main() {
  tasks := getTasks()
  // 处理每个任务
  for _, task := range tasks {
    process(task)
  }
}
```

将其转换为 Go 的并发模式很容易，使用典型的 Task Queue 的模式：

```go
func main() {
  //  创建带缓冲的 channel
  ch := make(chan Task, 3)
  //  运行固定数量的 workers
  for i := 0; i < numWorkers; i++ {
    go worker(ch)
  }
  //  发送任务到 workers
  hellaTasks := getTasks()
  for _, task := range hellaTasks {
    ch <- task
  }
  ...
}

func worker(ch chan Task) {
  for {
    //  接收任务
    task := <-ch
    process(task)
  }
}
```

## channels 的特性

* goroutine-safe，多个 goroutine 可以同时访问一个 channel 而不会出现竞争问题
* 可以用于在 goroutine 之间*存储*和*传递*值
* 其语义是*先入先出（FIFO）*
* 可以导致 goroutine 的 block 和 unblock

# 解析

## 构造 channel

```go
//  带缓冲的 channel
ch := make(chan Task, 3)
//  无缓冲的 channel
ch := make(chan Tass)
```

回顾前面提到的 channel 的特性，特别是前两个。如果忽略内置的 channel，让你设计一个具有 goroutines-safe 并且可以用来存储、传递值的东西，你会怎么做？很多人可能觉得或许可以用一个带锁的队列来做。没错，事实上，channel 内部就是一个带锁的队列。

<https://golang.org/src/runtime/chan.go>

```go
type hchan struct {
  ...
  buf      unsafe.Pointer // 指向一个环形队列
  ...
  sendx    uint   // 发送 index
  recvx    uint   // 接收 index
  ...
  lock     mutex  //  互斥量
}
```

`buf` 的具体实现很简单，就是一个环形队列的实现。`sendx` 和 `recvx` 分别用来记录发送、接收的位置。然后用一个 `lock` 互斥锁来确保无竞争冒险。

对于每一个 `ch := make(chan Task, 3)` 这类操作，都会在**堆**中，分配一个空间，建立并初始化一个 `hchan` 结构变量，而 `ch` 则是指向这个 `hchan` 结构的**指针**。

因为 `ch` 本身就是个指针，所以我们才可以在 goroutine 函数调用的时候直接将 `ch` 传递过去，而不用再 `&ch` 取指针了，所以所有使用同一个 `ch` 的 goroutine 都指向了同一个实际的内存空间。

## 发送、接收

为了方便描述，我们用 `G1` 表示 `main()` 函数的 goroutine，而 `G2` 表示 worker 的 goroutine。

```go
// G1
func main() {
  ...
  for _, task := range tasks {
    ch <- task
  }
  ...
}
```

```go
// G2
func worker(ch chan Task) {
  for {
    task :=<-ch
    process(task)
  }
}
```

### 简单的发送、接收

那么 `G1` 中的 `ch <- task0` 具体是怎么做的呢？

1. 获取锁
2. `enqueue(task0)`（这里是内存复制 task0）
3. 释放锁

这一步很简单，接下来看 `G2` 的 `t := <- ch` 是如何读取数据的。

1. 获取锁
2. `t = dequeue()`（同样，这里也是内存复制）
3. 释放锁

这一步也非常简单。但是我们从这个操作中可以看到，所有 goroutine 中共享的部分只有这个 `hchan` 的结构体，而所有通讯的数据都是**内存复制**。这遵循了 Go 并发设计中很核心的一个理念：

> "Do not communicate by sharing memory;
> instead, share memory by communicating."

## 阻塞和恢复

### 发送方被阻塞

假设 `G2` 需要很长时间的处理，在此期间，`G1` 不断的发送任务：

1. `ch <- task1`
2. `ch <- task2`
3. `ch <- task3`

但是当再一次 `ch <- task4` 的时候，由于 `ch` 的缓冲只有 `3` 个，所以没有地方放了，于是 `G1` 被 block 了，当有人从队列中取走一个 Task 的时候，`G1` 才会被恢复。这是我们都知道的，不过我们今天关心的不是发生了什么，而是如何做到的？

### goroutine 的运行时调度

首先，goroutine **不是操作系统线程**，而是**用户空间线程**。因此 goroutine 是由 Go runtime 来创建并管理的，而不是 OS，所以要比操作系统线程轻量级。

当然，goroutine 最终还是要运行于某个线程中的，控制 goroutine 如何运行于线程中的是 Go runtime 中的 scheduler （调度器）。

Go 的运行时调度器是 `M:N` 调度模型，既 `N` 个 goroutine，会运行于 `M` 个 OS 线程中。换句话说，一个 OS 线程中，可能会运行多个 goroutine。

Go 的 `M:N` 调度中使用了3个结构：

* `M`: OS 线程
* `G`: goroutine
* `P`: 调度上下文
  * `P` 拥有一个运行队列，里面是所有可以运行的 goroutine 及其上下文

要想运行一个 goroutine - `G`，那么一个线程 `M`，就必须持有一个该 goroutine 的上下文 `P`。

### goroutine 被阻塞的具体过程

那么当 `ch <- task4` 执行的时候，channel 中已经满了，需要**pause** `G1`。这个时候，：

1. `G1` 会调用运行时的 `gopark`，
2. 然后 Go 的运行时调度器就会接管
3. 将 `G1` 的状态设置为 `waiting`
4. 断开 `G1` 和 `M` 之间的关系（switch out)，因此 `G1` 脱离 `M`，换句话说，`M` 空闲了，可以安排别的任务了。
5. 从 `P` 的运行队列中，取得一个可运行的 goroutine `G`
6. 建立新的 `G` 和 `M` 的关系（Switch in)，因此 `G` 就准备好运行了。
7. 当调度器返回的时候，新的 `G` 就开始运行了，而 `G1` 则不会运行，也就是 block 了。

从上面的流程中可以看到，对于 goroutine 来说，`G1` 被阻塞了，新的 `G` 开始运行了；而对于操作系统线程 `M` 来说，则根本没有被阻塞。

我们知道 OS 线程要比 goroutine 要沉重的多，因此这里尽量避免 OS 线程阻塞，可以提高性能。

### goroutine 恢复执行的具体过程

前面理解了阻塞，那么接下来理解一下如何恢复运行。不过，在继续了解如何恢复之前，我们需要先进一步理解 `hchan` 这个结构。因为，当 channel 不在满的时候，调度器是如何知道该让哪个 goroutine 继续运行呢？而且 goroutine 又是如何知道该从哪取数据呢？

在 `hchan` 中，除了之前提到的内容外，还定义有 `sendq` 和 `recvq` 两个队列，分别表示等待发送、接收的 goroutine，及其相关信息。

```go
type hchan struct {
  ...
  buf      unsafe.Pointer // 指向一个环形队列
  ...
  sendq    waitq  // 等待发送的队列
  recvq    waitq  // 等待接收的队列
  ...
  lock     mutex  //  互斥量
}
```

其中 `waitq` 是一个链表结构的队列，每个元素是一个 `sudog` 的结构，其定义大致为：

```go
type sudog struct {
  g          *g //  正在等候的 goroutine
  elem       unsafe.Pointer // 指向需要接收、发送的元素
  ...
}
```

<https://golang.org/src/runtime/runtime2.go?h=sudog#L270>

所以在之前的阻塞 `G1` 的过程中，实际上：

1. `G1` 会*给自己*创建一个 `sudog` 的变量
2. 然后追加到 `sendq` 的等候队列中，方便将来的 **receiver** 来使用这些信息恢复 `G1`。

这些都是**发生在调用调度器之前**。

那么现在开始看一下如何恢复。

当 `G2` 调用 `t := <- ch` 的时候，channel 的状态是，缓冲是满的，而且还有一个 `G1` 在等候发送队列里，然后 `G2` 执行下面的操作：

1. `G2` 先执行 `dequeue()` 从缓冲队列中取得 `task1` 给 `t`
2. `G2` 从 `sendq` 中弹出一个等候发送的 `sudog`
3. 将弹出的 `sudog` 中的 `elem` 的值 `enqueue()` 到 `buf` 中
4. 将弹出的 `sudog` 中的 goroutine，也就是 `G1`，状态从 `waiting` 改为 `runnable`
  1. 然后，`G2` 需要通知调度器 `G1` 已经可以进行调度了，因此调用 `goready(G1)`。
  2. 调度器将 `G1` 的状态改为 `runnable`
  3. 调度器将 `G1` 压入 `P` 的运行队列，因此在将来的某个时刻调度的时候，`G1` 就会开始恢复运行。
  4. 返回到 G2

> 注意，这里是由 `G2` 来负责将 `G1` 的 `elem` 压入 `buf` 的，这是一个优化。这样将来 `G1` 恢复运行后，就不必再次获取锁、`enqueue()`、释放锁了。这样就避免了多次锁的开销。

### 如果接收方先阻塞呢？

更酷的地方是接收方先阻塞的流程。

如果 `G2` 先执行了 `t := <- ch`，此时 `buf` 是空的，因此 `G2` 会被阻塞，他的流程是这样：

1. `G2` 给自己创建一个 `sudog` 结构变量。其中 `g` 是自己，也就是 `G2`，而 `elem` 则指向 `t`
2. 将这个 `sudog` 变量压入 `recvq` 等候接收队列
3. `G2` 需要告诉 goroutine，自己需要 pause 了，于是调用 `gopark(G2)`
  1. 和之前一样，调度器将其 `G2` 的状态改为 `waiting`
  2. 断开 `G2` 和 `M` 的关系
  3. 从 `P` 的运行队列中取出一个 goroutine
  4. 建立新的 goroutine 和 `M` 的关系
  5. 返回，开始继续运行新的 `goroutine`

这些应该已经不陌生了，那么当 `G1` 开始发送数据的时候，流程是什么样子的呢？

`G1` 可以将 `enqueue(task)`，然后调用 `goready(G2)`。不过，我们可以更聪明一些。

我们根据 `hchan` 结构的状态，已经知道 `task` 进入 `buf` 后，`G2` 恢复运行后，会读取其值，复制到 `t` 中。那么 `G1` 可以根本不走 `buf`，**`G1` 可以直接把数据给 `G2`**。

Goroutine 通常都有自己的栈，互相之间不会访问对方的栈内数据，**除了 channel**。这里，由于我们已经知道了 `t` 的地址（通过 `elem`指针），而且由于 `G2` 不在运行，所以我们可以很安全的直接赋值。当 `G2` 恢复运行的时候，既不需要再次获取锁，也不需要对 `buf` 进行操作。从而节约了内存复制、以及锁操作的开销。

## 总结

* goroutine-safe
  * `hchan` 中的 `lock mutex`

* 存储、传递值，FIFO
  * 通过 `hchan` 中的环形缓冲区来实现

* 导致 goroutine 的阻塞和恢复
  * `hchan` 中的 `sendq`和`recvq`，也就是 `sudog` 结构的链表队列
  * 调用运行时调度器 (`gopark()`, `goready()`)

# 其它 channel 的操作

## 无缓冲 channel

无缓冲的 channel 行为就和前面说的**直接发送**的例子一样：

* 接收方阻塞 → 发送方**直接写入接收方的栈**
* 发送方阻塞 → 接受法**直接从发送方的 `sudog` 中读取**

## `select`

<https://golang.org/src/runtime/select.go>

1. 先把所有需要操作的 channel 上锁
2. 给自己创建一个 `sudog`，然后添加到所有 channel 的 `sendq`或`recvq`（取决于是发送还是接收）
3. 把所有的 channel 解锁，然后 pause 当前调用 `select` 的 goroutine（`gopark()`）
4. 然后当有任意一个 channel 可用时，`select` 的这个 goroutine 就会被调度执行。
5. resuming mirrors the pause sequence

# 为什么 Go 会这样设计？

## Simplicity

更倾向于带锁的队列，而不是无锁的实现。

> “性能提升不是凭空而来的，是随着复杂度增加而增加的。” - dvyokov

后者虽然性能可能会更好，但是这个优势，并不一定能够战胜随之而来的实现代码的复杂度所带来的劣势。

## Performance

* 调用 Go 运行时调度器，这样可以保持 OS 线程不被阻塞

跨 goroutine 的栈读、写。

* 可以让 goroutine 醒来后不必获取锁
* 可以避免一些内存复制

当然，**任何优势都会有其代价**。这里的代价是实现的复杂度，所以这里有更复杂的内存管理机制、垃圾回收以及栈收缩机制。

在这里性能的提高优势，要比复杂度的提高带来的劣势要大。

所以在 channel 实现的各种代码中，我们都可以见到这种 **simplicity vs performance** 的权衡后的结果。
