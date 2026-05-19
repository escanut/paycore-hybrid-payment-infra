import boto3
import os


PRIMARY_ID  = os.environ["PRIMARY_INSTANCE_ID"]
STANDBY_ID  = os.environ["STANDBY_INSTANCE_ID"]
EIP_ALLOC   = os.environ["EIP_ALLOCATION_ID"]
REGION_NAME = os.environ["REGION_NAME"]

ec2 = boto3.client("ec2", region_name = REGION_NAME)

def handler(event, context):
    
    # Check current EIP association
    addrs = ec2.describe_addresses(AllocationIds=[EIP_ALLOC])["Addresses"]
    current_assoc = addrs[0].get("AssociationId")
    current_instance = addrs[0].get("InstanceId")

    if current_instance == STANDBY_ID:
        print("EIP already on standby. No action.")
        return
    
    # Confirm primary is actually down before moving EIP
    response = ec2.describe_instances(InstanceIds=[PRIMARY_ID])
    state = response["Reservations"][0]["Instances"][0]["State"]["Name"]

    if state in ("running", "pending"):
        print(f"Primary is {state}. CloudWatch false positive — no action.")
        return
    
    print(f"Primary is {state}. Moving EIP to standby.")

    if current_assoc:
        ec2.disassociate_address(AssociationId=current_assoc)

    ec2.associate_address(
        InstanceId=STANDBY_ID,
        AllocationId=EIP_ALLOC
    )

    print(f"EIP {EIP_ALLOC} moved to standby {STANDBY_ID}")