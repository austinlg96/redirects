import json
import os
from base64 import urlsafe_b64decode
from typing import TYPE_CHECKING

import boto3

if TYPE_CHECKING:
    from local_types import Input_Context, Input_Event, Output
else:
    Input_Event = object
    Input_Context = object
    Output = object

kms = boto3.client(service_name="kms")

def lambda_handler(event: Input_Event, context: Input_Context) -> Output:
    try:
        destination:str = event["queryStringParameters"]["d"]
    except (KeyError, TypeError):
        destination = "https://google.com"
    
    try:
        ciphertext = event["queryStringParameters"]["v"]
        pad = len(ciphertext) % 4
        ciphertext = ciphertext + "=" * pad
        ciphertextblob = urlsafe_b64decode(ciphertext)
        plaintext = kms.decrypt(CiphertextBlob=ciphertextblob)["Plaintext"]
    except Exception:
        pass
    
    return {
        "isBase64Encoded": False,
        "statusCode": 307,
        "headers": {"Location": destination},
    }   
