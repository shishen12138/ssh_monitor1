import asyncio

class Logger:
    def __init__(self):
        self.connections = []

    async def connect(self, ws):
        await ws.accept()
        self.connections.append(ws)

    def disconnect(self, ws):
        if ws in self.connections:
            self.connections.remove(ws)

    async def broadcast(self, message):
        for ws in self.connections:
            await ws.send_json({"log": message})

logger = Logger()
