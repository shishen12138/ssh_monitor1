import paramiko

class SSHClient:
    def __init__(self, ip, username="root", password="Qcy1994@06"):
        self.ip = ip
        self.username = username
        self.password = password
        self.client = None

    def connect(self):
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(self.ip, username=self.username, password=self.password, timeout=5)

    def execute(self, command):
        if not self.client:
            self.connect()
        stdin, stdout, stderr = self.client.exec_command(command)
        return stdout.read().decode(), stderr.read().decode()

    def close(self):
        if self.client:
            self.client.close()
            self.client = None
