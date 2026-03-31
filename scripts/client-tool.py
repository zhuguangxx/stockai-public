#!/usr/bin/env python3
"""
StockAI - 客户创建工具
快速创建新客户的Agent和绑定码
"""

import os
import sys
import argparse

sys.path.insert(0, '/opt/stockai-platform')
from agents.feishu_simple import SimpleFeishuSystem

def create_client(tier: str = "free", user_id: str = None):
    """创建新客户"""
    system = SimpleFeishuSystem()
    
    # 创建Agent
    agent = system.create_agent(tier)
    
    print("=" * 60)
    print("🎉 新客户创建成功！")
    print("=" * 60)
    print(f"\n📋 Agent信息:")
    print(f"   Agent ID: {agent['agent_id']}")
    print(f"   绑定码: {agent['bind_code']}")
    print(f"   等级: {tier.upper()}")
    print(f"   API Key: {agent['api_key'][:20]}...")
    
    print(f"\n📱 绑定方式:")
    print(f"   1. 微信: 发送绑定码到机器人")
    print(f"   2. 飞书: @机器人 发送绑定码")
    print(f"   3. 绑定码: {agent['bind_code']}")
    
    # 如果提供了用户ID，自动绑定
    if user_id:
        result = system.bind(agent['agent_id'], user_id)
        if result['success']:
            print(f"\n✅ 已自动绑定到用户: {user_id}")
        else:
            print(f"\n⚠️  自动绑定失败: {result.get('error', '未知错误')}")
    
    print("\n" + "=" * 60)
    
    return agent

def list_clients():
    """列出所有客户"""
    system = SimpleFeishuSystem()
    
    print("=" * 60)
    print("📊 客户列表")
    print("=" * 60)
    
    # 从feishu_bindings目录读取
    import json
    bindings_dir = '/opt/stockai-platform/agents/feishu_bindings'
    
    if not os.path.exists(bindings_dir):
        print("暂无客户")
        return
    
    count = 0
    for filename in os.listdir(bindings_dir):
        if filename.endswith('.json') and '_README' not in filename:
            with open(os.path.join(bindings_dir, filename)) as f:
                agent = json.load(f)
            
            status = "✅ 已绑定" if agent.get('bound_user') else "⏳ 待绑定"
            print(f"\n{count+1}. {agent['agent_id']}")
            print(f"   等级: {agent['tier'].upper()}")
            print(f"   绑定码: {agent['bind_code']}")
            print(f"   状态: {status}")
            if agent.get('bound_user'):
                print(f"   绑定用户: {agent['bound_user']}")
            count += 1
    
    print(f"\n共 {count} 个客户")
    print("=" * 60)

def main():
    parser = argparse.ArgumentParser(description='StockAI 客户管理工具')
    parser.add_argument('action', choices=['create', 'list'], 
                       help='操作: create(创建) / list(列表)')
    parser.add_argument('--tier', '-t', default='free',
                       choices=['free', 'standard', 'pro', 'enterprise'],
                       help='客户等级 (默认: free)')
    parser.add_argument('--user', '-u', help='飞书/微信用户ID (自动绑定)')
    
    args = parser.parse_args()
    
    if args.action == 'create':
        create_client(args.tier, args.user)
    elif args.action == 'list':
        list_clients()

if __name__ == '__main__':
    main()
