#!/bin/bash
source /opt/ssh_monitor/venv/bin/activate
exec uvicorn main:app --host 0.0.0.0 --port 8000
