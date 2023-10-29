from typing import Any, TypedDict


class _QS_Params(TypedDict, total=True):
    d: str


class QS_Params(_QS_Params, total=False):
    id: str


class Input_Event(TypedDict):
    queryStringParameters: QS_Params


Input_Context = Any

class Output(TypedDict):
    statusCode: int
    isBase64Encoded: bool
    headers: dict[str,str]
