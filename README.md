# Misaka-blog x-ui 魔改优化版

支持多协议多用户的 xray 面板

博客说明：https://owo.misaka.rest/misakablog-xui/

x-ui教程：https://owo.misaka.rest/x-ui/

## 安装命令

```shell
wget -N --no-check-certificate https://raw.githubusercontents.com/Misaka-blog/x-ui/main/install.sh && bash install.sh
```

快捷方式：`x-ui`

> 如提示 `wget: command not found` 请安装wget后再执行本脚本

> CentOS: `yum install -y wget` Debian / Ubuntu: `apt install -y wget`

## 建议系统

* CentOS 7+
* Fedora 29+
* Ubuntu 16+
* Debian 9+

## 功能介绍

* 系统状态监控
* 支持多用户多协议，网页可视化操作
* 支持的协议：vmess、vless、trojan、shadowsocks、shadowsocks 2022、dokodemo-door、socks、http
* 支持配置更多传输配置
* 流量统计，限制流量，限制到期时间
* 可自定义 xray 配置模板
* 支持 https 访问面板（请自行准备域名 + ssl 证书）
* 支持纯IPv4、纯IPv6及原生双栈VPS
* 支持 amd64、arm64、s390x CPU架构的VPS
* 支持 Telegram Bot 提醒面板，SSH登录信息、流量使用情况

## TG机器人使用

本魔改优化版x-ui面板支持通过TG机器人实现每日流量通知，面板登录提醒以及cmd控制等功能。

通知内容：节点流量使用、面板登录提醒、节点到期提醒和流量预警提醒

机器人命令列表：

```
/help 获取bot的帮助信息
/delete [port] 删除对应端口的节点
/restart 重启xray内核
/status 获取当前系统状态
/enable [port] 开启对应端口的节点
/disable [port] 关闭对应端口的节点
/clear [port] 清理对应端口的节点流量
/clearall 清理所有节点流量
/version [version] 将会升级xray内核到 [version] 版本
```

### 准备材料

* TG机器人TOKEN
* TG机器人ChatId
* 机器人周期运行时间，采用crontab语法，语法说明如下

![](https://gcore.jsdelivr.net/gh/Misaka-blog/tuchuang@master/20220420235233.png)

> Crontab表达式生成器：https://cron.qqe2.com/

## 感谢列表

X-ui 原作：https://github.com/vaxilu/x-ui

FranzKafkaYu 魔改版：https://github.com/FranzKafkaYu/x-ui
