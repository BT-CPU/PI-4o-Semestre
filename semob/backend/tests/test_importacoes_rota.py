"""Testes das rotas POST /importacoes e GET /importacoes.

Usam as mesmas peças dos outros testes da API (client, admin, func) e o mongomock.
Os HTMLs de teste vêm de tests/test_leitores.py.
"""
import pytest
from mongomock.collection import BulkOperationBuilder

from app.db import garantir_indices, obter_banco
from app.main import app
from tests.conftest import cabecalho
from tests.test_leitores import arquivo, documento, fcv, resumo_geral, saldos


@pytest.fixture(autouse=True)
def _mongomock_aceita_sort(monkeypatch):
    """Mesmo ajuste de tests/test_importador.py (mongomock x pymongo novo)."""
    original = BulkOperationBuilder.add_update

    def add_update(self, *args, sort=None, **kwargs):
        return original(self, *args, **kwargs)

    monkeypatch.setattr(BulkOperationBuilder, "add_update", add_update)


@pytest.fixture
def api(client, usuarios):
    """O cliente de teste, com o banco de mentira também nas rotas de importação."""
    banco = usuarios.database
    garantir_indices(banco)
    app.dependency_overrides[obter_banco] = lambda: banco  # o "client" limpa isso no fim
    client.banco = banco
    return client


def html(nome="Mensal_202608.html", conteudo=None):
    return {"arquivo": (nome, conteudo if conteudo is not None else resumo_geral(), "text/html")}


def test_funcionario_envia_relatorio(api, admin, func):
    h = cabecalho(api, "func", "123456")
    resp = api.post("/importacoes", files=html(), headers=h)
    assert resp.status_code == 200, resp.text
    corpo = resp.json()
    assert corpo["status"] == "concluida" and corpo["tipo"] == "resumo_geral" and corpo["periodicidade"] == "Mensal"
    assert corpo["periodo"] == {"inicio": "2026-08-01", "fim": "2026-08-02"}
    assert corpo["gravados"] == {"dias_operacao.resumo": 2}
    assert api.banco.dias_operacao.count_documents({}) == 2
    # a importação registra quem enviou
    assert api.banco.importacoes.find_one()["enviadoPor"] == api.banco.usuarios.find_one({"usuario": "func"})["_id"]


def test_administrador_tambem_envia(api, admin):
    h = cabecalho(api, "admin", "admin123")
    assert api.post("/importacoes", files=html(), headers=h).status_code == 200


def test_sem_login_nao_envia_nem_lista(api, admin):
    assert api.post("/importacoes", files=html()).status_code == 401
    assert api.get("/importacoes").status_code == 401
    assert api.post("/importacoes", files=html(), headers={"Authorization": "Bearer lixo"}).status_code == 401
    assert api.banco.importacoes.count_documents({}) == 0


def test_enviar_de_novo_o_mesmo_arquivo_devolve_duplicada(api, admin):
    h = cabecalho(api, "admin", "admin123")
    primeira = api.post("/importacoes", files=html(), headers=h).json()
    segunda = api.post("/importacoes", files=html(), headers=h)
    assert segunda.status_code == 200 and segunda.json()["status"] == "duplicada"
    assert segunda.json()["id"] == primeira["id"]
    forcada = api.post("/importacoes?forcar=true", files=html(), headers=h).json()
    assert forcada["status"] == "concluida" and forcada["id"] != primeira["id"]
    assert api.banco.dias_operacao.count_documents({}) == 2


def test_relatorio_com_erro_devolve_422_e_nao_grava(api, admin):
    h = cabecalho(api, "admin", "admin123")
    resp = api.post("/importacoes", files=html(conteudo=resumo_geral("1999")), headers=h)
    assert resp.status_code == 422
    assert resp.json()["detail"].startswith("Arquivo recusado, com 1 erro(s)")
    assert resp.json()["resultado"]["status"] == "rejeitada"
    assert api.banco.dias_operacao.count_documents({}) == 0
    assert api.banco.importacoes.find_one()["status"] == "rejeitada"  # a tentativa fica no histórico


@pytest.mark.parametrize("conteudo", [b"", b"nao sou um relatorio", arquivo(documento("Mensal - Outra Coisa", ["A"], [["1"]]))])
def test_arquivo_que_nao_e_relatorio_devolve_422(api, admin, conteudo):
    h = cabecalho(api, "admin", "admin123")
    resp = api.post("/importacoes", files=html(conteudo=conteudo), headers=h)
    assert resp.status_code == 422 and isinstance(resp.json()["detail"], str)


def test_extensao_errada_devolve_400(api, admin):
    h = cabecalho(api, "admin", "admin123")
    resp = api.post("/importacoes", files=html(nome="relatorio.pdf"), headers=h)
    assert resp.status_code == 400


def test_arquivo_grande_demais_devolve_413(api, admin, monkeypatch):
    from app.rotas import importacoes
    monkeypatch.setattr(importacoes, "TAMANHO_MAXIMO", 100)
    h = cabecalho(api, "admin", "admin123")
    resp = api.post("/importacoes", files=html(), headers=h)
    assert resp.status_code == 413 and api.banco.importacoes.count_documents({}) == 0


def test_nome_com_pasta_e_limpo(api, admin):
    h = cabecalho(api, "admin", "admin123")
    api.post("/importacoes", files=html(nome="C:\\Users\\x\\Mensal_202608.html"), headers=h)
    assert api.banco.importacoes.find_one()["nomeArquivo"] == "Mensal_202608.html"


def test_historico_mostra_quem_enviou_e_ordena_do_mais_novo(api, admin, func):
    api.post("/importacoes", files=html(), headers=cabecalho(api, "admin", "admin123"))
    api.post("/importacoes", files=html("Mensal_FCV_202608.html", fcv()), headers=cabecalho(api, "func", "123456"))
    resp = api.get("/importacoes", headers=cabecalho(api, "func", "123456"))
    assert resp.status_code == 200
    lista = resp.json()
    assert [i["tipo"] for i in lista] == ["fcv", "resumo_geral"]
    assert [i["enviadoPor"] for i in lista] == ["Func", "Admin"]
    assert "hash" not in lista[0] and lista[0]["status"] == "concluida"


def test_nome_sem_periodicidade_e_aceito(api, func):
    # Passageiros.html e Saldos.html não dizem Mensal/Quinzenal no nome (o período vem do conteúdo)
    h = cabecalho(api, "func", "123456")
    resp = api.post("/importacoes", files=html("Saldos.html", saldos()), headers=h)
    assert resp.status_code == 200, resp.text
    assert resp.json()["tipo"] == "saldos" and resp.json()["periodicidade"] is None
