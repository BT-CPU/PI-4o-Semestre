from pymongo import MongoClient
from pymongo.collection import Collection

from .config import config

_cliente = None


def obter_banco():
    global _cliente
    if _cliente is None:
        _cliente = MongoClient(config.mongo_uri, serverSelectionTimeoutMS=5000)
    return _cliente[config.mongo_banco]


def garantir_indices(banco) -> None:
    # Login único, sem diferenciar maiúsculas de minúsculas
    banco.usuarios.create_index("usuarioNormalizado", unique=True)


def colecao_usuarios() -> Collection:
    return obter_banco().usuarios
