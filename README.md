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

- **自动依赖安装**：自动检测并安装 `ufw` 和 `curl`，适配精简版（Minimal）系统。
- **清理旧规则**：自动识别并删除 `Nginx Full`、`Allow 80` 等可能导致 IP 泄露的宽泛规则。
- **防自锁机制**：强制保留 SSH 端口访问权限，防止配置防火墙时将自己关在外面。
- **IPv4 & IPv6**：完整支持 Cloudflare 的所有 IP 段。
- **一键执行**：支持 `curl | bash` 一键远程运行，无需手动下载。

## 🚀 快速开始

### 方式一：一键远程执行（推荐）

```bash
# 使用默认 SSH 端口 (22)
bash <(curl -sL https://raw.githubusercontent.com/ZDoge7/cf-only-ufw/master/cf-ufw.sh)

# 指定自定义 SSH 端口
bash <(curl -sL https://raw.githubusercontent.com/ZDoge7/cf-only-ufw/master/cf-ufw.sh) -p 2222
```

### 方式二：克隆仓库执行

```bash
git clone https://github.com/ZDoge7/cf-only-ufw.git
cd cf-only-ufw
chmod +x cf-ufw.sh
sudo bash cf-ufw.sh
```

## 📖 命令参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-p <port>` | 指定 SSH 端口 | `22` |
| `-f` | 强制模式，跳过部分确认 | 关闭 |
| `-h` | 显示帮助信息 | - |

**示例：**

```bash
# 自定义 SSH 端口为 2222，并启用强制模式
sudo bash cf-ufw.sh -p 2222 -f
```

## 🔧 工作原理

脚本执行以下 5 个步骤：

1. **检查系统环境** — 确认为 Debian/Ubuntu 系统，自动安装缺失的 `curl` 和 `ufw`。
2. **获取 Cloudflare IP** — 从 Cloudflare 官方接口拉取最新的 IPv4 和 IPv6 地址段。
3. **清理旧规则** — 删除可能导致源站 IP 暴露的宽泛放行规则（如 `Nginx Full`、`allow 80/tcp`）。
4. **配置白名单规则** — 为所有 Cloudflare IP 段添加 UFW 放行规则，仅允许其访问 80/443 端口。
5. **启用防火墙** — 重载并启用 UFW，使规则立即生效。

## ⚠️ 注意事项

- 脚本**必须以 root 权限运行**（`sudo` 或 root 用户）。
- 执行前请确认你的 SSH 端口，如果使用了非标准端口，务必通过 `-p` 参数指定，否则可能导致 SSH 连接中断。
- 脚本仅适用于 **Debian / Ubuntu** 系统。
- Cloudflare 会不定期更新其 IP 段，建议定期重新运行此脚本以保持规则最新。

### 定期自动更新（可选）

通过 cron 定时任务自动更新 Cloudflare IP 规则：

```bash
# 每周日凌晨 3 点自动更新
echo "0 3 * * 0 root bash /path/to/cf-ufw.sh -f" | sudo tee /etc/cron.d/cf-ufw-update
```

## 📋 系统要求

- **操作系统**：Ubuntu 16.04+ / Debian 9+
- **权限**：root 或 sudo
- **网络**：需要能访问 `https://www.cloudflare.com`

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。
