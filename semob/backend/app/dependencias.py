from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .db import colecao_usuarios
from .seguranca import ler_token
from .utilitarios import para_objectid

_esquema = HTTPBearer(auto_error=False)


def usuario_atual(
    credenciais: HTTPAuthorizationCredentials | None = Depends(_esquema),
    usuarios=Depends(colecao_usuarios),
) -> dict:
    """Confere o token e busca o usuário no banco a cada requisição.

    Assim, quem foi excluído perde o acesso na hora e uma mudança de perfil
    vale imediatamente (o perfil NÃO é lido do token).
    """
    erro = HTTPException(
        status_code=401,
        detail="Sessão inválida ou expirada. Entre novamente.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credenciais is None:
        raise erro
    usuario_id = ler_token(credenciais.credentials)
    oid = para_objectid(usuario_id) if usuario_id else None
    if oid is None:
        raise erro
    doc = usuarios.find_one({"_id": oid})
    if doc is None:
        raise erro
    return doc


def exigir_admin(atual: dict = Depends(usuario_atual)) -> dict:
    if atual["perfil"] != "administrador":
        raise HTTPException(status_code=403, detail="Acesso restrito a administradores.")
    return atual
