from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def healthcheck():
    return {"status": "ok new"}


@app.get("/ping")
async def ping():
    return {"message": "pong"}
