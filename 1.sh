#!/bin/bash

set -e

WORKDIR="/root/ssh_monitor"
REPO_URL="https://raw.githubusercontent.com/shishen12138/ssh_monitor1/main"

echo "=== 安装系统依赖 ==="
apt update
apt install -y wget curl git build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev python3-venv

# 检查 Python 3.13.6
if ! python3.13 --version &>/dev/null; then
    echo "=== 安装 Python 3.13.6 ==="
    cd /tmp
    wget https://www.python.org/ftp/python/3.13.6/Python-3.13.6.tgz
    tar xvf Python-3.13.6.tgz
    cd Python-3.13.6
    ./configure --enable-optimizations
    make -j$(nproc)
    make altinstall
fi

PYTHON_BIN=python3.13

echo "=== 创建工作目录 $WORKDIR ==="
mkdir -p $WORKDIR
cd $WORKDIR

echo "=== 下载主文件 ==="
wget -O main.py "$REPO_URL/main.py"
wget -O start.sh "$REPO_URL/start.sh"
wget -O config.json "$REPO_URL/config.json"

echo "=== 下载模块文件 ==="
# host_manager
mkdir -p host_manager
wget -O host_manager/manager.py "$REPO_URL/host_manager/manager.py"

# ssh_client
mkdir -p ssh_client
wget -O ssh_client/ssh.py "$REPO_URL/ssh_client/ssh.py"

# monitoring
mkdir -p monitoring
wget -O monitoring/monitor.py "$REPO_URL/monitoring/monitor.py"

# aws_importer
mkdir -p aws_importer
wget -O aws_importer/importer.py "$REPO_URL/aws_importer/importer.py"

# logger
mkdir -p logger
wget -O logger/logger.py "$REPO_URL/logger/logger.py"

# web_panel
mkdir -p web_panel
wget -O web_panel/routes.py "$REPO_URL/web_panel/routes.py"
wget -O web_panel/ws_monitor.py "$REPO_URL/web_panel/ws_monitor.py"
wget -O web_panel/ws_logs.py "$REPO_URL/web_panel/ws_logs.py"

# components (Vue 前端)
mkdir -p components
wget -O components/HostMonitorFull.vue "$REPO_URL/components/HostMonitorFull.vue"

echo "=== 创建 Python 虚拟环境 ==="
$PYTHON_BIN -m venv venv
source venv/bin/activate

echo "=== 安装 Python 依赖 ==="
pip install --upgrade pip
pip install fastapi uvicorn paramiko boto3 python-multipart websockets aiofiles

echo "=== 修改 start.sh 端口为 12138 ==="
sed -i 's/--port [0-9]\+/--port 12138/' start.sh
chmod +x start.sh

echo "=== 创建 systemd 服务 ==="
SERVICE_FILE="/etc/systemd/system/ssh_monitor.service"
tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=SSH Monitor Web Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORKDIR
ExecStart=$WORKDIR/start.sh
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

echo "=== 重新加载 systemd ==="
systemctl daemon-reload
systemctl enable ssh_monitor
systemctl start ssh_monitor

IP=$(hostname -I | awk '{print $1}')
echo "=== 部署完成 ==="
echo "请访问 Web 面板：http://$IP:12138"
