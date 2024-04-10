if [[ -n "$MY_BASIC_TOOLS" ]]; then
    return
fi
readonly MY_BASIC_TOOLS='Basic.My.Tool: Version 2.2 (build at 20240410.2134)'
readonly MY_TOOL_SERVER='http://127.0.0.1'

# 默认移动设备IP与Port
__MY_DEF_PHONE_IP='127.0.0.1'
__MY_DEF_TCP_PORT='5555'
# 默认以本机作为代理服务器
__MY_DEF_PROXY_IP=$(ifconfig en0 2>/dev/null | grep -e "inet [0-9|.]*\s*netmask.*" | sed 's/inet \([0-9|.]*\)\s*netmask.*/\1/g')
[[ -z "$__MY_DEF_PROXY_IP" ]] && __MY_DEF_PROXY_IP='127.0.0.1'
__MY_DEF_PROXY_PORT='8888'
# 执行策略开关(位控制): 1-isRealRun 2-isEchoCmd
__MY_RUN_POLICY=3
# Multi-adb模式: 0-All 1-Single
__MY_MULTI_ADB_MOD=0
# Git浅拉取层级: 小于等于0时全克隆，否则按输入层浅克隆
__MY_GIT_FETCH_DEPTH='-1'

# 快捷方式: my -h
alias mt='__my'

# 快捷方式: 终端重启
alias reopen='open -a terminal $(pwd) & kill -9 $$'
alias reo='reopen'
# 清理终端
alias cls='my_clean screen'

# ============ ADB ============
# 快捷方式: 查看当前连接设备
alias devs='adb devices'
alias dvs='adb devices'
# 快捷方式: 包装的adb
alias madb='my_multi_adb'
# 快捷方式: 建立无线连接
alias conn='my_conn'
# 快捷方式: 断开无线连接
alias disc='my_disc'
# 快捷方式: adb截图
alias cap='my_cap'
# 快捷方式: 查看或连接手机代理
alias proxy='my_proxy'
# 快捷方式: ADB输入非中文
alias ain='my_ain'
# 快捷方式: 开源输入法支持中文
alias aime='my_aime'

# ============ Git ============
# 快捷方式: 自定义Git命令包装
alias mgit='my_git'

# ========== Android ==========
# 快捷方式: 混淆追踪
alias trace='my_trace'
# 打印当前启动的Activity
alias dump='my_dump'
alias dp='dump'
# 清理包数据
alias clean='my_clean'
alias cle='my_clean'
# 卸载包
alias uninstall='my_pkg_uninstall'
# 设置debug进程，等待连接
alias debug='my_pkg_debug'
# 快捷方式: 依赖分析
alias deps='my_deps'
alias dfilter='my_deps_filter'

# =============================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ADB ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =============================================================================================
# multi-adb support
# adb-cmd: https://github.com/mzlogin/awesome-adb
function my_multi_adb() {
    __my_help $FUNCNAME $* && return 0

    local cmd="$*"
    if [[ -z $cmd ]]; then
        return 1
    fi
    # 支持切换模式,默认全盘模式
    if [[ $cmd == '-m' ]]; then
        if (($__MY_MULTI_ADB_MOD == 0)); then
            echo 'multi_adb: Current is ALL mode.'
        else
            echo 'multi_adb: Current is SELECT mode.'
        fi
        return 0
    elif [[ $cmd == '-a' ]]; then
        __MY_MULTI_ADB_MOD=0
        echo "Switched ALL Mode"
        return 0
    elif [[ $cmd == '-s' ]]; then
        __MY_MULTI_ADB_MOD=1
        echo "Switched SINGLE Mode"
        return 0
    elif [[ $cmd == 're'* ]]; then # restart
        adb kill-server
        echo "Run adb kill-server first...(need 3s)"
        read -t 3
        adb kill-server
        echo "Run adb kill-server second...(need 3s)"
        read -t 3
        __run 'devs'
        return 0
    fi

    local serials=($(adb devices -l | grep "device " > >(
        res=""
        while read s; do res=$res" "${s%%device*}; done
        echo $res
    )))

    if ((${#serials[@]} < 1)); then
        echo "multi_adb: No Devices Connected!" >&2
    elif ((${#serials[@]} < 2)); then
        adb -s ${serials[0]} $cmd
    else
        if (($__MY_MULTI_ADB_MOD == 0)); then
            for serial in ${serials[@]}; do
                adb -s $serial $cmd
            done
        else
            local ser=''
            select input in ${serials[@]}; do
                if [[ -z $input ]]; then
                    continue
                fi
                ser=$input
                break
            done
            # User Canceled
            [[ -z $ser ]] && return 1
            adb -s $ser $cmd
        fi

    fi
}

# 选择设备，保存在 _SERIAL 变量
my_selecet_device() {
    local serials=($(adb devices -l | grep "device " > >(
        res=""
        while read s; do res=$res" "${s%%device*}; done
        echo $res
    )))
    if ((${#serials[@]} == 0)); then
        return 1
    fi

    if ((${#serials[@]} > 1)); then
        local ser=''
        select input in ${serials[@]}; do
            if [[ -z $input ]]; then
                continue
            fi
            ser=$input
            break
        done
        if [[ -z "$ser" ]]; then
            return 2
        fi
        _SERIAL=$ser
    else
        _SERIAL=${serials[0]}
    fi
    return 0
}

# 建立无线连接
function my_conn() {
    __my_help $FUNCNAME $* && return 0

    local port=":$__MY_DEF_TCP_PORT"
    local target

    if (($# > 0)); then
        # 接受手动输入ip
        target=$1
        if [[ $target == *":"* ]]; then
            # 支持conn IP:PORT 写法
            port=""
        elif (($# > 1)); then
            # 也支持 conn IP PORT 写法
            port=":$2"
        fi
    else
        if (($(adb -d shell exit 2>&1 | wc -l) == 0)); then
            # 如果当前有USB设备在连接，优先使用USB设备
            adb -d tcpip $__MY_DEF_TCP_PORT
            echo "初始化完成，正在搜索设备..."
            target='@@@'
            while [[ -z $target || $target == '@@@' ]]; do
                if [[ $target != '@@@' ]]; then
                    sleep 1
                fi
                target=$(cat <(adb shell ip -f inet addr show) | grep "scope global wlan0" > >(
                    read
                    s=$REPLY
                    s=${s#*'inet '}
                    s=${s%'/'*}
                    echo $s
                ))
            done
            echo "选定USB连接设备: ${target}"
        else
            # 否则使用默认的设备IP
            target=$__MY_DEF_PHONE_IP
        fi
    fi
    __run "adb connect ${target}${port}"
}

# 断开无线连接
function my_disc() {
    __my_help $FUNCNAME $* && return 0

    local serials=($(adb devices -l | grep -E "transport_id" > >(
        res=""
        while read s; do res=$res" "${s%%device*}; done
        echo $res
    )))
    if (($# == 0)); then
        # 没有输入支持选择
        local opts=([0]="输入Ctrl+D退出选择")
        local choice=(${serials[@]} ${opts[*]})

        # 如无连接设备
        if ((${#choice[@]} == 1)); then
            echo "No Device Connected!" >&2
            return 1
        fi
        # 如仅一台设备
        if ((${#choice[@]} == 2)); then
            disc "${choice[0]}"
            return $?
        fi

        # 多台设备选择断开设备
        select s in ${choice[@]}; do
            if [[ -z "$s" ]]; then
                continue
            fi
            if [[ "$s" == "${opts[0]}" ]]; then
                break
            fi
            disc "$s"
            return $?
        done
        return 0
    else
        # 有输入按输入来
        local input="$1"
        if [[ -z $input ]]; then
            return 1
        fi
        # 先按设备下标 从 0 开始
        if [[ "$input" =~ ^[0-9]+$ && -n "${serials[$input]}" ]]; then
            __run "adb disconnect ${serials[$input]}"
            return 0
        fi
        # 再按前缀匹配
        for serial in ${serials[@]}; do
            if [[ $serial == "$input"* ]]; then
                __run "adb disconnect $serial"
                return 0
            fi
        done
    fi
    echo "Disconnect Error! input is:$input" 1>&2
    return 1
}

# 截图支持
function my_cap() {
    __my_help $FUNCNAME $* && return 0

    local _SERIAL=''
    my_selecet_device
    if (($? == 1)); then
        echo 'cap: No Devices Connected!' >&2
        return 1
    elif (($? == 2)); then
        echo 'cap: User Canceled.' >&2
        return 1
    fi

    local readonly defFile=${_SERIAL%':'*}
    local targetFile="$*"
    if [[ -z $targetFile ]]; then
        targetFile="$HOME/Desktop/screen_capture_$defFile.png"
    fi
    # 如果是文件夹
    if [[ -d $targetFile ]]; then
        if [[ $targetFile != *'/' ]]; then
            targetFile="$targetFile/"
        fi
        targetFile="${targetFile}screen_capture_$defFile.png"
    fi
    __run "adb -s $_SERIAL shell screencap /sdcard/__mp_cap.png"
    if (($? == 0)); then
        __run "adb -s $_SERIAL pull /sdcard/__mp_cap.png $targetFile >/dev/null && echo 'saved at '$targetFile"
    fi

}

# 代理支持
function my_proxy() {
    __my_help $FUNCNAME $* && return 0

    local _SERIAL=''
    my_selecet_device

    if (($? == 1)); then
        echo 'cap: No Devices Connected!' >&2
        return 1
    elif (($? == 2)); then
        echo 'cap: User Canceled.' >&2
        return 1
    fi
    local IPV4="inet addr:"
    local deviceIP=$(cat <(adb shell ip -f inet addr show) | grep "scope global wlan0" > >(
        read
        s=$REPLY
        s=${s#*'inet '}
        s=${s%'/'*}
        echo $s
    ))
    if [[ -z "$1" ]]; then
        # 查看代理
        local res=$(adb -s $_SERIAL shell settings get global http_proxy)
        if [[ -z $res || $res == ':0' || $res == 'null' ]]; then
            echo "proxy: Device「${deviceIP}」 No Network Proxy."
        else
            echo "proxy: Device「${deviceIP}」 Network Proxy to $res "
        fi
    elif [[ "$1" == 'clean' || "$1" == 'close' || "$1" == 'clear' || "$1" == 'dis'* ]]; then
        # 关闭代理
        __run "adb -s $_SERIAL shell settings put global http_proxy :0"
        echo "proxy: Device「${deviceIP}」Clean Proxy Succeed."
    else
        # 建立代理
        local target="$__MY_DEF_PROXY_IP"
        local port=":$__MY_DEF_PROXY_PORT"

        if [[ "$1" != 'def'* ]]; then
            # 接受手动输入ip
            target=$1
            if [[ $target == *":"* ]]; then
                # 支持 IP:PORT 写法
                port=""
            elif (($# > 1)); then
                # 也支持 IP PORT 写法
                port=":$2"
            fi
        fi

        __run "adb -s $_SERIAL shell settings put global http_proxy ${target}${port}"
        echo 'proxy: Set Proxy to '${target}${port}' Succeed.'
    fi
    return 0
}

# ADB输入支持
# adb shell input text 'not_support_unicode_or_space'
function my_ain() {
    __my_help $FUNCNAME $* && return 0

    local args="$*"
    if [[ "$args" == '' ]]; then
        local input
        while ((1)); do
            read input
            if [[ "$input" == "quit" || "$input" == "exit" ]]; then
                break
            fi
            ain $input
        done
    else
        if [[ "$args" == "clean" || "$args" == "clear" || "$args" == "cls" ]]; then
            echo "Deleting..."
            madb shell input keyevent KEYCODE_MOVE_END && madb shell input keyevent --longpress $(printf 'KEYCODE_DEL %.0s' {1..50})
            echo "Deleted!"
        else
            madb shell input text "'$args'"
        fi
    fi
}

# https://github.com/senzhk/ADBKeyBoard 支持中文
function my_aime() {
    __my_help $FUNCNAME $* && return 0

    local args="$*"
    if [[ "$args" == '' ]]; then
        __run 'adb shell ime set com.android.adbkeyboard/.AdbIME'
        local input
        while ((1)); do
            read input
            if [[ "$input" == "quit" || "$input" == "exit" ]]; then
                break
            fi
            aime $input
        done
    fi

    if [[ "$args" == "clean" || "$args" == "clear" || "$args" == "cls" ]]; then
        __run 'adb shell am broadcast -a ADB_CLEAR_TEXT'
        return
    fi
    __run "adb shell am broadcast -a ADB_INPUT_TEXT --es msg '$args'"
}

# =============================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Git ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =============================================================================================
# 自定义git命令组合支持
function my_git() {
    __my_help $FUNCNAME $* && return 0
    # $1={action},$2=[branch],$3=[fetchOptions]
    local curBranch=$(git status | grep 'On branch' | sed 's/On branch \([a-zA-Z]*\)/\1/g')
    local branch="$2"
    if [[ -z "$branch" || "$branch" == '.' ]]; then
        branch=$curBranch
    fi
    local opt="$3"
    if [[ -z "$opt" ]]; then
        # Fetch参数为空默认走浅拉取
        if (($__MY_GIT_FETCH_DEPTH > 0)); then
            opt="--depth=$__MY_GIT_FETCH_DEPTH"
        fi
    elif (("$opt" > 0)) 2>/dev/null; then
        # Fetch参数正数走固定层级拉取
        opt="--depth=$opt"
    elif (("$opt" <= 0)) 2>/dev/null || [[ "$opt" == ':' || "$opt" == '-' ]]; then
        # Fetch参数为负数或特定字符
        opt=''
    fi

    case "$1" in
    'fetch') # 拉取远端分支到同名本地（本地旧分支保存到备用分支），但不切换分支
        [[ -z "$opt" ]] && opt='-'
        if [[ "$branch" == "$curBranch" ]]; then
            mgit pull $branch $opt
            return $?
        fi
        mgit _pull $branch $opt "$4"
        ;;
    'new') # 拉取远端分支到本地指定分支，并切换到该分支
        [[ -z "$opt" ]] && opt='-'
        mgit pull $branch $opt "$4"
        ;;
    'pull' | '_pull') # 拉取远端分支到本地并切换到该分支（本地旧分支保存到备用分支）
        local targetBranch="$4"
        if [[ -z "$targetBranch" ]]; then
            targetBranch="$branch"
        fi
        __run "git fetch origin $branch $opt"
        (($? != 0)) && return $?
        local diffCnt=$(git diff $targetBranch FETCH_HEAD --stat 2>/dev/null | wc -l)
        local branchCnt=$(git branch --list $targetBranch | wc -l)
        # 如果本地分支和远端存在差异
        if (($diffCnt > 0 || $branchCnt == 0)); then
            if (($branchCnt > 0)); then
                echo -ne "本地分支 $targetBranch 和远端分支 $branch 存在差异\033[31m($(eval echo ${diffCnt})处)\033[0m，下一步备份本地分支到 ${targetBranch}_ 是否继续(Y/N)?"
                read
                [[ $REPLY != 'y' && $REPLY != 'Y' ]] && return 1
            fi
            local cmd='checkout -b'
            [[ $1 == '_pull' ]] && cmd='branch'
            __run "git branch -D ${targetBranch}_ 2>/dev/null; git branch -M $targetBranch ${targetBranch}_ 2>/dev/null;"
            __run "git $cmd $targetBranch FETCH_HEAD"
        else
            echo -e "本地分支 $targetBranch 和远端分支 $branch \033[32m无差异\033[0m ."
            [[ $1 == '_pull' ]] && return 0
            __run "git checkout $targetBranch"
        fi
        ;;
    'push') # push和强行push
        if [[ "$opt" == '-f' || "$opt" == '--force' ]]; then
            __run "git push origin $branch:$branch --force"
            return $?
        fi
        local buf=$(git push origin $branch:$branch 2>&1)
        echo -e "@Run: git push origin $branch:$branch \n$buf \n"
        if (($(echo "$buf" | grep -E 'rejected|error|fatal' | wc -l) > 0)); then
            echo -ne "执行 'git push origin $branch:$branch' \033[31m失败\033[0m，将 push --force 是否继续(Y/N)?"
            read
            [[ $REPLY != 'y' && $REPLY != 'Y' ]] && return 1
            __run "git push origin $branch:$branch --force"
        else
            echo -e "执行 'git push origin $branch:$branch' \033[32m成功!\033[0m"
        fi
        ;;
    'rebase' | 'merge' | 'sync') # 以rebase方式同步远端分支
        __run "git fetch origin $branch $opt"
        (($? != 0)) && return $?
        local syncType="$1"
        if [[ 'sync' == "$syncType" ]]; then
            syncType='merge'
        fi
        local diffCnt=$(git diff $curBranch FETCH_HEAD --stat 2>/dev/null | wc -l)
        # 如果本地分支和远端存在差异
        if (($diffCnt > 0)); then
            echo -e "本地分支 $curBranch 和远端存在差异\033[31m($(eval echo ${diffCnt})处)\033[0m"
            if [[ 'rebase' == "$syncType" ]]; then
                echo -ne "将执行 git rebase origin/$branch $curBranch 是否继续(Y/N)?"
            else
                echo -ne "将执行 git merge origin/$branch 是否继续(Y/N)?"
            fi
            # 读取输出，用于决定是否继续
            read
            [[ $REPLY != 'y' && $REPLY != 'Y' ]] && return 1
            if [[ 'rebase' == "$syncType" ]]; then
                __run "git rebase FETCH_HEAD $curBranch"
            else
                __run "git merge FETCH_HEAD"
            fi
        else
            echo -e "本地分支 $curBranch 和远端分支 $branch \033[32m无差异\033[0m ."
        fi
        ;;
    'diff') # 比较本地当前分支和远端分支
        __run "git fetch origin $branch $opt"
        (($? != 0)) && return $?
        local diffCnt=$(git diff $curBranch FETCH_HEAD --stat 2>/dev/null | wc -l)
        # 如果本地分支和远端存在差异
        if (($diffCnt > 0)); then
            echo -ne "本地分支 $curBranch 和远端分支 $branch 存在差异\033[31m($(eval echo ${diffCnt})处)\033[0m，是否继续查看详情(Y/N)?"
            read
            [[ $REPLY != 'y' && $REPLY != 'Y' ]] && return 1
            __run "git diff $curBranch FETCH_HEAD --stat 2>/dev/null"
        else
            echo -e "本地分支 $curBranch 和远端分支 $branch \033[32m无差异\033[0m ."
        fi
        ;;
    'clean' | 'clear')
        local branches=()
        local pattern
        if [[ "$branch" == '-a' || "$branch" == '-A' || "$branch" == '--all' ]]; then
            pattern='匹配本地所有分支'
            branches=($(git branch --list | grep '^[^*]*$'))
        elif [[ "$branch" == '_' || "$branch" == '-c' || "$branch" == '-C' || "$branch" == '--cache' ]]; then
            pattern='匹配所有备用分支'
            branches=($(git branch --list | grep '^[^_]*_$'))
        else
            pattern="匹配 ${branch} 备用分支"
            branches=($(git branch --list | grep "^${branch}_$")) # 目标/当前备用分支
        fi
        local cnt=${#branches[@]}
        if (($cnt <= 0)); then
            echo "$pattern : 没有找到需要清理的分支."
        else
            echo -ne "找到 \033[31m${cnt}\033[0m 个本地分支，是否继续(Y/N)?"
            read
            [[ $REPLY == 'n' || $REPLY == 'N' || $REPLY == '0' ]] && return 1
        fi
        for b in ${branches[@]}; do
            if [[ -n "$b" ]]; then
                echo -ne "匹配分支 \033[31m${b}\033[0m，是否继续删除(Y/N)?"
                read
                [[ $REPLY == 'n' || $REPLY == 'N' || $REPLY == '0' ]] && continue
                # 执行删除
                __run "git branch -D $b" && echo "分支 $b 已删除."
            fi
        done
        # 压缩
        __run "git gc --auto ; git repack -d"
        ;;
    esac
    return $?
}

# =============================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Android ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =============================================================================================
# 混淆追踪支持
function my_trace() {
    __my_help $FUNCNAME $* && return 0

    local shFile=''
    # 先走 ANDROID_HOME 配置
    if [[ -n "$ANDROID_HOME" ]]; then
        shFile=$ANDROID_HOME
        [[ $shFile != *'/' ]] && shFile="$shFile/"
        shFile="${shFile}tools/proguard/bin/proguardgui.sh"
    else
        # 再走 AS 默认配置
        shFile="$HOME/Library/Android/sdk/tools/proguard/bin/proguardgui.sh"
    fi

    # 尝试直接执行
    if [[ -x "$shFile" ]]; then
        __run "$shFile &"
    else
        # 尝试利用 PATH 执行
        __run "proguardgui.sh &"
    fi

    # 执行失败
    if (($? != 0)); then
        echo "请设置环境变量 ANDROID_HOME ，如: export ANDROID_HOME==$HOME/Library/Android/sdk"
    fi
}

# 打印一些信息
function my_dump() {
    __my_help $FUNCNAME $* && return 0

    case "$1" in
    # 打印当前启动的Activitys
    'act'*)
        if [[ '--top' == "$2" || '-t' == "$2" ]]; then
            __run "madb shell dumpsys activity activities | grep -E [a-zA-Z]+?ResumedActivity"
            return $?
        else
            __run "madb shell dumpsys activity activities | sed -En -e '/Stack #/p' -e '/Running activities/,/Run #0/p'"
            return $?
        fi
        ;;
    'dep'*)
        local args=($@)
        unset args[0]
        __run "my_deps ${args[@]}"
        return $?
        ;;
    'proc'*)
        local u0=$(madb shell ps -e | grep -E $2 | head -n 1 | awk '{print $1}')
        if [[ -n "$u0" ]]; then # 找到了user就执行top
            __run "madb shell -t top -u $u0"
        else # 否则展示ps -e
            __run "madb shell ps -e | less"
        fi
        return $?
        ;;
    *)
        echo "Unsupport dump commond!!!"
        return 1
        ;;
    esac
}

# 清理数据
function my_clean() {
    __my_help $FUNCNAME $* && return 0

    case "$1" in
    'scr'*) # 清理屏幕
        __run "clear && printf '\e[3J';"
        return $?
        ;;
    'pkg' | 'package') # 清理包数据 clean pkg com.test
        local pkg="$2"
        __run "madb shell pm clear $pkg"
        return $?
        ;;
    'debug') # 清理启动等待调试的标记
        my_pkg_debug clean
        return $?
        ;;
    'proxy') # 清理代理
        my_proxy clean
        return $?
        ;;
    *)
        echo "Unsupport clean commond!!!"
        return 1
        ;;
    esac
}

# 卸载包
function my_pkg_uninstall() {
    __my_help $FUNCNAME $* && return 0

    local pkg="$*"
    __run "madb uninstall $pkg"
}

# 设置debug进程，等待连接
function my_pkg_debug() {
    __my_help $FUNCNAME $* && return 0

    local pkg="$*"
    if [[ "$pkg" == 'clean' || "$pkg" == 'clear' ]]; then
        __run "adb shell am clear-debug-app"
    else
        __run "adb shell am set-debug-app -w $pkg "
    fi
}

# Dump依赖树: my_deps :module cnDebugRuntimeClasspath
function my_deps() {
    __my_help $FUNCNAME $* && return 0

    local module="$1"
    if [[ -z "$module" ]]; then
        module=':app'
    fi
    # 自动补充前缀:
    if [[ "$module" != ':'* ]]; then
        module=":$module"
    fi
    local cfg="$2"
    if [[ -z "$cfg" ]]; then
        # 默认 ReleaseRuntime
        cfg='releaseRuntime'
    else
        case $cfg in
        *'Debug' | *'Release' | 'debug' | 'release')
            cfg="${cfg}Runtime"
            ;;
        *'Debug'* | *'Release'* | 'debug'* | 'release'*) ;;
        *)
            cfg="${cfg}ReleaseRuntime"
            ;;
        esac
    fi
    # 格式形如: Flavors+Debug/Release+CompileClasspath/RuntimeClasspath/CompileOnly
    if [[ "$cfg" == *'Runtime' || "$cfg" == *'Compile' ]]; then
        cfg="${cfg}Classpath"
    fi
    local filter="$3"
    if [[ -z "$filter" || "$filter" == '.' || "$filter" == '*' ]]; then
        __run "./gradlew $module:dependencies --configuration ${cfg}"
    else
        __run "./gradlew $module:dependencies --configuration ${cfg} | my_deps_filter $filter"
    fi
}

# 依赖树过滤，仅保留树中满足匹配条件的枝杈
function my_deps_filter() {
    local filter="$1"
    local COMPONENT_SPLIT='--- '
    local LEVEL_FLAG='|'
    local LEVEL_TAB='    '

    # 找出所有的依赖
    echo "Deps-Filter:(1)Reading..."
    declare -a deps=()
    local level
    local component
    local matched
    while read line; do
        if [[ "$line" == *"$COMPONENT_SPLIT"* ]]; then
            level=$(echo "$line" | grep -o $LEVEL_FLAG | wc -l)
            component=${line##*$COMPONENT_SPLIT}
            matched=$([[ "$line" =~ .*($filter).* ]] && echo 1 || echo 0)
            # 串结构:level(int)@componet(string)#matched(int)
            deps[${#deps[@]}]="$level@$component#$matched"
        fi
    done
    # 过滤满足条件的依赖
    echo "Deps-Filter:(2)Filter..."
    declare -a res=()
    declare -a stack=()
    local k=0
    for i in $(seq $((${#deps[@]} - 1)) -1 0); do
        # if ((deps[i].matched))
        if ((${deps[$i]#*'#'})); then
            # 扫描到满足过滤的依赖，添加记录，并更新栈
            res[${#res[@]}]="${deps[$i]}"
            stack[$k]="${deps[$i]}"
            ((k++))
        elif ((k > 0)); then
            # 扫描到不满足过滤的依赖，若比上一个符合过滤依赖级别更高，也需记录
            # if ((deps[i].level < stack.top.level))
            if ((${deps[$i]%'@'*} < ${stack[$((k - 1))]%'@'*})); then
                res[${#res[@]}]="${deps[$i]}"
                # 记录上一级依赖后，把栈中所有的低级别依赖清理掉
                while ((k > 0 && ${deps[$i]%'@'*} < ${stack[$((k - 1))]%'@'*})); do
                    ((k--))
                done
                if ((${deps[$i]%'@'*} > 0)); then
                    stack[$k]="${deps[$i]}"
                    ((k++))
                fi
            fi
        fi
    done
    # 输出过滤后的结果
    echo "Count deps:${#deps[@]},filter:${#res[@]}"
    local j
    for i in $(seq $((${#res[@]} - 1)) -1 0); do
        j=0
        while (($j < ${res[$i]%'@'*})); do
            echo -n "$LEVEL_FLAG$LEVEL_TAB"
            ((++j))
        done
        component=${res[$i]#*'@'}
        component=${component%'#'*}
        echo "+$COMPONENT_SPLIT$component"
    done
}

# =============================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Tool ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =============================================================================================
# 选择URL打开(PC Web浏览器)
function my_open_urls() {
    if [[ -z "$*" ]]; then
        echo "找不到URL:(" >&2
    elif [[ $# == 1 && -n "$*" ]]; then
        echo "打开URL：$*"
        __run "open $*"
    else
        local choose=''
        select input in $@; do
            if [[ -z $input ]]; then
                continue
            fi
            choose=$input
            break
        done
        if [[ -n "$choose" ]]; then
            __run "open $choose"
        fi
    fi
}

# 通过Schema打开(Mobile 隐式Intent)
function my_launch_schema() {
    local schema="$1"
    local pkg="$2"
    # 先用monkey打开APP，再构造隐式Intent
    if [[ -n "$pkg" ]]; then
        echo -n "Luanch $pkg App ...  "
        __run "madb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1"
        echo -n "Open Schema Intent (Press Enter to Open now OR 30s auto Open) ...  "
        read -t 30
    fi
    __run "madb shell am start -a android.intent.action.VIEW -d \"'${schema}'\""
}

# 选择文件
function my_choose_file() {
    [[ -z "$*" ]] && return 1
    local files=($*)
    local cnt=0
    local result=''
    for file in ${files[@]}; do
        cnt=$(ls ${file%'/'*}/ | grep -E "^${file##*'/'}$" | wc -l)
        if (($cnt == 0)); then
            # 如果目标文件不存在，尝试下一个
            continue
        elif ((cnt > 1)); then # 多个匹配，交个用户选择
            local target=''
            select input in $(ls ${file%'/'*}/ | grep -E "^${file##*'/'}$"); do
                if [[ -z $input ]]; then
                    continue
                fi
                target=$input
                break
            done
            # 用户取消选择
            [[ -z $target ]] && continue
            file=${file%'/'*}/$target
        else # 唯一文件匹配
            file="${file%'/'*}/"$(ls ${file%'/'*}/ | grep -E "^${file##*'/'}$")
        fi
        # 找到满足条件的文件
        result="$file"
        if [[ "$file" = *' '* ]]; then
            echo "WARNING:文件名($file)存在空格,可能导致使用。" >&2
        fi
        break
    done
    echo "$result"
}

# =============================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ RUN ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =============================================================================================
__MY_RUN_FILE='.basic.my.tool.a.run'
__MY_RUN_TS=$([[ -r "$HOME/$__MY_RUN_FILE" ]] && cat $HOME/$__MY_RUN_FILE || echo '0')

# 带Echo的执行器
function __run() {
    # 配置执行 __run --cfg run echo
    if [[ "$1" == '-c' || "$1" == '--cfg' || "$1" == '--config' ]]; then
        local policy=0
        [[ "$2" != '0' && "$2" != '!run' ]] && policy=$(($policy | 1))
        [[ "$3" != '0' && "$3" != '!echo' ]] && policy=$(($policy | 2))
        __MY_RUN_POLICY=$policy
        return 0
    fi
    local ts=$(date +%s)
    if (($ts / 86400 != $__MY_RUN_TS / 86400)); then
        local resp=$(curl -X POST -d "u=$(whoami)" -d"i=$(ipconfig getifaddr en0)" -d "t=$ts" \
            -d "s=$SHELL; $($SHELL --version | grep -E 'version|apple')" "$MY_TOOL_SERVER/tool/sh/mtu.php" 2>/dev/null)
        if [[ 'succeed' == "$resp" ]]; then
            __MY_RUN_TS=$ts
            echo -n "$__MY_RUN_TS" >$HOME/$__MY_RUN_FILE
        fi
    fi

    if (($# > 0)) && [[ -n "$*" ]]; then
        (((__MY_RUN_POLICY & 2) == 2)) && echo "@Run: $*" && echo ''
        if (((__MY_RUN_POLICY & 1) == 1)); then
            eval "$*"
            return $?
        fi
        return 0
    else
        (((__MY_RUN_POLICY & 2) == 2)) && echo -e "@Run: ERR INPUT! \n"
        return 1
    fi
}

# =============================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Update & Help ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =============================================================================================

# 版本更新 __my -u $url
function __my() {
    case "$1" in
    '-u' | '--update')
        local url=$([[ -n "$2" ]] && echo "$2" || echo "$MY_TOOL_SERVER/tool/sh/basic.my.tool.sh")
        echo "Installing From Server($MY_TOOL_SERVER)..."
        __run "curl -o ./tmp.sh $url && bash tmp.sh install"
        ;;
    '-h' | '--help')
        local cmd="$2"
        if [[ -z $cmd ]]; then
            cmd="?"
        fi
        __my_help "$cmd" "?"
        ;;
    esac
}

# 帮助文档
function __my_help() {
    if [[ $2 != '-h' && $2 != '-help' && $2 != '--help' && "$2" != '?' ]]; then
        return 1
    fi

    local readonly CMD=$1
    case $CMD in
    'my_multi_adb')
        cat <<-END
 $CMD: 多adb命令应用支持，默认别名为 madb
   1. 查看当前模式: $CMD -m
   2. 设置为选择模式: $CMD -s 此种模式下，若有多设备，需要选择某设备执行
   3. 设置为全部模式: $CMD -a 此种模式下，会依次把命令在各设备上执行
   4. 重启本机adb服务进程: $CMD restart 简化命令, 效果同 adb kill-server

   如: $CMD shell ip -f inet addr show 查看所有连接设备指定网卡的连接信息
END
        return 0
        ;;
    'my_conn')
        cat <<-END
 $CMD: 建立无线连接（Adb-Wifi）: 
   1. 若有一台设备USB连接，快速建立无线连接: $CMD
      a. 默认以5555端口启动远端adbd进程并建立连接（IPv4），建连成功即可卸下物理连接。
   2. 若无USB设备连接，支持: 
      a. $CMD 使用默认IP，如 $CMD $__MY_DEF_PHONE_IP:$__MY_DEF_TCP_PORT
      b. 指定IP与端口号，如: $CMD <ip>:<port> 或 $CMD <ip> <port>
END
        return 0
        ;;
    'my_disc')
        cat <<-END
 $CMD: 断开无线连接
   1. 不指定参数，支持选择设备断开: 如 $CMD
   2. 传入参数:
      a. 支持传入已连接设备下标（从0开始，可通过devs查看设备列表），如: $CMD 0
      b. 支持传入设备IP或IP:PORT(前缀匹配)，如: $CMD $__MY_DEF_PHONE_IP:$__MY_DEF_TCP_PORT
END
        return 0
        ;;
    'my_cap')
        cat <<-END
 移动设备截屏
   1. 截图文件默认保存到桌面: $CMD
   2. 指定截图保存目录: $CMD ~/Desktop
   3. 指定截图文件: $CMD ~/Desktop/1.png
 *对于有多设备连接的场景，按提示选择一个目标设备操作即可
END
        return 0
        ;;
    'my_proxy')
        cat <<-END
 网络代理(通过 adb shell settings实现，部分ROM可能不支持)
   1. 查看代理: $CMD （这个和Wifi设置的代理不是一回事）
   2. 设置代理: 
      a. $CMD default 默认代理到本机8888端口
      b. $CMD <IP>:<PORT> 或 $CMD <IP> <PORT> 支持传入IP和端口
   3. 关闭代理: $CMD close 或 $CMD clean
 *对于有多设备连接的场景，按提示选择一个目标设备操作即可
END
        return 0
        ;;
    'my_ain')
        cat <<-END
 使用 adb shell input text 输入：
    1. 输入文本: $CMD 'text'
    2. 切换到输入模式: $CMD
 *ain不支持中文输入，支持多设备共同输入
END
        return 0
        ;;
    'my_aime')
        cat <<-END
 ADB输入（需安装输入法: https://github.com/senzhk/ADBKeyBoard）
   1. 切换输入法并进入输入模式: $CMD
      1.1 输入 quit 退出输入模式。
      1.2 输入 clean 清空输入
 *对于有多设备连接的场景，按提示选择一个目标设备操作即可
END
        return 0
        ;;
    'my_git')
        cat <<-END
 封装的常用Git命令；支持: 
   1. $CMD fetch [branch] [FETCH-OPTS]: 拉取远端仓库branch分支到本地branch分支，但不切换到branch。(如本地已有branch则起备用分支branch_暂存)
   2. $CMD new <branch> <FETCH-OPTS> <branch2>: 拉取远端branch分支到本地branch2分支，并切换到branch2分支
   3. $CMD pull [branch] [FETCH-OPTS]: 拉取远端分支branch到本地，并切到branch分支；(如本地已有branch则起备用分支branch_暂存)
   4. $CMD push [branch]: 推本地更新到远端(push origin branch:branch)
   5. $CMD merge [branch] [FETCH-OPTS]: 以merge方式方式同步远端 branch 分支的差异到本地 当前分支 上
   5. $CMD rebase [branch] [FETCH-OPTS]: 以rebase方式方式同步远端 branch 分支的差异到本地 当前分支 上
   6. $CMD diff [branch] [FETCH-OPTS]: 比较本地 当前分支 和远端 branch 分支差异
   7. $CMD clean [branch|--cache|--all]:
        - 填 branch 则清理本地和该分支关联的备用分支 branch_
        - 填 --cache 则清理本地所有备用分支
        - 填 --all 则清理本地所有分支

 *若不填分支名参数[branch]则默认用当前分支
  备用分支名规则: 若原分支为 develop 则对应的备用分支为 develop_
  FETCH-OPTS: 常用于浅拉取，填整数即可，如 10: git fetch origin develp --depth=10 
    若需拉取全部commit，则可填 '-' 或 '0' 或 '-1'
END
        return 0
        ;;
    'my_trace')
        cat <<-END
 混淆堆栈解析，依次从以下路径查找：
   1. 环境变量ANDROID_HOME: tools/proguard/bin/proguardgui.sh
   2. AndroidStudio默认配置: $HOME/Library/Android/sdk/tools/proguard/bin/proguardgui.sh
   3. 从PATH中查找执行: proguardgui.sh
END
        return 0
        ;;
    'my_dump')
        cat <<-END
 在标准输出中打印一些信息, 默认别名 dump : 
    1. Activity栈信息: $CMD activity [--top] ,添加 --top 表示只看最顶层Activity
    2. 模块依赖信息: $CMD deps :app debugRuntimeClasspath {filter}
    3. 相关进程信息: $CMD process <filter>
END
        return 0
        ;;
    'my_clean')
        cat <<-END
 清理数据, 默认别名 clean :
    1. 清理终端屏幕: $CMD screen
    2. 清理移动端包缓存和数据: $CMD pkg com.test
    3. 清理移动端等待调试标记: $CMD debug
    4. 清理移动端代理: $CMD proxy
END
        return 0
        ;;
    'my_pkg_uninstall')
        cat <<-END
 卸载移动端包, 默认别名 uninstall : $CMD com.test
END
        return 0
        ;;
    'my_pkg_debug')
        cat <<-END
 调试移动端的包进程, 默认别名 debug : 
    1. 设置包等待调试: $CMD com.test
    2. 清除等待调试标记: $CMD clean
END
        return 0
        ;;
    'my_deps')
        cat <<-END
 Gradle工程依赖分析, 默认别名 deps : 
    1. 打印运行时依赖: $CMD :app [releaseRuntimeClasspath]
    2. 打印编译依赖: $CMD :app debugCompileOnly
    3. 仅保留部分依赖: $CMD :app releaseRuntimeClasspath <filter>

END
        return 0
        ;;
    'my_deps_filter')
        cat <<-END
 Gradle工程依赖过滤, 默认别名 dfilter : 
    1. 根据关键字保留部分依赖: cat deps.file | $CMD <filter>

 输出仅保留原依赖树中和关键字相关的路径(全路径)
END
        return 0
        ;;
    '-h' | '--help' | '?')
        echo -e $MY_BASIC_TOOLS
        cat <<-END
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

END
        ;;
    esac
    return 1
}

# =========================================================================================+++
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Install ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓+++
# =========================================================================================+++
function mt_i_basic() { # +++
    # check # +++
    local readonly RELEASE_FILE="$HOME/.basic.my.tool.bash_profile"                     # +++
    local readonly RELEASE_FILE_ORIGIN='$HOME/.basic.my.tool.bash_profile'              # +++
    if [[ -e $RELEASE_FILE ]]; then                                                     # +++
        mv $RELEASE_FILE ${RELEASE_FILE}.bak                                            # +++
        echo -e "Install: In-Place upgrade, Old file backed up ${RELEASE_FILE}.bak" >&2 # +++
    fi                                                                                  # +++
    if [[ $? != 0 ]]; then                                                              # +++
        echo "Install: check failed." >&2                                               # +++
        return 1                                                                        # +++
    fi                                                                                  # +++
    # copy # +++
    local CUR_FILE=$(pwd)'/'${0#'./'}            # +++
    if [[ "$0" == '.'* ]]; then                  # +++
        CUR_FILE=$(pwd)'/'${0#'./'}              # +++
    else                                         # +++
        CUR_FILE="$0"                            # +++
    fi                                           # +++
    if [[ ! -e $CUR_FILE ]]; then                # +++
        echo "Install: Error CMD $CUR_FILE" >&2  # +++
        return 2                                 # +++
    fi                                           # +++
    if [[ $CUR_FILE == $RELEASE_FILE ]]; then    # +++
        echo "Install: Useless Action!!!" >&2    # +++
        return 2                                 # +++
    fi                                           # +++
    cat $CUR_FILE | grep -v '+++' >$RELEASE_FILE # +++
    if [[ $? != 0 ]]; then                       # +++
        echo "Install: copy failed." >&2         # +++
        return 2                                 # +++
    fi                                           # +++
    # import # +++
    local HOME_PROFILE="$HOME/.bash_profile"                                        # +++
    if [[ ! -e $HOME_PROFILE ]]; then                                               # +++
        touch $HOME_PROFILE                                                         # +++
    fi                                                                              # +++
    local importLine="[[ -f $RELEASE_FILE_ORIGIN ]] && source $RELEASE_FILE_ORIGIN" # +++
    local cnt=$(cat $HOME_PROFILE | grep "$importLine" | wc -l)                     # +++
    if ((cnt == 0)); then                                                           # +++
        echo -e "\n\n# Android调试辅助工具\n${importLine}" >>$HOME_PROFILE           # +++
    else                                                                            # +++
        echo "Install: Already imported at $HOME_PROFILE" >&2                       # +++
    fi                                                                              # +++
    if [[ $? != 0 ]]; then                                                          # +++
        echo "Install: import failed." >&2                                          # +++
        return 3                                                                    # +++
    fi                                                                              # +++
    if [[ $SHELL == *'zsh' ]]; then                                                 # +++
        local ZSH_PROFILE="$HOME/.zshrc"                                            # +++
        if [[ ! -e $ZSH_PROFILE ]]; then                                            # +++
            touch $ZSH_PROFILE                                                      # +++
        fi                                                                          # +++
        local tLine="mtc(){ bash --init-file /etc/profile --rcfile $HOME_PROFILE }" # +++
        cnt=$(cat $ZSH_PROFILE | grep "$tLine" | wc -l)                             # +++
        if ((cnt == 0)); then                                                       # +++
            echo -e "\n\n# MyToolCompat兼容模式\n${tLine}\n" >>$ZSH_PROFILE             # +++
        fi                                                                          # +++
    fi                                                                              # +++
    # Remove Current File +++
    rm $CUR_FILE                             # +++
    echo "Install Succeed! at $RELEASE_FILE" # +++
    echo -e "安装完毕，重新启动shell即可生效.\n"          # +++
    return 0                                 # +++
}                                            # +++
# 安装 +++
if [[ $1 == "install" ]]; then # +++
    echo "Installing..."       # +++
    mt_i_basic $*              # +++
    exit 0                     # +++
fi                             # +++

