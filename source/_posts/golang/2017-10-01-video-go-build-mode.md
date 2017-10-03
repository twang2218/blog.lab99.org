---
layout: post
category: golang
title: 视频笔记：Go 的构建模式 - David Crawshaw
date: 2017-10-01
tags: [golang, gophercon2017, youtube, notes]
---

<!-- toc -->

# 视频信息

**Go Build Modes**
by David Crawshaw, Google
at GopherCon 2017

{% owl youtube x-LhC-J2Vbk %}

<https://www.youtube.com/watch?v=x-LhC-J2Vbk>

# 什么是 Build Mode？

**build mode** 用于指导编译器如何创建可执行二进制文件。越多的执行方式，就意味着可以让 Go 程序运行于更多的位置。

# Go 的八种 Build Mode

* `exe` (静态编译)
* `exe` (动态链接 `libc`)
* `exe` (动态链接 `libc` 和非 Go 代码)
* `pie` 地址无关可执行文件（安全特性）
* `c-archive` C 的静态链接库
* `c-shared` C 的动态链接库
* `shared` Go 的动态链接库
* `plugin` Go 的插件

## `exe` （静态编译）

这个是大家最喜欢的，所有的代码都构建到一个可执行文件了。

```bash
CGO_ENABLED=0 go build hello.go
```

这是大家使用 Go 最喜欢的构建方式。所有的依赖都构建到了一个二进制文件了，没有任何外部依赖，可执行文件直接调用 `syscall` 和内核通讯。

这里使用 `CGO_ENABLED=0` 来约束不使用任何 `CGO` 的部分，这样不会依赖 `libc` 这类库。

## exe (用 libc)

这样的可执行文件大部分都是静态编译，只不过使用了 `libc` 动态链接库，因此像一些 net 包的操作，比如 DNS 查询、`os/user` 的用户名查询等等，这些会使用系统提供的 `libc` 动态链接库。

其好处是，可以利用系统特定的实现，保证行为和系统一致。

## exe (动态链接 `libc` 和非 Go 代码)

当程序编译的时候，所有 Go 代码自然都被编译为 object 文件，而所有非 Go 的代码，也可以被被其编译器（如 C, Fortran 等）编译为 object 文件，而这些非 Go 代码可以被 `cgo` 调用。

当程序被连接(link)的时候，这些非 Go 代码可以选择被编译进最终的二进制文件中，也可以选择动态链接，在运行时加载。

## `pie` - Position Independent Executables

这是构建运行地址无关的二进制可执行文件的形式，这是一种安全特性，可以在支持 PIE 的操作系统中，让可执行文件在加载时，每次的地址都是不同的。避免已知地址的跳跃式的攻击。

这种方式和 exe 基本一样，将来可能会成为默认。

## `c-archive` C 的静态链接库

从这里开始，和前面构建可执行文件不同了。这里构建的是供 C 程序调用的库。更准确一些的说，这里是把 Go 程序构建为 archive (`.a`) 文件，这样 C 类的程序可以静态链接 `.a` 文件，并调用其中代码。

* `hello.go`

```go
package main

import "fmt"
import "C"

func main() {}

//export Hello
func Hello() {
	fmt.Println("Hello, world.")
}
```

> 注意这里的 `//export Hello`，这是约定，所有需要导出给 `C` 调用的函数，必须通过注释添加这个构建信息，否则不会构建生成 C 所需的头文件。

然后我们构建这个 `hello.go` 文件：

```bash
go build -buildmode=c-archive hello.go
```

构建后，会生成两个文件，一个是静态库文件 `hello.a`，另一个则是 C 的头文件 `hello.h`。

```bash
hello.a:  current ar archive random library
hello.h:  c program text, ASCII text
```

在所生成的 `hello.h` 的头文件中，我们可以看到 Go 的 `Hello()` 函数的定义：

```c
#ifdef __cplusplus
extern "C" {
#endif


extern void Hello();

#ifdef __cplusplus
}
#endif
```

然后我们可以在 `hello.c` 中引用头文件，并使用 Go 编译的静态库：

```c
#include "hello.h"

int main(void) {
  Hello();
  return 0;
}
```

然后，构建 C 程序：

```bash
cc hello.a hello.c -o hello
```

最后执行：

```bash
$ ./hello
Hello, world.
```

## `c-shared` C 的动态链接库

和前一个例子不同的地方是，这将用 Go 代码创建一个动态链接库（Unix: `.so`/Windows `.dll`），然后用 C 语言程序动态加载运行。

Go 和 C 语言的代码和上面是一样的，但是构建过程不同：

```bash
go build -buildmode=c-shared -o hello.so hello.go
```

这里我们使用了 `-buildmode=c-shared`，以构建 C 所支持的动态链接库。

> 注：需要注意的是，这里明确指定了 `-o hello.so`，这里我和演讲者不同，如果不指定输出文件名，那么默认会使用 `hello` 作为文件名，导致后续的操作找不到 `hello.so` 文件。

这次也生成了两个文件，一个是 `hello.so`，一个是 `hello.h`：

```bash
hello.h:  c program text, ASCII text
hello.so: Mach-O 64-bit dynamically linked shared library x86_64
```

然后，编译对应的 C 程序：

```bash
cc hello.c hello.so -o hello
```

如果对比 `c-archive` 例子和 `c-shared` 例子中的 `hello` 二进制可执行文件的大小，就会发现 `c-shared` 的例子的 `hello` 要小很多：

```bash
# c-archive
-rwxr-xr-x  1 taowang  staff   1.5M  3 Oct 17:51 hello

# c-shared
-rwxr-xr-x  1 taowang  staff   8.2K  3 Oct 19:17 hello
```

这是因为前者，将 Go 的代码静态编译进了 C 的程序中；而后者，则是动态链接，C 的可执行文件内不包含我们写的 Go 的代码，所有这部分函数都在动态链接库 `hello.so` 中。

```bash
-rw-r--r--  1 taowang  staff   2.2M  3 Oct 19:17 hello.so
```

因此，执行的时候，我们除了需要 `hello` 这个二进制可执行文件外，我们还需要 `hello.so` 这个动态链接库。如果默认的 `LD_LIBRARY_PATH` 包含了当前目录，并且 `hello.so` 就在当前目录，那么可以直接：

```bash
$ ./hello
Hello, world.
```

否则，如果提示找不到 `hello.so`，如：

```
dyld: Library not loaded: hello.so
```

那可以手动指定 `LD_LIBRARY_PATH` 变量，告诉操作系统到哪里去寻找动态链接库：

```bash
# On Linux
$ LD_LIBRARY_PATH=. ./hello
Hello, world.

# On macOS
$ DYLD_LIBRARY_PATH=. ./hello
Hello, world.
```

### 为什么会需要动态链接？

从开始使用 Go 我们就反反复复的听到人说 Go 的静态链接如何方便，既然如此，那么我们为什么需要动态链接？

因为动态链接可以在运行时需要的时候，由程序决定加载，也可以在不需要的时候卸载，这样可以节约内存资源。

```c
#include <dlfcn.h>
#include <stdio.h>

int main(void) {
  void* lib = dlopen("hello", 0);
  void (*fn)() = dlsym(lib, "Hello");

  if (!fn) {
    fprintf(stderr, "no fn: %s\n", dlerror());
    return 1;
  }
  //  Calls Hello();
  fn();
  return 0;
}
```

这里我们使用 `dlopen()` 来加载库，然后用 `dlsym()` 来加载符号（函数）到一个函数指针，然后我们调用该函数指针 `fn()`。

## `shared` Go 的动态链接库

`shared` 模式和 `c-shared` 有些相似，都是构建一个动态链接库，以便在运行时加载。所不同的是 `shared` 并非构建 C 语言的动态链接库，而是专门为 Go 可执行文件构建动态链接库。

> macOS 下目前不支持 `shared` 模式。

这次还是 `hello.go`，不过稍有不同。

```go
package main

import "fmt"

func main() {
	fmt.Println("Hello, World!")
}
```

这里就是独立的一个文件，一个 `main()`，执行后打印 `Hello, World`。我们可以像以前一样用 `exe` 模式构建，然后执行。不过这次我们用一种不同的方式构建。

```bash
go install -buildmode=shared std
go build -linkshared hello.go
```

这里我们首先把 Go 标准库 `std` 构建并安装到 `$GOPATH/pkg` 下，然后使用 `-linkshared` 来构建 `hello.go`。

执行结果和前面一样，但是如果仔细观察生成的文件，就会发现和前面很不同。

```bash
$ ls -l hello
-rwxr-xr-x 1 root root 16032 Oct  3 13:27 hello
```

可以看到这个 Hello World 程序只有十几KB大小。对于 C 程序员来说，这没啥惊讶的，因为就应该这么大啊。但是对于 Go 程序员来说，这就是很奇怪了，因为一般不都得 7~8MB 么？

其原因就是使用了动态链接库，所有标准库部分，都用动态链接的办法来调用，构建的二进制可执行文件中只包含了程序部分。C 程序构建的 Hello World 之所以小，也是因为动态链接的原因。

如果我们查阅程序所调用的库就可以看到具体情况：

```bash
$ ldd hello
        linux-vdso.so.1 (0x00007ffed3d4e000)
        libstd.so => /usr/local/go/pkg/linux_amd64_dynlink/libstd.so (0x00007f608c409000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f608c06a000)
        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007f608be66000)
        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f608bc49000)
        /lib64/ld-linux-x86-64.so.2 (0x00007f608e866000)
```

如果我们进一步去查看 `libstd.so`，就会看到一个巨大的动态链接库，这就是 Go 的标准库：

```bash
-rw-r--r-- 1 root root 37M Oct  3 13:27 /usr/local/go/pkg/linux_amd64_dynlink/libstd.so
```

当然，要使用这个模式需要很多准备工作，所有的动态链接库都需要在指定的位置，版本都必须兼容等等，所以我们一般不常用这个模式。

## `plugin` Go 的插件

插件形式和 `c-shared`、`shared` 相似，都是构建一个动态链接库，和 `shared` 一样，这是构建一个 Go 专用的动态链接库，而和 `shared` 不同的是，动态链接库并非在程序启动时加载，而是由程序内决定何时加载和释放。

> 这是个新的东西，所以意味着可能不能用😓……，当然如果用的对的话，应该还可以用。

我们创建一个 plugin，`myplugin.go`：

```go
package main

import "fmt"

func Hello() {
  fmt.Println("Hello, World!")
}
```

可以看到，这和最初那个静态链接库的性质相似。不过不同的是，这里既没有 `import "C"`，也没有 `//export Hello`，而且也没有 `func main()`。因为这里不需要，我们是 Go 调用 Go 的代码，因此很多东西都省了。

调用代码这么写：

```go
package main

import "plugin"

func main() {
	//	加载 myplugin 库
	p, err := plugin.Open("myplugin.so")
	if err != nil {
		log.Fatal(err)
	}
	//	取得 Hello 函数
	fn, err := p.Lookup("Hello")
	if err != nil {
		log.Fatal(err)
	}
	//	调用函数
	fn.(func())()
}
```

可以看到，这个逻辑上，和 `hello-dyn.c` 很相似。`plugin.Open()` 有点儿像 `dlopen()`；而 `p.Lookup()` 有点儿像 `dlsym()`。实际上也是如此，底层实现的时候就是调用的这两个函数。

注意这里的 `fn.(func())()`，`p.Lookup()` 返回的是一个 `interface{}`，因此这里需要转型为具体函数类型。

用下面的命令构建：

```bash
go build -buildmode=plugin myplugin.go
go build runplugin.go
```

前者会生成一个 `myplugin.so`，后者会生成调用者 `runplugin`。

```bash
-rw-r--r-- 1 root root 3.8M Oct  3 13:58 myplugin.so
-rwxr-xr-x 1 root root 3.5M Oct  3 13:58 runplugin
```

# 优缺点

* `exe` (静态编译)
  * Pros:
    * 全部集成，不需要任何依赖
    * 非常适合超小型的容器环境
    * 很容易跨不同 Linux 发行版
* `exe` (动态链接 `libc`)
  * Pros:
    * 可以利用系统功能，比如 DNS 查询。
    * 可以通过 `libc` 直接使用系统配置。
  * Cons:
    * 依赖用户空间的执行环境
* `exe` (动态链接 `libc` 和非 Go 代码)
  * Pros:
    * 可以直接在 Go 程序中使用非 Go 的代码
    * 方便和老的系统集成
  * Cons:
    * 构建变得更加复杂
    * C 不是 Go
    * 更容易出问题。
      * 所有 Go 可能出问题地方
      * 所有 C 可能出问题的地方
      * 所有 Go <-> C 之间通讯可能出问题的地方
* `pie` 地址无关可执行文件（安全特性）
  * Pros:
    * 和 `exe` 一样
    * 让系统更难攻击
  * Cons:
    * 二进制会更大一些(bug, will be fixed)
    * 大约会有 `~1%` 的性能损失
* `c-archive` C 的静态链接库
  * Pros:
    * 可以让 Go 集成到现有的 C 程序中
    * 事实上，这就是 Go 在 iOS 上的工作方式
    * 非常适用于已存在的非 Go 环境的构建
  * Cons:
    * 跨语言调用会比较麻烦
* `c-shared` C 的动态链接库
  * Pros:
    * 比较方便 Go 集成进现有的 C 程序中
    * 可以在运行时加载
    * 这是目前 Go 在 Android 下的工作方式（Java 的 `System.load()`）
  * Cons:
    * 跨语言调用会比较麻烦
    * 想想 Android 的环境，可能出问题的面积更大了：
      * Go 可能出问题的地方
      * C 可能出问题的地方
      * Java 可能出问题的地方
      * 所有它们之间通讯可能出问题的地方……😱
* `shared` Go 的动态链接库
  * Pros:
    * 多个可执行文件可以共享动态链接库，可以降低系统总的体积。
    * 一般操作系统厂商会比较青睐于这种方式，可以让整个系统的体积降低。
      * 事实上，这就是 **Canonical(Ubuntu)** 力推实现的方式
    * 可以降低系统体积，不过现在存储空间一般不是问题
    * 可以降低内存，可以在内存中共享动态链接库代码(如果动态链接库的 loader 足够聪明的话)
  * Cons:
    * 依赖管理、以及发布是非常难得
      * 不过一般操作系统厂商已经有成熟的发布系统了
* `plugin` Go 的插件
  * Pros:
    * 在运行时 Go 程序加载其它 Go 程序
    * 对于复杂应用来说，允许不同部分在不同时间构建
  * Cons:
    * 构建比较复杂，部署也会很复杂
    * 如果问演讲者是否该用 `plugin` 模式，答案一般是 **No**。

# 未来

还有很多地方需要改进。

* `c-shared`：目前不支持 Windows（可能），macOS（部分支持）
* `shared`：目前不支持 macOS
* `plugin`：目前不支持 macOS、Windows
* `plugin`：或许可以将 `runtime` 从插件中移除以获得更小的可执行文件
