# StockAI 平台 - 运维手册

## 🎯 日常运维检查清单

### 每日检查

```bash
# 1. 检查服务状态
./start.sh status

# 2. 检查日志（异常/错误）
tail -100 logs/api.log | grep -i error
tail -100 logs/collector.log | grep -i error

# 3. 检查磁盘空间
df -h | grep -E '(Filesystem|/dev/)'

# 4. 检查内存使用
free -h

# 5. 检查API响应时间
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/

# curl-format.txt 内容:
# time_namelookup: %{time_namelookup}\n
# time_connect: %{time_connect}\n
# time_total: %{time_total}\n
```

### 每周检查

```bash
# 1. 数据库备份
./scripts/backup_db.sh

# 2. 清理旧日志
find logs/ -name "*.log" -mtime +7 -delete

# 3. 检查数据完整性
python3 scripts/verify_data.py

# 4. 分析访问日志
python3 scripts/analyze_logs.py

# 5. 更新系统补丁
sudo apt update && sudo apt upgrade -y
```

### 每月检查

```bash
# 1. 性能评估
python3 tests/stress_test.py

# 2. 安全扫描
# - 检查开放端口
# - 检查异常登录
# - 检查文件权限

# 3. 成本分析
# - API调用量
# - 存储使用
# - 带宽消耗

# 4. 更新依赖
pip3 list --outdated
```

---

## 🔧 常用运维命令

### 服务管理

```bash
# 启动
./start.sh

# 停止
./start.sh stop

# 重启
./start.sh restart

# 查看状态
./start.sh status

# 强制停止
pkill -f "python3 api/main.py"
pkill -f "python3 collectors/data_collector.py"
```

### 日志查看

```bash
# 实时查看API日志
tail -f logs/api.log

# 查看错误日志
grep ERROR logs/api.log

# 查看特定时间段
sed -n '/2026-03-31 14:00/,/2026-03-31 15:00/p' logs/api.log

# 统计请求量
grep "GET /api/v1" logs/api.log | wc -l
```

### 数据库操作

```bash
# 进入SQLite命令行
sqlite3 data/stockai.db

# 常用查询
.tables                          # 查看表
.schema stocks                   # 查看表结构
SELECT COUNT(*) FROM stocks;     # 股票数量
SELECT COUNT(*) FROM clients;    # 客户数量
SELECT * FROM stocks LIMIT 5;    # 查看5条股票数据

# 备份
cp data/stockai.db data/stockai.db.backup.$(date +%Y%m%d_%H%M%S)

# 导出
sqlite3 data/stockai.db ".dump" > backup.sql

# 导入
sqlite3 data/stockai.db < backup.sql
```

---

## 🚨 故障处理

### 服务崩溃

```bash
# 1. 查看最后日志
tail -n 200 logs/api.log

# 2. 检查内存使用
ps aux | grep python3 | sort -k4 -nr

# 3. 检查磁盘空间
df -h

# 4. 重启服务
./start.sh restart

# 5. 通知用户（如需要）
```

### 数据库损坏

```bash
# 1. 停止服务
./start.sh stop

# 2. 备份损坏的数据库
cp data/stockai.db data/stockai.db.corrupted

# 3. 尝试修复
sqlite3 data/stockai.db ".recover" | sqlite3 data/stockai.db.recovered

# 4. 替换并重启
mv data/stockai.db.recovered data/stockai.db
./start.sh

# 5. 如修复失败，从备份恢复
cp data/stockai.db.backup.YYYYMMDD data/stockai.db
```

### API响应慢

```bash
# 1. 检查队列状态
python3 -c "
from task_queue.task_queue import get_task_queue
q = get_task_queue()
print(q.get_queue_status())
"

# 2. 检查数据库锁
lsof data/stockai.db

# 3. 检查系统负载
uptime
top -bn1 | head -20

# 4. 增加工作线程（临时）
# 编辑 task_queue.py MAX_WORKERS
```

### 数据采集失败

```bash
# 1. 测试数据源
curl -s "http://qt.gtimg.cn/q=sh000001" | head -c 200

# 2. 检查网络
ping -c 3 qt.gtimg.cn

# 3. 手动触发采集
python3 -c "
from collectors.data_collector import DataCollector
c = DataCollector()
c.collect_realtime_quotes()
"

# 4. 检查IP是否被封
# 如被封，更换IP或增加采集间隔
```

---

## 📊 监控告警

### 关键指标阈值

| 指标 | 警告 | 严重 |
|------|------|------|
| CPU使用率 | >70% | >90% |
| 内存使用率 | >70% | >90% |
| 磁盘使用率 | >80% | >95% |
| API响应时间 | >500ms | >2000ms |
| 错误率 | >1% | >5% |
| 队列积压 | >100 | >500 |

### 告警脚本

```bash
#!/bin/bash
# alert.sh - 简单告警脚本

WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# 检查磁盘
disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$disk_usage" -gt 90 ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"⚠️ 磁盘空间不足: '$disk_usage'%"}' \
        $WEBHOOK_URL
fi

# 检查API
if ! curl -s http://localhost:8000/ > /dev/null; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"🚨 API服务不可用"}' \
        $WEBHOOK_URL
fi
```

添加到cron:
```bash
*/5 * * * * /home/user/stockai/stockai-platform/scripts/alert.sh
```

---

## 🔒 安全维护

### 定期检查

```bash
# 1. 检查异常登录
last | grep -v "still logged in" | tail -20

# 2. 检查系统用户
cat /etc/passwd | grep /bin/bash

# 3. 检查开放端口
sudo netstat -tlnp

# 4. 检查文件权限
find . -type f -perm /o+w  # 其他用户可写

# 5. 检查可疑进程
ps aux | grep -E "(python|node|java)" | grep -v grep
```

### 安全更新

```bash
# 1. 更新系统
sudo apt update
sudo apt list --upgradable | grep security
sudo apt upgrade -y

# 2. 更新Python依赖
pip3 list --outdated
pip3 install --upgrade -r requirements.txt

# 3. 重启服务
./start.sh restart
```

---

## 📝 运维记录模板

### 日常检查记录

```markdown
## 运维记录 - 2026-03-31

### 服务状态
- [x] API服务正常
- [x] 采集服务正常
- [x] 队列运行正常

### 性能指标
- CPU: 15%
- 内存: 45%
- 磁盘: 32%
- API延迟: 120ms

### 今日处理
- 无异常

### 明日计划
- 常规检查

签名: ___________
```

---

## 📞 紧急联系

| 角色 | 姓名 | 电话 | 邮箱 |
|------|------|------|------|
| 运维 | ___ | ___ | ___ |
| 开发 | ___ | ___ | ___ |
| 业务 | ___ | ___ | ___ |

---

*运维手册版本: v1.0*
*更新日期: 2026-03-31*
