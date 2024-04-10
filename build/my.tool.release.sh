# =========================================================================================
# ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Publish Release: bash my.tool.sh ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
# =========================================================================================

function release_my_basic() {
    cat $HOME/.basic.my.tool.bash_profile >./basic.my.tool.sh
    cat <<"END" >>./basic.my.tool.sh
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

END
}

function release_my_tools() {
    if [[ -r "$HOME/.basic.my.tool.bash_profile" ]]; then
        release_my_basic
        # echo 'start upload: ./basic.my.tool.sh'
        # scp ./basic.my.tool.sh 'chenchangwen@10.227.71.119:/var/www/html/tool/sh/'
        # (($?==0)) && echo 'file uploaded: http://10.227.71.119/tool/sh/basic.my.tool.sh'
    fi
}

release_my_tools
