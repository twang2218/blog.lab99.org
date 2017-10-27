---
layout: post
category: golang
title: 视频笔记：7种 Go 程序性能分析方法 - Dave Cheney
date: 2017-10-20
tags: [golang, golang-uk-2016, youtube, notes]
---

<!-- toc -->

# 视频信息

**Seven ways to Profile Go Applications**
by Dave Cheney
at Golang UK Conf. 2016

{% owl youtube 2h_NFBFrciI %}

* 视频：<https://www.youtube.com/watch?v=2h_NFBFrciI>
* 幻灯：<http://talks.godoc.org/github.com/davecheney/presentations/seven.slide#1>

# 方法一：`time`

## shell 内置的 `time`

最简单的性能测试工具就是 shell 中内置的 `time` 命令，这是由 POSIX.2 (IEEE Std 1003.2-1992) 标准定义的，因此所有 Unix/Linux 都有这个内置命令。

```bash
$ time go fmt github.com/docker/machine

real    0m0.110s
user    0m0.056s
sys     0m0.040s
```

这是使用shell**内置的 `time`**来对 `go fmt github.com/docker/machine` 的命令进行性能分析。

这里一共有3项指标：

* `real`：从程序开始到结束，实际度过的时间；
* `user`：程序在**用户态**度过的时间；
* `sys`：程序在**内核态**度过的时间。

一般情况下 `real` **>=** `user` + `sys`，因为系统还有其它进程。

## GNU 实现的 `time`

除此以外，对于 Linux 系统，还有一套 GNU 的 `time`，位于 `/usr/bin/time`，需要用完整路径去调用，不过这个功能就更强大了。

```bash
vagrant@vagrant:~$ /usr/bin/time -v go fmt github.com/docker/machine
        Command being timed: "go fmt github.com/docker/machine"
        User time (seconds): 0.02
        System time (seconds): 0.06
        Percent of CPU this job got: 85%
        Elapsed (wall clock) time (h:mm:ss or m:ss): 0:00.09
        Average shared text size (kbytes): 0
        Average unshared data size (kbytes): 0
        Average stack size (kbytes): 0
        Average total size (kbytes): 0
        Maximum resident set size (kbytes): 18556
        Average resident set size (kbytes): 0
        Major (requiring I/O) page faults: 0
        Minor (reclaiming a frame) page faults: 9925
        Voluntary context switches: 430
        Involuntary context switches: 121
        Swaps: 0
        File system inputs: 0
        File system outputs: 32
        Socket messages sent: 0
        Socket messages received: 0
        Signals delivered: 0
        Page size (bytes): 4096
        Exit status: 0
```

可以看到这里的功能要强大多了，除了之前的信息外，还包括了：

* CPU占用率；
* 内存使用情况；
* Page Fault 情况；
* 进程切换情况；
* 文件系统IO；
* Socket 使用情况；
* ……

## *BSD、macOS 的 `time`

*BSD 也有自己实现的 time，功能稍逊，但也比 Shell 里的 `time` 强大。比如 macOS 中继承自 FreeBSD 的 `time`：

```bash
$ /usr/bin/time -l go fmt github.com/docker/machine
        0.70 real         0.05 user         0.40 sys
  11710464  maximum resident set size
         0  average shared memory size
         0  average unshared data size
         0  average unshared stack size
      8579  page reclaims
      2571  page faults
         0  swaps
         0  block input operations
         0  block output operations
         0  messages sent
         0  messages received
         3  signals received
      1118  voluntary context switches
      1702  involuntary context switches
$
```

这里有：

* 内存使用情况
* Page Fault 情况
* IO 情况
* 进程切换情况
* Signal 情况
* ……

## go tool 中的 `-toolexec` 参数

当我们构建很慢的时候，如何才能知道为什么慢呢？go 工具链中支持 `-x` 命令，可以显示具体执行的每一条命令，这样我们就可以看到到底执行到哪里的时候慢了。

```bash
$ go build -x fmt
WORK=/var/folders/wc/9tzsn1hd7c38tvc54kctn4100000gn/T/go-build846067626
mkdir -p $WORK/runtime/internal/sys/_obj/
mkdir -p $WORK/runtime/internal/
cd /usr/local/Cellar/go/1.9.1/libexec/src/runtime/internal/sys
/usr/local/Cellar/go/1.9.1/libexec/pkg/tool/darwin_amd64/compile -o $WORK/runtime/internal/sys.a -trimpath $WORK -goversion go1.9.1 -p runtime/internal/sys -std -+ -complete -buildid 2749cc50ea3a4ebcf
...
```

但是如果构建时间很长，或者是计划在 CI 中运行，我们就不可能一直盯着了。当然，我们可以时候从输出中复制粘贴到命令行，前缀上 `time`，也可以知道每个命令的执行时间。不过这太繁琐了。

go tool 工具链中，还支持一个叫做 `-toolexec` 的参数，其值将作为工具链每一个命令的前缀来执行。

```bash
go build -toolexec=... github.com/pkg/profile
go test -toolexec=... net/http
...
```

换句话说，如果 `-toolexec=time`，那么假如有一个 `go build xxx.go` 的命令，就会变为 `time go build xxx.go` 来执行。

```bash
$ go build -toolexec="/usr/bin/time" cmd/compile/internal/gc
# runtime/internal/sys
        0.09 real         0.01 user         0.02 sys
# runtime/internal/atomic
        0.01 real         0.00 user         0.00 sys
# runtime/internal/atomic
        0.02 real         0.00 user         0.00 sys
# runtime
        1.60 real         1.90 user         0.12 sys
# runtime
        0.00 real         0.00 user         0.00 sys
# runtime
        0.02 real         0.01 user         0.00 sys
# runtime
        0.01 real         0.00 user         0.00 sys
# runtime
        0.00 real         0.00 user         0.00 sys
...
```

用好了，这就可以变得很强大，不仅仅是计时。比如，我们 `go build` 的时候我们可以在 Mac 或者 Linux 上进行交叉编译，但是 `go test` 的时候，我们希望则在手机设备上直接运行。另外，也可以用来校验输出结果的一致性 （`toolstash`）

# 方法二：`GODEBUG`

`/usr/bin/time` 是外部工具，除此外，我们还可以使用 Go 内置的功能。Go 的 runtime 可以收集程序运行周期内的很多数据。当然，这些收集默认都是不启用的，你可以手动启用特定信息的收集。

比如，如果你关心垃圾收集，则可以启用 `gctrace=1` 标志。如：

```bash
$ env GODEBUG=gctrace=1 godoc -http=:8080
gc 1 @18446741350.644s 0%: 0.026+2.0+0.075 ms clock, 0.052+2.6/2.0/0+0.15 ms cpu, 4->4->0 MB, 5 MB goal, 4 P
gc 2 @18446741350.664s 0%: 0.12+1.5+0.049 ms clock, 0.25+0.50/1.2/0+0.098 ms cpu, 4->4->1 MB, 5 MB goal, 4 P
gc 3 @18446741350.695s 0%: 0.024+1.1+0.059 ms clock, 0.072+1.3/0.96/0+0.17 ms cpu, 4->4->1 MB, 5 MB goal, 4P
gc 4 @18446741350.714s 0%: 0.036+1.8+0.092 ms clock, 0.11+1.4/1.7/0+0.27 ms cpu, 4->4->1 MB, 5 MB goal, 4 P
gc 5 @18446741350.746s 0%: 0.021+2.2+0.055 ms clock, 0.087+2.5/2.1/0+0.22 ms cpu, 4->4->1 MB, 5 MB goal, 4 P
gc 6 @18446741350.770s 0%: 0.013+4.5+0.12 ms clock, 0.053+1.3/3.9/0+0.50 ms cpu, 4->4->1 MB, 5 MB goal, 4 P
gc 7 @18446741350.800s 0%: 0.020+2.5+0.056 ms clock, 0.083+2.4/2.5/0+0.22 ms cpu, 4->4->2 MB, 5 MB goal, 4 P
gc 8 @18446741350.817s 0%: 0.030+3.2+0.053 ms clock, 0.12+2.8/3.0/0+0.21 ms cpu, 4->4->2 MB, 5 MB goal, 4 P
gc 9 @18446741350.845s 0%: 0.041+4.7+0.10 ms clock, 0.16+1.6/4.3/0+0.40 ms cpu, 4->4->2 MB, 5 MB goal, 4 P
gc 10 @18446741350.881s 0%: 0.018+3.7+0.070 ms clock, 0.072+2.5/3.6/0+0.28 ms cpu, 4->4->2 MB, 5 MB goal, 4
...
```

这样的话，垃圾收集的信息都会被输出出来，可以帮助 GC 排障。如果发现 GC 一直都在很忙碌的工作，那恐怕内存管理上有可以改进的地方。

# 插曲一：Profiler 是如何工作的？

Profiler 会启动你的程序，然后通过配置操作系统，来定期中断程序，然后进行采样。比如发送 `SIGPROF` 信号给被分析的进程，这样进程就会被暂停，然后切换到 Profiler 中进行分析。Profiler 则取得被分析的程序的每个线程的当前位置等信息进行统计，然后恢复程序继续执行。

## 性能分析注意事项

* 性能分析必须在一个**可重复的、稳定的环境**中来进行。
  * 机器**必须闲置**。
    * 不要在共享硬件上进行性能分析;
    * 不要在性能分析期间，在同一个机器上去浏览网页！！😓；
  * 注意省电模式和过热保护，如果突然进入这些模式，会导致分析数据严重不准确
  * **不要使用虚拟机、共享的云主机**，太多干扰因素，分析数据会很不一致；
  * 不要在 macOS 10.11 及以前的版本运行性能分析，有 bug，之后的版本修复了。

如果承受得起，购买专用的性能测试分析的硬件设备，上架。

* 关闭电源管理、过热管理;
* 绝不要升级，以保证测试的一致性，以及具有可比性。

如果没有这样的环境，那就一定要在多个环境中，执行多次，以取得可参考的、具有相对一致性的测试结果。

# 方法三：`pprof`

[`pprof`](https://github.com/google/pprof) 源自 [Google Performance Tools](https://github.com/gperftools/gperftools/wiki) 工具集。Go runtime 中内置了 `pprof` 的性能分析功能。这包含了两部分：

* 每个 Go 程序中内置 [`runtime/pprof`](https://golang.org/pkg/runtime/pprof/) 包
* 然后用 [`go tool pprof`](https://blog.golang.org/profiling-go-programs) 来分析性能数据文件

## CPU 性能分析

最常用的就是 CPU 性能分析，当 CPU 性能分析启用后，Go runtime 会每 `10ms` 就暂停一下，记录当前运行的 Go routine 的调用堆栈及相关数据。当性能分析数据保存到硬盘后，我们就可以分析代码中的热点了。

一个函数如果出现在数据中的次数越多，就越说明这个函数调用栈占用了更多的运行时间。

## 内存性能分析

内存性能分析则是在**堆(Heap)分配**的时候，记录一下调用堆栈。默认情况下，是每 `1000` 次分配，取样一次，这个数值可以改变。

**栈(Stack)分配** 由于会随时释放，因此**不会**被内存分析所记录。

由于内存分析是**取样**方式，并且也因为其记录的**是分配内存，而不是使用内存**。因此使用内存性能分析工具来准确判断程序具体的内存使用是比较困难的。

## 阻塞性能分析

阻塞分析是一个很独特的分析。它有点儿类似于 CPU 性能分析，但是它所记录的是 goroutine 等待资源所花的时间。

阻塞分析对分析程序**并发瓶颈**非常有帮助。阻塞性能分析可以显示出什么时候出现了大批的 goroutine 被阻塞了。阻塞包括：

* 发送、接受无缓冲的 channel；
* 发送给一个满缓冲的 channel，或者从一个空缓冲的 channel 接收；
* 试图获取已被另一个 go routine 锁定的 `sync.Mutex` 的锁；

阻塞性能分析是特殊的分析工具，在排除 CPU 和内存瓶颈前，不应该用它来分析。

## 一次只分析一个东西

**性能分析不是没有开销的**。虽然性能分析对程序的影响并不严重，但是毕竟有影响，特别是内存分析的时候增加采样率的情况。大多数工具甚至直接就不允许你同时开启多个性能分析工具。如果你同时开启了多个性能分析工具，那很有可能会出现他们互相观察对方的开销从而导致你的分析结果彻底失去意义。

所以，**一次只分析一个东西**。

## 对函数分析

最简单的对一个函数进行性能分析的办法就是使用 `testing` 包。`testing` 包内置支持生成 CPU、内存、阻塞的性能分析数据。

* `-cpuprofile=xxxx`： 生成 **CPU** 性能分析数据，并写入文件 `xxxx`；
* `-memprofile=xxxx`： 生成 **内存** 性能分析数据，并写入文件 `xxxx`；
  * `-memprofilerate=N`：调整采样率为 `1/N`；
* `-blockprofile=xxxx`： 生成 **阻塞** 性能分析数据，并写入文件 `xxxx`；

如：

```bash
$ go test -run=XXX -bench=IndexByte -cpuprofile=/tmp/c.p bytes
goos: darwin
goarch: amd64
pkg: bytes
BenchmarkIndexByte/10-4         200000000                6.44 ns/op     1553.83 MB/s
BenchmarkIndexByte/32-4         200000000                7.41 ns/op     4318.84 MB/s
BenchmarkIndexByte/4K-4         10000000               210 ns/op        19455.95 MB/s
BenchmarkIndexByte/4M-4             5000            321910 ns/op        13029.39 MB/s
BenchmarkIndexByte/64M-4             300           5406798 ns/op        12411.94 MB/s
BenchmarkIndexBytePortable/10-4                 100000000               13.8 ns/op       722.79 MB/s
BenchmarkIndexBytePortable/32-4                 30000000                44.9 ns/op       712.86 MB/s
BenchmarkIndexBytePortable/4K-4                   500000              2910 ns/op        1407.32 MB/s
BenchmarkIndexBytePortable/4M-4                      500           2979323 ns/op        1407.80 MB/s
BenchmarkIndexBytePortable/64M-4                      30          47259940 ns/op        1419.99 MB/s
PASS
ok      bytes   18.689s
```

> 注意这里的 `-run=XXX` 是说只运行 Benchmarks，而不要运行任何 Tests。

然后我们用 `go tool pprof` 来分析：

```bash
$ go tool pprof bytes.test /tmp/c.p
```

## 对整个应用分析

`testing` 适用于分析具体某个函数，但是如果想分析整个应用，则可以使用 `runtime/pprof` 包。当然这比较底层，Dave Cheney 在几年前还写了个包 [`github.com/pkg/profile`](https://github.com/pkg/profile)，可以简化使用。

只需要在启动的时候加入 `defer profile.Start().Stop()` 即可。

```go
import "github.com/pkg/profile"

func main() {
        defer profile.Start().Stop()
        ...
}
```

# 方法四：`/debug/pprof`

`pprof` 适合在开发的时候进行分析，从运行到结束。但是如果应用已经在数据中心运行，我们希望远程启用调试进行在线分析，这种情况，可以通过 `http` 远程调试。

```go
import _ "net/http/pprof"

func main() {
        log.Println(http.ListenAndServe("localhost:3999", nil))
        ...
}
```

然后使用 `pprof` 工具来查看一段 `30秒` 的：

* CPU 性能分析数据：

```bash
go tool pprof http://localhost:3999/debug/pprof/profile
```

* 内存性能分析数据：

```bash
go tool pprof http://localhost:3999/debug/pprof/heap
```

> 在 `/debug/pprof/heap` 页面的最下方，是 `runtime.MemStats`，这是你的应用真实使用内存的情况（不仅仅是分配）。其中的 `HeapSys` 是应用从系统申请到的页面数量。

* 阻塞性能分析数据：

```bash
go tool pprof http://localhost:3999/debug/pprof/block
```

## 使用 `pprof`

`pprof` 始终需要两个参数：

```bash
go tool pprof /path/to/your/binary /path/to/your/profile
```

* `binary` 必须指向生成这个性能分析数据的那个二进制可执行文件；
* `profile` 必须是该二进制可执行文件所生成的性能分析数据文件。

换句话说，**`binary` 和 `profile` 必须严格匹配**。

由于 `pprof` 有在线模式，可以获取性能分析数据文件，所以很多人误解了可以只有 profile。所有可能会有人执行：

```bash
go tool pprof /tmp/c.p
```

**不是这样的**，这样会发现显示 profile 里面是空的。

我们可以在命令行里分析：

```bash
$ go tool pprof bytes.test /tmp/c.p
File: bytes.test
Type: cpu
Time: Oct 22, 2017 at 8:41pm (AEDT)
Duration: 18.60s, Total samples = 16.38s (88.06%)
Entering interactive mode (type "help" for commands, "o" for options)
(pprof) top
Showing nodes accounting for 16300ms, 99.51% of 16380ms total
Dropped 30 nodes (cum <= 81.90ms)
Showing top 10 nodes out of 12
      flat  flat%   sum%        cum   cum%
    7560ms 46.15% 46.15%     7560ms 46.15%  runtime.indexbytebody /usr/local/Cellar/go/1.9.1/libexec/src/runtime/asm_amd64.s
    5950ms 36.32% 82.48%     5950ms 36.32%  bytes.indexBytePortable /usr/local/Cellar/go/1.9.1/libexec/src/bytes/bytes.go
    2180ms 13.31% 95.79%    15880ms 96.95%  bytes_test.bmIndexByte.func1 /usr/local/Cellar/go/1.9.1/libexec/src/bytes/bytes_test.go
     420ms  2.56% 98.35%      420ms  2.56%  runtime.usleep /usr/local/Cellar/go/1.9.1/libexec/src/runtime/sys_darwin_amd64.s
     190ms  1.16% 99.51%      190ms  1.16%  bytes.IndexByte /usr/local/Cellar/go/1.9.1/libexec/src/runtime/asm_amd64.s
         0     0% 99.51%    15880ms 96.95%  bytes_test.benchBytes.func1 /usr/local/Cellar/go/1.9.1/libexec/src/bytes/bytes_test.go
         0     0% 99.51%      410ms  2.50%  runtime.mstart /usr/local/Cellar/go/1.9.1/libexec/src/runtime/proc.go
         0     0% 99.51%      410ms  2.50%  runtime.mstart1 /usr/local/Cellar/go/1.9.1/libexec/src/runtime/proc.go
         0     0% 99.51%      410ms  2.50%  runtime.sysmon /usr/local/Cellar/go/1.9.1/libexec/src/runtime/proc.go
         0     0% 99.51%    15810ms 96.52%  testing.(*B).launch /usr/local/Cellar/go/1.9.1/libexec/src/testing/benchmark.go
(pprof)
```

这显然很不直观，性能分析更好的是使用可视化分析。可以在交互模式下执行 `web` 命令，这样会生成一个 `svg` 文件，然后用浏览器或者其它工具打开。

![profile svg](../pics/golang/profile/pprof.svg)

这个图是 CPU 性能分析的图，这里可以直观的看出哪个地方最消耗 CPU，使用时间越多的，方块面积就越大。而且由于其继承关系清晰可见，我们可以很清楚的看到为什么它会消耗很多 CPU。

这里默认是 `-svg`，还可以设置为 `-pdf` 等，可以用 `go tool pprof -help` 来查看详细配置。

推荐阅读：

* [Profiling Go programs](http://blog.golang.org/profiling-go-programs)
* [Debugging performance issues in Go programs](https://software.intel.com/en-us/blogs/2014/05/10/debugging-performance-issues-in-go-programs)

除了可视化 CPU 性能分析外，同样可以分析内存和阻塞。

### 内存性能分析：

```bash
$ go build -gcflags='-memprofile=/tmp/m.p'
$ go tool pprof --alloc_objects -svg $(go tool -n compile) /tmp/m.p > alloc_objects.svg
$ go tool pprof --inuse_objects -svg $(go tool -n compile) /tmp/m.p > inuse_objects.svg
```

* alloc_objects

![alloc_objects](../pics/golang/profile/alloc_objects.svg)

* inuse_objects

![inuse_objects](../pics/golang/profile/inuse_objects.svg)

### 阻塞性能分析

这里分析的是 `net/http` 包：

```bash
$ go test -run=XXX -bench=ClientServer -blockprofile=/tmp/b.p net/http
$ go tool pprof -svg http.test /tmp/b.p > block.svg
```

![inuse_objects](../pics/golang/profile/block.svg)

# 插曲二：Frame Pointer

[Frame pointer](https://en.wikipedia.org/wiki/Call_stack#Stack_and_frame_pointers) 是整个 Unix/Linux 调试工具链的核心的东西。Frame Pointer 就是一个指向调用栈顶端的寄存器。

Go 从 `1.7` 开始，编译器默认启用 Frame pointers 了。所以像 [gdb](https://sourceware.org/gdb/current/onlinedocs/gdb/)、[perf](https://perf.wiki.kernel.org/index.php/Tutorial) 命令也可以理解 Go 的调用栈，从而可以进行调试分析。

# 方法五：`perf`

对于 Linux 用户来说，[`perf`](http://www.brendangregg.com/perf.html) 是一个非常好的工具。由于现在 Go 已经支持了 Frame Pointer，所以可以和 `-toolexec=` 配合来对 Go 应用进行性能分析。

```bash
$ go build -toolexec="perf stat" cmd/compile/internal/gc
```

我们也可以用 `perf record` 来记录一段性能分析数据。

```bash
$ go build -toolexec="perf record -g -o /tmp/p" cmd/compile/internal/gc
$ perf report -i /tmp/p
```

![perf](https://github.com/davecheney/presentations/raw/master/seven/perf.png)

# 方法六：火焰图 (Flame Graph)

[火焰图(Flame Graph)](http://www.brendangregg.com/flamegraphs.html) 也是性能分析的利器。最初是由 Netflix 的 [Brendan Gregg](https://github.com/brendangregg) 发明并推广的。

**X 轴**显示的是在该性能指标分析中所**占用的资源量**，也就是横向越宽，则意味着在该指标中占用的资源越多，**Y 轴**则是**调用栈的深度**。

有几点需要注意：

* **左右顺序不重要**，X 轴不是按时间顺序发生的，而是**按字母顺序排序的**
* 虽然很好看，但是**颜色深浅没关系**，这是随机选取的。

火焰图可以来自于很多数据源，包括 `pprof` 和 `perf`。

感谢 Uber 提供了火焰图的 Go 的工具，[go-torch](https://github.com/uber/go-torch)，在你提供了 `/debug/pprof` 的情况下，可以自动进行分析处理生成火焰图。

```bash
$ go build -gcflags=-cpuprofile=/tmp/c.p .
$ go-torch $(go tool -n compile) /tmp/c.p
```

![torch](https://github.com/davecheney/presentations/raw/master/seven/torch.svg?sanitize=true)

# 方法七：`go tool trace`

在 Go 1.5 的时候，[Dmitry Vyukov](https://github.com/dvyukov) 在 runtime 里添加了一个新的性能分析工具，[execution tracer profile](https://golang.org/doc/go1.5#trace_command)。

```bash
$ go test -trace=trace.out path/to/package
$ go tool trace [flags] pkg.test trace.out
```

这个工具可以用来分析程序动态执行的情况，并且分析的精度达到纳秒级别：

* goroutine 创建、启动、结束
* gorouting 阻塞、恢复
* 网络阻塞
* 系统调用（syscall）
* GC 事件

这个工具目前介绍的文档不多，<https://golang.org/pkg/runtime/trace/>。只有很少量的文档，或许应该有一些文档、博客啥的描述一下。这里有几个文档可以看看：

* https://docs.google.com/document/u/1/d/1FP5apqzBgr7ahCCgFO-yoVhk4YZrNIDNf9RybngBc14/pub
* https://www.dotconferences.com/2016/10/rhys-hiltner-go-execution-tracer

通过 `-traceprofile=` 来标志生成性能分析文件。

比如这里我们构建包 `cmd/compile/internal/gc`，并生成构建的性能分析数据文件。

```bash
$ go build -gcflags=-traceprofile=/tmp/t.p cmd/compile/internal/gc
$ go tool trace /tmp/t.p
2017/10/23 20:59:09 Parsing trace...
2017/10/23 20:59:10 Serializing trace...
2017/10/23 20:59:10 Splitting trace...
2017/10/23 20:59:11 Opening browser

```

这会打开一个浏览器，显示：

* View trace
* Goroutine analysis
* Network blocking profile
* Synchronization blocking profile
* Syscall blocking profile
* Scheduler latency profile

点进去就可以看到各种分析。

![trace](../pics/golang/profile/trace.jpg)

另外，Dave Cheney 做的 `pkg/profile` 也支持生成 trace profile 了。

```go
import "github.com/pkg/profile"

...

func main() {
        defer profile.Start(profile.TraceProfile).Stop()
        ...
}
```

# 总结

不同的工具可以从不同的角度对你的应用进行分析。一般你不需要非得把上面提及的每个工具都用一遍，但是建议大家熟悉一下上面的工具，先从小的东西开始，当熟悉之后，在真正需要的时候，才可以快速的选择自己所需的工具来诊断问题。
