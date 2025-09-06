#!/bin/bash
# 启动 SSH Monitor Web 面板

# 绝对路径调用虚拟环境中的 uvicorn
/root/ssh_monitor/venv/bin/uvicorn main:app --host 0.0.0.0 --port 12138
