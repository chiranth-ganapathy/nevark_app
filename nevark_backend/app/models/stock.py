from pydantic import BaseModel
from typing import Optional

class StockQuote(BaseModel):
    symbol:    str
    price:     float
    change:    float
    changePct: str
    volume:    int
    high:      Optional[float] = 0.0
    low:       Optional[float] = 0.0
    prevClose: Optional[float] = 0.0
    error:     Optional[str]   = None