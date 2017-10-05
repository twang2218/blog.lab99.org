---
layout: post
category: golang
title: 视频笔记：Go 和 syscall - Liz Rice
date: 2017-10-05
tags: [golang, gophercon2017, youtube, notes]
---

<!-- toc -->

# 视频信息

**A Go programmer's guide to syscalls**
by Liz Rice
at GopherCon 2017

{% owl youtube 01w7viEZzXQ %}

<https://www.youtube.com/watch?v=01w7viEZzXQ>

* 幻灯：<https://speakerdeck.com/lizrice/a-go-programmers-guide-to-syscalls>
* 博文：<https://about.sourcegraph.com/go/a-go-guide-to-syscalls>
* 代码：<https://github.com/lizrice/strace-from-scratch>

# 什么是 `syscall`？

> “在电脑中，系统调用（英语：system call），又称为系统呼叫，指运行在用户空间的程序向操作系统内核请求需要更高权限运行的服务。系统调用提供用户程序与操作系统之间的接口。大多数系统交互式操作需求在内核态执行。如设备IO操作或者进程间通信。” - [维基百科](https://zh.wikipedia.org/zh-cn/系统调用)

实际上，你基本上做任何事情的时候，都需要系统调用。

* 访问文件
* 访问设备
* 进程管理
* 通讯
* 时间
* ...

## 即使是简单程序也在使用 `syscall`

无论你是写 C 程序、写 Go 程序，或者哪怕是写 bash 脚本，你实际上都会用到 syscall。举一个简单的 Go 的例子。

**hello.go**

```go
package main

import "fmt"

func main() {
	fmt.Println("Hello, GopherCon!")
}
```

如果我们在 Linux 上构建，并且使用 `strace` 的话，就可以看到发生了多少系统调用了：

```bash
$ go build hello.go
$ strace ./hello
execve("./hello", ["./hello"], [/* 23 vars */]) = 0
arch_prctl(ARCH_SET_FS, 0x52c008)       = 0
sched_getaffinity(0, 8192, [0])         = 8
mmap(0xc000000000, 65536, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xc000000000
munmap(0xc000000000, 65536)             = 0

...

futex(0x52c0b0, FUTEX_WAIT, 0, NULL)    = 0
mmap(NULL, 262144, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f1eef3ac000
write(1, "Hello, GopherCon!\n", 18Hello, GopherCon!
)     = 18
futex(0x52ba58, FUTEX_WAKE, 1)          = 1
futex(0x52b990, FUTEX_WAKE, 1)          = 1
exit_group(0)                           = ?
+++ exited with 0 +++
```

我们看到了海海的 syscall，而这里我们可以关注一下最后的那个 `write()`：

```go
write(1, "Hello, GopherCon!\n", 18Hello, GopherCon!
)     = 18
```

这是最后的系统调用，将字符串输出到了标准输出，`1`。

那么中间都经过了什么？如果我们顺着代码一步步跟踪进去就会看到，`fmt.Println()` 的定义在 `fmt/print.go` 中：

```go
func Println(a ...interface{}) (n int, err error) {
	return Fprintln(os.Stdout, a...)
}
```

`Fprintln()` 的定义为：

```go
func Fprintln(w io.Writer, a ...interface{}) (n int, err error) {
	p := newPrinter()
	p.doPrintln(a)
	n, err = w.Write(p.buf)
	p.free()
	return
}
```

注意到这里最后调用的是 `w.Write()`，而 `w` 实际上是前面的 `os.Stdout`，其定义在 `os/file.go` 中，为：

```go
	Stdout = NewFile(uintptr(syscall.Stdout), "/dev/stdout")
```

这里的 `NewFile()` 会返回一个文件：

```go
// "os/file_unix.go"
func newFile(fd uintptr, name string, pollable bool) *File {
	fdi := int(fd)
	if fdi < 0 {
		return nil
	}
	f := &File{&file{
		pfd: poll.FD{
			Sysfd:         fdi,
			IsStream:      true,
			ZeroReadIsEOF: true,
		},
		name: name,
	}}
  ...
  return f
}
```

然后去看这个 `file` 的具体实现：

```go
func (f *File) write(b []byte) (n int, err error) {
	n, err = f.pfd.Write(b)
	runtime.KeepAlive(f)
	return n, err
}
```

进一步去看 `f.pfd.Write()` 的实现：

```go
func (fd *FD) Write(p []byte) (int, error) {
	if err := fd.writeLock(); err != nil {
		return 0, err
	}
	defer fd.writeUnlock()
	if err := fd.pd.prepareWrite(fd.isFile); err != nil {
		return 0, err
	}
	var nn int
	for {
		max := len(p)
		if fd.IsStream && max-nn > maxRW {
			max = nn + maxRW
		}
		n, err := syscall.Write(fd.Sysfd, p[nn:max])
		if n > 0 {
			nn += n
		}
		if nn == len(p) {
			return nn, err
		}
		if err == syscall.EAGAIN && fd.pd.pollable() {
			if err = fd.pd.waitWrite(fd.isFile); err == nil {
				continue
			}
		}
		if err != nil {
			return nn, err
		}
		if n == 0 {
			return nn, io.ErrUnexpectedEOF
		}
	}
}
```

这里我们就看到了最终的 `syscall`：

```go
		n, err := syscall.Write(fd.Sysfd, p[nn:max])
```

Go 的系统调用使用了 `syscall` 这个标准库的包。包里有很多操作系统相关的代码，以及特定构架的自动生成的代码。

* 系统相关的代码：
  * 如： <https://golang.org/src/syscall/syscall_linux.go>
* 自动生成的代码：
  * 如：<https://golang.org/src/syscall/zsyscall_linux_386.go>

对于 Linux 而言，现在大约有 `330` 多个系统调用。

## 如何进行的 `syscall`

如何进行系统调用？和往常一样，先查 `man`：

> `syscall()` saves CPU registers before making the system call, restores the registers upon return from the system call, and stores any error code returned by the system call in `errno(3)` if an error occurs.

就是说调用 `syscall` 之前先保存环境；`syscall` 返回之后，恢复环境；错误代码在 `errno` 中。

而实际的调用接口，可以参考：<http://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/>

以 `sys_write` 调用为例，系统调用号放到了 `%rax` 之中，文件的 `fd` 放到了 `%rdi` 中，要写入的 `buf` 放到了 `%rsi` 中，写入长度放到了 `%rdx` 之中。

当执行了 `syscall()` 后，开始进入 Trap，然后进入内核态，开始执行对应的系统调用的代码。而系统调用的返回值，会放到了 `%rax` 之中。

当然，这里是以 `amd64` 架构的 Linux 系统举例，不同的系统，无论是指令集、还是调用方式都会不同。

## `syscall` 可以作为一个兼容层

可以把 `syscall` 作为一层可移植层。因为我们可以通过实现一组 `syscall` 接口，来模拟 Linux。

这个概念不新鲜，比如 [Windows Subsystem for Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux)、以及 FreeBSD 的 [Linux emulation layer](https://www.freebsd.org/doc/handbook/linuxemu-lbc-install.html)，还有 [L4Linux](https://en.wikipedia.org/wiki/L4Linux) 都是这么做的。

## 观察程序的 `syscall` 调用情况

* Linux 下的 `strace`：
  * `strace -c` 汇总输出。

比如刚才的那个 `hello` 程序：

```bash
$ strace -c ./hello
Hello, GopherCon!
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
  0.00    0.000000           0         1           write
  0.00    0.000000           0         8           mmap
  0.00    0.000000           0         1           munmap
  0.00    0.000000           0       114           rt_sigaction
  0.00    0.000000           0         6           rt_sigprocmask
  0.00    0.000000           0         2           clone
  0.00    0.000000           0         1           execve
  0.00    0.000000           0         2           sigaltstack
  0.00    0.000000           0         1           arch_prctl
  0.00    0.000000           0         1           gettid
  0.00    0.000000           0         3           futex
  0.00    0.000000           0         1           sched_getaffinity
  0.00    0.000000           0         1           readlinkat
------ ----------- ----------- --------- --------- ----------------
100.00    0.000000                   142           total
```

换句话说，如果我们需要运行这个程序的话，只要有个内核可以实现这`13`个系统调用，就够了。😼

不过 `strace` 是怎么做到监听系统调用的呢？

实际上 `strace` 使用了 Linux 的另一个系统调用，`ptrace`。`ptrace` 可以让一个进程监听、控制另一个进程的执行，检查、改变该进程的内存、寄存器等等。这经常用于断点调试、和系统调用跟踪。很暴力、很强大……💪

# 用 Go 写一个 `strace`

既然 `strace` 是使用的 `ptrace` 系统调用，而 Go 可以直接进行系统调用，并且封装了一些 `ptrace` 的调用，那么我们其实可以用 Go 实现一个 `strace`。

## 调用另一个命令

```go
//	main.go
package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	fmt.Printf("Run %v\n", os.Args[1:])

	cmd := exec.Command(os.Args[1], os.Args[2:]...)
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout

	cmd.Start()
	err := cmd.Wait()
	if err != nil {
		fmt.Printf("wait() returned: %v\n", err)
	}
}
```

这里我们使用 `exec.Command()` 来建立要执行的命令，将系统的标准输入、输出、错误对接过去，并且把参数传递过去，然后开始执行。

```bash
$ ./strace ../hello/hello abcd
Run [../hello/hello abcd]
Hello, GopherCon!
```

## 添加 `ptrace` 支持

添加 `ptrace` 支持非常简单，设置 `cmd.SysProcAttr` 即可。

```go
  ...
	cmd.Stdout = os.Stdout
  //  设置 Ptrace 为 true
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Ptrace: true,
	}
  ...

  //  为了更明显的看出效果，在退出前等待一会儿
	time.Sleep(time.Second * 2)
}
```

这次再执行，就会发现，被调用的程序暂停了一段时间，然后才继续执行：

```bash
$ ./strace ../hello/hello
Run [../hello/hello]
wait() returned: stop signal: trace/breakpoint trap
# <- 这里等候了2秒
$ Hello, GopherCon!
```

由于启用了 `ptrace`，当 `hello` 被加载后，并没有立刻执行，而是控制权回到了我们这个程序，就像是断点一样。所以 `hello` 暂停了一段时间。而当 `time.Sleep()` 结束后，我们的主程序退出，和 `hello` 断开了这个控制联系，于是 `hello` 就继续执行，于是看到了后面的 `Hello, GopherCon!` 了。

## 打印断点的寄存器变量

既然是断点，控制权回到主程序，那么我们实际上可以打印被调试程序的寄存器变量：

```go
	pid := cmd.Process.Pid
	var regs syscall.PtraceRegs
	if err = syscall.PtraceGetRegs(pid, &regs); err != nil {
		panic(err)
	}

	fmt.Printf("%#v\n", regs)
```

然后再次执行我们的 strace，就可以看到寄存器信息了：

```bash
$ ./strace ../hello/hello
Run [../hello/hello]
wait() returned: stop signal: trace/breakpoint trap
syscall.PtraceRegs{R15:0x0, R14:0x0, R13:0x0, R12:0x0, Rbp:0x0, Rbx:0x0, R11:0x0, R10:0x0, R9:0x0, R8:0x0, Rax:0x0, Rcx:0x0, Rdx:0x0, Rsi:0x0, Rdi:0x0, Orig_rax:0x3b, Rip:0x452060, Cs:0x33, Eflags:0x200, Rsp:0x7ffe862afdf0, Ss:0x2b, Fs_base:0x0, Gs_base:0x0, Ds:0x0, Es:0x0, Fs:0x0, Gs:0x0}
$ Hello, GopherCon!
```

`hello` 所有断点位置的寄存器信息我们就都可以看到了。还记得我们之前说过的系统调用都用了哪些寄存器么？`%rax` 应该存储的是系统调用号的，而这里的 `Rax:0x0`，经过了解后，实际的断点位置的系统调用存在于 `Orig_rax:0x3b`。`0x3b`，也就是 `59` 号系统调用，查询之前的表格，可以知道在 Linux 里对应的是 `sys_execve`。

## 输出系统调用名称

既然知道了系统调用号，可不可以直接打印出系统调用名字？在 Go 中，这很容易，使用 `github.com/seccomp/libseccomp-golang` 即可，这里我们进行一层封装，封装为 `syscallCounter`，然后在我们的 `main.go` 中调用：

```go
	var ss syscallCounter
	ss = ss.init()

	name := ss.getName(regs.Orig_rax)
	fmt.Printf("%s\n", name)
```

然后再次运行，就会看到输出的名字 `execve` 了：

```bash
$ ./strace ../hello/hello
Run [../hello/hello]
wait() returned: stop signal: trace/breakpoint trap
execve
$ Hello, GopherCon!
```

## 输出所有的系统调用

这只是碰到的第一个 `syscall`，如何才能显示接下来的系统调用呢？

`ptrace` 允许指定在下一个系统调用的时候暂停，所以只需要在打印 `syscall` 名字之后，加入这部分设置，然后整体循环就好了。

```go

	for {
		//	打印断点寄存器值
		if err = syscall.PtraceGetRegs(pid, &regs); err != nil {
			panic(err)
		}
		// fmt.Printf("%#v\n", regs)

		//	输出系统调用的名字
		var ss syscallCounter
		ss = ss.init()
		name := ss.getName(regs.Orig_rax)
		fmt.Printf("%s\n", name)

		//	要求在下一个系统调用的时候暂停
		if err := syscall.PtraceSyscall(pid, 0); err != nil {
			panic(err)
		}

		//	开始等待下一个系统调用
		if _, err = syscall.Wait4(pid, nil, 0, nil); err != nil {
			panic(err)
		}
	}
```

这次我们再执行我们的 strace，就会发现所有的系统调用都打印出来了：

```go
$ ./strace ../hello/hello
Run [../hello/hello]
wait() returned: stop signal: trace/breakpoint trap
execve
arch_prctl
arch_prctl
sched_getaffinity
sched_getaffinity
mmap
mmap
munmap

...

futex
futex
readlinkat
readlinkat
mmap
mmap
write
Hello, GopherCon!
write
exit_group
panic: no such process

goroutine 1 [running]:
main.main()
        /vagrant/syscall/strace/main.go:36 +0x530
```

不过注意到最后出现了 `panic: no such process` 了么？这是因为 `hello` 程序执行完后退出了，所以自然我们的 `main()` 程序无法继续取得其寄存器的值了。

怎么才能不 `panic` 呢？很简单嘛，我们在`36`行那里，去掉 `panic()`，直接 `break` 出循环即可。然后就没有 `panic` 啦。😸

## 其实 `ptrace` 会停两次……

如果仔细观察之前的输出：

```bash
...

readlinkat
readlinkat
mmap
mmap
futex
futex
futex
futex
write
Hello, GopherCon!
write
exit_group
```

注意到貌似每个系统调用都成对出现么？特别是 `Hello, GopherCon!` 的前后各夹了一个 `write`。真的这么整齐的都是两次系统调用么？不是的。其实**系统调用只发生了一次**，不过我们的程序却**停了两次**。

如果仔细看 `ptrace` 的 [manpage](http://man7.org/linux/man-pages/man2/ptrace.2.html) 的话，翻到后面，会发现它提到，在被监听程序进入 `syscall` 之前，会停一下，叫做 `syscall-enter-stop`，而在从 `syscall` 返回后，还会停一下，叫做 `syscall-exit-stop`。所以我们实际上对于每个系统调用都输出了两边名字，而且一次是系统调用之前、一次是之后。所以就出现了三明治形式的输出了：

```bash
write
Hello, GopherCon!
write
```

比较郁闷的是，仅从返回结果来看，我们没有办法区分哪次是 `syscall-enter-stop`，哪次是 `syscall-exit-stop`。所以我们只能在外面做一个 tik-tok 的标志位，来表明到底是啥。

我们再次修改程序，添加一个 `exit` 标志位。

```go
	//	是否是 syscall-exit-stop 的标志位
	exit := true
	for {
		//	如果是 syscall-exit-stop 就打印
		if exit {
			//	打印断点寄存器值
			if err := syscall.PtraceGetRegs(pid, &regs); err != nil {
				break
			}
			// fmt.Printf("%#v\n", regs)

			//	输出系统调用的名字
			var ss syscallCounter
			ss = ss.init()
			name := ss.getName(regs.Orig_rax)
			fmt.Printf("%s\n", name)
		}

		//	要求在下一个系统调用的时候暂停
		if err := syscall.PtraceSyscall(pid, 0); err != nil {
			panic(err)
		}

		//	开始等待下一个系统调用
		if _, err := syscall.Wait4(pid, nil, 0, nil); err != nil {
			panic(err)
		}

		//	每次循环翻转一下，来表明 enter, exit 这一对状态
		exit = !exit
	}
```

> 注意这里 `exit` 的初始值为 `true`，这是因为第一次停的时候，是 `execve` 系统调用。熟悉 Unix/Linux 程序设计的人应该一下就反应过来了，这是父进程建立子进程的函数/系统调用。当子进程第一次进入用户态的时候，必然是从这个系统调用返回。换句话说，这个 `syscall` 是由父进程发起的，分别在子进程和父进程中返回。因此当 `ptrace` 第一次截获子进程的系统调用事件的时候，一定是**退出**系统调用的状态。

这一次再输出，就会发现成对的系统调用只剩下后半部分了：

```go
$ ./strace ../hello/hello
Run [../hello/hello]
wait() returned: stop signal: trace/breakpoint trap
execve
arch_prctl
sched_getaffinity
mmap
munmap
mmap
mmap

...

clone
rt_sigprocmask
futex
futex
futex
readlinkat
mmap
futex
Hello, GopherCon!
write
```

这回就对了，我们都是在系统调用返回后，才打印该系统调用。因此 `Hello, GopherCon!` 是发生在打印 `write` 之前。

## 汇总系统调用

我们之前看过 `strace -c` 这个汇总的结果，看起来不错。我们这里实现一下。

这里针对 `syscallCounter` 实现一个计数函数 `ss.inc()` 和一个汇总输出函数 `ss.print()`：

```go
//  syscall_counter.go
func (s syscallCounter) inc(syscallID uint64) error {
	if syscallID > maxSyscalls {
		return fmt.Errorf("invalid syscall ID (%x)", syscallID)
	}

	s[syscallID]++
	return nil
}

func (s syscallCounter) print() {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 8, ' ', tabwriter.AlignRight|tabwriter.Debug)
	for k, v := range s {
		if v > 0 {
			name, _ := sec.ScmpSyscall(k).GetName()
			fmt.Fprintf(w, "%d\t%s\n", v, name)
		}
	}
	w.Flush()
}
```

然后在每次打印函数名的地方加入 `ss.inc(regs.Orig_rax)` 即可。

```go
func main() {
	fmt.Printf("Run %v\n", os.Args[1:])

	//	创建调用的命令
	cmd := exec.Command(os.Args[1], os.Args[2:]...)
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	//	启用 ptrace
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Ptrace: true,
	}

	//	启动程序
	cmd.Start()
	err := cmd.Wait()
	if err != nil {
		fmt.Printf("wait() returned: %v\n", err)
	}

	pid := cmd.Process.Pid
	var regs syscall.PtraceRegs
	var ss syscallCounter
	ss = ss.init()

	//	是否是 syscall-exit-stop 的标志位
	exit := true
	for {
		//	如果是 syscall-exit-stop 就打印
		if exit {
			//	打印断点寄存器值
			if err := syscall.PtraceGetRegs(pid, &regs); err != nil {
				break
			}
			// fmt.Printf("%#v\n", regs)

			//	输出系统调用的名字
			name := ss.getName(regs.Orig_rax)
			fmt.Printf("%s\n", name)

			//	对系统调用计数
			ss.inc(regs.Orig_rax)
		}

		//	要求在下一个系统调用的时候暂停
		if err := syscall.PtraceSyscall(pid, 0); err != nil {
			panic(err)
		}

		//	开始等待下一个系统调用
		if _, err := syscall.Wait4(pid, nil, 0, nil); err != nil {
			panic(err)
		}

		//	每次循环翻转一下，来表明 enter, exit 这一对状态
		exit = !exit
	}

	//	输出系统调用汇总
	ss.print()
}
```

这一次再来输出看看。

```go
$ ./strace ../hello/hello
Run [../hello/hello]
wait() returned: stop signal: trace/breakpoint trap
execve
arch_prctl
sched_getaffinity
mmap

...

readlinkat
futex
mmap
Hello, GopherCon!
write
          1|write
          8|mmap
          1|munmap
        114|rt_sigaction
          8|rt_sigprocmask
          3|clone
          1|execve
          2|sigaltstack
          1|arch_prctl
          1|gettid
          3|futex
          1|sched_getaffinity
          1|readlinkat
```

这次就可以看到汇总数据了。😁

# syscall 与系统安全

* 对于微服务而言，每个服务只会执行很少一部分功能
* 对于安全而言，则追求的是**最小权限**的原则

从前面的输出可以看到这个 `hello` 程序只需要十几个 `syscall`，那么对于拥有 `330` 多个 `syscall` 的 Linux 内核而言，绝大多数的系统调用我们都不需要。更何况现在我们已经了解到 `ptrace` 这个系统调用是非常危险的，不应该允许不需要的程序有这个系统调用的能力。

那么或许我们可以通过约束，限定这个 `hello` 只可以用这十几个系统调用，其它的系统调用都不允许。这样我们就可以**缩小攻击面积**，以满足**最小权限**的安全需求。

对于传统的臃肿的应用而言，可能意义不大，因为应用可能会什么都干，导致用了很多系统调用。但是对于微服务而言，每个服务都很小，只做特定的事情，那么其系统调用的使用就会被限定在一个很小的范围。那么如果可以进行这种系统调用的约束，我们就可以提高系统的安全性。

[seccomp](https://en.wikipedia.org/wiki/Seccomp) 可以让我们做这个事情，在 docker 中甚至直接[集成了 seccomp 的安全约束](https://docs.docker.com/engine/security/seccomp/)，因此我们可以结合 Docker 来约束微服务的细化的系统调用权限。

```bash
$ docker run --security-opt seccomp=/path/sc_profile.json hello-world
```

这东西的缺点是太长了，比如看一下这个默认配置的文件：<https://github.com/moby/moby/blob/master/profiles/seccomp/default.json>

还有更长的，比如 Jessie Frazelle(Docker Queen) 做的那个在 Docker 中运行 Chrome 的镜像所需要的 seccomp 配置：<https://github.com/jessfraz/dotfiles/blob/master/etc/docker/seccomp/chrome.json>

这没有个基础还真写不了，或许这就是安全公司存在的原因之一吧……😎

## 程序中使用 seccomp 配置

我们可以直接指定 `seccomp` 的配置。我们添加一个 `disallow()` 函数，来禁止某个 syscall。

```go
func disallow(sc string) {
	id, err := sec.GetSyscallFromName(sc)
	if err != nil {
		panic(err)
	}

	filter, _ := sec.NewFilter(sec.ActAllow)
	filter.AddRule(id, sec.ActErrno.SetReturnCode(int16(syscall.EPERM)))
	filter.Load()
}
```

然后我们在 `main()` 中执行 `hello` 前，禁用一个 syscall，假设我们禁用 `write`：

```go
func main() {
	fmt.Printf("Run %v\n", os.Args[1:])

	//	禁用 write 系统调用
	disallow("write")

	//	创建调用的命令
	cmd := exec.Command(os.Args[1], os.Args[2:]...)
...
}
```

然后再次执行的时候，发现什么系统调用都没输出：

```bash
$ ./strace ../hello/hello
Run [../hello/hello]
```

为什么连除了 `write` 的系统调用都没有输出呢？因为打印那些字符串到屏幕的过程，也是通过调用 `write` 来实现的。而这个加载的 `seccomp` 的安全配置，是对当前进程有效的（当然，`hello` 执行后也会集成该配置），那么父进程自然也不能通过 `write` 系统调用打印输出了，我们貌似把自己也给禁了……😅

好吧，这样子我们根本啥都看不见，来换一个系统调用禁止一下。这次我们换个命令，不用 `hello` 了，用 `echo hello`。然后用我们的 strace 看看都有啥系统调用：

```bash
        1|read
        1|write
        3|open
        5|close
        4|fstat
        7|mmap
        4|mprotect
        1|munmap
        3|brk
        3|access
        1|execve
        1|arch_prctl
```

嗯，这里看 `open` 不顺眼，就禁用它了。

```go
	//	禁用 open 系统调用
	disallow("open")
```

构建后，再次运行：

```bash
$ ./strace echo hello
Run [echo hello]
wait() returned: stop signal: trace/breakpoint trap
execve
brk
access
mmap
access
open
open
stat
open
stat
open
stat
open
stat
echo: error while loading shared libraries: libc.so.6: cannot open shared object file: Operation not permitted
writev
        5|open
        4|stat
        1|mmap
        1|brk
        1|writev
        2|access
        1|execve
```

这里我们看到了 `cannot open shared object file: Operation not permitted` 的报错，这就是由于我们禁止了 `open` 系统调用，从而导致 `echo hello` 进行该系统调用的时候，出错了。而且可以注意到，`echo hello` 的内部有错误处理，尝试了好几次才最后报错退出的。
