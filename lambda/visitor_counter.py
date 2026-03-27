import json
import os

import boto3


dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    response = table.update_item(
        Key={"id": "visitors"},
        UpdateExpression="SET visit_count = if_not_exists(visit_count, :start) + :inc",
        ExpressionAttributeValues={
            ":start": 0,
            ":inc": 1,
        },
        ReturnValues="UPDATED_NEW",
    )

    count = int(response["Attributes"]["visit_count"])

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/plain",
        },
        "body": str(count),
    }
