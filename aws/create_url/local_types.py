from typing import Any, TypedDict


class _QS_Params(TypedDict, total=True):
    destination: str


class QS_Params(_QS_Params, total=False):
    tracking_id: str


class Input_Event(TypedDict):
    queryStringParameters: QS_Params


Input_Context = Any

Output_Body = TypedDict(
    "body",
    {
        "full_url": str,
        "id": str,
        "destination": str,
        "v": str,
        "d": str,
    },
)


class Output(TypedDict):
    statusCode: int
    body: str
