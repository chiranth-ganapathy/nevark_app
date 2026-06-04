from fastapi import APIRouter, HTTPException
from app.services.market_data_service import (
    get_stock_quote,
    get_index_data,
    get_multiple_quotes,
    get_cache_info,
)

router = APIRouter(prefix="/api/stocks", tags=["stocks"])

@router.get("/quote/{symbol}")
async def stock_quote(symbol: str):
    result = await get_stock_quote(symbol.upper())
    if result.get("error"):
        raise HTTPException(status_code=503, detail=result["error"])
    return result

@router.get("/indices")
async def market_indices():
    return await get_index_data()

@router.get("/batch")
async def batch_quotes(symbols: str):
    symbol_list = [s.strip().upper() for s in symbols.split(",")]
    if len(symbol_list) > 10:
        raise HTTPException(status_code=400, detail="Max 10 symbols per batch")
    return await get_multiple_quotes(symbol_list)

@router.get("/cache/status")
def cache_status():
    return get_cache_info()

@router.get("/health")
def health():
    return {"status": "ok", "service": "market-data"}