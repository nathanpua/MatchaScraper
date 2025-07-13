# Python 3.12 with Boto3
import os
import boto3
import logging

# Initialize logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Boto3 client outside the handler for reuse
autoscaling = boto3.client('autoscaling')

# --- Environment Variables ---
# Required: The name of the Auto Scaling Group to manage.
ASG_NAME = os.environ.get('ASG_NAME')
# Optional: The desired capacity to scale up to. Defaults to 1.
DESIRED_CAPACITY = int(os.environ.get('DESIRED_CAPACITY', 1))
# Optional: The minimum size of the ASG. Defaults to 1.
MIN_SIZE = int(os.environ.get('MIN_SIZE', 1))
# Optional: The maximum size of the ASG. Defaults to 1.
MAX_SIZE = int(os.environ.get('MAX_SIZE', 1))

def lambda_handler(event, context):
    if not ASG_NAME:
        logger.error("ASG_NAME environment variable not set.")
        return {"statusCode": 500, "body": "Configuration error: ASG_NAME not set."}

    logger.info(f"Setting desired capacity for {ASG_NAME} to {DESIRED_CAPACITY}")
    
    try:
        autoscaling.update_auto_scaling_group(
            AutoScalingGroupName=ASG_NAME,
            MinSize=MIN_SIZE,
            MaxSize=MAX_SIZE,
            DesiredCapacity=DESIRED_CAPACITY
        )
        logger.info(f"Successfully scaled up ASG {ASG_NAME}.")
        return {"statusCode": 200, "body": f"ASG {ASG_NAME} scaled up."}
    except Exception as e:
        logger.error(f"Error scaling up ASG {ASG_NAME}: {e}")
        return {"statusCode": 500, "body": f"Error scaling up ASG: {e}"} 