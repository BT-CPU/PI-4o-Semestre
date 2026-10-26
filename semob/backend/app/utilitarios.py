from bson import ObjectId
from bson.errors import InvalidId

from .modelos import UsuarioSaida


def para_objectid(texto: str) -> ObjectId | None:
    try:
        return ObjectId(texto)
    except (InvalidId, TypeError):
        return None


def doc_para_saida(doc: dict) -> UsuarioSaida:
    # Nunca devolve senhaHash nem campos internos
    return UsuarioSaida(
        id=str(doc["_id"]),
        nome=doc["nome"],
        usuario=doc["usuario"],
        email=doc["email"],
        perfil=doc["perfil"],
    )
