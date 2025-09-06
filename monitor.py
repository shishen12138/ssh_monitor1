import paramiko
import asyncio

class HostMonitor:
    def __init__(self, hosts):
        self.hosts = hosts

    async def fetch_stats(self, host):
        stats = {"ip": host["ip"]}
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(host["ip"], username=host["username"], password=host["password"], timeout=5)

            # CPU
            stdin, stdout, _ = ssh.exec_command("top -bn1 | grep 'Cpu(s)'")
            cpu_line = stdout.read().decode()
            stats["cpu"] = float(cpu_line.split("%")[0].split()[-1])

            # 内存
            stdin, stdout, _ = ssh.exec_command("free -m | grep Mem")
            mem_line = stdout.read().decode()
            mem_total, mem_used = map(int, mem_line.split()[1:3])
            stats["mem"] = round(mem_used / mem_total * 100, 2)

            # 网络流量
            stdin, stdout, _ = ssh.exec_command("cat /proc/net/dev | grep eth0")
            net_line = stdout.read().decode()
            rx, tx = map(int, net_line.split()[1:3])
            stats["rx"] = rx
            stats["tx"] = tx

            # 延迟
            stdin, stdout, _ = ssh.exec_command("ping -c 1 8.8.8.8 | tail -1")
            ping_line = stdout.read().decode()
            if "rtt" in ping_line:
                stats["latency"] = float(ping_line.split("/")[4])
            else:
                stats["latency"] = None

            # Top5进程
            stdin, stdout, _ = ssh.exec_command("ps aux --sort=-%cpu | head -n 6")
            procs = stdout.read().decode().splitlines()[1:]
            stats["top5"] = [p.split()[10] for p in procs]

            ssh.close()
        except Exception as e:
            stats["error"] = str(e)
        return stats

    async def monitor_loop(self, callback):
        while True:
            tasks = [self.fetch_stats(host) for host in self.hosts]
            results = await asyncio.gather(*tasks)
            await callback(results)
            await asyncio.sleep(5)
