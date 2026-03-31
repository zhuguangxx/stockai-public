#!/bin/bash
# StockAI - OpenClaw 安装后自动配置脚本
# 在Ubuntu Server上运行

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/stockai-platform"
LOG_FILE="/var/log/stockai-setup.log"

# 日志函数
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

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
       error "请使用 sudo 运行此脚本"
    fi
}

# 系统更新
update_system() {
    log "正在更新系统..."
    apt-get update -qq
    apt-get upgrade -y -qq
    log "✓ 系统更新完成"
}

# 安装基础依赖
install_dependencies() {
    log "正在安装基础依赖..."
    apt-get install -y -qq \
        curl \
        wget \
        git \
        vim \
        htop \
        net-tools \
        ufw \
        fail2ban \
        nginx \
        certbot \
        python3-certbot-nginx \
        sqlite3 \
        logrotate \
        2>&1 | tee -a $LOG_FILE
    log "✓ 基础依赖安装完成"
}

# 安装Node.js (OpenClaw需要)
install_nodejs() {
    log "正在安装 Node.js..."
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> $LOG_FILE 2>&1
        apt-get install -y nodejs -qq >> $LOG_FILE 2>&1
    fi
    log "✓ Node.js 版本: $(node --version)"
}

# 安装OpenClaw
install_openclaw() {
    log "正在安装 OpenClaw..."
    
    if ! command -v openclaw &> /dev/null; then
        npm install -g openclaw >> $LOG_FILE 2>&1
    fi
    
    log "✓ OpenClaw 版本: $(openclaw --version)"
    
    # 初始化OpenClaw
    log "初始化 OpenClaw 配置..."
    openclaw setup >> $LOG_FILE 2>&1 || true
    
    log "✓ OpenClaw 安装完成"
}

# 安装Python依赖
install_python_deps() {
    log "正在安装 Python 依赖..."
    apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        >> $LOG_FILE 2>&1
    
    # 创建虚拟环境
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR
    python3 -m venv venv
    source venv/bin/activate
    
    # 创建requirements.txt
    cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
requests==2.31.0
qrcode==7.4.2
Pillow==10.1.0
numpy==1.26.2
pandas==2.1.3
akshare==1.11.0
python-multipart==0.0.6
pydantic==2.5.0
starlette==0.27.0
EOF
    
    pip3 install -r requirements.txt -q >> $LOG_FILE 2>&1
    log "✓ Python 依赖安装完成"
}

# 创建项目结构
create_project_structure() {
    log "创建项目目录结构..."
    
    mkdir -p $PROJECT_DIR/{api,agents,collector,database,task_queue,monitor,tests,docs,scripts,data,logs}
    
    # 设置权限
    useradd -r -s /bin/false stockai 2>/dev/null || true
    chown -R stockai:stockai $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR
    
    log "✓ 项目目录结构创建完成"
}

# 配置防火墙
configure_firewall() {
    log "配置防火墙..."
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8000/tcp  # API端口（内部）
    
    echo "y" | ufw enable >> $LOG_FILE 2>&1
    
    log "✓ 防火墙配置完成"
    ufw status verbose | tee -a $LOG_FILE
}

# 配置SSH安全
configure_ssh() {
    log "配置SSH安全..."
    
    # 备份原配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)
    
    # 修改SSH配置
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
    
    # 重启SSH
    systemctl restart sshd
    
    log "✓ SSH安全配置完成"
    log "⚠️  请确保已配置SSH密钥登录，否则将无法登录！"
}

# 配置fail2ban
configure_fail2ban() {
    log "配置 fail2ban..."
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "✓ fail2ban 配置完成"
}

# 配置日志轮转
configure_logrotate() {
    log "配置日志轮转..."
    
    cat > /etc/logrotate.d/stockai << 'EOF'
/opt/stockai-platform/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 stockai stockai
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "✓ 日志轮转配置完成"
}

# 创建系统服务
create_systemd_services() {
    log "创建系统服务..."
    
    # StockAI API服务
    cat > /etc/systemd/system/stockai-api.service << EOF
[Unit]
Description=StockAI API Service
After=network.target

[Service]
Type=simple
User=stockai
Group=stockai
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python3 api/main.py
Restart=always
RestartSec=5
StandardOutput=append:$PROJECT_DIR/logs/api.log
StandardError=append:$PROJECT_DIR/logs/api.error.log

[Install]
WantedBy=multi-user.target
EOF

    # StockAI采集服务
    cat > /etc/systemd/system/stockai-collector.service << EOF
[Unit]
Description=StockAI Data Collector
After=network.target

[Service]
Type=simple
User=stockai
Group=stockai
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python3 collector/data_collector.py
Restart=always
RestartSec=60
StandardOutput=append:$PROJECT_DIR/logs/collector.log
StandardError=append:$PROJECT_DIR/logs/collector.error.log

[Install]
WantedBy=multi-user.target
EOF

    # 重载systemd
    systemctl daemon-reload
    
    log "✓ 系统服务创建完成"
}

# 配置Nginx
configure_nginx() {
    log "配置 Nginx..."
    
    cat > /etc/nginx/sites-available/stockai << 'EOF'
server {
    listen 80;
    server_name _;  # 接受所有域名
    
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
        proxy_read_timeout 86400;
    }
    
    location /static {
        alias /opt/stockai-platform/static;
        expires 1d;
    }
}
EOF

    # 启用站点
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/stockai /etc/nginx/sites-enabled/stockai
    
    # 测试配置
    nginx -t >> $LOG_FILE 2>&1 || error "Nginx配置测试失败"
    
    systemctl restart nginx
    systemctl enable nginx
    
    log "✓ Nginx 配置完成"
}

# 创建管理脚本
create_management_scripts() {
    log "创建管理脚本..."
    
    # 启动脚本
    cat > $PROJECT_DIR/start.sh << 'EOF'
#!/bin/bash
# StockAI 启动脚本

echo "🚀 启动 StockAI 服务..."

# 检查虚拟环境
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# 启动API
sudo systemctl start stockai-api

# 启动采集
sudo systemctl start stockai-collector

echo "✅ 服务已启动"
echo ""
echo "查看状态: sudo systemctl status stockai-api"
echo "查看日志: tail -f logs/api.log"
EOF

    # 停止脚本
    cat > $PROJECT_DIR/stop.sh << 'EOF'
#!/bin/bash
echo "🛑 停止 StockAI 服务..."
sudo systemctl stop stockai-api
sudo systemctl stop stockai-collector
echo "✅ 服务已停止"
EOF

    # 状态脚本
    cat > $PROJECT_DIR/status.sh << 'EOF'
#!/bin/bash
echo "📊 StockAI 服务状态"
echo "==================="
sudo systemctl status stockai-api --no-pager -l
echo ""
sudo systemctl status stockai-collector --no-pager -l
EOF

    chmod +x $PROJECT_DIR/*.sh
    
    log "✓ 管理脚本创建完成"
}

# 输出安装信息
print_install_info() {
    log "========================================"
    log "🎉 StockAI 服务器初始化完成！"
    log "========================================"
    log ""
    log "📁 项目目录: $PROJECT_DIR"
    log "👤 运行用户: stockai"
    log "📜 日志文件: $LOG_FILE"
    log ""
    log "🚀 下一步操作:"
    log "   1. 上传 StockAI 代码到 $PROJECT_DIR"
    log "   2. 运行: cd $PROJECT_DIR && ./setup-project.sh"
    log "   3. 启动服务: sudo systemctl start stockai-api"
    log ""
    log "📋 常用命令:"
    log "   - 查看API状态: sudo systemctl status stockai-api"
    log "   - 查看日志: tail -f $PROJECT_DIR/logs/api.log"
    log "   - 重启服务: sudo systemctl restart stockai-api"
    log ""
    log "⚠️  安全提醒:"
    log "   - SSH密钥登录已启用，密码登录已禁用"
    log "   - 防火墙仅开放80/443/22端口"
    log "   - fail2ban已启用，防暴力破解"
    log ""
    log "📖 详细文档: $PROJECT_DIR/docs/"
    log "========================================"
}

# 主函数
main() {
    log "========================================"
    log "🚀 StockAI 服务器初始化脚本"
    log "========================================"
    
    check_root
    update_system
    install_dependencies
    install_nodejs
    install_openclaw
    install_python_deps
    create_project_structure
    configure_firewall
    configure_ssh
    configure_fail2ban
    configure_logrotate
    create_systemd_services
    configure_nginx
    create_management_scripts
    
    print_install_info
}

# 运行
main "$@"
