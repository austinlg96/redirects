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


def lambda_handler(event: Input_Event, context: Input_Context) -> Output:
    kms = boto3.client(service_name="kms")

    destination = event["queryStringParameters"]["destination"]
    try:
        id = event["queryStringParameters"]["tracking_id"]
    except KeyError:
        id = uuid.uuid4()

    msg = json.dumps({"d": destination, "id": str(id)}).encode()

    response = kms.encrypt(
        KeyId=os.environ["KMS_ENCRYPTION_KEY"],
        Plaintext=msg,
        EncryptionAlgorithm="SYMMETRIC_DEFAULT",
    )

    verification = urlsafe_b64encode(response["CiphertextBlob"]).decode()

    decode_check = kms.decrypt(CiphertextBlob=response["CiphertextBlob"])
    full_url = f"{os.environ['URL_PREFIX']}/?v={verification}"

    return {
        "statusCode": 200,
        "body": 
            json.dumps(Output_Body({
                "full_url": full_url,
                "id": str(id),
                "destination": destination,
                "v": verification,
                "d": json.loads(decode_check["Plaintext"].decode()),
            }))
    }
