from datetime import datetime, timezone

import mongomock
import pytest
from fastapi.testclient import TestClient

from app.config import config

config.jwt_segredo = "segredo-so-para-testes-com-32-bytes-ou-mais"

from app.db import colecao_usuarios  # noqa: E402
from app.main import app  # noqa: E402
from app.seguranca import gerar_hash  # noqa: E402


@pytest.fixture
def usuarios():
    colecao = mongomock.MongoClient().semob_teste.usuarios
    colecao.create_index("usuarioNormalizado", unique=True)
    return colecao


@pytest.fixture
def client(usuarios):
    app.dependency_overrides[colecao_usuarios] = lambda: usuarios
    yield TestClient(app)
    app.dependency_overrides.clear()


def inserir(usuarios, login, senha, perfil="funcionario"):
    return usuarios.insert_one(
        {
            "nome": login.capitalize(),
            "usuario": login,
            "usuarioNormalizado": login.lower(),
            "email": f"{login}@semob.local",
            "senhaHash": gerar_hash(senha),
            "perfil": perfil,
            "criadoEm": datetime.now(timezone.utc),
        }
    ).inserted_id


def cabecalho(client, login, senha):
    resp = client.post("/login", json={"usuario": login, "senha": senha})
    assert resp.status_code == 200, resp.text
    return {"Authorization": f"Bearer {resp.json()['token']}"}


@pytest.fixture
def admin(usuarios):
    inserir(usuarios, "admin", "admin123", "administrador")


@pytest.fixture
def func(usuarios):
    inserir(usuarios, "func", "123456", "funcionario")


NOVO = {
    "nome": "Maria Souza",
    "usuario": "maria",
    "email": "maria@semob.local",
    "senha": "maria123",
    "perfil": "funcionario",
}
