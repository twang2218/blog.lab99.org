---
layout: post
category: golang
title: 视频笔记：Go 密码学应用 - Daniel Whitenack
date: 2017-09-23
tags: [golang, gophercon2016, youtube, notes]
---

<!-- toc -->

# 视频信息

Go for Crypto Developers
by George Tankersley
at GopherCon 2016

{% owl youtube 2r_KMzXB74w %}

<https://www.youtube.com/watch?v=2r_KMzXB74w>

幻灯地址：<https://speakerdeck.com/gtank/crypto-for-go-developers>
代码：<https://github.com/gtank/cryptopasta>

## Don't write your own crypto

很多人把这句话_误解为_不要使用加密、不要使用任何密码学的技术，因为你不够聪明。**No。完全不是这个意思**。

这句话是说**不要试图去发明创造那些加密类的算法**。因为你不大可能会创造一个超过 AES 的加密算法、也不大可能会创造一个比 SHA 更好的 hash 算法。所以自己闭门造的算法一般意味着安全性的大大降低。

全世界能干这件事情的人不超过5个，而且他们今天都不在这里。另外一半都是 [Daniel J. Bernstein](https://en.wikipedia.org/wiki/Daniel_J._Bernstein) 干的（开个玩笑，不过这人很牛，今天我们在用的很多加密的东西都是他设计、实现的）。

表面上好像这是个限制，其实这是个优势。因为我们**不需要**编写自己的加密算法，一切痛苦的工作都已经由别人做好了。我们只需要和搭积木一样去使用这些密码学工具就好了。

## 经常听到这样的建议

* 对传输中的数据用 TLS
* 对静止的数据用 GPG

### TLS

Go 可以很容易使用 TLS，因为必须的东西都内置了，从客户端到服务端。

客户端

```go
var minimalTLSConfig = &tls.Config{
	MinVersion: tls.VersionTLS12,
}
var tlsTransport = &http.Transport{
	TLSClientConfig: minimalTLSConfig,
}
var httpClient = &http.Client{
	Transport: tlsTransport,
	Timeout:   10 * time.Second,
}

func MakeRequest() error {
	resp, err := httpClient.Get("https://www.google.com")
	if err != nil {
		return err
	}
	// have fun
}
```

这里最重要的是 `tls.VersionTLS12`，因为低于 `1.2` 的话，会导致 Go 使用一些不安全的低版本的实现，所以这里限定 `1.2` 比较安全。而且大部分网站也都支持。

服务端

```go
var minimalTLSConfig = &tls.Config{
	MinVersion:               tls.VersionTLS12,
	PreferServerCipherSuites: true,
}
var srv = &http.Server{
	Addr:      "localhost:8080",
	TLSConfig: minimalTLSConfig,
}

func handleReq(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, world")
}
func main() {
	http.HandleFunc("/", handleReq)
	err := srv.ListenAndServeTLS("cert.pem", "key.pem")
	if err != nil {
		log.Fatal(err)
	}
}
```

这里和客户端一样，限定最小版本是 `1.2`，并且多了一个额外的参数，要求以服务器的 Cipher 优先，因此不按照客户端给的选择，而是按照Go服务端给的选择。因为 Go 的 TLS 包中有大量针对各种安全问题的调整，因此选择加密包的话，遵循 Go 内部的决定是最好的。

### GPG

GPG 是为了人和人之间的交流信息，而不是机器和机器之间交流信息的。

那么如何安全的使用 GPG 呢？答案就是**不用GPG**。因为作者觉得 GPG 太过阴谋论了，陷入了很多本不需要过多注意的区域，即使那么做了，也不见得更安全。

## 这个 Talk 不讲 TLS 和 GPG

因为当你实现安全的信息系统的时候，通常不会用到这两个东西。TLS 和 GPG 有他们应用的场合，但是对于每天的密码学工作来说，基本都不用这两个工具：

* 对文件计算散列
* 生成随机 ID
* API 验证
* 网站密码存储
* 签名、加密 cookies
* JWT
* 签名更新

## 在 Go 的 crypto 包里的算法可不都是好的算法

### 加密

下列划掉的算法都不应该再使用了：

* ~~DES~~
* ~~3DES~~
* ~~RC4~~
* ~~TEA~~
* ~~XTEA~~
* ~~Blowfish~~
* ✔️ Twofish
* ~~CAST5~~
* ✔️ Salsa20
* ✔️ AES

只有 `Twofish`、`Salsa20` 和 `AES` 还算是安全的加密算法，但是 `AES` 在大部分的计算机上都有硬件加速。因此只剩下一个 `AES` 是最佳加密算法。

#### 怎么使用 AES

要注意，`aesCipher.Encrypt()` **只会加密前16个字节**。不少人掉到这个坑里了，结果不知道为啥就前几个字符是密文，后面全都是明文。解决办法就是**不直接用AES**，通过 Mode 来使用。

Block cipher mode 一样有很多种选择：

* ~~CBC~~
* ~~CFB~~
* ~~CTR~~
* ~~OFB~~
* ✔️ GCM

这里只有 `GCM` 是**验证的**加密算法，因此别的都可以不选。

#### 加密

```go
import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
)
func Encrypt(data []byte, key [32]byte) ([]byte, error) {
	//	初始化 block cipher
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, err
	}
	//	设置 block cipher mode
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	//	生成随机 nonce
	nonce := make([]byte, gcm.NonceSize())
	_, err = rand.Read(nonce)
	if err != nil {
		return nil, err
	}
	//	封装、返回
	return gcm.Seal(nonce, nonce, data, nil), nil
}
```

#### 解密

```go
import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
)
func Decrypt(ciphertext []byte, key [32]byte) (plaintext []byte, err error) {
	//	初始化 block cipher
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, err
	}
	//	设置 block cipher mode
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	//	返回解开的包，注意这里的 nonce 是直接取的。
	return gcm.Open(nil,
		ciphertext[:gcm.NonceSize()],
		ciphertext[gcm.NonceSize():],
		nil,
	)
}
```

### 哈希散列

将一大段数据使用 Hash 算法，希望得到一串数值，这串数值可以反映你的这段数据，任何数据变化，这串数值都不同。而且希望无法从这串数值反推数据。这就是密码学 Hash 函数要保证的。（**注意：哈希不等于加密，很多人这点容易搞混**）

同样 Hash 函数一样有很多选择，一样是大部分都不用：

* ~~MD4~~
* ~~MD5~~
* ~~RIPEMD160~~
* ~~SHA1~~
* ✔️ SHA2
* ✔️ SHA3

选择 `SHA3` 并不是因为它比 `SHA2` 更新更好，而是因为它不同于 `SHA1` 和 `SHA2`。几年前密码学家已经开始担心，因为MD*以及SHA*的哈希算法本质太相似了，那么一旦这个依赖出现问题，就意味着这个体系的不再安全。因此开始寻找一种不同的算法。经过竞赛、挑选，最终 `SHA3` 脱颖而出。他本身是个很出色的 Hash 算法，同时其设计和之前的这几个算法完全不一样。

但是由于 `SHA3` 并不被广泛支持，所以如果你明确知道你可以用 `SHA3`，那么就用 `SHA3`。其它情况用 `SHA2`。

但是和加密一样，我们**不应该直接使用 Hash 算法**。因为可能会面临一系列的攻击：

* Length extension
* Rainbow tables
* Small number of possibilities (phone numbers)
* Salt? Peper?

> 我们应该使用 `HMAC`，而不要直接用 Hash


#### 实现 Hash

```go
import (
	"crypto/hmac"
	"crypto/sha512"
)
func Hash(tag string, data []byte) []byte {
	h := hmac.New(sha512.New512_256, []byte(tag))
	h.Write(data)
	return h.Sum(nil)
}
func ExampleHash() error {
	tag := "hashing file for storage key"
	contents, err := ioutil.ReadFile("testfile")
	if err != nil {
		return error
	}
	digest := Hash(tag, contents)
	fmt.Println(hex.EncodeToString(digest))
}
//	Output:
//	9f4c795d8ae5e207f19184ccebee6a606c1fdfe509c793614006d613580f03e1
```

### Hash 密码

一般东西的 Hash 用刚才的就行了，但是**除了密码Hash**。密码 Hash 和数据 Hash 的特征完全不同。

* **数据** Hash 希望的是 Hash 算法**越快越好**
* 而**密码** Hash 则希望 Hash 算法**越慢越好**

> 过快的密码哈希会导致暴力破解的成本降低。因此密码哈希需要特殊算法。

#### 使用 bcrypt

```go
import (
	"golang.org/x/crypto/bcrypt"
)
func HashPassword(password []byte) ([]byte, error) {
	return bcrypt.GenerateFromPassword(password, 14)
}
func CheckPasswordHash(hash, password []byte) error {
	return bcrypt.CompareHashAndPassword(hash, password)
}
func Example() {
	myPassword := []byte("password")
	hashed, err := HashPassword(myPassword)
	if err != nil {
		return
	}
	fmt.Println(string(hashed))
}
```

`14` 是计算量的复杂度，`14` 是个比较好的值，如果觉得性能无法接受，可以降到 `12`，但是不要再低了。

### 签名

首先是有一对密钥，一个是公钥、一个是私钥。任何拥有私钥的人可以对一段信息签名，而所有拥有公钥的人都可以来验证这个消息确实是由那个人签名的。

通过签名可以确保两件事情：

* 消息未曾被篡改
* 是谁发出的这个消息

和前面一样，Go 有很多签名算法可以选择：

* RSA
	* ~~PKCS1v15~~
	* PSS
* ECDSA
	* ✔️ P256
	* ~~P385~~
	* ~~P521~~
* Ed25519

这次和前面不同，签名算法的安全更多的_不是取决于算法选择，而是取决于你是怎么使用的_。

比如这里比较推荐使用 `ECDSA/P256`，但是要注意，当初 PS3 被黑，被解出私钥就是用的这个算法，当时是由于那个算法实现是非常烂的。幸运的是 Go 没这个问题。所以相对于其他语言，Go 可以使用这个比较安全的签名算法。

#### 实现

生成密钥

```go
import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
)
func NewSigningKey() (*ecdsa.PrivateKey, error) {
	return ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
}
```

签名数据

```go
func Sign(data []byte, priv *ecdsa.PrivateKey) ([]byte, error) {
	digest := sha256.Sum256(data)
	r, s, err := ecdsa.Sign(rand.Reader, priv, digest[:])
	if err != nil {
		return nil, err
	}
	//	encode the signature {R, S}
	params := priv.Curve.Params()
	curveByteSize := params.P.BitLen() / 8
	rBytes, sBytes := r.Bytes(), s.Bytes()
	signature := make([]byte, curveByteSize * 2)
	copy(signature[curveByteSize - len(rBytes):], rBytes)
	copy(signature[curveByteSize*2 - len(sBytes):], sBytes)
	return signature, nil
}
```

验证签名

```go
import (
	"crypto/ecdsa"
	"crypto/sha256"
	"math/big"
)

//	验证成功返回 true，否则 false
func Verify(data, sig []byte, pub *ecdsa.PublicKey) bool {
	digest := sha256.Sum256(data)
	curveByteSize := pub.Curve.Params().P.BitLen() / 8
	r, s := new(big.Int), new(big.Int)
	r.SetBytes(signature[:curveByteSize])
	s.SetBytes(signature[curveByteSize:])
	return ecdsa.Verify(pub, digest[:], r, s)
}
```
