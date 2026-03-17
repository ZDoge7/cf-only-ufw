#!/bin/bash
set -euo pipefail

# =========================================================
# Cloudflare UFW Auto-Shield (One-Liner Edition)
# Source: https://github.com/[YourUser]/[YourRepo]
# =========================================================

# --- 默认配置 ---
SSH_PORT=22
FORCE_MODE=false
CF_PORTS=(80 443)
CLOUDFLARED_TOKEN=""

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 帮助函数 ---
usage() {
    echo -e "用法: bash <(curl -sL https://...) [选项]"
    echo -e "选项:"
    echo -e "  -p <port>   指定 SSH 端口 (默认: 22)"
    echo -e "  -f          强制模式 (跳过部分确认)"
    echo -e "  -t <token>  自动安装并配置 cloudflared (Tunnel Token)"
    echo -e "  -h          显示帮助信息"
    exit 1
}

validate_port() {
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        echo -e "${RED}[Error] 无效的 SSH 端口: $1 (有效范围: 1-65535)。${NC}"
        exit 1
    fi
}

# --- cloudflared 自动配置 ---
setup_cloudflared() {
    local token="$1"

    echo -e "${YELLOW}[6/6] 配置 cloudflared Connector...${NC}"

    if ! command -v cloudflared &> /dev/null; then
        echo -e "   -> 安装 cloudflared..."
        install -m 0755 -d /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
        chmod a+r /usr/share/keyrings/cloudflare-main.gpg
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
            > /etc/apt/sources.list.d/cloudflared.list
        apt-get update -qq
        apt-get install -y -qq cloudflared
    else
        echo -e "   -> cloudflared 已安装，跳过安装步骤。"
    fi

    echo -e "   -> 注册 cloudflared systemd 服务..."
    cloudflared service uninstall > /dev/null 2>&1 || true
    cloudflared service install "$token" > /dev/null
    systemctl enable --now cloudflared > /dev/null 2>&1 || true

    if systemctl is-active --quiet cloudflared; then
        echo -e "${GREEN}   -> cloudflared 服务运行中。${NC}"
    else
        echo -e "${RED}[Error] cloudflared 服务启动失败，请检查: journalctl -u cloudflared -e${NC}"
        exit 1
    fi
}

# --- ASCII Logo (致敬 YABS) ---
print_logo() {
    echo -e "${BLUE}"
    echo "   ____ ___      _   _  ______        __"
    echo "  / ___| __|    | | | ||  ____|       \ \\"
    echo " | |   | |_     | | | || |__ __      __\ \\"
    echo " | |___|  _|    | |_| ||  __|\ \ /\ / / | |"
    echo "  \____|_|       \___/ |_|    \ V  V /  | |"
    echo "                               \_/\_/  /_/"
    echo -e "${NC}"
    echo -e "Cloudflare UFW Shield | Version 3.0"
    echo -e "----------------------------------------"
}

# --- 参数解析 ---
# 这一步是 One-Liner 的核心，允许 curl | bash -s -- -p 1234 这种用法
while getopts "p:ft:h" opt; do
  case $opt in
    p) SSH_PORT=$OPTARG ;;
    f) FORCE_MODE=true ;;
    t) CLOUDFLARED_TOKEN=$OPTARG ;;
    h) usage ;;
    *) usage ;;
  esac
done

validate_port "$SSH_PORT"

# --- 主逻辑开始 ---
print_logo

# 权限检查
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[Error] 请使用 root 权限或 sudo 执行此脚本。${NC}"
  exit 1
fi

echo -e "${GREEN}==> 目标 SSH 端口: ${SSH_PORT}${NC}"

if [ "$FORCE_MODE" = false ]; then
    echo -e "${YELLOW}即将应用 UFW 规则，可能影响现有网络访问。${NC}"
    read -r -p "继续执行？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消执行。${NC}"
        exit 0
    fi
fi

# 环境安装 (curl, ufw)
echo -e "${YELLOW}[1/5] 检查系统环境...${NC}"
if [ -f /usr/bin/apt-get ]; then
    # 简单的锁检测
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done
    
    if ! command -v curl &> /dev/null; then apt-get update -qq && apt-get install -y -qq curl; fi
    if ! command -v ufw &> /dev/null; then apt-get update -qq && apt-get install -y -qq ufw; fi
else
    echo -e "${RED}[Error] 仅支持 Debian/Ubuntu 系统。${NC}"
    exit 1
fi

# 获取 IP
echo -e "${YELLOW}[2/5] 获取 Cloudflare IP 列表...${NC}"
CF_IPV4=$(curl -fsSL --connect-timeout 10 --max-time 20 https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -fsSL --connect-timeout 10 --max-time 20 https://www.cloudflare.com/ips-v6 || true)

if [ -z "$CF_IPV4" ]; then
    echo -e "${RED}[Error] 无法连接 Cloudflare IP 接口。${NC}"
    exit 1
fi

# 清理旧规则
echo -e "${YELLOW}[3/5] 清理旧规则...${NC}"
ufw --force delete allow 80/tcp > /dev/null 2>&1 || true
ufw --force delete allow 443/tcp > /dev/null 2>&1 || true
ufw --force delete allow 'Nginx Full' > /dev/null 2>&1 || true
ufw --force delete allow 'Nginx HTTP' > /dev/null 2>&1 || true
ufw --force delete allow 'Nginx HTTPS' > /dev/null 2>&1 || true

# 应用新规则
echo -e "${YELLOW}[4/5] 配置防火墙规则...${NC}"

# 1. 确保 SSH 不会被封 (最关键的一步)
if ! ufw status | grep -q "$SSH_PORT/tcp"; then
    echo -e "   -> 添加 SSH 端口放行规则: $SSH_PORT"
    ufw allow "$SSH_PORT/tcp" comment 'SSH Access' > /dev/null
fi

# 2. 添加 CF 白名单
for ip in $CF_IPV4; do
    for port in "${CF_PORTS[@]}"; do
        ufw allow proto tcp from "$ip" to any port "$port" comment 'Cloudflare IP' > /dev/null
    done
done

for ip in $CF_IPV6; do
    for port in "${CF_PORTS[@]}"; do
        ufw allow proto tcp from "$ip" to any port "$port" comment 'Cloudflare IP' > /dev/null
    done
done

# 重载与启用
if [ -n "$CLOUDFLARED_TOKEN" ]; then
    echo -e "${YELLOW}[5/6] 启用防火墙...${NC}"
else
    echo -e "${YELLOW}[5/5] 启用防火墙...${NC}"
fi
ufw reload > /dev/null
ufw --force enable > /dev/null 2>&1

if [ -n "$CLOUDFLARED_TOKEN" ]; then
    setup_cloudflared "$CLOUDFLARED_TOKEN"
fi

echo -e "${GREEN}"
echo "================================================"
echo "   配置完成！Success!"
echo "   - SSH 端口 $SSH_PORT: 已放行"
echo "   - Web 端口 80/443: 仅 Cloudflare 可访问"
if [ -n "$CLOUDFLARED_TOKEN" ]; then
    echo "   - cloudflared: 已安装并连接 Tunnel"
    echo "   - 下一步: 在 Cloudflare Dashboard > Zero Trust > Networks > Tunnels 中配置域名/端口映射"
fi
echo "================================================"
echo -e "${NC}"
