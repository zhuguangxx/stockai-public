# StockAI - AI股票分析平台

一个基于AI的股票分析平台，支持微信/飞书接入，提供实时行情、AI评分、投资建议等服务。

## 🚀 快速开始

### 方式1: 本地开发

```bash
# 克隆项目
git clone https://github.com/yourusername/stockai-platform.git
cd stockai-platform

# 安装依赖
pip3 install -r requirements.txt

# 启动服务
./start.sh

# 访问API
open http://localhost:8000/docs
```

### 方式2: 硬件部署（推荐生产环境）

```bash
# 1. 准备Ubuntu Server 22.04小主机
# 2. 运行服务器初始化脚本
sudo bash scripts/setup-server.sh

# 3. 上传项目代码后运行部署
sudo bash scripts/setup-project.sh

# 4. 完成！
# 访问: http://your-server-ip
```

**详细部署流程**: [硬件部署工作流](docs/HARDWARE_DEPLOYMENT_WORKFLOW.md)

## 📦 功能特性

### 核心功能
- ✅ **实时行情**: 全市场A股实时数据（延迟15分钟）
- ✅ **AI分析**: 基于多因子的股票评分系统
- ✅ **市场情绪**: 实时市场情绪指标
- ✅ **分级服务**: 免费/标准/专业/企业四级服务

### 接入方式
- ✅ **微信**: 扫码绑定，命令交互
- ✅ **飞书**: 扫码绑定，@机器人交互
- ✅ **API**: REST API，Token认证

### 系统特性
- ✅ **并发控制**: 本地队列，最大3并发（避免Kimi限制）
- ✅ **优先级**: 企业用户优先，免费用户排队
- ✅ **权限隔离**: 每个客户独立Agent，只读权限
- ✅ **监控面板**: 实时系统状态和性能指标

## 🏗️ 系统架构

```
┌─────────┐   ┌─────────┐   ┌─────────┐
│  微信   │   │  飞书   │   │  API    │
└────┬────┘   └────┬────┘   └────┬────┘
     │             │             │
     └─────────────┴─────────────┘
                   │
     ┌─────────────┴─────────────┐
     │      Agent层 (隔离)       │
     └─────────────┬─────────────┘
                   │
     ┌─────────────┴─────────────┐
     │      队列层 (3并发)       │
     │  PriorityQueue: 企业>专业 │
     └─────────────┬─────────────┘
                   │
     ┌─────────────┴─────────────┐
     │      API层 (FastAPI)      │
     └─────────────┬─────────────┘
                   │
     ┌─────────────┴─────────────┐
     │      数据层               │
     │  SQLite + 腾讯财经        │
     └───────────────────────────┘
```

## 📁 项目结构

```
stockai-platform/
├── api/                    # API服务
│   └── main.py            # FastAPI应用
├── agents/                 # Agent系统
│   ├── client_manager.py  # Agent管理
│   ├── wechat_handler.py  # 微信交互
│   ├── feishu_binding.py  # 飞书绑定
│   └── deployed/          # 已部署Agent
├── collectors/             # 数据采集
│   └── data_collector.py  # 股票数据采集
├── database/               # 数据库
│   └── stock_db.py        # SQLite封装
├── task_queue/             # 任务队列
│   └── task_queue.py      # 并发队列
├── monitor/                # 监控面板
│   └── dashboard.py       # 实时状态
├── tests/                  # 测试
│   ├── integration_test.py # 集成测试
│   └── stress_test.py     # 压力测试
├── docs/                   # 文档
│   ├── DEPLOYMENT.md      # 部署指南
│   ├── OPERATIONS.md      # 运维手册
│   └── LAUNCH_CHECKLIST.md # 上线检查清单
├── start.sh               # 一键启动脚本
└── README.md              # 本文件
```

## 🔧 技术栈

- **后端**: Python 3.9+, FastAPI
- **数据库**: SQLite（可迁移PostgreSQL）
- **队列**: Python queue.PriorityQueue
- **采集**: akshare + 腾讯财经API
- **监控**: 终端/Web双模式

## 📝 API文档

### 认证
所有API请求需要携带API Key:
```
Authorization: Bearer YOUR_API_KEY
```

### 端点

| 端点 | 方法 | 描述 |
|------|------|------|
| `/` | GET | 服务状态 |
| `/api/v1/system/status` | GET | 系统状态 |
| `/api/v1/stocks` | GET | 股票列表 |
| `/api/v1/quote/{code}` | GET | 实时行情 |
| `/api/v1/analysis/{code}` | GET | AI分析 |

### 示例

```bash
# 获取股票报价
curl http://localhost:8000/api/v1/quote/000001 \
  -H "Authorization: Bearer sk_your_api_key"

# 响应
{
  "code": "000001",
  "name": "平安银行",
  "price": 11.14,
  "change_pct": 1.36,
  "pe": 5.07,
  "pb": 0.56,
  "market_cap": 2160.51
}
```

## 💰 分级服务

| 等级 | 价格 | 速率限制 | 功能 |
|------|------|----------|------|
| 免费 | ¥0 | 10/min | 基础分析 |
| 标准 | ¥99/月 | 60/min | 实时分析 |
| 专业 | ¥299/月 | 300/min | 高级分析+优先 |
| 企业 | ¥5000+/月 | 1000/min | 定制+专属 |

## 🛡️ 免责声明

**本服务仅供参考，不构成投资建议。**

- 股市有风险，投资需谨慎
- 所有分析基于历史数据，不保证未来收益
- 用户应独立判断，自行承担投资风险

## 📚 文档

- [硬件部署工作流](docs/HARDWARE_DEPLOYMENT_WORKFLOW.md) - 从零到上线的完整流程
- [部署指南](docs/DEPLOYMENT.md) - 详细部署配置
- [运维手册](docs/OPERATIONS.md) - 日常运维指南
- [速查卡片](docs/QUICK_REFERENCE.md) - 常用命令速查
- [上线检查清单](docs/LAUNCH_CHECKLIST.md) - 上线前检查

## 🤝 贡献

欢迎提交Issue和PR！

## 📄 许可

MIT License

---

**StockAI** © 2026 - AI驱动的股票分析平台
