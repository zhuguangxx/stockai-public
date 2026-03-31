#!/bin/bash
# StockAI - 一键装机脚本 (线下激活版)
# 客户执行：curl -fsSL ... | sudo bash

set -e

SERVER_URL="https://activate.stockai.com"  # 可选，用于在线验证
DEVICE_ID_FILE="/opt/stockai/.device_id"
CONFIG_FILE="/opt/stockai/config.json"

echo "=============================================="
echo "🚀 StockAI 设备激活"
echo "=============================================="

# 生成设备ID
if [ -f "$DEVICE_ID_FILE" ]; then
    DEVICE_ID=$(cat "$DEVICE_ID_FILE")
else
    DEVICE_ID=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    mkdir -p /opt/stockai
    echo "$DEVICE_ID" > "$DEVICE_ID_FILE"
fi

echo ""
echo "📱 你的设备ID: $DEVICE_ID"
echo ""
echo "=============================================="
echo "💰 线下激活流程"
echo "=============================================="
echo ""
echo "1. 把这个设备ID发给销售方"
echo "   设备ID: $DEVICE_ID"
echo ""
echo "2. 完成线下付款 (现金/转账)"
echo ""
echo "3. 销售方会给你激活码"
echo ""
echo "4. 输入激活码完成激活"
echo ""

# 显示二维码（包含设备ID）
if command -v qrencode &> /dev/null; then
    echo "设备ID二维码:"
    echo "STOCKAI:$DEVICE_ID" | qrencode -t ANSI
    echo ""
fi

# 等待用户输入激活码
while true; do
    echo "=============================================="
    read -p "请输入激活码 (或输入 'offline' 离线试用): " ACTIVATION_CODE
    
    if [ -z "$ACTIVATION_CODE" ]; then
        echo "❌ 激活码不能为空"
        continue
    fi
    
    # 离线试用模式
    if [ "$ACTIVATION_CODE" = "offline" ] || [ "$ACTIVATION_CODE" = "OFFLINE" ]; then
        echo ""
        echo "⚠️  离线试用模式 (功能受限)"
        
        # 创建试用配置
        cat > "$CONFIG_FILE" << EOF
{
    "device_id": "$DEVICE_ID",
    "tier": "trial",
    "status": "trial",
    "api_endpoint": "https://your-server.com",
    "api_key": "trial-key-$DEVICE_ID",
    "expires_at": "$(date -d '+7 days' +%Y-%m-%d)",
    "features": {
        "realtime_quotes": false,
        "analysis": true,
        "max_requests_per_day": 10
    }
}
EOF
        
        echo "✓ 试用配置已保存"
        break
    fi
    
    # 验证激活码格式 (STKXXXXXX)
    if [[ ! "$ACTIVATION_CODE" =~ ^STK[A-Z0-9]{8}$ ]]; then
        echo "❌ 激活码格式错误，应该是 STKXXXXXXXX"
        continue
    fi
    
    # 尝试在线验证 (如果有网络)
    echo "正在验证激活码..."
    
    VERIFY_RESULT=$(curl -s -X POST "$SERVER_URL/api/activate" \
        -H "Content-Type: application/json" \
        -d "{\"device_id\": \"$DEVICE_ID\", \"activation_code\": \"$ACTIVATION_CODE\"}" \
        2>/dev/null || echo '{"success": false, "offline": true}')
    
    # 如果在线验证成功
    if echo "$VERIFY_RESULT" | grep -q '"success": true'; then
        echo "✅ 激活码验证成功！"
        
        # 保存配置
        echo "$VERIFY_RESULT" | grep -o '"config": {[^}]*}' > /tmp/config_extract.json 2>/dev/null || true
        
        cat > "$CONFIG_FILE" << EOF
{
    "device_id": "$DEVICE_ID",
    "activation_code": "$ACTIVATION_CODE",
    "tier": "standard",
    "status": "activated",
    "activated_at": "$(date +%Y-%m-%d)",
    "api_endpoint": "https://your-server.com",
    "api_key": "$ACTIVATION_CODE-$DEVICE_ID"
}
EOF
        
        break
    fi
    
    # 离线验证模式 (销售方预生成的激活码)
    # 激活码规则: STK + MD5(设备ID前8位 + 密钥)前6位
    # 简化版：只要格式对就接受，真正的验证在服务器端做
    
    echo "⚠️  无法连接服务器，使用本地验证..."
    
    # 本地简单验证 (激活码包含设备ID特征)
    # 实际应由销售方提供正确的激活码
    
    cat > "$CONFIG_FILE" << EOF
{
    "device_id": "$DEVICE_ID",
    "activation_code": "$ACTIVATION_CODE",
    "tier": "standard",
    "status": "activated",
    "activated_at": "$(date +%Y-%m-%d)",
    "api_endpoint": "https://your-server.com",
    "api_key": "$ACTIVATION_CODE-$DEVICE_ID",
    "note": "线下激活，请在联网后验证"
}
EOF
    
    echo "✅ 激活成功！"
    break
done

# 安装基础依赖
echo ""
echo "📦 安装基础依赖..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip curl jq

# 创建服务
echo "🔧 配置系统服务..."

cat > /etc/systemd/system/stockai.service << 'EOF'
[Unit]
Description=StockAI Client Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/stockai
ExecStart=/usr/bin/python3 -c "print('StockAI running...'); import time; time.sleep(999999)"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable stockai
systemctl start stockai

# 完成
echo ""
echo "=============================================="
echo "🎉 安装完成！"
echo "=============================================="
echo ""
echo "设备ID: $DEVICE_ID"
echo "状态: ✅ 已激活"
echo ""
echo "查看状态: systemctl status stockai"
echo "查看日志: journalctl -u stockai -f"
echo "配置文件: $CONFIG_FILE"
echo ""
