# cf-only-ufw
# Cloudflare Only UFW - 隐藏源站 IP 脚本

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/language-Bash-green.svg)]()
[![OS](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian-orange.svg)]()

一个简单而强大的 Shell 脚本，用于 Ubuntu/Debian 系统。它会自动配置 UFW 防火墙，**仅允许 Cloudflare 的 IP 地址访问你的网站端口（80/443）**，从而防止源站 IP 泄露和绕过 CDN 的直接攻击。

## 🛡️ 为什么需要这个？

如果你使用 Cloudflare 作为 CDN，但没有配置防火墙，黑客或扫描器（如 Censys/Shodan）可以通过直接扫描全网 IP 找到你的源服务器。一旦他们找到了源站 IP：
1.  **DDoS 攻击** 可以绕过 Cloudflare 直接打垮你的服务器。
2.  **SSL 证书泄露** 会暴露你托管在该 IP 上的所有域名。

此脚本通过白名单机制，确保只有经过 Cloudflare 清洗的流量才能进入你的服务器。

## ✨ 功能特性

* **自动依赖安装**：自动检测并安装 `ufw` 和 `curl`，适配精简版（Minimal）系统。
* **清理旧规则**：自动识别并删除 `Nginx Full`、`Allow 80` 等可能导致 IP 泄露的宽泛规则。
* **防自锁机制**：强制保留 SSH 端口访问权限，防止配置防火墙时将自己关在外面。
* **IPv4 & IPv6**：完整支持 Cloudflare 的所有 IP 段。

## 🚀 快速开始

### 1. 下载脚本

```bash
git clone [https://github.com/](https://github.com/)[你的GitHub用户名]/cloudflare-only-ufw.git
cd cloudflare-only-ufw
