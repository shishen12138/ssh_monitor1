from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from web_panel import routes, ws_monitor, ws_logs

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

app.include_router(routes.router)
app.include_router(ws_monitor.router)
app.include_router(ws_logs.router)
