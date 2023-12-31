import json
import os
from base64 import urlsafe_b64decode
from datetime import datetime
from typing import TYPE_CHECKING

import boto3

if TYPE_CHECKING:
    from local_types import Input_Context, Input_Event, Output
else:
    Input_Event = object
    Input_Context = object
    Output = object

kms = boto3.client(service_name="kms") # type: ignore
ddb = boto3.resource("dynamodb") # type: ignore
redirect_table = ddb.Table(os.environ['DDB_TABLE_NAME'])

class DebugError(BaseException):
    pass

def skip_on_debug(*exceptions: type[Exception]):
    if os.environ.setdefault('DEBUGGING','False') == 'True':
        return DebugError
    else:
        return exceptions if exceptions else Exception

def lambda_handler(event: Input_Event, context: Input_Context) -> Output:
    try:
        destination:str = event["queryStringParameters"]["d"]
    except skip_on_debug(KeyError, TypeError):
        destination = os.environ.setdefault('ERROR_DESTINATION','https://google.com')
    
    try:
        ciphertext = event["queryStringParameters"]["v"]
    except skip_on_debug(KeyError):
        ciphertext = "Error identifying ciphertext."

    try:
        ciphertext = event["queryStringParameters"]["v"]
        pad = len(ciphertext) % 4
        ciphertext = ciphertext + "=" * pad
        ciphertextblob = urlsafe_b64decode(ciphertext)
        plaintext = json.loads(kms.decrypt(CiphertextBlob=ciphertextblob)["Plaintext"])

    except skip_on_debug() as e:
        plaintext = f"Error decrypting object. ERRMSG: {e}"

    try:
        id = plaintext["id"] # type: ignore
    except skip_on_debug():
        id = 'unable_to_parse_id'

    try:
        redirect_table.put_item(
                Item = {
                    'HK': f"link_usage-{id}",
                    'SK': datetime.utcnow().isoformat(),
                    'event': event,
                    'decrypted_params': plaintext,
                    'context': {str(k):str(v) for k,v in getattr(context,'__dict__',{}).items()}
                }
            )
    except skip_on_debug() as e:
        print(f'Error adding usage to table. ERRMSG: {e}')

    return {
        "isBase64Encoded": False,
        "statusCode": 307,
        "headers": {"Location": destination},
    }   
