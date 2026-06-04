import httpx, os, time
from dotenv import load_dotenv

load_dotenv()
AV_KEY = os.getenv("ALPHA_VANTAGE_KEY")

_cache: dict = {}
CACHE_TTL = 300

def _cached(key: str, fetch_fn):
    now = time.time()
    if key in _cache:
        data, ts = _cache[key]
        if now - ts < CACHE_TTL:
            return data
    data = fetch_fn()
    _cache[key] = (data, now)
    return data

async def get_stock_quote(symbol: str) -> dict:
    def fetch():
        url = (
            f"https://www.alphavantage.co/query"
            f"?function=GLOBAL_QUOTE"
            f"&symbol={symbol}.BSE"
            f"&apikey={AV_KEY}"
        )
        r = httpx.get(url, timeout=10)
        data = r.json()
        q = data.get("Global Quote", {})
        if not q:
            return {
                "symbol": symbol, "price": 0.0,
                "change": 0.0, "changePct": "0%",
                "volume": 0, "high": 0.0, "low": 0.0,
                "prevClose": 0.0, "error": "Rate limit or invalid symbol"
            }
        return {
            "symbol":    symbol,
            "price":     float(q.get("05. price", 0)),
            "change":    float(q.get("09. change", 0)),
            "changePct": q.get("10. change percent", "0%"),
            "volume":    int(q.get("06. volume", 0)),
            "high":      float(q.get("03. high", 0)),
            "low":       float(q.get("04. low", 0)),
            "prevClose": float(q.get("08. previous close", 0)),
        }
    return _cached(f"quote_{symbol}", fetch)

async def get_index_data() -> dict:
    indices = {
        "NIFTY":     "NSEI",
        "SENSEX":    "BSESN",
        "BANKNIFTY": "NSEBANK",
    }
    results = {}
    for name, sym in indices.items():
        results[name] = await get_stock_quote(sym)
    return results

async def get_multiple_quotes(symbols: list) -> list:
    results = []
    for sym in symbols:
        results.append(await get_stock_quote(sym))
    return results

def get_cache_info() -> dict:
    now = time.time()
    return {
        key: {
            "age_seconds": round(now - ts),
            "expires_in":  max(0, round(CACHE_TTL - (now - ts)))
        }
        for key, (_, ts) in _cache.items()
    }