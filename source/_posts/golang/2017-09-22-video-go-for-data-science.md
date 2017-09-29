---
layout: post
category: golang
title: 视频笔记：Go 数据科学 - Daniel Whitenack
date: 2017-09-22
tags: [golang, gophercon2016, youtube, notes]
---

<!-- toc -->

# 视频信息

**Go for Data Science**
by Daniel Whitenack
at GopherCon 2016

{% owl youtube D5tDubyXLrQ %}

<https://www.youtube.com/watch?v=D5tDubyXLrQ>

幻灯地址：<https://github.com/dwhitena/slides/tree/master/gophercon2016>

## 什么是 Data Science

* ETL, Data Cleaning, Organization
* Parsing, Extraction of Patterns
* Arithmetic

## Data science 的 struggle

### Integrity

使用 python 经常出现无法预期的结果。

比如这里分别使用 python 和 golang 读取 CSV 的数值，并且求第一列的最大值。

Python 代码

```python
import pandas as pd
cols = [
  'integercolumn',
  'stringcolumn'
]

data = pd.read_csv('example.csv', names=cols)

print data['integercolumn'].max()
```

Go 代码：

```go
f, err := os.Open("example.csv")
if err != nil {
  err = errors.Wrap(err, "Could not open CSV")
  log.Fatal(err)
}

r := csv.NewReader(bufio.NewReader(f))
records, err := r.ReadAll()
if err != nil {
  err = errors.Wrap(err, "Could not parse CSV")
  log.Fatal(err)
}

var intMax int
for _, record := range records {
  intVal, err := strconv.Atoi(record[0])
  if err != nil {
    err = errors.Wrap(err, "Parse failed")
    log.Fatal(err)
  }
  if intVal > intMax {
    intMax = intVal
  }
}
fmt.Println(intMax)
```

正常情况一些都没问题，但是如果数据有缺失，比如某些列值缺失。对于 golang 而言，会很严谨的报错，而 python 的不报错，继续执行。所以时间一久，数据量一大，当发生这种不一致的时候，就没法排障，因为根本不知道哪里出过错误。

比如当三行三列输入给入，而第三行的第一列缺失的时候。

Python 返回：

```bash
$ python example2.py
2.0
```

而 golang 返回

```go
$ go run example2.go
2016/05/12 13:23:53 Parse failed: strconv.ParseInt: parsing "": invalid syntax
exit status 1
```

### 部署

* GCE or AWS
* SciKit
* Numpy
* Pandas

即使写好了觉得很赞的 Data Science 的应用，每次部署的都需要和 Ops 坐下来详细的谈应该用什么云，里面都装什么库，以及都什么版本等等，整个过程会变得相当繁琐和复杂。即使写了一个超长的 Dockerfile 来构建所需的环境，在之后自己进行维护这个镜像也变得不大现实。

而在 golang 中则完全不存在这样的问题，因为 golang 是静态编译，所以只要编译好，所有需要的依赖都在里面了。因此一切一下子就变轻松了。Dockerfile 可以变得超简单：

```Dockerfil
FROM scratch
ADD myservice /myservice
CMD ["/myservice"]
```

## 做一次 Data Science

* 使用 `github.com/google/go-github/github` 包来获取 Github 的 go 项目的信息。
* 使用 `pachyderm` 来组织数据，pachyderm 也是用 Go 写的，并且基于 k8s。有一个 pfs 的类文件系统。

## Arithmetic 和 Visualization

推荐使用 `gonum`

* plot
* graph
* stat
* integrate
* lapack
* unit
* matrix
* mathext
* floats
* blas
* optimize

可以进行矩阵运算(matrix)，也可以画图(plot)。

## Prediction

这里使用线性回归，使用的是 `github.com/sajari/regression` 这个包。

预测，2016年讲座这天会有195个项目建立，2017年的时候将会有 240 个项目建立。

## 其它数据相关的项目

* gophernotes: 交互式的 Go notebooks
* GoLearn: 通用的机器学习
* glow: 分布式计算系统(map reduce)
* GoBot: 专门为传感器和 IoT 准备的 Go的库
* golang 将内部支持多维 slice
* TensorFlow 提供 Go API

Gopher Slack 还有一个 data science 频道
