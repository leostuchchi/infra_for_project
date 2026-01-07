from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Personal Assistant API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Personal Assistant API"}

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "personal-assistant"}

# Или если нужен минимальный вариант:
# from fastapi import FastAPI
# app = FastAPI()
# @app.get("/health")
# async def health():
#     return {"status": "ok"}
