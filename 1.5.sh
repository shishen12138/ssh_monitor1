#!/bin/bash

set -e

WORKDIR="/root/ssh_monitor"
REPO_URL="https://raw.githubusercontent.com/shishen12138/ssh_monitor1/main"

echo "=== 安装系统依赖 ==="
apt update
apt install -y wget curl git build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev python3-venv jq

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

echo "=== 下载 main 目录下所有文件 ==="
wget -qO- https://api.github.com/repos/shishen12138/ssh_monitor1/contents/main \
 | jq -r '.[].download_url' | while read url; do
    [ "$url" = "null" ] && continue
    fname=$(basename "$url")
    wget -O "$fname" "$url"
done

echo "=== 创建子目录并整理文件 ==="
mkdir -p host_manager ssh_client monitoring aws_importer logger web_panel components

# 移动文件到对应目录
mv manager.py host_manager/manager.py
mv ssh.py ssh_client/ssh.py
mv monitor.py monitoring/monitor.py
mv importer.py aws_importer/importer.py
mv logger.py logger/logger.py
mv routes.py web_panel/routes.py
mv ws_monitor.py web_panel/ws_monitor.py
mv ws_logs.py web_panel/ws_logs.py
mv HostMonitorFull.vue components/HostMonitorFull.vue

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

echo "=== 重新加载 systemd 并启动服务 ==="
systemctl daemon-reload
systemctl enable ssh_monitor
systemctl restart ssh_monitor

IP=$(hostname -I | awk '{print $1}')
echo "=== 部署完成 ==="
echo "请访问 Web 面板：http://$IP:12138"
