#youku上传脚本
####说明：使用youku开放api上传视频
##一. 环境要求
* 操作系统：只要tcl支持的平台，但是我只在centos下测试
* 脚本环境：Tcl+tcllib+tls
	* tcllib提供http包和DNS解析包，tcllib安装具体看tcl环境安装：[http://www.4linuxfun.com/tcltk-huan-jing-da-jian/](http://www.4linuxfun.com/tcltk-huan-jing-da-jian/)
	* tls提供https支持，tls安装参考：[http://www.4linuxfun.com/centos-install-tcl-tls/](http://www.4linuxfun.com/centos-install-tcl-tls/)
* DNS:由于TCL自带的DNS解析使用TCP解析，所以最好设置成8.8.8.8或8.8.4.4或其他支持TCP解析的DNS服务器

##二. 创建youku应用
使用youku开放接口，需要创建应用

1. 进入官网[http://open.youku.com/](http://open.youku.com/)

2. 进入管理中心->创建应用
	**注意：**此处的回调地址我填写了*http://localhost*，测试填写空置的时候貌似会返回错误，自己可测试下。

3. 记录应用的信息
	记住创建完应用后的**client_id**和**client_secret**

##三. 脚本修改
编辑upload.tcl脚本，在脚本开头，找到如下内容，并按照自己需要修改：
```
set md5_check       0
set slice_length    10240
set client_id       "xxxxxxxxxxxxxxxxxxxx"
set client_secret   "xxxxxxxxxxxxxxxxxxxx"
set redirect_uri 	"http://localhost"
```
**md5_check**：用来确认是否在传输过程中使用hash，保障数据传输完整性，0为关闭，1为开启（不建议启用，由于使用tcllib包的md5功能，启用后会大量占用CPU资源）

**slice_length**：设置上传分片大小，最小为2048Kb，最大为10240Kb

**client_id**：创建应用中获取的id

**client_secret**：需要连接授权，后期token过期后也需要刷新

**redirect_uri**：创建应用时填写的回调地址，必须一致

##四. 上传视频到youku
1. 赋予脚本权限：chmod +x upload.tcl auth.tcl
2. 运行脚本，第一次运行需要授权：./upload.tcl
	**注意：**授权的帐号密码为youku登录帐号密码。
3. 如果授权成功或已经授权，则进入上传环节
	![文件信息](文件信息.png)
	信息说面（此三项信息为必填信息，不能为空）：
	* video title：视频标题
	* video tags：视频标签
	* video path：视频路径（绝对或相对路径）

回车后即自动上传,上传完成后可在youku的控制台看到视频已进入转码环节，等转码和审核成功后就可以在线观看了。

###如何续传
当用户停止上传（ctrl-c关闭进程），可通过运行**./upload.tcl -c**来续传

###参考：
官方文档：[http://open.youku.com/docs/upload_client_chinese.html](http://open.youku.com/docs/upload_client_chinese.html)

tcl环境安装：[http://www.4linuxfun.com/tcltk-huan-jing-da-jian/](http://www.4linuxfun.com/tcltk-huan-jing-da-jian/)

tcl安装tls：[http://www.4linuxfun.com/centos-install-tcl-tls/](http://www.4linuxfun.com/centos-install-tcl-tls/)
