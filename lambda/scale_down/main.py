# Python 3.12 with Boto3
import os
import boto3

ASG_NAME = os.environ['ASG_NAME']

def lambda_handler(event, context):
    autoscaling = boto3.client('autoscaling')
    print(f"Setting desired capacity for {ASG_NAME} to 0")
    
    try:
        autoscaling.update_auto_scaling_group(
            AutoScalingGroupName=ASG_NAME,
            MinSize=0,
            MaxSize=1, # Keep max at 1 to allow scale up again
            DesiredCapacity=0
        )
        return {"statusCode": 200, "body": f"ASG {ASG_NAME} scaled down."}
    except Exception as e:
        print(f"Error scaling down: {e}")
        return {"statusCode": 500, "body": f"Error: {e}"} 