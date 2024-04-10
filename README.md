# 一款提升 Android 开发者效率的 Bash 工具

> 这是一款适用于 Android 应用开发者调试所需的工具。所有实际要执行的命令都会先在终端输出
```bash
# 查看帮助索引
mt -h

Basic.My.Tool: Version 2.1 (build at 20211014.2050)
 使用方法索引:
    1.重启终端: reopen   清理终端: cls
    2.查看Adb连接的移动设备: devs
    3.支持多设备的Adb: madb <ADB_CMD>
    4.Adb-Wifi连接,建立: conn   断开: disc
    5.移动设备截屏: cap
    6.移动设备网络代理: proxy
    7.ADB输入: ain 通过adb输入; aime 通过第三方输入法输入
    8.自定义Git命令组: mgit
    9.混淆堆栈解析: trace
    10.打印一些信息(如当前Activity栈、模块依赖等): dump
    11.清理数据(如终端、手机应用、代理、调试标记等): clean
    12.卸载移动设备应用: uninstall
    13.移动设备进程等待调试: debug

# 详细的使用方式 <CMD> -h ，如
proxy -h

# 命令仅输出不实际执行
__run --cfg echo
# 恢复到先输出再执行的模式
__run --cfg run echo
```

## Adb 无线连接

```bash
# 查看当前连接设备
devs
# 以TCP-IP方式启动手机端adb服务进程，并以无线方式连接到改设备
# 可更新 ~/.basic.my.tool.bash_profile 中的 __MY_DEF_PHONE_IP 值为常用设备IP，即可省略参数
conn

my_conn: 建立无线连接（Adb-Wifi）:
   1. 若有一台设备USB连接，快速建立无线连接: my_conn
      a. 默认以5555端口启动远端adbd进程并建立连接（IPv4），建连成功即可卸下物理连接。
   2. 若无USB设备连接，支持:
      a. my_conn 使用默认IP，如 my_conn 192.168.3.13:5555
      b. 指定IP与端口号，如: my_conn <ip>:<port> 或 my_conn <ip> <port>

# 断开第一台设备的无线连接
disc 0

my_disc: 断开无线连接
   1. 不指定参数，支持选择设备断开: 如 my_disc
   2. 传入参数:
      a. 支持传入已连接设备下标（从0开始，可通过devs查看设备列表），如: my_disc 0
      b. 支持传入设备IP或IP:PORT(前缀匹配)，如: my_disc 192.168.3.13:5555
```

## Adb 批量执行

> `adb`在连接有多台设备时执行指令会报错，需要通过设备序列号选择设备执行，本工具中的`madb`可简化此操作；其指令参数同`adb`

```bash
# 推送文件到多个设备
madb push ./data.txt /sdcard/

my_multi_adb: 多adb命令应用支持，默认别名为 madb
   1. 查看当前模式: my_multi_adb -m
   2. 设置为选择模式: my_multi_adb -s 此种模式下，若有多设备，需要选择某设备执行
   3. 设置为全部模式: my_multi_adb -a 此种模式下，会依次把命令在各设备上执行
   4. 重启本机adb服务进程: my_multi_adb restart 简化命令, 效果同 adb kill-server

   如: my_multi_adb shell ip -f inet addr show 查看所有连接设备指定网卡的连接信息
```

## 移动设备操作

```bash
# 截图保存到桌面
cap

 移动设备截屏
   1. 截图文件默认保存到桌面: my_cap
   2. 指定截图保存目录: my_cap ~/Desktop
   3. 指定截图文件: my_cap ~/Desktop/1.png
 *对于有多设备连接的场景，按提示选择一个目标设备操作即可

# 查看手机端网络代理
proxy
# 设备移动设备代理为当前PC的8888端口
proxy def
# 移除移动设备代理
proxy clean

 网络代理(通过 adb shell settings实现，部分ROM可能不支持)
   1. 查看代理: my_proxy （这个和Wifi设置的代理不是一回事）
   2. 设置代理:
      a. my_proxy default 默认代理到本机8888端口
      b. my_proxy <IP>:<PORT> 或 my_proxy <IP> <PORT> 支持传入IP和端口
   3. 关闭代理: my_proxy close 或 my_proxy clean
 *对于有多设备连接的场景，按提示选择一个目标设备操作即可

# 从adb输入字符（不支持中文）
ain 'hello world'

 使用 adb shell input text 输入：
    1. 输入文本: my_ain 'text'
    2. 切换到输入模式: my_ain
 *ain不支持中文输入，支持多设备共同输入

# aime 拉起第三方输入法，支持中文
aime

ADB输入（需安装输入法: https://github.com/senzhk/ADBKeyBoard）
   1. 切换输入法并进入输入模式: my_aime
      1.1 输入 quit 退出输入模式。
      1.2 输入 clean 清空输入
 *对于有多设备连接的场景，按提示选择一个目标设备操作即可

# 通过包名卸载APP
uninstall com.test.app
```

## App 调试

```bash
# 查看进程信息
dump process com.test.app
# 查看Activity栈信息
dump activity
# 查看工程模块依赖(在 gradlew 同级目录下执行)
dump deps :app

在标准输出中打印一些信息, 默认别名 dump : 
    1. Activity栈信息: my_dump activity [--top] ,添加 --top 表示只看最顶层Activity
    2. 模块依赖信息: my_dump deps :app debugRuntimeClasspath {filter}
    3. 相关进程信息: my_dump process <filter>


# 设置和清空调试标志
debug com.test.app
debug clean

# 清理应用数据
clean pkg com.test.app

# 拉起Android Studio自带的 proguardgui.sh 工具
trace

混淆堆栈解析，依次从以下路径查找：
   1. 环境变量ANDROID_HOME: tools/proguard/bin/proguardgui.sh
   2. AndroidStudio默认配置: /Users/chavinchen/Library/Android/sdk/tools/proguard/bin/proguardgui.sh
   3. 从PATH中查找执行: proguardgui.sh
```

## Git 相关

> 此命令封装有常用Git操作，如 Fetch、Rebase、Push，自动处理分支同名问题、支持简易的浅克隆写法

```bash
# 浅克隆方式拉取远端分支到本地
mgit new develop 10 develop
# 以Rebase方式同步远端分支到当前分支
mgit rebase develop
# 推送本地更新到远端
mgit push


封装的常用Git命令；支持: 
   1. my_git fetch [branch] [FETCH-OPTS]: 拉取远端仓库branch分支到本地branch分支，但不切换到branch。(如本地已有branch则起备用分支branch_暂存)
   2. my_git new <branch> <FETCH-OPTS> <branch2>: 拉取远端branch分支到本地branch2分支，并切换到branch2分支
   3. my_git pull [branch] [FETCH-OPTS]: 拉取远端分支branch到本地，并切到branch分支；(如本地已有branch则起备用分支branch_暂存)
   4. my_git push [branch]: 推本地更新到远端(push origin branch:branch)
   5. my_git merge [branch] [FETCH-OPTS]: 以merge方式方式同步远端 branch 分支的差异到本地 当前分支 上
   5. my_git rebase [branch] [FETCH-OPTS]: 以rebase方式方式同步远端 branch 分支的差异到本地 当前分支 上
   6. my_git diff [branch] [FETCH-OPTS]: 比较本地 当前分支 和远端 branch 分支差异
   7. my_git clean [branch|--cache|--all]:
        - 填 branch 则清理本地和该分支关联的备用分支 branch_
        - 填 --cache 则清理本地所有备用分支
        - 填 --all 则清理本地所有分支

 *若不填分支名参数[branch]则默认用当前分支
  备用分支名规则: 若原分支为 develop 则对应的备用分支为 develop_
  FETCH-OPTS: 常用于浅拉取，填整数即可，如 10: git fetch origin develp --depth=10 
    若需拉取全部commit，则可填 '-' 或 '0' 或 '-1'
```

## 其他

```bash
# 清理终端输出
cls
# 重新在当前路径打开终端（terminal）
reopen
```
