from pydantic import BaseModel

class DescriptionRequest(BaseModel):
    url: str
