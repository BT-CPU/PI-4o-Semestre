from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from .config import config

_hasher = PasswordHasher()


def gerar_hash(senha: str) -> str:
    return _hasher.hash(senha)


def verificar_senha(senha: str, hash_guardado: str) -> bool:
    try:
        return _hasher.verify(hash_guardado, senha)
    except (VerifyMismatchError, InvalidHashError):
        return False


def criar_token(usuario_id: str) -> str:
    if not config.jwt_segredo:
        raise RuntimeError("JWT_SEGREDO não definido (veja o arquivo .env).")
    agora = datetime.now(timezone.utc)
    dados = {
        "sub": usuario_id,
        "iat": agora,
        "exp": agora + timedelta(hours=config.jwt_horas),
    }
    return jwt.encode(dados, config.jwt_segredo, algorithm="HS256")


def ler_token(token: str) -> str | None:
    """Devolve o id do usuário, ou None se o token for inválido ou expirou."""
    try:
        dados = jwt.decode(token, config.jwt_segredo, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    sub = dados.get("sub")
    return sub if isinstance(sub, str) else None
