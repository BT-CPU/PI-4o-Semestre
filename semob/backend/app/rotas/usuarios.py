from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Response
from pymongo.errors import DuplicateKeyError

from ..db import colecao_usuarios
from ..dependencias import exigir_admin, usuario_atual
from ..modelos import UsuarioAtualizacao, UsuarioEntrada, UsuarioSaida
from ..seguranca import gerar_hash
from ..utilitarios import doc_para_saida, para_objectid

router = APIRouter(prefix="/usuarios", tags=["usuários"])

_LOGIN_REPETIDO = "Já existe um usuário com este login."


def _buscar(usuarios, usuario_id: str) -> dict:
    oid = para_objectid(usuario_id)
    doc = usuarios.find_one({"_id": oid}) if oid else None
    if doc is None:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return doc


def _contar_admins(usuarios) -> int:
    return usuarios.count_documents({"perfil": "administrador"})


@router.get("/eu", response_model=UsuarioSaida)
def meu_perfil(atual: dict = Depends(usuario_atual)):
    return doc_para_saida(atual)


@router.get("", response_model=list[UsuarioSaida])
def listar(_: dict = Depends(exigir_admin), usuarios=Depends(colecao_usuarios)):
    return [doc_para_saida(d) for d in usuarios.find().sort("nome", 1)]


@router.post("", response_model=UsuarioSaida, status_code=201)
def criar(
    dados: UsuarioEntrada,
    _: dict = Depends(exigir_admin),
    usuarios=Depends(colecao_usuarios),
):
    doc = {
        "nome": dados.nome,
        "usuario": dados.usuario,
        "usuarioNormalizado": dados.usuario.lower(),
        "email": dados.email,
        "senhaHash": gerar_hash(dados.senha),
        "perfil": dados.perfil,
        "criadoEm": datetime.now(timezone.utc),
    }
    try:
        doc["_id"] = usuarios.insert_one(doc).inserted_id
    except DuplicateKeyError:
        raise HTTPException(status_code=409, detail=_LOGIN_REPETIDO)
    return doc_para_saida(doc)


@router.put("/{usuario_id}", response_model=UsuarioSaida)
def atualizar(
    usuario_id: str,
    dados: UsuarioAtualizacao,
    _: dict = Depends(exigir_admin),
    usuarios=Depends(colecao_usuarios),
):
    antigo = _buscar(usuarios, usuario_id)
    if (
        antigo["perfil"] == "administrador"
        and dados.perfil != "administrador"
        and _contar_admins(usuarios) == 1
    ):
        raise HTTPException(
            status_code=409, detail="O sistema precisa ter pelo menos um administrador."
        )

    campos = {
        "nome": dados.nome,
        "usuario": dados.usuario,
        "usuarioNormalizado": dados.usuario.lower(),
        "email": dados.email,
        "perfil": dados.perfil,
    }
    if dados.senha:
        campos["senhaHash"] = gerar_hash(dados.senha)
    try:
        usuarios.update_one({"_id": antigo["_id"]}, {"$set": campos})
    except DuplicateKeyError:
        raise HTTPException(status_code=409, detail=_LOGIN_REPETIDO)
    return doc_para_saida(usuarios.find_one({"_id": antigo["_id"]}))


@router.delete("/{usuario_id}", status_code=204)
def excluir(
    usuario_id: str,
    atual: dict = Depends(exigir_admin),
    usuarios=Depends(colecao_usuarios),
):
    alvo = _buscar(usuarios, usuario_id)
    if alvo["_id"] == atual["_id"]:
        raise HTTPException(
            status_code=400, detail="Você não pode excluir o seu próprio usuário."
        )
    if alvo["perfil"] == "administrador" and _contar_admins(usuarios) == 1:
        raise HTTPException(
            status_code=409, detail="Não é possível excluir o único administrador."
        )
    usuarios.delete_one({"_id": alvo["_id"]})
    return Response(status_code=204)
