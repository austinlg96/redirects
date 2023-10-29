import json
import os
import uuid
from base64 import urlsafe_b64encode
from typing import TYPE_CHECKING

import boto3

if TYPE_CHECKING:
    from local_types import Input_Context, Input_Event, Output, Output_Body
else:
    Input_Event = object
    Input_Context = object
    Output = object
    Output_Body = dict


kms = boto3.client("kms")
ddb = boto3.resource("dynamodb")
redirect_table = ddb.Table(os.environ['DDB_TABLE_NAME'])

def get_id(event:Input_Event):
    try:
        id = event["queryStringParameters"]["tracking_id"]
    except KeyError:
        id = uuid.uuid4()
    return id

def lambda_handler(event: Input_Event, context: Input_Context) -> Output:
    
    destination = event["queryStringParameters"]["destination"]

    try:
        description = event["queryStringParameters"]["description"]
    except (KeyError, TypeError):
        description = ""
    
    id = get_id(event)

    msg = json.dumps({"d": destination, "id": str(id)}).encode()

    response = kms.encrypt(
        KeyId=os.environ["KMS_ENCRYPTION_KEY"],
        Plaintext=msg,
        EncryptionAlgorithm="SYMMETRIC_DEFAULT",
    )

    ciphertext = urlsafe_b64encode(response["CiphertextBlob"]).decode().rstrip("=")

    full_url = f"{os.environ['URL_PREFIX']}?d={destination}&v={ciphertext}"

    redirect_table.put_item(Item={
        "HK":f'link-{str(id)}',
        "SK": destination,
        "id": str(id),
        "destination": destination,
        "description": description,
        "ciphertext": ciphertext,
        "full_url": full_url,
        "event" : event,
        "context" : getattr(context,'__dict__',context)
    })

    return {
        "statusCode": 200,
        "body": 
            json.dumps(Output_Body({
                "full_url": full_url,
                "id": str(id),
                "destination": destination,
                "ciphertext": ciphertext,
            }))
    }
