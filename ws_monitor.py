from fastapi import WebSocket, APIRouter
import asyncio
from monitoring.monitor import HostMonitor

router = APIRouter()

class WSMonitor:
    def __init__(self):
        self.connections = []
        self.hosts = []
        self.monitor_task = None

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.connections.append(ws)
        if not self.monitor_task:
            self.monitor_task = asyncio.create_task(self.start_monitor())

    def disconnect(self, ws: WebSocket):
        if ws in self.connections:
            self.connections.remove(ws)

    async def broadcast(self, data):
        for ws in self.connections:
            await ws.send_json(data)

    async def start_monitor(self):
        monitor = HostMonitor(self.hosts)
        await monitor.monitor_loop(self.broadcast)

ws_monitor = WSMonitor()

@router.websocket("/ws/monitor")
async def websocket_monitor(ws: WebSocket):
    await ws_monitor.connect(ws)
    try:
        while True:
            await asyncio.sleep(1)
    except:
        ws_monitor.disconnect(ws)
