import boto3
import json
import os
import urllib3

secrets_client = boto3.client("secretsmanager", region_name=os.environ["REGION_NAME"])
sns_client = boto3.client("sns", region_name=os.environ["REGION_NAME"])
s3_client = boto3.client("s3", region_name=os.environ["REGION_NAME"])
http = urllib3.PoolManager()

def get_secrets():
    response = secrets_client.get_secret_value(SecretId=os.environ["SECRET_NAME"])
    return json.loads(response["SecretString"])

# Basic fraud checker
def check_fraud(body: dict):
    if body["amount"] > 10000000:
        return True
    if body.get("currency") not in ["NGN", "USD", "EUR"]:
        return True
    return False


# Updating status on on prem db
def patch_status(token: str, status: str, api_key: str):
    url = (
        f"{os.getviron["PROXMOX_VPN_IP"]}"
        f"/api/transactions/{token}/status?status={status}"
    )
    response = http.request("PATCH", url, api_key)
    return response.status


# Main code
def lambda_handler(event, context):
    secrets = get_secrets()
    api_key = secrets["callback_api_key"]

    for record in event["Records"]:
        body = json.loads(record["body"])
        token = body["token"]
        merchant_id = body["merchant_id"]
        amount = body["amount"]


        # Add the transaction to s3 first for auditability
        s3_client.put_object(
                Bucket=os.environ["S3_BUCKET"],
                Key=f"transactions/{token}.json",
                Body=json.dumps(body)
        )
    
        if check_fraud(body):
            sns_client.publish(
                TopicArn=os.environ["SNS_TOPIC_ARN"],
                Subject="PayCore Fraud Alert",
                Message=json.dumps({
                    "token":       token,
                    "merchant_id": merchant_id,
                    "amount":      amount,
                    "reason":      "Fraud rules triggered"
                })
            )
            patch_status(token, "flagged", api_key)

        else:
            
            patch_status(token, "processed", api_key)
    
    return {"statusCode": 200}