"""Testes da consulta (app/consulta.py) e das rotas GET /dados/*.

Os dados são montados com os mesmos HTMLs de teste dos outros arquivos, gravados pelo
importador no mongomock. O último teste só roda com a pasta Agosto_2026\\Mensal real
(SEMOB_HTMLS) e confere os mesmos números que o app tem nos dados de exemplo.
"""
import os

import pytest

from app.consulta import disponibilidade, periodo
from app.importador import importar
from app.leitores import ler_relatorio
from tests.conftest import cabecalho
from tests.test_importacoes_rota import _mongomock_aceita_sort, api  # noqa: F401 (fixtures)
from tests.test_importador import nao_realizadas
from tests.test_leitores import (
    COLS_RESUMO,
    COLS_SALDO,
    COLS_VENDA,
    arquivo,
    documento,
    fcv,
    resumo_geral,
    resumo_tres_dias,
    saldos,
)


@pytest.fixture
def banco(api):  # noqa: F811
    return api.banco


def carregar(banco, nome, conteudo):
    resp = importar(banco, ler_relatorio(nome, conteudo), conteudo)
    assert resp["status"] == "concluida", resp
    return resp


def resumo_dias(n):
    """Resumo geral com n dias iguais (100 viagens, 10 km produtivos, 1 improdutivo)."""
    linhas = [[f"{d:02d}/08/2026", "Seg", "10", "8", "100", "100", "0", "10", "1", "11"] for d in range(1, n + 1)]
    linhas.append(["Total Geral", "", "", "", str(100 * n), str(100 * n), "0", str(10 * n), str(1 * n), str(11 * n)])
    return arquivo(documento("Mensal - Resumo Geral", COLS_RESUMO, linhas))


def saldos_dois_lancamentos():
    """Lançamentos em 02/08 (saldo 9.000, transferido 1.000) e 04/08 (saldo 8.500, transferido 500)."""
    return arquivo(
        documento("São Caetano do Sul - Saldo de créditos do sistema", COLS_SALDO, [
            ["2026-08", "02", "1", "1.000,00", "9.000,00"],
            ["2026-08", "04", "1", "500,00", "8.500,00"],
            ["2026-08", "Total Mês", "", "1.500,00", ""]]),
        documento("São Caetano do Sul - Venda x Utilização", COLS_VENDA, [
            ["2026-08", "02", "0,00", "0,00", "0,00"],
            ["2026-08", "Total Mês", "0,00", "0,00", "0,00"]]))


# ---------------------------------------------------------------
# disponibilidade
# ---------------------------------------------------------------
def test_banco_vazio_nao_tem_dados(banco):
    d = disponibilidade(banco)
    assert d["temDados"] is False and d["dataMinima"] is None and d["dataMaxima"] is None


def test_disponibilidade_ignora_dia_so_com_financeiro(banco):
    carregar(banco, "Mensal_202608.html", resumo_geral())  # dias 01 e 02
    carregar(banco, "Saldos_Mensal.html", saldos())  # dias 02 e 03 (o 03 só tem financeiro)
    d = disponibilidade(banco)
    assert (d["dataMinima"], d["dataMaxima"]) == ("2026-08-01", "2026-08-02")
    assert d["saldoDesde"] == "2026-08-02" and d["passageirosDesde"] is None
    assert d["atualizadoEm"] == "2026-09-04T08:00:00"  # quando a Smart Data gerou o resumo


# ---------------------------------------------------------------
# periodo: os dias
# ---------------------------------------------------------------
def test_dia_reune_os_relatorios_no_formato_do_app(banco):
    carregar(banco, "Mensal_202608.html", resumo_tres_dias())
    carregar(banco, "Mensal_FCV_202608.html", fcv())
    carregar(banco, "Saldos_Mensal.html", saldos())
    dias = {d["data"]: d for d in periodo(banco, "2026-08-01", "2026-08-03")["dias"]}
    assert list(dias) == ["2026-08-01", "2026-08-02", "2026-08-03"]

    d2 = dias["2026-08-02"]
    assert (d2["viagensProgramadas"], d2["viagensRealizadas"], d2["veiculos"]) == (710, 703, 25)
    assert (d2["tardeProgramadas"], d2["tardeRealizadas"]) == (244, 238)  # do FCV
    assert (d2["kmProdutivo"], d2["kmImprodutivo"]) == (5253.0, 312.4)
    assert (d2["utilizacao"], d2["creditosTransferidos"], d2["saldoSistema"]) == (1980.0, 4805.0, 20434667.35)
    assert d2["passageirosCatraca"] == 0  # sem relatório de passageiros: zero

    # sem FCV nesse dia: faixas zeradas (o app trata como 100%)
    assert dias["2026-08-03"]["manhaProgramadas"] == 0


def test_saldo_repete_o_ultimo_lancamento_e_antes_do_primeiro_usa_o_saldo_anterior(banco):
    carregar(banco, "Mensal_202608.html", resumo_dias(5))
    carregar(banco, "Saldos_Mensal.html", saldos_dois_lancamentos())
    saldos_dos_dias = {d["data"][-2:]: d["saldoSistema"] for d in periodo(banco, "2026-08-01", "2026-08-05")["dias"]}
    assert saldos_dos_dias == {"01": 10000.0,  # antes do 1º lançamento: 9.000 + 1.000 transferidos
                               "02": 9000.0, "03": 9000.0,  # 03: sem lançamento, repete o do 02
                               "04": 8500.0, "05": 8500.0}


def test_saldo_com_periodo_que_comeca_depois_do_lancamento(banco):
    carregar(banco, "Mensal_202608.html", resumo_dias(5))
    carregar(banco, "Saldos_Mensal.html", saldos_dois_lancamentos())
    # o período só tem os dias 03 e 05: o saldo vem de lançamentos de FORA do período
    r = periodo(banco, "2026-08-03", "2026-08-03")["dias"]
    assert r[0]["saldoSistema"] == 9000.0
    # e um período só com dias antes do primeiro lançamento
    assert periodo(banco, "2026-08-01", "2026-08-01")["dias"][0]["saldoSistema"] == 10000.0


def test_periodo_anterior_e_dias_do_grafico(banco):
    carregar(banco, "Mensal_202608.html", resumo_dias(5))
    r = periodo(banco, "2026-08-04", "2026-08-05", anterior=("2026-08-02", "2026-08-03"),
                grafico_inicio="2026-08-01")
    assert [d["data"][-2:] for d in r["dias"]] == ["04", "05"]
    assert [d["data"][-2:] for d in r["diasAnteriores"]] == ["02", "03"]
    assert [d["data"][-2:] for d in r["diasGrafico"]] == ["01", "02", "03", "04", "05"]
    # sem os parâmetros opcionais: nada de anterior, e o gráfico é o próprio período
    r = periodo(banco, "2026-08-04", "2026-08-05")
    assert r["diasAnteriores"] == [] and len(r["diasGrafico"]) == 2


# ---------------------------------------------------------------
# periodo: ocorrências e motorista (LGPD)
# ---------------------------------------------------------------
def test_ocorrencias_e_numero_do_motorista(banco):
    carregar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05"), ("02", "04", "07")))
    admin = periodo(banco, "2026-08-01", "2026-08-31", administrador=True)["ocorrencias"]
    outro = periodo(banco, "2026-08-01", "2026-08-31", administrador=False)["ocorrencias"]
    outro_de_novo = periodo(banco, "2026-08-01", "2026-08-31", administrador=False)["ocorrencias"]

    assert [o["motorista"] for o in admin] == ["199", "199"]  # administrador: número real
    assert all(o["motorista"].startswith("M-") and "199" not in o["motorista"] for o in outro)
    assert outro[0]["motorista"] == outro[1]["motorista"] == outro_de_novo[0]["motorista"]  # código estável
    assert admin[0]["tipo"] == "naoRealizada" and admin[0]["inicioProgramado"] == "2026-08-02T05:00:00"
    assert admin[0]["inicioRealizado"] is None


def test_codigos_de_motoristas_diferentes_sao_diferentes(banco):
    conteudo = nao_realizadas(("02", "10", "05"), ("03", "04", "07")).replace(b">199<", b">200<", 1)
    carregar(banco, "Mensal_Viag_NRealiz_202608.html", conteudo)
    ocs = periodo(banco, "2026-08-01", "2026-08-31")["ocorrencias"]
    assert len(ocs) == 2 and ocs[0]["motorista"] != ocs[1]["motorista"]


# ---------------------------------------------------------------
# As rotas
# ---------------------------------------------------------------
def test_rotas_exigem_login(api, admin):
    assert api.get("/dados/disponibilidade").status_code == 401
    assert api.get("/dados/periodo?inicio=2026-08-01&fim=2026-08-31").status_code == 401


def test_rota_disponibilidade_e_periodo(api, admin, func, banco):
    carregar(banco, "Mensal_202608.html", resumo_geral())
    h = cabecalho(api, "func", "123456")
    assert api.get("/dados/disponibilidade", headers=h).json()["dataMaxima"] == "2026-08-02"
    r = api.get("/dados/periodo?inicio=2026-08-01&fim=2026-08-02", headers=h)
    assert r.status_code == 200 and len(r.json()["dias"]) == 2
    assert set(r.json()) == {"dias", "diasAnteriores", "diasGrafico", "ocorrencias", "ocorrenciasAnteriores",
                             "kmLinhas", "kmLinhasAnteriores", "faixasLinha", "faixasSistema"}


def test_rota_so_o_administrador_recebe_o_numero_do_motorista(api, admin, func, banco):
    carregar(banco, "Mensal_Viag_NRealiz_202608.html", nao_realizadas(("02", "10", "05")))
    url = "/dados/periodo?inicio=2026-08-01&fim=2026-08-31"
    como_admin = api.get(url, headers=cabecalho(api, "admin", "admin123")).json()["ocorrencias"]
    como_func = api.get(url, headers=cabecalho(api, "func", "123456")).json()["ocorrencias"]
    assert como_admin[0]["motorista"] == "199"
    assert como_func[0]["motorista"].startswith("M-") and "199" not in str(como_func)


@pytest.mark.parametrize("consulta", [
    "inicio=2026-13-01&fim=2026-08-31",  # data inválida
    "inicio=2026-08-31&fim=2026-08-01",  # fim antes do início
    "inicio=2026-08-01&fim=2026-08-31&anterior_inicio=2026-07-01",  # anterior pela metade
    "inicio=2026-08-01&fim=2026-08-31&anterior_inicio=2026-07-31&anterior_fim=2026-07-01",
    "inicio=2025-01-01&fim=2026-08-31",  # mais de 400 dias
    "inicio=2026-08-01&fim=2026-08-31&grafico_inicio=2024-01-01",  # idem, pelo gráfico
])
def test_rota_periodo_recusa_pedidos_invalidos(api, admin, consulta):
    r = api.get(f"/dados/periodo?{consulta}", headers=cabecalho(api, "admin", "admin123"))
    assert r.status_code == 422 and isinstance(r.json()["detail"], str)


# ---------------------------------------------------------------
# Relatórios reais (opcional): Agosto_2026\Mensal
# ---------------------------------------------------------------
@pytest.mark.skipif(
    not os.path.exists(os.path.join(os.getenv("SEMOB_HTMLS", ""), "Mensal_202608.html")),
    reason="defina SEMOB_HTMLS com a pasta Agosto_2026\\Mensal",
)
def test_agosto_real_bate_com_os_dados_de_exemplo_do_app(banco):
    pasta = os.environ["SEMOB_HTMLS"]
    for nome in sorted(os.listdir(pasta)):
        if nome.lower().endswith(".html") and "Viagens_202608" not in nome:  # o detalhe das viagens não é gravado
            with open(os.path.join(pasta, nome), "rb") as f:
                carregar(banco, nome, f.read())

    assert disponibilidade(banco)["dataMaxima"] == "2026-08-31"  # 01/09 (só financeiro) não conta
    r = periodo(banco, "2026-08-01", "2026-08-31", administrador=True)
    dias = r["dias"]
    assert len(dias) == 31 and len(r["ocorrencias"]) == 56 and len(r["kmLinhas"]) == 279
    assert len(r["faixasLinha"]) == 5598 and len(r["faixasSistema"]) == 651
    # os mesmos totais que dados_exemplo_test.dart confere no app
    assert sum(d["viagensProgramadas"] for d in dias) == 35050
    assert sum(d["viagensRealizadas"] for d in dias) == 34994
    assert sum(d["passageirosNaoPagantes"] for d in dias) == 761870
    assert round(sum(d["kmProdutivo"] for d in dias), 1) == 261886.8
    assert sum(d["vendas"] for d in dias) == pytest.approx(668605.71, abs=0.01)
    assert sum(d["creditosTransferidos"] for d in dias) == pytest.approx(676230.71, abs=0.01)
    assert dias[0]["saldoSistema"] == 20439472.35  # dia 1: sem lançamento, derivado do dia 2
    assert dias[-1]["saldoSistema"] == 19763241.64
    assert max(d["maxVeiculosFaixa"] for d in dias) == 48
