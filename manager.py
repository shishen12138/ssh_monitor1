import json
from pathlib import Path

class HostManager:
    def __init__(self, file_path="hosts.json"):
        self.file_path = Path(file_path)
        if self.file_path.exists():
            self.hosts = json.loads(self.file_path.read_text())
        else:
            self.hosts = []

    def list_hosts(self):
        return self.hosts

    def add_host(self, host_info):
        self.hosts.append(host_info)
        self.save()

    def save(self):
        self.file_path.write_text(json.dumps(self.hosts, indent=2))

    def get_hosts_by_account(self, account):
        return [h for h in self.hosts if h.get("account") == account]
