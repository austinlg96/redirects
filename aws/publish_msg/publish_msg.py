import json
import os
from typing import TYPE_CHECKING

import boto3

if TYPE_CHECKING:
    from local_types import Input_Context, Input_Event, Output, Output_Body
else:
    Input_Event = object
    Input_Context = object
    Output = object
    Output_Body = dict

sns = boto3.client("sns")

def lambda_handler(event: Input_Event, context: Input_Context) -> Output:
    for record in event["Records"]:
        try:
            msg = {
                "id-HK": record["dynamodb"]["NewImage"]["HK"]["S"],
                "destination": record["dynamodb"]["NewImage"]["event"]["M"][
                    "queryStringParameters"
                ]["M"]["d"]["S"],
            }

            response = sns.publish(
                TopicArn=os.environ["SNS_TOPIC_ARN"],
                Message=json.dumps(msg),
                Subject="Link Viewed",
            )
        except KeyError as e:
            response = sns.publish(
                TopicArn=os.environ["SNS_TOPIC_ARN"],
                Message=f"Failed to create message. ERRMSG: {repr(e)} - {json.dumps(event)}",
                Subject="Link Viewed",
            )

        except Exception as e:
            response = sns.publish(
                TopicArn=os.environ["SNS_TOPIC_ARN"],
                Message=f"Failed to create message. ERRMSG: {repr(e)}",
                Subject="Link Viewed",
            )

    return {"body": "done"}
