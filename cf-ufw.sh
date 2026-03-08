#!/bin/bash

# =========================================================
# Cloudflare UFW Auto-Shield (One-Liner Edition)
# Source: https://github.com/[YourUser]/[YourRepo]
# =========================================================

# --- 默认配置 ---
SSH_PORT=22
FORCE_MODE=false
CF_PORTS="80,443"

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
    echo -e "  -h          显示帮助信息"
    exit 1
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
while getopts "p:fh" opt; do
  case $opt in
    p) SSH_PORT=$OPTARG ;;
    f) FORCE_MODE=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

# --- 主逻辑开始 ---
print_logo

# 权限检查
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[Error] 请使用 root 权限或 sudo 执行此脚本。${NC}"
  exit 1
fi

echo -e "${GREEN}==> 目标 SSH 端口: ${SSH_PORT}${NC}"

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
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

if [ -z "$CF_IPV4" ]; then
    echo -e "${RED}[Error] 无法连接 Cloudflare IP 接口。${NC}"
    exit 1
fi

# 清理旧规则
echo -e "${YELLOW}[3/5] 清理旧规则...${NC}"
ufw delete allow 80/tcp > /dev/null 2>&1
ufw delete allow 443/tcp > /dev/null 2>&1
ufw delete allow 'Nginx Full' > /dev/null 2>&1
ufw delete allow 'Nginx HTTP' > /dev/null 2>&1
ufw delete allow 'Nginx HTTPS' > /dev/null 2>&1

# 应用新规则
echo -e "${YELLOW}[4/5] 配置防火墙规则...${NC}"

# 1. 确保 SSH 不会被封 (最关键的一步)
if ! ufw status | grep -q "$SSH_PORT/tcp"; then
    echo -e "   -> 添加 SSH 端口放行规则: $SSH_PORT"
    ufw allow "$SSH_PORT/tcp" comment 'SSH Access' > /dev/null
fi

# 2. 添加 CF 白名单
for ip in $CF_IPV4; do ufw allow proto tcp from "$ip" to any port "$CF_PORTS" comment 'Cloudflare IP' > /dev/null; done
for ip in $CF_IPV6; do ufw allow proto tcp from "$ip" to any port "$CF_PORTS" comment 'Cloudflare IP' > /dev/null; done

# 重载与启用
echo -e "${YELLOW}[5/5] 启用防火墙...${NC}"
ufw reload > /dev/null
echo "y" | ufw enable > /dev/null 2>&1

echo -e "${GREEN}"
echo "================================================"
echo "   配置完成！Success!"
echo "   - SSH 端口 $SSH_PORT: 已放行"
echo "   - Web 端口 80/443: 仅 Cloudflare 可访问"
echo "================================================"
echo -e "${NC}"
