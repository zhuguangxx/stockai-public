#!/bin/bash
# StockAI - 项目部署脚本
# 在代码上传到服务器后运行

set -e

PROJECT_DIR="/opt/stockai-platform"
LOG_FILE="/var/log/stockai-deploy.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

cd $PROJECT_DIR

log "========================================"
log "🚀 StockAI 项目部署脚本"
log "========================================"

# 1. 激活虚拟环境
log "激活虚拟环境..."
source venv/bin/activate

# 2. 安装/更新依赖
log "安装 Python 依赖..."
pip3 install -r requirements.txt -q 2>&1 | tee -a $LOG_FILE

# 3. 初始化数据库
log "初始化数据库..."
python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/stockai-platform')
from database.stock_db import db
from collectors.data_collector import DataCollector

# 创建表
db.init_db()
print("✓ 数据库表创建完成")

# 导入股票列表
collector = DataCollector()
collector.init_stock_list()
print(f"✓ 股票列表导入完成: {db.get_system_stats()['total_stocks']} 只")
PYEOF

# 4. 创建测试客户
log "创建测试客户..."
python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/stockai-platform')
from database.stock_db import db

# 创建测试客户
try:
    db.create_client(
        client_id='test_client',
        wechat_id='test_wechat_id',
        api_key='sk_test_deployment_key',
        tier='pro',
        expires_at=None
    )
    print("✓ 测试客户创建完成")
except:
    print("✓ 测试客户已存在")
PYEOF

# 5. 设置权限
log "设置文件权限..."
chown -R stockai:stockai $PROJECT_DIR
chmod -R 755 $PROJECT_DIR
chmod -R 777 $PROJECT_DIR/logs
chmod -R 777 $PROJECT_DIR/data

# 6. 测试配置
log "测试配置..."
python3 << 'PYEOF'
import sys
sys.path.insert(0, '/opt/stockai-platform')

# 测试导入
from database.stock_db import db
from api.main import app
from task_queue.task_queue import TaskQueue

print("✓ 所有模块导入正常")

# 测试数据库
stats = db.get_system_stats()
print(f"✓ 数据库连接正常: {stats['total_stocks']} 只股票")
PYEOF

# 7. 启动服务
log "启动服务..."
systemctl start stockai-api
systemctl start stockai-collector

# 8. 等待服务启动
log "等待服务启动 (5秒)..."
sleep 5

# 9. 健康检查
log "执行健康检查..."
HEALTH_CHECK=$(curl -s http://localhost:8000/ || echo "FAILED")

if [[ $HEALTH_CHECK == *"running"* ]]; then
    log "✅ 服务健康检查通过！"
else
    log "⚠️  服务可能未完全启动，请检查日志"
fi

# 10. 设置开机自启
log "设置开机自启..."
systemctl enable stockai-api
systemctl enable stockai-collector

log ""
log "========================================"
log "🎉 部署完成！"
log "========================================"
log ""
log "📊 服务状态:"
systemctl status stockai-api --no-pager -l | head -5
log ""
log "🌐 访问地址:"
log "   - 本地: http://localhost:8000"
log "   - 公网: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
log ""
log "📋 下一步:"
log "   1. 测试API: curl http://localhost:8000/"
log "   2. 查看日志: tail -f $PROJECT_DIR/logs/api.log"
log "   3. 配置微信/飞书: 参见 docs/DEPLOYMENT.md"
log "   4. 配置HTTPS: certbot --nginx"
log ""
log "========================================"
