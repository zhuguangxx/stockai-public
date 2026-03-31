# StockAI 硬件交付 - 完整工作流程

## 📋 流程概览

```
硬件采购 → Ubuntu安装 → 服务器初始化 → 代码部署 → 配置通道 → 上线运营
   (1天)      (2小时)       (1小时)         (30分钟)    (2小时)    (持续)
```

**总预计时间**: 2-3天（含物流）

---

## 阶段一：硬件采购 (1天)

### 1.1 硬件清单

| 物品 | 规格建议 | 预算 | 采购渠道 |
|------|----------|------|----------|
| **小主机** | Intel N100/12代i3, 8G RAM, 256G SSD | ¥1500-2500 | 京东/淘宝/闲鱼 |
| **网线** | Cat6, 3米 | ¥15 | 京东 |
| **显示器** | 可选（仅安装使用） | - | 借用 |
| **键盘鼠标** | USB | - | 借用 |

### 1.2 推荐小主机型号

**性价比款** (¥1500-1800):
- 零刻 SEi12 (i3-1220P, 8G, 256G)
- 铭凡 UN100D (N100, 8G, 256G)
- 天虹 ZN11 (N100, 8G, 256G)

**性能款** (¥2000-2500):
- 零刻 SEi12 Pro (i5-1240P, 16G, 512G)
- 铭凡 UM690 (R5 6900HX, 16G, 512G)

### 1.3 验收检查

```bash
# 收到硬件后检查
□ 主机外观无损坏
□ 电源适配器齐全
□ 能正常开机
□ BIOS可进入
□ 网口正常
```

---

## 阶段二：Ubuntu Server安装 (2小时)

### 2.1 准备安装介质

```bash
# 1. 下载 Ubuntu Server 22.04 LTS
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.4-live-server-amd64.iso

# 2. 制作启动U盘 (在另一台电脑上)
# Windows: 使用 Rufus https://rufus.ie
# Mac: 使用 balenaEtcher https://www.balena.io/etcher
# Linux: 
sudo dd if=ubuntu-22.04.4-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
```

### 2.2 安装步骤

**Step 1**: 插入U盘，开机按 F2/DEL 进入BIOS
**Step 2**: 设置U盘为第一启动项，保存退出
**Step 3**: 进入Ubuntu安装界面，选择 "Try or Install Ubuntu Server"

**安装配置**:

```
语言: English
键盘: English (US)
安装类型: Ubuntu Server
网络: DHCP (自动获取IP) 或手动配置静态IP
代理: 留空
镜像: 默认 (清华/阿里云镜像)
磁盘: 使用整个磁盘，无LVM
分区: 默认
用户名: stockai
主机名: stockai-server
密码: [设置强密码]
SSH: 安装OpenSSH服务器 ✓
特性: 不选任何snap
```

**Step 4**: 等待安装完成，重启，拔掉U盘

### 2.3 安装后基础配置

```bash
# 登录后执行
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git vim htop net-tools

# 设置静态IP（如需要）
sudo nano /etc/netplan/00-installer-config.yaml

# 示例配置:
network:
  ethernets:
    enp2s0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 114.114.114.114]
  version: 2

# 应用配置
sudo netplan apply

# 记录IP地址
ip addr show | grep "inet " | head -1
```

---

## 阶段三：OpenClaw安装与服务器初始化 (1小时)

### 3.1 上传初始化脚本

```bash
# 在你的电脑上，将脚本传到服务器
scp scripts/setup-server.sh stockai@192.168.1.100:/tmp/

# SSH登录服务器
ssh stockai@192.168.1.100
```

### 3.2 运行服务器初始化

```bash
# 登录服务器后执行
sudo bash /tmp/setup-server.sh
```

**此脚本会自动完成**:
- ✅ 系统更新
- ✅ 安装Node.js
- ✅ 安装OpenClaw
- ✅ 安装Python依赖
- ✅ 创建项目目录
- ✅ 配置防火墙
- ✅ 配置SSH安全
- ✅ 安装fail2ban
- ✅ 配置Nginx
- ✅ 创建systemd服务

### 3.3 验证安装

```bash
# 检查OpenClaw
openclaw --version

# 检查Node
node --version

# 检查Python
python3 --version

# 检查服务
sudo systemctl status nginx
sudo ufw status
```

---

## 阶段四：StockAI代码部署 (30分钟)

### 4.1 准备代码包

```bash
# 在你的开发机上，打包项目
cd ~/.openclaw/workspace/stockai-platform
tar -czvf stockai-deploy.tar.gz \
    api/ agents/ collectors/ database/ task_queue/ monitor/ tests/ docs/ scripts/ \
    start.sh stop.sh status.sh README.md requirements.txt
```

### 4.2 上传并部署

```bash
# 上传代码
scp stockai-deploy.tar.gz stockai@192.168.1.100:/opt/stockai-platform/

# SSH登录并解压
ssh stockai@192.168.1.100
cd /opt/stockai-platform
tar -xzvf stockai-deploy.tar.gz
rm stockai-deploy.tar.gz

# 运行项目部署脚本
sudo bash scripts/setup-project.sh
```

### 4.3 验证部署

```bash
# 测试API
curl http://localhost:8000/

# 期望输出:
# {"name":"StockAI API","version":"1.0.0","status":"running","docs":"/docs"}

# 查看服务状态
sudo systemctl status stockai-api
sudo systemctl status stockai-collector

# 查看日志
tail -f /opt/stockai-platform/logs/api.log
```

---

## 阶段五：配置微信/飞书通道 (2小时)

### 5.1 配置OpenClaw微信通道

```bash
# 登录服务器
ssh stockai@192.168.1.100

# 配置微信通道
openclaw channels add \
  --name "StockAI微信" \
  --type openclaw-weixin \
  --profile default

# 按照提示完成扫码绑定
```

### 5.2 配置OpenClaw飞书通道

```bash
# 配置飞书通道
openclaw channels add \
  --name "StockAI飞书" \
  --type feishu \
  --profile default

# 按照提示完成授权
```

### 5.3 配置Agent自动响应

```bash
# 编辑OpenClaw配置
nano ~/.openclaw/config.json

# 添加自动路由配置:
{
  "agents": {
    "stockai": {
      "path": "/opt/stockai-platform/agents/feishu_simple.py",
      "trigger": "always"
    }
  }
}

# 重启OpenClaw
openclaw gateway restart
```

### 5.4 测试通道

```bash
# 测试微信
# 向你的微信发送消息，验证Agent响应

# 测试飞书
# 在飞书@机器人，验证Agent响应
```

---

## 阶段六：上线运营

### 6.1 配置HTTPS（公网部署）

```bash
# 申请SSL证书
sudo certbot --nginx -d your-domain.com

# 自动续期测试
sudo certbot renew --dry-run
```

### 6.2 配置域名解析

```
类型    主机记录    记录值
A       @          你的服务器公网IP
A       www        你的服务器公网IP
```

### 6.3 创建第一个付费客户

```bash
# 登录服务器
ssh stockai@192.168.1.100
cd /opt/stockai-platform
source venv/bin/activate

# 创建专业版客户
python3 << 'PYEOF'
from agents.feishu_simple import SimpleFeishuSystem

system = SimpleFeishuSystem()
agent = system.create_agent("pro")

print(f"新客户创建成功!")
print(f"Agent ID: {agent['agent_id']}")
print(f"绑定码: {agent['bind_code']}")
print(f"等级: PRO")
print(f"")
print(f"将绑定码发给客户，客户发送绑定码到微信/飞书即可绑定")
PYEOF
```

### 6.4 日常运维

```bash
# 每日检查（设置cron定时任务）
crontab -e

# 添加:
# 每天9点检查服务状态
0 9 * * * /opt/stockai-platform/scripts/daily-check.sh
# 每小时备份数据库
0 * * * * /opt/stockai-platform/scripts/backup-db.sh
```

---

## 📁 交付清单

### 硬件交付物
- [ ] 小主机（已安装Ubuntu Server）
- [ ] 电源适配器
- [ ] 网线

### 软件交付物
- [ ] OpenClaw已安装配置
- [ ] StockAI平台已部署
- [ ] 微信通道已配置
- [ ] 飞书通道已配置
- [ ] 系统服务已配置

### 文档交付物
- [ ] 服务器IP和登录信息
- [ ] SSH密钥
- [ ] 管理后台地址
- [ ] 运维手册
- [ ] 紧急联系人

---

## 🆘 故障排查速查

### 服务无法启动
```bash
# 查看错误日志
sudo journalctl -u stockai-api -n 50

# 检查端口占用
sudo lsof -i :8000

# 手动启动测试
cd /opt/stockai-platform
source venv/bin/activate
python3 api/main.py
```

### 数据库锁定
```bash
# 检查锁定
lsof /opt/stockai-platform/data/stockai.db

# 修复数据库
sqlite3 /opt/stockai-platform/data/stockai.db ".recover" | \
  sqlite3 /opt/stockai-platform/data/stockai.db.fixed
mv /opt/stockai-platform/data/stockai.db.fixed \
   /opt/stockai-platform/data/stockai.db
```

### OpenClaw连接失败
```bash
# 检查OpenClaw状态
openclaw gateway status

# 重启Gateway
openclaw gateway restart

# 查看日志
openclaw logs
```

---

## 📞 支持联系

部署过程中遇到问题:
1. 查看日志: `tail -f /var/log/stockai-setup.log`
2. 检查文档: `/opt/stockai-platform/docs/`
3. OpenClaw社区: https://discord.gg/clawd

---

*工作流程版本: v1.0*  
*更新日期: 2026-03-31*
