import boto3
from host_manager.manager import HostManager

class AWSImporter:
    def __init__(self, host_manager: HostManager):
        self.host_manager = host_manager

    def import_hosts(self, account: str, access_key: str, secret_key: str, region="ap-southeast-1"):
        session = boto3.Session(
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region
        )
        ec2 = session.client("ec2")
        hosts = []

        resp = ec2.describe_instances(Filters=[{'Name':'instance-state-name','Values':['running']}])
        for reservation in resp['Reservations']:
            for instance in reservation['Instances']:
                ip = instance.get("PublicIpAddress")
                if ip:
                    hostname = instance.get("Tags", [{}])[0].get("Value", instance['InstanceId'])
                    host_info = {
                        "hostname": hostname,
                        "ip": ip,
                        "username": "root",
                        "password": "Qcy1994@06",
                        "account": account,
                        "access_key": access_key,
                        "secret_key": secret_key
                    }
                    hosts.append(host_info)
                    self.host_manager.add_host(host_info)
        return hosts
