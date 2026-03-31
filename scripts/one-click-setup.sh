#!/bin/bash
# StockAI - 一键装机脚本 (简化版)
# 客户小主机执行：curl -fsSL ... | sudo bash

set -e

SERVER_URL="https://activate.stockai.com"
DEVICE_ID_FILE="/opt/stockai/.device_id"

echo "=============================================="
echo "🚀 StockAI 一键装机"
echo "=============================================="

# 生成设备ID
if [ -f "$DEVICE_ID_FILE" ]; then
    DEVICE_ID=$(cat "$DEVICE_ID_FILE")
else
    DEVICE_ID=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    mkdir -p /opt/stockai
    echo "$DEVICE_ID" > "$DEVICE_ID_FILE"
fi

echo "设备ID: $DEVICE_ID"
echo ""

# 安装基础依赖
echo "📦 安装基础依赖..."
apt-get update -qq
apt-get install -y -qq curl python3 python3-pip jq qrencode

# 注册设备
echo "📡 注册设备..."
RESPONSE=$(curl -s -X POST "$SERVER_URL/api/device/register" \
    -H "Content-Type: application/json" \
    -d "{\"device_id\": \"$DEVICE_ID\"}" 2>/dev/null || echo '{"success":false}')

if ! echo "$RESPONSE" | grep -q '"success": true'; then
    echo "❌ 服务器连接失败"
    exit 1
fi

ACTIVATION_CODE=$(echo "$RESPONSE" | grep -o '"activation_code": "[^"]*"' | cut -d'"' -f4)

echo ""
echo "=============================================="
echo "📱 请扫码完成激活"
echo "=============================================="
echo ""
echo "激活码: $ACTIVATION_CODE"
echo ""

# 生成二维码显示在终端
QR_URL=$(echo "$RESPONSE" | grep -o '"qr_url": "[^"]*"' | cut -d'"' -f4)
qrencode -t ANSI "$QR_URL" 2>/dev/null || echo "访问: $QR_URL"

echo ""
echo "⏳ 等待支付完成 (30分钟)..."
echo ""

# 轮询等待激活
for i in {1..180}; do
    sleep 10
    
    STATUS=$(curl -s "$SERVER_URL/api/device/check?device_id=$DEVICE_ID" 2>/dev/null)
    
    if echo "$STATUS" | grep -q '"status": "activated"'; then
        echo ""
        echo "✅ 激活成功！"
        
        # 下载配置
        curl -s "$SERVER_URL/api/client/init" \
            -X POST -H "Content-Type: application/json" \
            -d "{\"device_id\": \"$DEVICE_ID\"}" \
            > /opt/stockai/config.json
        
        echo "📥 下载核心代码..."
        # 从配置中获取下载地址
        DOWNLOAD_URL=$(cat /opt/stockai/config.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('download_url',''))" 2>/dev/null)
        
        if [ -n "$DOWNLOAD_URL" ]; then
            curl -s "$DOWNLOAD_URL" | tar -xz -C /opt/stockai/
        fi
        
        # 启动服务
        echo "🔧 启动服务..."
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable stockai 2>/dev/null || true
        systemctl start stockai 2>/dev/null || true
        
        echo ""
        echo "=============================================="
        echo "🎉 安装完成！"
        echo "=============================================="
        echo "查看日志: journalctl -u stockai -f"
        exit 0
    fi
    
    echo -n "."
done

echo ""
echo "⏰ 激活超时，请重新运行脚本"
exit 1
