from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import stocks

app = FastAPI(
    title="Nevark API",
    version="1.0.0",
    description="Market data, signals and news for Nevark stock app"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # restrict to your domain in production
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(stocks.router)
# news router will be added in Day 4

@app.get("/")
def root():
    return {"status": "Nevark API running", "version": "1.0.0"}
