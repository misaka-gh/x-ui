#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统，请使用主流的操作系统" && exit 1

cur_dir=$(pwd)
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

[[ $SYSTEM == "CentOS" && ${os_version} -lt 7 ]] && echo -e "请使用 CentOS 7 或更高版本的系统！" && exit 1
[[ $SYSTEM == "Fedora" && ${os_version} -lt 29 ]] && echo -e "请使用 Fedora 29 或更高版本的系统！" && exit 1
[[ $SYSTEM == "Ubuntu" && ${os_version} -lt 16 ]] && echo -e "请使用 Ubuntu 16 或更高版本的系统！" && exit 1
[[ $SYSTEM == "Debian" && ${os_version} -lt 9 ]] && echo -e "请使用 Debian 9 或更高版本的系统！" && exit 1

archAffix(){
    case "$(uname -m)" in
        x86_64 | x64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构! " && rm -f install.sh && exit 1 ;;
    esac
}

check_centos8(){
    if [[ -n $(cat /etc/os-release | grep "CentOS Linux 8") ]]; then
        yellow "检测到当前VPS系统为CentOS 8, 是否升级为CentOS Stream 8以确保软件包正常安装?"
        read -rp "请输入选项 [y/n]: " comfirm
        if [[ $comfirm =~ "y"|"Y" ]]; then
            yellow "正在为你升级到CentOS Stream 8, 大概需要10-30分钟的时间"
            sleep 1
            sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
            yum clean all && yum makecache
            dnf swap centos-linux-repos centos-stream-repos distro-sync -y
        else
            red "已取消升级过程, 脚本即将退出！"
            exit 1
        fi
    fi
}

check_status(){
    yellow "正在检查VPS系统及IP配置环境, 请稍等..."
    WgcfIPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfIPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WgcfIPv4Status =~ "on"|"plus" ]] || [[ $WgcfIPv6Status =~ "on"|"plus" ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        v6=`curl -s6m8 https://ip.gs -k`
        v4=`curl -s4m8 https://ip.gs -k`
        wg-quick up wgcf >/dev/null 2>&1
    else
        v6=`curl -s6m8 https://ip.gs -k`
        v4=`curl -s4m8 https://ip.gs -k`
        if [[ -z $v4 && -n $v6 ]]; then
            yellow "检测到为纯IPv6 VPS, 已自动添加DNS64解析服务器"
            echo -e "nameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
        fi
    fi
}

config_panel() {
    yellow "出于安全考虑，安装/更新完成后需要强制修改端口与账户密码"
    read -rp "请设置您的用户名 [默认随机用户名]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "请设置您的密码 [默认随机密码]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "请设置面板访问端口 [默认随机端口]: " config_port
    [[ -z $config_port ]] && config_port=$(shuf -i 1000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$config_port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w  "$config_port") ]]; then
            yellow "你设置的端口目前已被占用，请重新设置端口"
            read -rp "请设置面板访问端口 [默认随机端口]: " config_port
        fi
    done
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    /usr/local/x-ui/x-ui setting -port ${config_port} >/dev/null 2>&1
}

install_base(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    
    if [[ -z $(type -P curl) ]]; then
        yellow "检测curl未安装，正在安装中..."
        ${PACKAGE_INSTALL[int]} curl
    fi
    
    if [[ -z $(type -P tar) ]]; then
        yellow "检测tar未安装，正在安装中..."
        ${PACKAGE_INSTALL[int]} tar
    fi
    
    check_status
}

download_xui(){
    if [[ -e /usr/local/x-ui/ ]]; then
        rm -rf /usr/local/x-ui/
    fi
    
    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/Misaka-blog/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -z "$last_version" ]]; then
            red "检测 x-ui 版本失败，可能是超出 Github API 限制，正在使用备用源检测最新版本"
            last_version=$(curl -sm8 https://raw.githubusercontents.com/Misaka-blog/x-ui/main/config/version)
            if [[ -z "$last_version" ]]; then
                red "检测 x-ui 版本失败，请确保你的服务器能够连接 Github 服务"
                rm -f install.sh
                exit 1
            fi
        fi
        yellow "检测到 x-ui 最新版本：${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz https://github.com/Misaka-blog/x-ui/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz
        if [[ $? -ne 0 ]]; then
            red "下载 x-ui 失败，请确保你的服务器能够连接并下载 Github 的文件"
            rm -f install.sh
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Misaka-blog/x-ui/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz"
        yellow "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            red "下载 x-ui v$1 失败，请确保此版本存在"
            rm -f install.sh
            exit 1
        fi
    fi
    
    cd /usr/local/
    tar zxvf x-ui-linux-$(archAffix).tar.gz
    rm -f x-ui-linux-$(archAffix).tar.gz
    
    cd x-ui
    chmod +x x-ui bin/xray-linux-$(archAffix)
    cp -f x-ui.service /etc/systemd/system/
    
    wget -N --no-check-certificate https://raw.githubusercontents.com/Misaka-blog/x-ui/main/x-ui.sh -O /usr/bin/x-ui
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
}

info_bar(){
    clear
    echo "#############################################################"
    echo -e "#                   ${RED}Misaka x-ui 魔改优化版${PLAIN}                  #"
    echo -e "# ${GREEN}作者${PLAIN}: vaxilu, FranzKafkaYu, Misaka No                     #"
    echo -e "# ${GREEN}博客${PLAIN}: https://owo.misaka.rest                             #"
    echo -e "# ${GREEN}论坛${PLAIN}: https://vpsgo.co                                    #"
    echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/misakanetcn                            #"
    echo "#############################################################"
    echo ""
    echo -e "系统: ${GREEN} ${CMD} ${PLAIN}"
    echo ""
    sleep 2
}

install_xui() {
    info_bar
    
    if [[ -e /usr/local/x-ui/ ]]; then
        yellow "检测到目前已安装x-ui面板, 确认卸载原x-ui面板?"
        read -rp "请输入选项 [Y/N, 默认N]" yn
        if [[ $yn =~ "Y"|"y" ]]; then
            x-ui uninstall
        else
            red "已取消卸载, 脚本退出!"
            exit 1
        fi
    fi
    
    systemctl stop x-ui >/dev/null 2>&1
    
    install_base
    download_xui $1
    config_panel
    
    systemctl daemon-reload
    systemctl enable x-ui >/dev/null 2>&1
    systemctl start x-ui
    
    cd $cur_dir
    rm -f install.sh
    green "x-ui v${last_version} 安装完成，面板已启动"
    echo -e ""
    echo -e "x-ui 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - 显示管理菜单 (功能更多)"
    echo -e "x-ui start        - 启动 x-ui 面板"
    echo -e "x-ui stop         - 停止 x-ui 面板"
    echo -e "x-ui restart      - 重启 x-ui 面板"
    echo -e "x-ui status       - 查看 x-ui 状态"
    echo -e "x-ui enable       - 设置 x-ui 开机自启"
    echo -e "x-ui disable      - 取消 x-ui 开机自启"
    echo -e "x-ui log          - 查看 x-ui 日志"
    echo -e "x-ui v2-ui        - 迁移本机器的 v2-ui 账号数据至 x-ui"
    echo -e "x-ui update       - 更新 x-ui 面板"
    echo -e "x-ui install      - 安装 x-ui 面板"
    echo -e "x-ui uninstall    - 卸载 x-ui 面板"
    echo -e "----------------------------------------------"
    echo -e ""
    show_login_info
}

show_login_info(){
    if [[ -n $v4 && -z $v6 ]]; then
        echo -e "面板IPv4登录地址为: ${GREEN}http://$v4:$config_port ${PLAIN}"
    elif [[ -n $v6 && -z $v4 ]]; then
        echo -e "面板IPv6登录地址为: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    elif [[ -n $v4 && -n $v6 ]]; then
        echo -e "面板IPv4登录地址为: ${GREEN}http://$v4:$config_port ${PLAIN}"
        echo -e "面板IPv6登录地址为: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    fi
    echo -e "登录用户名: ${GREEN}$config_account ${PLAIN}"
    echo -e "登录密码: ${GREEN}$config_password ${PLAIN}"
}

check_centos8
install_xui $1
