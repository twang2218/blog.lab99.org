---
layout: post
category: golang
title: 视频笔记：Go 抓包、分析、注入 - John Leon
date: 2017-09-23
tags: [golang, gophercon2016, youtube, notes]
---

<!-- toc -->

# 视频信息

**Packet Capture, Analysis, and Injection with Go**
by John Leon
at GopherCon 2016

{% owl youtube APDnbmTKjgM %}

<https://www.youtube.com/watch?v=APDnbmTKjgM>

代码：<https://github.com/gophercon/2016-talks/tree/master/JohnLeon-PacketCapturingWithGo>
博文：<http://www.devdungeon.com/content/packet-capture-injection-and-analysis-gopacket>

## 什么是抓包

抓包是分析网络上的流量。

有线网络和无线网络不同

有线网络会由交换机根据 MAC 地址决定是否将包转发给你，和你无关的包是不会转发给你，除非用的不是交换机而是古董的 Hub。而无线网络就很开放了，所有的包都无法控制发给谁，因此你是可以听到所有的包的。当然，需要设置为混淆模式，不然本地网络设备会过滤掉不是给自己的包。

抓包不会影响其它通讯，它只是被动监听，不是中间人的干扰。不过可以利用抓包来做一些事情。比如去年参加 [DefCon](https://www.defcon.org/html/defcon-23/dc-23-index.html) 的时候，John 身边的几个俄罗斯的与会者，就写了个东西抓包监听。凡是听到 HTTP 请求，就抢先一步模拟 HTTP 响应，让访问者重定向到某个[NSFW(色情网站)](https://zh.wikipedia.org/wiki/NSFW)上去了。

## 如何应用

* 应用开发：测试、验证加密
* 对 API 进行逆向工程
* 观察背景都是什么样的流量
* 偷取登录信息
* 网络管理
* 查看网络上的恶意的流量（比如是不是有人在扫描你的端口）
* 对犯罪现场进行调查
* DefCon 的一个 [Wall of Sheep](https://www.wallofsheep.com/pages/wall-of-sheep)

## 演讲者研究抓包的动机

* Hacker by nature，就像 Richard Stallman 说的，你不做一遍这个东西，你就无法理解这个东西。
* 总喜欢知道实物的内部是怎么工作的
* 验证实际的认证机制是否真的加密了
* 确保服务器上没有恶意流量
* 理解开放 WiFi 的流量是否安全
* 偷登录信息（当然，合法的偷，比如安全审计）
	* Facebook 很长一段时间都不用 SSL
	* [OKCupid](https://www.okcupid.com/) 也一样
	* <https://httpshaming.tumblr.com>

## 话题概况

* 获得网络设备列表
* 从网络设备抓包
* 保存获得的包到一个文件
* 从文件读取包
* 分层分析包结构
* 创建自定义的层
* 使用 BPF 过滤
* 注入包（发送包）
* 观察流

## 常用工具

* [Wireshark](https://www.wireshark.org/)/[tshark](https://www.wireshark.org/docs/man-pages/tshark.html)：这可能是大家都用过的
* [tcpdump](https://en.wikipedia.org/wiki/Tcpdump): 一些 Linux 下命令行操作的人应该用过
* [Driftnet](http://www.ex-parrot.com/~chris/driftnet/): 只关心网络流量中的图片，会在屏幕上显示所有流量里的图片……😓
* [Firesheep](https://en.wikipedia.org/wiki/Firesheep): Firefox 插件用于截获、分析、插入 http 流量比如 cookie 之类东西的。

## 本讲座的需求

* [libpcap or WinPcap](https://en.wikipedia.org/wiki/Pcap)
	* [libpcap](http://www.tcpdump.org/manpages/pcap.3pcap.html) 是一个 C 库，源自 tcpdump
	* [WinPcap](https://www.winpcap.org) 相当于是 libpcap 移植到 WinPCap 的版本，当然底层抓包实现非常不同。
* Go

### gopacket

* 支持 libpcap，但是也支持其它的，如 [pfring](http://www.ntop.org/products/packet-capture/pf_ring/) 和 [afpacket](http://manual-snort-org.s3-website-us-east-1.amazonaws.com/node7.html#SECTION00253000000000000000)
* <https://github.com/google/gopacket>
* <http://www.devdungeon.com/content/packet-capture-injection-and-analysis-gopacket>

子包：

* `github.com/google/gopacket`
* `github.com/google/gopacket/pcap`
* `github.com/google/gopacket/layers` ：解析包用的最多的就是这个包
* `github.com/google/gopacket/pcapgo`

类型：

* `Decoder`
* `Flow`
* `Layer`
* `Packet`
* `PacketSource`
* `Payload`

## 代码演示

### 获取 pcap 版本及网卡列表

```go
import (
	"fmt"
	"github.com/google/gopacket/pcap"
)
func main() {
	//	获取 libpcap 的版本
	version := pcap.Version()
	fmt.Println(version)
	//	获取网卡列表
	var devices []pcap.Interface
	devices, _ := pcap.FindAllDevs()
}
```

`pcap.Interface` 的定义是

```go
type Interface struct {
	Name	string
	Description string
	Address	[]InterfaceAddress
}
```

`InterfaceAddress` 的定义是：

```go
type InterfaceAddress struct {
	IP	net.IP
	Netmask	net.IPMask
}
```

### 打开网络接口

这是在线捕获分析

```go
handle, _ := pcap.OpenLive(
	"eth0",	// device
	int32(65535),	//	snapshot length
	false,	//	promiscuous mode?
	-1 * time.Second,	// timeout 负数表示不缓存，直接输出
)
defer handle.Close()
```


### 打开捕获的文件

对于一些抓到的包进行离线分析，可以用文件。

```go
handle, _ := pcap.OpenOffline("dump.pcap")
defer handle.Close()
```

### 建立 packet source

```go
packetSource := gopacket.NewPacketSource(
	handle,
	handle.LinkType()
)
```

### 从 packet source 读取抓的包

#### 一个包

```go
packet, _ := packetSource.NextPacket()
fmt.Println(packet)
```

#### 所有包

```go
for packet := range packetSource.Packets() {
	fmt.Println(packet)
}
```

### 过滤

默认是将所有捕获的包返回回来，而很多时候我们需要关注某个特定类型的包，这时候就需要设置过滤器。这里可以用 [Berkeley Packet Filter 的语法](https://biot.com/capstats/bpf.html)：

```go
handle.SetBPFFilter("tcp and port 80")
```

在 C 开发中，你必须独立的撰写 BPF，编译，然后再 attach 进来。而 Go 超方便，一行代码就好了。

#### 例子

* 过滤IP： 10.1.1.3
* 过滤CIDR： 128.3/16
* 过滤端口： port 53
* 过滤主机和端口： host 8.8.8.8 and udp port 53
* 过滤网段和端口： net 199.16.156.0/22 and port
* 过滤非本机 Web 流量： (port 80 and port 443) and not host 192.168.0.1

### 将捕获到的包保存到文件

```go
dumpFile, _ := os.Create("dump.pcap")
defer dumpFile.Close()

//	准备好写入的 Writer
packetWriter := pcapgo.NewWriter(dumpFile)
packetWriter.WriteFileHeader(
	65535,	//	Snapshot length
	layers.LinkTypeEthernet,
)
//	写入包
for packet := range packetSource.Packets() {
	packetWriter.WritePacket(
		packet.Metadata().CaptureInfo,
		packet.Data(),
	)
}
```

### 解析包

#### 列出包的层

```go
for _, layer := range packet.Layers() {
	fmt.Println(layer.LayerType())
}
```

包的分层就像俄罗斯套娃，上一层的 payload 是下一层完整的包，下一层解析完得出的 payload，是更下一层的包。

#### 解析 IP 层

```go
ipLayer := packet.Layer(layers.LayerTypeIPv4)
if ipLayer != nil {
	ip, _ := ipLayer.(*layers.IPv4)
	fmt.Println(ip.SrcIP, ip.DstIP)
	fmt.Println(ip.Protocol)
}
```

#### 解析 TCP 层

```go
tcpLayer := packet.Layer(layers.LayerTypeTCP)
if tcpLayer != nil {
	tcp, _ := tcpLayer.(*layers.TCP)
	fmt.Println(tcp.SrcPort)
	fmt.Println(tcp.DstPort)
}
```

#### 直接解析各层

```go
//	解析 ethernet 层
ethernetPacket := gopacket.NewPacket(
	packet, layers.LayerTypeEthernet, gopacket.Default)  // 复制一份包
//	解析 IP 层
ipPacket := gopacket.NewPacket(
	packet, layers.LayerTypeIPv6, gopacket.NoCopy) // 不复制，所以不要修改
//	解析 TCP 层
tcpPacket := gopacket.NewPacket(
	packet, layers.LayerTypeTCP, gopacket.Lazy)  // 等修改的时候再复制（不是thread safe）
)
```

#### 更快的解析

之前说的都是每次创建一个新的包，除此以外，也可以创建一个，以后每次复用。

```go
//	创建所有所需的变量
var eth layers.Ethernet
var ip4 layers.IPv4
var tcp layers.TCP
parser := gopacket.NewDecodingLayerParser(
	layers.LayerTypeEthernet, &eth, &ip4, &tcp)
decodedLayers := []gopacket.LayerType{}

//	解析
for packet := range packetSource.Packets() {
	parser.DecodeLayers(packet, &decodedLayers)
	for _, layerType := range decodedLayers {
		fmt.Println(layerType)
	}
}
```

这样做的好处是速度很快，因为复用了内存空间。缺点是只能检测定义的包，所以是个权衡。

#### 其它所支持的层

* ARP
* CiscoDiscovery
* DHCP
* DNS
* Dot11
* ICMP
* PPPoE
* USB
* 和其它包里支持的 118 种层

#### 常见的包层

* `packet.LinkLayer()`	//	以太网
* `packet.NetworkLayer()` 	//	网络层，通常也就是 IP 层
* `packet.TransportLayer()`	//	传输层，比如 TCP/UDP
* `packet.ApplicationLayer()`	//	应用层，比如 HTTP 层。
* `packet.ErrorLayer()`	//	……出错了

### 自定义包结构

如果有特殊的协议，无论是未公开的私有协议，还是包里没有提供支持的协议，可以自己定义包的结构以及解析方式。

```go
//	注册自定义的层
var MyLayerType = gopacket.RegisterLayerType(
	12345,				//	唯一的 ID
	"MyLayerType",		//	唯一的名字
	gopacket.DecodeFunc(decodeMyLayer),	//	解析函数（稍后定义）
)

//	定义层的内容
type MyLayer struct {
	Header []byte
	payload []byte
}

//	定义解析函数
func decodeMyLayer(data []byte, p gopacket.PacketBuilder) error {
	p.AddLayer(&MyLayer{data[:4], data[4:]})
	return p.NextDecoder(layers.LayerTypeEthernet)
}

//	定义一些解析包所需的接口
func (m MyLayer) LayerType() LayerType {
	return MyLayerType
}
func (m MyLayer) LayerContents() []byte {
	return m.Header
}
func (m MyLayer) LayerPayload() []byte {
	return m.payload
}

//	然后就可以像其它内置层一样解析这个自定义的包了
decodedPacket := gopacket.NewPacket(
	data,
	MyLayerType,
	gopacket.Default,
)
```

### 构造包

```go
buffer = gopacket.NewSerializeBuffer()
options := gopacket.SerializeOptions{}
gopacket.SerializeLayers(buffer, options, 
	&layers.Ethernet{},
	&layers.IPv4{},
	&layers.TCP{},
	gopacket.Payload([]byte{65, 66, 67}),
)
```

### 发送构造好的包

```go
handle.WritePacketData(buffer.Bytes())
```

### 流和 Endpoint

可以指定一个特定的流的数据，当发现后，会通知你找到了这样的流，当然具体的包还需要你去提取。

```go
someFlow := gopacket.NewFlow(
	layers.NewUDPPortEndpoint(1000),
	layers.NewUDPPortEndpoint(500))

t := packet.NetworkLayer()	//	Check nil
if t.TransportFlow() == someFlow {
	fmt.Println("UDP 1000 -> 500 found.")
}
```

## 潜在的应用

* 检查在黑名单的 IP
* 给网络服务捣乱啥的，看看是不是可以破坏
* 监控网络流量
* 端口扫描
* 防火墙（有状态和无状态的防火墙对于连接的反应不同，所以可以分析防火墙的情况）
* IDS 入侵检测
* 移动手机应用API的逆向工程
