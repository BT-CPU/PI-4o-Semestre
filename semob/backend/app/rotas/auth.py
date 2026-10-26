from fastapi import APIRouter, Depends, HTTPException

from ..db import colecao_usuarios
from ..modelos import LoginEntrada, LoginSaida
from ..seguranca import criar_token, gerar_hash, verificar_senha
from ..utilitarios import doc_para_saida

router = APIRouter(tags=["autenticação"])

# Usado quando o login não existe, para a resposta demorar o mesmo tempo
# e não revelar se o usuário existe ou não
_HASH_FALSO = gerar_hash("senha-que-ninguem-usa")


@router.post("/login", response_model=LoginSaida)
def login(dados: LoginEntrada, usuarios=Depends(colecao_usuarios)):
    doc = usuarios.find_one({"usuarioNormalizado": dados.usuario.strip().lower()})
    senha_ok = verificar_senha(dados.senha, doc["senhaHash"] if doc else _HASH_FALSO)
    if doc is None or not senha_ok:
        raise HTTPException(status_code=401, detail="Usuário ou senha incorretos.")
    return LoginSaida(token=criar_token(str(doc["_id"])), usuario=doc_para_saida(doc))
