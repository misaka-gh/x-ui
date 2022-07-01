#!/bin/bash

export LANG=en_US.UTF-8

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

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
        * ) red "不支持的CPU架构！" && exit 1 ;;
    esac
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启x-ui面板，重启面板也会重启xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${YELLOW}按回车键返回主菜单: ${PLAIN}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/Misaka-blog/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    read -rp "本功能会更新x-ui面板至目前最新版本, 数据不会丢失, 是否继续? [Y/N]: " yn
    if [[ $yn =~ "Y"|"y" ]]; then
        systemctl stop x-ui
        if [[ -e /usr/local/x-ui/ ]]; then
            rm -rf /usr/local/x-ui/
        fi
        
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
        
        yellow "检测到 x-ui 最新版本: ${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz https://github.com/Misaka-blog/x-ui/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz
        if [[ $? -ne 0 ]]; then
            red "下载 x-ui 失败, 请确保你的服务器能够连接并下载 Github 的文件"
            exit 1
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
        
        systemctl daemon-reload
        systemctl enable x-ui >/dev/null 2>&1
        systemctl start x-ui
        
        green "更新完成，已自动重启x-ui面板 "
        exit 1
    else
        red "已取消升级x-ui面板"
        exit 1
    fi
}

uninstall() {
    confirm "确定要卸载x-ui面板吗，xray 也会卸载?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf
    rm /usr/bin/x-ui -f
    green "x-ui面板已彻底卸载成功"
}

reset_user() {
    confirm "确定要重置面板用户名和密码吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    read -rp "请设置您的用户名 [默认随机用户名]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "请设置您的密码 [默认随机密码]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    echo -e "面板用户名已重置为: ${GREEN} ${config_account} ${PLAIN}"
    echo -e "面板密码已重置为: ${GREEN} ${config_password} ${PLAIN}"
    green "请使用新的用户名、密码登录x-ui面板"
    confirm_restart
}

reset_config() {
    confirm "确定要重置所有设置吗，账号数据不会丢失，用户名和密码不会改变" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset >/dev/null 2>&1
    echo -e "所有面板设置已重置为默认值，请重启面板并使用默认的 ${GREEN}54321${PLAIN} 端口访问面板"
    confirm_restart
}

set_port() {
    echo && echo -n -e "输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        red "已取消设置端口!"
        before_show_menu
    else
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                yellow "你设置的端口目前已被占用，请重新设置端口"
                echo -n -e "输入端口号[1-65535]: " && read port
            fi
        done
        /usr/local/x-ui/x-ui setting -port ${port} >/dev/null 2>&1
        echo -e "设置端口完毕，请重启面板并使用新设置的端口 ${GREEN}${port}${PLAIN} 访问面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        green "x-ui面板已运行，无需再次启动，如需重启面板请使用重启选项"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            green "x-ui 面板启动成功"
        else
            red "x-ui 面板启动失败，请稍后使用 x-ui log 查看日志信息"
        fi
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        green "x-ui 面板目前已停止，无需再次停止"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            green "x-ui 与 xray 停止成功"
        else
            red "x-ui 面板停止失败，请稍后使用 x-ui log 查看日志信息"
        fi
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        green "x-ui 与 xray 重启成功"
    else
        red "x-ui 面板重启失败，请稍后使用 x-ui log 查看日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable_xui() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        green "x-ui 设置开机自启成功"
    else
        red "x-ui 设置开机自启失败"
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable_xui() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        green "x-ui 取消开机自启成功"
    else
        red "x-ui 取消开机自启失败"
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui
    
    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontents.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/Misaka-blog/x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        red "下载脚本失败，请检查本机能否连接 GitHub"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        green "升级脚本成功，请重新运行脚本" && exit 1
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        red "x-ui 面板已安装，请不要重复安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        red "请先安装 X-ui 面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "面板状态: ${GREEN}已运行${PLAIN}"
            show_enable_status
        ;;
        1)
            echo -e "面板状态: ${YELLOW}未运行${PLAIN}"
            show_enable_status
        ;;
        2)
            echo -e "面板状态: ${RED}未安装${PLAIN}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${GREEN}是${PLAIN}"
    else
        echo -e "是否开机自启: ${RED}否${PLAIN}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray 状态: ${GREEN}运行中${PLAIN}"
    else
        echo -e "xray 状态: ${RED}未运行${PLAIN}"
    fi
}

open_ports(){
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    green "VPS中的所有网络端口已开启"
    before_show_menu
}

show_usage() {
    echo "x-ui 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "x-ui              - 显示管理菜单 (功能更多)"
    echo "x-ui start        - 启动 x-ui 面板"
    echo "x-ui stop         - 停止 x-ui 面板"
    echo "x-ui restart      - 重启 x-ui 面板"
    echo "x-ui status       - 查看 x-ui 状态"
    echo "x-ui enable       - 设置 x-ui 开机自启"
    echo "x-ui disable      - 取消 x-ui 开机自启"
    echo "x-ui log          - 查看 x-ui 日志"
    echo "x-ui v2-ui        - 迁移本机器的 v2-ui 账号数据至 x-ui"
    echo "x-ui update       - 更新 x-ui 面板"
    echo "x-ui install      - 安装 x-ui 面板"
    echo "x-ui uninstall    - 卸载 x-ui 面板"
    echo "------------------------------------------"
}

check_login_info(){
    yellow "正在检查VPS系统及x-ui面板配置, 请稍等..."
    
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
    fi
    
    config_port=$(/usr/local/x-ui/x-ui 2>&1 | grep tcp | awk '{print $5}' | sed "s/://g")
}

show_menu() {
    echo -e "
  ${GREEN}x-ui 面板管理脚本${PLAIN}
  ${GREEN}0.${PLAIN} 退出脚本
————————————————
  ${GREEN}1.${PLAIN} 安装 x-ui
  ${GREEN}2.${PLAIN} 更新 x-ui
  ${GREEN}3.${PLAIN} 卸载 x-ui
————————————————
  ${GREEN}4.${PLAIN} 重置用户名密码
  ${GREEN}5.${PLAIN} 重置面板设置
  ${GREEN}6.${PLAIN} 设置面板端口
————————————————
  ${GREEN}7.${PLAIN} 启动 x-ui
  ${GREEN}8.${PLAIN} 停止 x-ui
  ${GREEN}9.${PLAIN} 重启 x-ui
 ${GREEN}10.${PLAIN} 查看 x-ui 状态
 ${GREEN}11.${PLAIN} 查看 x-ui 日志
————————————————
 ${GREEN}12.${PLAIN} 设置 x-ui 开机自启
 ${GREEN}13.${PLAIN} 取消 x-ui 开机自启
————————————————
 ${GREEN}14.${PLAIN} 一键安装 bbr (最新内核)
 ${GREEN}15.${PLAIN} 一键申请证书 (acme脚本申请)
 ${GREEN}16.${PLAIN} VPS防火墙放开所有网络端口
 ${GREEN}17.${PLAIN} 安装并配置CloudFlare WARP
    "
    show_status
    echo ""
    if [[ -n $v4 && -z $v6 ]]; then
        echo -e "面板IPv4登录地址为: ${GREEN}http://$v4:$config_port ${PLAIN}"
    elif [[ -n $v6 && -z $v4 ]]; then
        echo -e "面板IPv6登录地址为: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    elif [[ -n $v4 && -n $v6 ]]; then
        echo -e "面板IPv4登录地址为: ${GREEN}http://$v4:$config_port ${PLAIN}"
        echo -e "面板IPv6登录地址为: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    fi
    echo && read -rp "请输入选择 [0-17]: " num
    
    case "${num}" in
        0) exit 1 ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && reset_user ;;
        5) check_install && reset_config ;;
        6) check_install && set_port ;;
        7) check_install && start ;;
        8) check_install && stop ;;
        9) check_install && restart ;;
        10) check_install && status ;;
        11) check_install && show_log ;;
        12) check_install && enable_xui ;;
        13) check_install && disable_xui ;;
        14) install_bbr ;;
        15) wget -N https://raw.githubusercontents.com/Misaka-blog/acme-1key/master/acme1key.sh && bash acme1key.sh && before_show_menu ;;
        16) open_ports ;;
        17) wget -N --no-check-certificate https://raw.githubusercontents.com/Misaka-blog/Misaka-WARP-Script/master/misakawarp.sh && bash misakawarp.sh && before_show_menu ;;
        *) red "请输入正确的数字 [0-17]" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable_xui 0 ;;
        "disable") check_install 0 && disable_xui 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0 ;;
        "update") check_install 0 && update ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        *) show_usage ;;
    esac
else
    check_login_info && show_menu
fi