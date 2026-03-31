# StockAI 硬件交付 - 速查卡片

## 🚀 快速启动（部署后）

```bash
# 1. 登录服务器
ssh stockai@YOUR_SERVER_IP

# 2. 查看服务状态
sudo systemctl status stockai-api

# 3. 查看日志
tail -f /opt/stockai-platform/logs/api.log

# 4. 测试API
curl http://localhost:8000/

# 5. 创建新客户
python3 /opt/stockai-platform/scripts/create-client.py pro
```

---

## 📋 每日检查清单

```bash
□ 服务运行正常
  sudo systemctl is-active stockai-api
  sudo systemctl is-active stockai-collector

□ API响应正常
  curl -s http://localhost:8000/ | grep running

□ 磁盘空间充足
  df -h / | awk 'NR==2 {print $5}'

□ 内存使用正常
  free -h | grep Mem | awk '{print $3"/"$2}'

□ 无异常错误
  tail -100 /opt/stockai-platform/logs/api.log | grep -i error || echo "无错误"
```

---

## 🔧 常用命令

### 服务管理
```bash
# 启动
sudo systemctl start stockai-api
sudo systemctl start stockai-collector

# 停止
sudo systemctl stop stockai-api stockai-collector

# 重启
sudo systemctl restart stockai-api

# 查看状态
sudo systemctl status stockai-api --no-pager
```

### 日志查看
```bash
# API日志
tail -f /opt/stockai-platform/logs/api.log

# 采集日志
tail -f /opt/stockai-platform/logs/collector.log

# 错误日志
grep ERROR /opt/stockai-platform/logs/api.log

# 系统日志
sudo journalctl -u stockai-api -f
```

### 数据库操作
```bash
# 进入数据库
sqlite3 /opt/stockai-platform/data/stockai.db

# 查看表
.tables

# 查看股票数
SELECT COUNT(*) FROM stocks;

# 查看客户数
SELECT COUNT(*) FROM clients;

# 备份数据库
cp /opt/stockai-platform/data/stockai.db \
   /opt/stockai-platform/data/stockai.db.backup.$(date +%Y%m%d)
```

### 客户管理
```bash
cd /opt/stockai-platform
source venv/bin/activate

# 创建免费客户
python3 -c "
from agents.feishu_simple import SimpleFeishuSystem
system = SimpleFeishuSystem()
agent = system.create_agent('free')
print(f'绑定码: {agent[\"bind_code\"]}')
"

# 创建专业客户
python3 -c "
from agents.feishu_simple import SimpleFeishuSystem
system = SimpleFeishuSystem()
agent = system.create_agent('pro')
print(f'绑定码: {agent[\"bind_code\"]}')
"

# 查看所有Agent
ls /opt/stockai-platform/agents/feishu_bindings/
```

---

## 🌐 网络配置

### 查看IP
```bash
# 内网IP
ip addr show | grep "inet " | head -1

# 公网IP
curl -s ifconfig.me
```

### 防火墙管理
```bash
# 查看状态
sudo ufw status

# 允许端口
sudo ufw allow 8080/tcp

# 拒绝端口
sudo ufw deny 8080/tcp

# 删除规则
sudo ufw delete allow 8080/tcp
```

### 端口检查
```bash
# 查看监听端口
sudo netstat -tlnp

# 检查特定端口
sudo lsof -i :8000
```

---

## 💾 备份与恢复

### 自动备份脚本
```bash
#!/bin/bash
# /opt/stockai-platform/scripts/backup.sh

BACKUP_DIR="/opt/stockai-platform/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# 备份数据库
cp /opt/stockai-platform/data/stockai.db $BACKUP_DIR/

# 备份配置
cp -r /opt/stockai-platform/agents/feishu_bindings $BACKUP_DIR/

# 清理7天前的备份
find /opt/stockai-platform/backups -type d -mtime +7 -exec rm -rf {} + 2>/dev/null

echo "备份完成: $BACKUP_DIR"
```

### 恢复数据
```bash
# 停止服务
sudo systemctl stop stockai-api

# 恢复数据库
cp /opt/stockai-platform/backups/20260331/stockai.db \
   /opt/stockai-platform/data/stockai.db

# 启动服务
sudo systemctl start stockai-api
```

---

## 🆘 紧急故障处理

### 场景1: 服务无法启动
```bash
# 1. 查看错误日志
sudo journalctl -u stockai-api -n 100 --no-pager

# 2. 检查Python环境
cd /opt/stockai-platform
source venv/bin/activate
python3 -c "from api.main import app; print('OK')"

# 3. 检查数据库
sqlite3 data/stockai.db ".tables"

# 4. 手动启动查看错误
cd /opt/stockai-platform
source venv/bin/activate
python3 api/main.py
```

### 场景2: 数据库损坏
```bash
# 1. 停止服务
sudo systemctl stop stockai-api

# 2. 备份损坏的数据库
cp data/stockai.db data/stockai.db.corrupted.$(date +%Y%m%d)

# 3. 尝试修复
sqlite3 data/stockai.db ".recover" | sqlite3 data/stockai.db.fixed
mv data/stockai.db.fixed data/stockai.db

# 4. 启动服务
sudo systemctl start stockai-api
```

### 场景3: 磁盘空间满
```bash
# 1. 查看磁盘使用
df -h

# 2. 清理日志
tail -n 1000 /opt/stockai-platform/logs/api.log > /tmp/api.log.tmp
mv /tmp/api.log.tmp /opt/stockai-platform/logs/api.log

# 3. 清理旧备份
find /opt/stockai-platform/backups -mtime +30 -delete

# 4. 清理系统日志
sudo journalctl --vacuum-time=7d
```

### 场景4: 忘记SSH密码
```bash
# 需要在服务器物理终端操作
# 重启进入恢复模式
# 修改密码: passwd stockai
```

---

## 📊 性能监控

### 实时监控
```bash
# CPU/内存
htop

# 磁盘IO
iotop

# 网络流量
iftop
```

### API性能测试
```bash
# 并发测试
ab -n 100 -c 10 http://localhost:8000/

# 响应时间
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/
```

---

## 🔐 安全速查

### SSH安全
```bash
# 禁用root登录
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# 禁用密码登录（确保已配置密钥）
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# 重启SSH
sudo systemctl restart sshd
```

### 更新系统
```bash
# 更新软件包
sudo apt update && sudo apt upgrade -y

# 重启服务
sudo systemctl restart stockai-api
```

---

## 📞 联系信息

| 项目 | 信息 |
|------|------|
| 服务器IP | ________________ |
| SSH端口 | 22 |
| 用户名 | stockai |
| 管理后台 | http://服务器IP |
| API文档 | http://服务器IP/docs |

---

**打印此卡片并贴在服务器旁边**
