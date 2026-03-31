# StockAI 平台 - 部署指南

## 📋 系统要求

### 最低配置
- **CPU**: 1核
- **内存**: 512MB
- **磁盘**: 2GB
- **网络**: 公网IP（可选，用于外部访问）

### 推荐配置
- **CPU**: 2核
- **内存**: 1GB
- **磁盘**: 5GB SSD
- **网络**: 公网IP + 域名

### 软件环境
- **OS**: Ubuntu 20.04/22.04, CentOS 7/8
- **Python**: 3.9+
- **SQLite**: 3.0+

---

## 🚀 快速部署

### 1. 环境准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装依赖
sudo apt install -y python3 python3-pip git curl

# 创建工作目录
mkdir -p ~/stockai
cd ~/stockai
```

### 2. 下载代码

```bash
# 克隆项目（实际部署时替换为你的仓库）
git clone https://github.com/yourusername/stockai-platform.git
cd stockai-platform

# 或手动上传
# scp -r stockai-platform user@server:~/stockai/
```

### 3. 安装Python依赖

```bash
# 创建虚拟环境（推荐）
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip3 install -r requirements.txt
```

**requirements.txt**:
```
fastapi==0.104.1
uvicorn==0.24.0
requests==2.31.0
qrcode==7.4.2
Pillow==10.1.0
numpy==1.26.2
pandas==2.1.3
akshare==1.11.0
```

### 4. 初始化数据库

```bash
# 自动初始化
python3 -c "
from database.stock_db import db
from collectors.data_collector import DataCollector
collector = DataCollector()
collector.init_stock_list()
print('✅ 数据库初始化完成')
"
```

### 5. 启动服务

```bash
# 一键启动
./start.sh

# 查看状态
./start.sh status
```

---

## 🔧 配置说明

### 配置文件

#### 1. 环境变量 (`.env`)

```bash
# API配置
API_HOST=0.0.0.0
API_PORT=8000
API_KEY_HEADER=X-API-Key

# 数据库
DATABASE_PATH=data/stockai.db

# 队列
MAX_WORKERS=3
QUEUE_SIZE=1000

# 采集
COLLECTOR_INTERVAL=300  # 5分钟
COLLECTOR_BATCH_SIZE=50

# 日志
LOG_LEVEL=INFO
LOG_PATH=logs/
```

#### 2. 数据库初始化

```bash
python3 database/init_db.py
```

#### 3. 速率限制配置

编辑 `task_queue/task_queue.py`:

```python
RATE_LIMITS = {
    "free": {"rpm": 10, "rpd": 100},
    "standard": {"rpm": 60, "rpd": 1000},
    "pro": {"rpm": 300, "rpd": 10000},
    "enterprise": {"rpm": 1000, "rpd": 100000}
}
```

---

## 🌐 反向代理配置（Nginx）

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/stockai /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🔒 安全配置

### 1. 防火墙

```bash
# 开放HTTP端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 限制API端口（仅本地访问）
sudo ufw deny 8000/tcp

sudo ufw enable
```

### 2. API密钥管理

```bash
# 生成安全密钥
python3 -c "import secrets; print('sk_' + secrets.token_hex(32))"

# 添加到数据库
python3 -c "
from database.stock_db import db
db.create_client(
    client_id='your_client',
    wechat_id='wechat_id',
    api_key='your_secure_key',
    tier='pro',
    expires_at=None
)
"
```

### 3. HTTPS（Let's Encrypt）

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## 📊 监控配置

### 1. 监控面板

```bash
# 终端模式
./start.sh monitor

# Web模式（后台运行）
nohup python3 monitor/dashboard.py web > logs/monitor.log 2>&1 &
```

### 2. 日志轮转

```bash
# 安装logrotate配置
sudo tee /etc/logrotate.d/stockai << 'EOF'
/home/user/stockai/stockai-platform/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 user user
}
EOF
```

---

## 🔄 更新部署

```bash
# 1. 备份数据
cp data/stockai.db data/stockai.db.backup.$(date +%Y%m%d)

# 2. 停止服务
./start.sh stop

# 3. 更新代码
git pull origin main

# 4. 更新依赖
pip3 install -r requirements.txt --upgrade

# 5. 数据库迁移（如有）
python3 database/migrate.py

# 6. 重启服务
./start.sh
```

---

## 🆘 故障排查

### 常见问题

#### 1. API无法启动

```bash
# 检查端口占用
sudo lsof -i :8000

# 查看日志
tail -f logs/api.log

# 测试启动
python3 api/main.py
```

#### 2. 数据采集失败

```bash
# 检查网络
ping qt.gtimg.cn

# 手动测试采集
python3 -c "
from collectors.data_collector import DataCollector
c = DataCollector()
collect_realtime_quotes()
"
```

#### 3. 数据库锁定

```bash
# 检查锁定
lsof data/stockai.db

# 修复（如有损坏）
sqlite3 data/stockai.db ".recover" | sqlite3 data/stockai.db.fixed
mv data/stockai.db.fixed data/stockai.db
```

---

## 📈 性能调优

### 1. 数据库优化

```sql
-- 添加索引（如查询慢）
CREATE INDEX IF NOT EXISTS idx_quotes_code_time ON realtime_quotes(code, timestamp);
CREATE INDEX IF NOT EXISTS idx_requests_client_time ON client_requests(client_id, timestamp);
```

### 2. 队列优化

```python
# 根据CPU核心数调整
MAX_WORKERS = 4  # CPU核心数 - 1
```

### 3. 缓存策略

```python
# 添加Redis缓存（高并发场景）
import redis
cache = redis.Redis(host='localhost', port=6379, db=0)
```

---

## 📞 联系支持

- **文档**: https://docs.stockai.com
- **问题**: https://github.com/yourusername/stockai-platform/issues
- **邮箱**: support@stockai.com

---

*部署版本: v1.0.0*
*更新日期: 2026-03-31*
