from fastapi import APIRouter
from pydantic import BaseModel
from host_manager.manager import HostManager
from ssh_client.ssh import SSHClient
from aws_importer.importer import AWSImporter
from logger.logger import logger
import asyncio

router = APIRouter()
host_manager = HostManager()
aws_importer = AWSImporter(host_manager)

class SSHCommand(BaseModel):
    hosts: list[str]
    command: str

@router.post("/ssh/execute")
async def execute_ssh(cmd: SSHCommand):
    results = {}
    for ip in cmd.hosts:
        ssh = SSHClient(ip)
        try:
            out, err = ssh.execute(cmd.command)
            results[ip] = {"out": out, "err": err}
            await logger.broadcast(f"{ip} 执行命令: {cmd.command}\n输出: {out}\n错误: {err}")
        except Exception as e:
            results[ip] = {"out": "", "err": str(e)}
            await logger.broadcast(f"{ip} 执行失败: {str(e)}")
        finally:
            ssh.close()
    return results

class AWSAccount(BaseModel):
    account: str
    access_key: str
    secret_key: str

@router.post("/aws/import")
def import_aws_hosts(acc: AWSAccount):
    hosts = aws_importer.import_hosts(acc.account, acc.access_key, acc.secret_key)
    return {"imported": len(hosts), "hosts": hosts}
