from fastapi import WebSocket, APIRouter, WebSocketDisconnect
from logger.logger import logger

router = APIRouter()

@router.websocket("/ws/logs")
async def websocket_logs(ws: WebSocket):
    await logger.connect(ws)
    try:
        while True:
            await asyncio.sleep(1)
    except WebSocketDisconnect:
        logger.disconnect(ws)
