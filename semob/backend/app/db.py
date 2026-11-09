from pymongo import ASCENDING, DESCENDING, MongoClient
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

    # Histórico dos arquivos enviados
    banco.importacoes.create_index([("enviadoEm", DESCENDING)])
    banco.importacoes.create_index("hash")

    # Dados da operação. A data é texto "AAAA-MM-DD" (ordena e filtra por período).
    # Os índices únicos garantem que reenviar um arquivo atualiza, em vez de duplicar.
    banco.dias_operacao.create_index("data", unique=True)
    banco.linhas_dia.create_index([("data", ASCENDING), ("linha", ASCENDING)], unique=True)
    banco.faixas_linha.create_index(
        [("data", ASCENDING), ("linha", ASCENDING), ("hora", ASCENDING)], unique=True
    )
    banco.faixas_sistema.create_index([("data", ASCENDING), ("hora", ASCENDING)], unique=True)
    banco.ocorrencias.create_index(
        [
            ("tipo", ASCENDING),
            ("data", ASCENDING),
            ("linha", ASCENDING),
            ("sentido", ASCENDING),
            ("tabela", ASCENDING),
            ("motorista", ASCENDING),
            ("inicioProgramado", ASCENDING),
        ],
        unique=True,
    )
    banco.ocorrencias.create_index([("data", ASCENDING), ("linha", ASCENDING)])


def colecao_usuarios() -> Collection:
    return obter_banco().usuarios
