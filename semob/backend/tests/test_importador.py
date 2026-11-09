"""Testes do importador. Usam o mongomock (um MongoDB de mentira, em memória).

Como em test_leitores.py, o último teste só roda se SEMOB_HTMLS apontar para a
pasta com os relatórios reais de agosto/2026.
"""
import os

import mongomock
import pytest
from mongomock.collection import BulkOperationBuilder

from app.db import garantir_indices
from app.importador import importar
from app.leitores import ler_relatorio
from tests.test_leitores import (
    COLS_SALDO,
    COLS_VENDA,
    arquivo,
    documento,
    fcv,
    resumo_geral,
    saldos,
)

COLS_OCORRENCIA = ["Data", "Linha", "Atendimento", "Prefixo", "Atividade", "Motorista", "Sentido", "Tabela",
                   "statusSaida", "statusChegada", "inicioProgramado", "inicioRealizado", "fimProgramado",
                   "fimRealizado", "kmProd"]


@pytest.fixture(autouse=True)
def _mongomock_aceita_sort(monkeypatch):
    """Versões novas do pymongo passam o argumento "sort" para o bulk_write, e algumas
    versões do mongomock ainda não o conhecem (TypeError). Só os testes precisam disso:
    no MongoDB de verdade (Atlas) o bulk_write funciona normalmente."""
    original = BulkOperationBuilder.add_update

    def add_update(self, *args, sort=None, **kwargs):
        return original(self, *args, **kwargs)

    monkeypatch.setattr(BulkOperationBuilder, "add_update", add_update)


@pytest.fixture
def banco():
    banco = mongomock.MongoClient().semob_teste
    garantir_indices(banco)
    return banco


def enviar(banco, nome, conteudo, **kw):
    return importar(banco, ler_relatorio(nome, conteudo), conteudo, **kw)


def nao_realizadas(*linhas):
    """Relatório de viagens não realizadas. Cada linha: (dia, linha, hora_inicio)."""
    regs = [[f"{d}/08/2026", ln, "CIRCULAR GERTY SENTIDO IDA", "", "Viagem Normal", "199", "I", "3A", "", "",
             f"2026-08-{d} {h}:00:00", "", f"2026-08-{d} {h}:30:00", "", "0"] for d, ln, h in linhas]
    return arquivo(documento("Mensal - Viagens não Realizadas", COLS_OCORRENCIA, regs))


# ---------------------------------------------------------------
def test_resumo_geral_cria_um_documento_por_dia(banco):
    resp = enviar(banco, "Mensal_202608.html", resumo_geral())
    assert resp["status"] == "concluida" and resp["periodo"] == {"inicio": "2026-08-01", "fim": "2026-08-02"}
    assert banco.dias_operacao.count_documents({}) == 2
    dia = banco.dias_operacao.find_one({"data": "2026-08-02"})
    assert dia["diaSemana"] == "Dom" and dia["veiculos"] == 25
    assert dia["viagens"] == {"programadas": 710, "realizadas": 703}
    assert dia["km"] == {"produtivo": 5253.0, "improdutivo": 312.4}


def test_importacao_fica_registrada_com_o_usuario(banco):
    resp = enviar(banco, "Mensal_202608.html", resumo_geral(), enviado_por="id-do-usuario")
    imp = banco.importacoes.find_one({"nomeArquivo": "Mensal_202608.html"})
    assert str(imp["_id"]) == resp["id"]
    assert (imp["tipoRelatorio"], imp["periodicidade"], imp["status"]) == ("resumo_geral", "Mensal", "concluida")
    assert imp["enviadoPor"] == "id-do-usuario" and imp["geradoEm"] == "2026-09-04T08:00:00"
    assert len(imp["hash"]) == 64


def test_relatorios_diferentes_se_juntam_no_mesmo_dia_sem_apagar_um_ao_outro(banco):
    enviar(banco, "Mensal_202608.html", resumo_geral("1627"))
    enviar(banco, "Mensal_FCV_202608.html", fcv())
    enviar(banco, "Saldos_Mensal.html", saldos())
    # o arquivo de saldos tem também o dia 03, que não está no resumo: vira um dia só com financeiro
    # (nos dados reais é o caso de 01/09)
    assert banco.dias_operacao.count_documents({}) == 3
    sem_viagens = banco.dias_operacao.find_one({"data": "2026-08-03"})
    assert "viagens" not in sem_viagens and sem_viagens["financeiro"]["vendas"] == 11692.0
    dia = banco.dias_operacao.find_one({"data": "2026-08-02"})
    assert dia["viagens"]["realizadas"] == 703  # do resumo geral
    assert dia["viagens"]["tarde"] == {"programadas": 244, "realizadas": 238}  # do FCV
    assert dia["financeiro"]["utilizacao"] == 1980.0 and dia["financeiro"]["saldoSistema"] == 20434667.35
    assert set(dia["origens"]) == {"resumo", "fcv", "vendas", "saldos"}


def test_reenviar_o_mesmo_arquivo_nao_faz_nada(banco):
    primeiro = enviar(banco, "Mensal_202608.html", resumo_geral())
    segundo = enviar(banco, "Mensal_202608.html", resumo_geral())
    assert segundo["status"] == "duplicada" and segundo["id"] == primeiro["id"]
    assert banco.importacoes.count_documents({}) == 1


def test_forcar_regrava_sem_duplicar(banco):
    enviar(banco, "Mensal_202608.html", resumo_geral())
    resp = enviar(banco, "Mensal_202608.html", resumo_geral(), forcar=True)
    assert resp["status"] == "concluida"
    assert banco.dias_operacao.count_documents({}) == 2
    assert banco.importacoes.count_documents({}) == 2  # o histórico guarda os dois envios


def test_arquivo_mais_novo_atualiza_os_valores_do_dia(banco):
    enviar(banco, "Mensal_202608.html", resumo_geral())
    novo = resumo_geral().replace(b"6889,4", b"6900,0").replace(b"7233,7", b"7244,3") \
        .replace(b"12142,4", b"12153,0").replace(b"12799,1", b"12809,7")
    resp = enviar(banco, "Mensal_202608.html", novo)
    assert resp["status"] == "concluida", resp
    assert banco.dias_operacao.find_one({"data": "2026-08-01"})["km"]["produtivo"] == 6900.0


def test_valor_em_branco_nao_apaga_o_que_outro_relatorio_ja_gravou(banco):
    # o mensal diz que em 02/08 foram transferidos 4.805,00
    enviar(banco, "Saldos_Mensal.html", saldos())
    assert banco.dias_operacao.find_one({"data": "2026-08-02"})["financeiro"]["creditosTransferidos"] == 4805.0

    # o quinzenal deixa essa célula em branco (None). O saldo é atualizado, a transferência NÃO vira zero.
    linhas = [["2026-08", "02", "1", "", "20.434.667,35"],
              ["2026-08", "03", "1", "11.932,00", "20.422.735,35"],
              ["2026-08", "Total Mês", "", "11.932,00", ""]]
    conteudo = arquivo(
        documento("São Caetano do Sul - Saldo de créditos do sistema", COLS_SALDO, linhas),
        documento("São Caetano do Sul - Venda x Utilização", COLS_VENDA, [
            ["2026-08", "02", "0,00", "1.980,00", "-1.980,00"],
            ["2026-08", "Total Mês", "0,00", "1.980,00", "-1.980,00"]]))
    resp = enviar(banco, "Saldos_Quinzenal.html", conteudo)
    assert resp["status"] == "concluida" and any("em branco" in a for a in resp["avisos"])
    fin = banco.dias_operacao.find_one({"data": "2026-08-02"})["financeiro"]
    assert fin["creditosTransferidos"] == 4805.0 and fin["saldoSistema"] == 20434667.35


def test_arquivo_com_erro_e_rejeitado_e_nada_e_gravado(banco):
    resp = enviar(banco, "Mensal_202608.html", resumo_geral("1999"))
    assert resp["status"] == "rejeitada" and resp["erros"]
    assert banco.dias_operacao.count_documents({}) == 0
    assert banco.importacoes.find_one()["status"] == "rejeitada"


def test_ocorrencias_removem_o_que_sumiu_do_periodo_do_arquivo(banco):
    enviar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05"), ("02", "04", "07")))
    assert banco.ocorrencias.count_documents({}) == 2
    resp = enviar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05")))
    assert banco.ocorrencias.count_documents({}) == 1
    assert banco.ocorrencias.find_one()["linha"] == "10"
    assert any("removidos" in a for a in resp["avisos"])


def test_ocorrencias_fora_do_periodo_do_arquivo_nao_sao_tocadas(banco):
    enviar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05"), ("20", "04", "07")))
    enviar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05")))  # só o dia 02
    assert banco.ocorrencias.count_documents({}) == 2


def test_ocorrencia_guarda_horarios_como_texto(banco):
    enviar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05")))
    o = banco.ocorrencias.find_one()
    assert o["data"] == "2026-08-02" and o["tipo"] == "naoRealizada"
    assert o["inicioProgramado"] == "2026-08-02T05:00:00" and o["inicioRealizado"] is None


def test_viagens_sao_conferidas_mas_nao_gravadas(banco):
    colunas = ["Data", "Linha", "Prefixo", "Atividade", "Sentido", "Fx_Hor", "inicioRealizado",
               "fimRealizado", "kmProd", "kmImprod", "kmTotal"]
    conteudo = arquivo(documento("Mensal - Viagens", colunas, [
        ["01/08/2026", "01", "1444", "Viagem Normal", "I", "5", "2026-08-01 05:00:00", "2026-08-01 05:30:00",
         "7,5", "0", "7,5"],
        ["", "", "", "", "", "", "", "", "7,5", "0", "7,5"]]))
    resp = enviar(banco, "Mensal_Viagens_202608.html", conteudo)
    assert resp["status"] == "concluida" and resp["gravados"] == {}
    assert any("não é gravado" in a for a in resp["avisos"])


def test_relatorio_vazio_de_ocorrencias_e_aceito(banco):
    resp = enviar(banco, "Mensal_Viag_NTerm_202608.html",
                  arquivo(documento("Mensal - Viagens não Terminadas", COLS_OCORRENCIA, [])))
    assert resp["status"] == "concluida" and resp["gravados"] == {"ocorrencias": 0}


def test_indices_unicos_impedem_duplicar_dia(banco):
    from pymongo.errors import DuplicateKeyError
    banco.dias_operacao.insert_one({"data": "2026-08-01"})
    with pytest.raises(DuplicateKeyError):
        banco.dias_operacao.insert_one({"data": "2026-08-01"})


# ---------------------------------------------------------------
# Relatórios reais (opcional)
# ---------------------------------------------------------------
@pytest.mark.skipif(
    not os.path.exists(os.path.join(os.getenv("SEMOB_HTMLS", ""), "Mensal_202608.html")),
    reason="defina SEMOB_HTMLS com a pasta Agosto_2026\\Mensal (os números esperados são de agosto/2026)",
)
def test_agosto_inteiro_no_banco(banco):
    pasta = os.environ["SEMOB_HTMLS"]
    for nome in sorted(os.listdir(pasta)):
        if nome.lower().endswith(".html"):
            with open(os.path.join(pasta, nome), "rb") as f:
                resp = enviar(banco, nome, f.read())
            assert resp["status"] == "concluida", (nome, resp)

    contagens = {c: banco[c].count_documents({}) for c in
                 ("dias_operacao", "linhas_dia", "faixas_linha", "faixas_sistema", "ocorrencias")}
    # 31 dias de agosto + 01/09, que só tem vendas/utilização (vem no arquivo de saldos)
    assert contagens == {"dias_operacao": 32, "linhas_dia": 279, "faixas_linha": 5598,
                         "faixas_sistema": 651, "ocorrencias": 56}

    # Os mesmos totais que dados_exemplo_test.dart confere no app
    agosto = list(banco.dias_operacao.find({"data": {"$regex": "^2026-08"}}))
    assert len(agosto) == 31
    assert sum(d["viagens"]["programadas"] for d in agosto) == 35050
    assert sum(d["viagens"]["realizadas"] for d in agosto) == 34994
    assert sum(d["passageiros"]["total"] for d in agosto) == 1050248
    assert sum(d["financeiro"]["vendas"] for d in agosto) == pytest.approx(668605.71, abs=0.01)
    assert sum(d["financeiro"]["creditosTransferidos"] for d in agosto if "creditosTransferidos" in d["financeiro"]) \
        == pytest.approx(676230.71, abs=0.01)
    assert round(sum(d["km"]["produtivo"] for d in agosto), 1) == 261886.8

    # Reenviar tudo (forçando) não muda nada
    for nome in sorted(os.listdir(pasta)):
        if nome.lower().endswith(".html"):
            with open(os.path.join(pasta, nome), "rb") as f:
                enviar(banco, nome, f.read(), forcar=True)
    assert contagens == {c: banco[c].count_documents({}) for c in contagens}
