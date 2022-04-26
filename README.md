# X-ui Misaka-blog 魔改版

支持多协议多用户的 xray 面板

# 功能介绍

- 系统状态监控
- 支持多用户多协议，网页可视化操作
- 支持的协议：vmess、vless、trojan、shadowsocks、dokodemo-door、socks、http
- 支持配置更多传输配置
- 流量统计，限制流量，限制到期时间
- 可自定义 xray 配置模板
- 支持 https 访问面板（自备域名 + ssl 证书）
- 支持 amd64、arm64、s390x 架构的VPS
- 支持 Telegram Bot 提醒登录信息、流量使用情况
- 更多高级配置项，详见面板

# 安装或升级命令

```shell
wget -N --no-check-certificate https://raw.githubusercontents.com/Misaka-blog/x-ui/master/install.sh && bash install.sh
```

## 建议系统

- CentOS 7+
- Ubuntu 16+
- Debian 8+

# 常见问题

## 从 v2-ui 迁移
首先在安装了 v2-ui 的服务器上安装最新版 x-ui，然后使用以下命令进行迁移，将迁移本机 v2-ui 的`所有 inbound 账号数据`至 x-ui，`面板设置和用户名密码不会迁移`
> 迁移成功后请`关闭 v2-ui`并且`重启 x-ui`，否则 v2-ui 的 inbound 会与 x-ui 的 inbound 会产生`端口冲突`
```
x-ui v2-ui
```

# 感谢列表

X-ui 原作：https://github.com/vaxilu/x-ui

FranzKafkaYu 魔改版：https://github.com/FranzKafkaYu/x-ui
