#!/bin/bash
set -e

WORKDIR="/root/ssh_monitor"
REPO_URL="https://raw.githubusercontent.com/shishen12138/ssh_monitor1/main"

echo "=== 安装系统依赖 ==="
apt update
apt install -y wget curl git build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev python3-venv

# 安装 Python 3.13.6
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

echo "=== 安装 Node.js 22.x ==="
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
echo "Node.js version: $(node -v)"

echo "=== 创建工作目录 $WORKDIR ==="
mkdir -p $WORKDIR
cd $WORKDIR

echo "=== 下载源码文件 ==="
FILES=("main.py" "config.json" "manager.py" "ssh.py" "monitor.py" "importer.py" \
"logger.py" "routes.py" "ws_monitor.py" "ws_logs.py" "HostMonitorFull.vue")

for file in "${FILES[@]}"; do
    wget -qO "$file" "$REPO_URL/$file"
done

echo "=== 创建子目录并整理文件 ==="
mkdir -p host_manager ssh_client monitoring aws_importer logger web_panel components
mv manager.py host_manager/
mv ssh.py ssh_client/
mv monitor.py monitoring/
mv importer.py aws_importer/
mv logger.py logger/
mv routes.py web_panel/
mv ws_monitor.py web_panel/
mv ws_logs.py web_panel/
mv HostMonitorFull.vue components/

echo "=== 创建 Python 虚拟环境并安装依赖 ==="
$PYTHON_BIN -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn paramiko boto3 python-multipart websockets aiofiles

echo "=== 安装前端打包工具（Vite + Vue + axios + ECharts） ==="
cd components
rm -rf dist node_modules package-lock.json
npm init -y
npm install vite vue@3 @vitejs/plugin-vue axios vue-echarts echarts --save-dev

# 创建 vite.config.js（解决静态资源路径问题）
cat > vite.config.js <<'EOF'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  base: './',  // 🔑 保证打包后静态资源路径正确
  plugins: [vue()],
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: './index.html'
    }
  }
})
EOF

# 创建入口文件 main.js
cat > main.js <<'EOF'
import { createApp } from 'vue'
import App from './HostMonitorFull.vue'
createApp(App).mount('#app')
EOF

# 创建 HTML 页面
cat > index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SSH Monitor Web Panel</title>
</head>
<body>
<div id="app"></div>
<script type="module" src="./main.js"></script>
</body>
</html>
EOF

echo "=== 打包前端 ==="
npx vite build

cd $WORKDIR

echo "=== 修改 main.py 挂载静态目录并返回 index.html ==="
sed -i "/from web_panel import routes/a from fastapi.staticfiles import StaticFiles\nfrom fastapi.responses import HTMLResponse\nimport os" main.py
sed -i "/app.include_router(ws_logs.router)/a app.mount('/static', StaticFiles(directory='components/dist'), name='static')" main.py
cat >> main.py <<'EOF'

@app.get("/", response_class=HTMLResponse)
def root():
    index_file = os.path.join("components/dist/index.html")
    if os.path.exists(index_file):
        with open(index_file, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Web 面板文件不存在</h1>"
EOF

echo "=== 创建 start.sh ==="
cat > start.sh <<'EOF'
#!/bin/bash
/root/ssh_monitor/venv/bin/uvicorn main:app --host 0.0.0.0 --port 12138
EOF
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

echo "=== 启动服务 ==="
systemctl daemon-reload
systemctl enable ssh_monitor
systemctl restart ssh_monitor

IP=$(hostname -I | awk '{print $1}')
echo "=== 部署完成 ==="
echo "请访问 Web 面板：http://$IP:12138/"
