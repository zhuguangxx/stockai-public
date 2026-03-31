#!/bin/bash
# StockAI - 一键装机脚本
# 在客户小主机首次启动时执行

set -e

# 配置
GITHUB_RAW="https://raw.githubusercontent.com/你的用户名/stockai-public/main"
SETUP_VERSION="v1.0.0"
DEVICE_ID_FILE="/opt/device-id"
CONFIG_DIR="/opt/stockai"
LOG_FILE="/var/log/stockai-setup.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a $LOG_FILE
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a $LOG_FILE
    exit 1
}

# 生成设备唯一ID
generate_device_id() {
    if [ -f "$DEVICE_ID_FILE" ]; then
        DEVICE_ID=$(cat $DEVICE_ID_FILE)
        log "设备ID已存在: $DEVICE_ID"
    else
        DEVICE_ID=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
        echo $DEVICE_ID > $DEVICE_ID_FILE
        log "生成新设备ID: $DEVICE_ID"
    fi
}

# 检查网络
check_network() {
    log "检查网络连接..."
    if ! ping -c 1 github.com > /dev/null 2>&1; then
        error "无法连接网络，请配置WiFi后重试"
    fi
    log "✓ 网络连接正常"
}

# 下载安装脚本
download_scripts() {
    log "从GitHub下载安装脚本..."
    
    mkdir -p $CONFIG_DIR/scripts
    cd $CONFIG_DIR
    
    # 下载公开脚本
    curl -fsSL "$GITHUB_RAW/scripts/install-base.sh" -o scripts/install-base.sh || error "下载失败"
    curl -fsSL "$GITHUB_RAW/scripts/install-agent.sh" -o scripts/install-agent.sh || error "下载失败"
    curl -fsSL "$GITHUB_RAW/scripts/first-boot.sh" -o scripts/first-boot.sh || error "下载失败"
    
    chmod +x scripts/*.sh
    log "✓ 脚本下载完成"
}

# 执行基础安装
install_base() {
    log "执行基础环境安装..."
    bash $CONFIG_DIR/scripts/install-base.sh
    log "✓ 基础环境安装完成"
}

# 显示激活二维码
show_activation() {
    log "生成激活二维码..."
    
    # 获取本机IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # 生成二维码内容
    QR_CONTENT="stockai://activate?device=$DEVICE_ID&ip=$LOCAL_IP"
    
    # 显示二维码 (如果安装了qrencode)
    if command -v qrencode > /dev/null; then
        echo ""
        echo "=============================================="
        echo "           请扫码激活设备"
        echo "=============================================="
        qrencode -t ANSI "$QR_CONTENT"
        echo ""
        echo "或访问: http://$LOCAL_IP:8080/activate"
        echo "设备ID: $DEVICE_ID"
        echo "=============================================="
    else
        echo ""
        echo "=============================================="
        echo "           设备待激活"
        echo "=============================================="
        echo "设备ID: $DEVICE_ID"
        echo "IP地址: $LOCAL_IP"
        echo ""
        echo "请在你的手机上完成激活:"
        echo "1. 打开StockAI小程序"
        echo "2. 点击'激活设备'"
        echo "3. 输入设备ID: $DEVICE_ID"
        echo "=============================================="
    fi
}

# 等待激活
wait_for_activation() {
    log "等待设备激活..."
    
    local retry_count=0
    local max_retry=360  # 等待1小时
    
    while [ $retry_count -lt $max_retry ]; do
        # 检查激活状态 (调用你的激活服务器)
        ACTIVATION_STATUS=$(curl -fsSL "https://你的激活服务器/api/device/$DEVICE_ID/status" 2>/dev/null || echo "pending")
        
        if [ "$ACTIVATION_STATUS" = "activated" ]; then
            log "✓ 设备已激活！"
            return 0
        fi
        
        sleep 10
        retry_count=$((retry_count + 1))
        
        if [ $((retry_count % 6)) -eq 0 ]; then
            log "等待激活中... (${retry_count}/$max_retry)"
        fi
    done
    
    error "激活超时，请检查网络或联系客服"
}

# 下载客户专属配置
download_config() {
    log "下载客户专属配置..."
    
    # 从私密仓库下载 (需要token)
    # 这个由激活服务器返回临时下载链接
    CONFIG_URL=$(curl -fsSL "https://你的激活服务器/api/device/$DEVICE_ID/config-url" 2>/dev/null)
    
    if [ -n "$CONFIG_URL" ]; then
        curl -fsSL "$CONFIG_URL" -o $CONFIG_DIR/config.json
        log "✓ 配置下载完成"
    else
        warn "未获取到专属配置，使用默认配置"
        cp $CONFIG_DIR/config.default.json $CONFIG_DIR/config.json
    fi
}

# 安装Agent
install_agent() {
    log "安装StockAI Agent..."
    bash $CONFIG_DIR/scripts/install-agent.sh --device-id $DEVICE_ID --config $CONFIG_DIR/config.json
    log "✓ Agent安装完成"
}

# 启动服务
start_services() {
    log "启动服务..."
    systemctl daemon-reload
    systemctl enable stockai-agent
    systemctl start stockai-agent
    log "✓ 服务已启动"
}

# 完成提示
show_completion() {
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    echo "🎉 StockAI 安装完成！"
    echo "=============================================="
    echo ""
    echo "设备ID: $DEVICE_ID"
    echo "IP地址: $LOCAL_IP"
    echo ""
    echo "使用方式:"
    echo "1. 微信添加 StockAI 机器人"
    echo "2. 发送'帮助'查看命令"
    echo "3. 发送股票代码获取分析"
    echo ""
    echo "管理后台: http://$LOCAL_IP:8080"
    echo ""
    echo "=============================================="
}

# 主流程
main() {
    echo "=============================================="
    echo "🚀 StockAI 一键装机脚本"
    echo "版本: $SETUP_VERSION"
    echo "=============================================="
    
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
       error "请使用 sudo 运行"
    fi
    
    # 步骤执行
    generate_device_id
    check_network
    download_scripts
    install_base
    show_activation
    wait_for_activation
    download_config
    install_agent
    start_services
    show_completion
    
    log "✅ 安装流程全部完成！"
}

# 运行
main "$@"
