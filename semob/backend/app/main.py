from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from .config import config
from .db import garantir_indices, obter_banco
from .rotas import auth, dados, importacoes, usuarios


@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    garantir_indices(obter_banco())
    yield


app = FastAPI(title="API do Dashboard SEMOB", lifespan=ciclo_de_vida)

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=config.cors_regex,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(importacoes.router)
app.include_router(dados.router)


@app.get("/saude", tags=["infra"])
def saude():
    return {"status": "ok"}
