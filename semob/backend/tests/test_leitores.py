"""Testes do leitor dos relatórios da Smart Data.

Os HTMLs de teste são montados aqui mesmo, no mesmo formato da Smart Data
(cabeçalho solto, <th> fora de <tr>, Cp1252). Os relatórios REAIS não ficam no
repositório: para testar com eles, aponte a variável de ambiente SEMOB_HTMLS
para a pasta (o último teste é pulado se ela não existir).
"""
import os
from datetime import date, datetime

import pytest

from app.leitores import ErroLeitura, conferir_relatorios, ler_relatorio
from app.leitores.base import data_hora, faixa_hora, int_br, num_br

CABECALHO = """<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html><body><table class="d0"><tr><th><a href="http://www.smartdatasource.com">SmartDataSource.com</a></th>
<th>Horário</th></tr><tr class="even"><td>Gerado por &quot;Smart Report&quot;</td>
<td>04/09/2026 08:00</td></tr></table></body></html>
"""


def documento(titulo, colunas, linhas):
    ths = "\n".join(f"<th>{c}</th>" for c in colunas)  # soltos, como na Smart Data
    trs = "".join(
        "<tr class='even'>" + "".join(f"<td align='right'>{c}</td>" for c in linha) + "</tr>\n"
        for linha in linhas
    )
    return (f"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n<html><body>"
            f"<h1>{titulo}</h1>\n<table class='data'>\n{ths}\n{trs}</table></body></html>\n")


def arquivo(*documentos) -> bytes:
    return (CABECALHO + "".join(documentos)).encode("cp1252")


COLS_RESUMO = ["Data", "diaSem", "nrVeiculos", "nrMaxVeicFx", "nrViagensProgr",
               "nrViagensRealiz", "Dif Viagens", "kmProd", "kmImprod", "kmTotal"]


def resumo_geral(total_realizadas="1627"):
    return arquivo(documento("Mensal - Resumo Geral", COLS_RESUMO, [
        ["01/08/2026", "Sab", "37", "35", "924", "924", "0", "6889,4", "344,3", "7233,7"],
        ["02/08/2026", "Dom", "25", "23", "710", "703", "7", "5253", "312,4", "5565,4"],
        ["Total Geral", "", "", "", "1634", "1627", "7", "12142,4", "656,7", "12799,1"],
    ]).replace("1627", total_realizadas))


# ---------------------------------------------------------------
# Funções de conversão
# ---------------------------------------------------------------
@pytest.mark.parametrize("texto,esperado", [("6889,4", 6889.4), ("1.050.248", 1050248), ("5253", 5253), ("0", 0)])
def test_num_br(texto, esperado):
    assert num_br(texto) == esperado


@pytest.mark.parametrize("texto", ["", "abc", "1,2,3", "12.5x"])
def test_num_br_recusa_lixo(texto):
    with pytest.raises(ValueError):
        num_br(texto)


def test_int_br_recusa_decimal():
    assert int_br("5.168") == 5168
    with pytest.raises(ValueError):
        int_br("1,5")


def test_data_hora_e_faixa():
    assert data_hora("2026-08-02 14:35:00") == datetime(2026, 8, 2, 14, 35)
    assert data_hora("") is None
    assert faixa_hora("4hs") == 4 and faixa_hora("23hs") == 23 and faixa_hora("0") == 0
    with pytest.raises(ValueError):
        faixa_hora("24hs")


# ---------------------------------------------------------------
# Leitura de um relatório
# ---------------------------------------------------------------
def test_resumo_geral_lido_corretamente():
    r = ler_relatorio("Mensal_202608.html", resumo_geral())
    assert r.ok, r.erros
    assert r.tipo == "resumo_geral" and r.periodicidade == "Mensal"
    assert r.gerado_em == datetime(2026, 9, 4, 8, 0)
    assert (r.data_inicio, r.data_fim) == (date(2026, 8, 1), date(2026, 8, 2))
    dias = r.tabelas["dias"]
    assert len(dias) == 2  # a linha "Total Geral" não vira dia
    assert dias[0]["km_produtivo"] == 6889.4 and dias[1]["viagens_realizadas"] == 703
    assert r.totais["km_total"] == 12799.1


def test_total_que_nao_bate_vira_erro():
    r = ler_relatorio("Mensal_202608.html", resumo_geral(total_realizadas="1999"))
    assert not r.ok
    assert any("Viagens realizadas" in e for e in r.erros)


def test_colunas_diferentes_viram_erro():
    dados = arquivo(documento("Mensal - Resumo Geral", COLS_RESUMO[:-1], []))
    r = ler_relatorio("Mensal_202608.html", dados)
    assert not r.ok and "Colunas diferentes" in r.erros[0]


def test_numero_invalido_diz_a_linha():
    ruim = resumo_geral().replace(b"6889,4", b"6889,x")
    r = ler_relatorio("Mensal_202608.html", ruim)
    assert not r.ok and r.erros[0].startswith("Linha 1:")


@pytest.mark.parametrize("conteudo", [b"", b"<html>qualquer coisa</html>", "texto solto".encode()])
def test_arquivo_que_nao_e_relatorio(conteudo):
    with pytest.raises(ErroLeitura):
        ler_relatorio("x.html", conteudo)


def test_titulo_desconhecido():
    with pytest.raises(ErroLeitura):
        ler_relatorio("x.html", arquivo(documento("Mensal - Outra Coisa", ["A"], [["1"]])))


def test_ocorrencia_com_acentos_e_horarios_vazios():
    colunas = ["Data", "Linha", "Atendimento", "Prefixo", "Atividade", "Motorista", "Sentido", "Tabela",
               "statusSaida", "statusChegada", "inicioProgramado", "inicioRealizado", "fimProgramado",
               "fimRealizado", "kmProd"]
    linha = ["02/08/2026", "10", "OSWALDO CRUZ SENTIDO ESTAÇÃO", "1444", "Viagem Normal", "77", "I", "1B",
             "", "RG", "2026-08-02 14:35:00", "", "2026-08-02 15:00:00", "2026-08-02 14:54:52", "0"]
    r = ler_relatorio("Mensal_Viag_Ninic_202608.html",
                      arquivo(documento("Mensal - Viagens não Iniciadas", colunas, [linha])))
    assert r.ok and r.tipo == "viag_ninic"
    o = r.tabelas["ocorrencias"][0]
    assert o["atendimento"] == "OSWALDO CRUZ SENTIDO ESTAÇÃO" and o["tipo"] == "naoIniciada"
    assert o["inicio_realizado"] is None and o["fim_realizado"] == datetime(2026, 8, 2, 14, 54, 52)
    assert not r.avisos


def test_ocorrencia_sem_registros_nao_e_erro():
    colunas = ["Data", "Linha", "Atendimento", "Prefixo", "Atividade", "Motorista", "Sentido", "Tabela",
               "statusSaida", "statusChegada", "inicioProgramado", "inicioRealizado", "fimProgramado",
               "fimRealizado", "kmProd"]
    r = ler_relatorio("Mensal_Viag_NRealiz_202608.html",
                      arquivo(documento("Mensal - Viagens não Realizadas", colunas, [])))
    assert r.ok and r.tabelas["ocorrencias"] == []


def test_passageiros_periodicidade_vem_do_nome_do_arquivo():
    colunas = ["Mês", "Dia", "Catraca", "Antecipados", "Não Pagantes", "Total Passageiros"]
    linhas = [["2026-08", "01", "       5.168", "         676", "      10.700", "      16.544"],
              ["2026-08", "Total Mês", "     5.168", "       676", "    10.700", "    16.544"]]
    r = ler_relatorio("Passageiros_Mensal.html",
                      arquivo(documento("São Caetano do Sul - Passageiros do Sistema", colunas, linhas)))
    assert r.ok, r.erros
    assert r.periodicidade == "Mensal"
    assert r.tabelas["passageiros"][0]["total"] == 16544
    assert r.tabelas["passageiros"][0]["data"] == date(2026, 8, 1)


def test_passageiros_soma_errada_vira_erro():
    colunas = ["Mês", "Dia", "Catraca", "Antecipados", "Não Pagantes", "Total Passageiros"]
    linhas = [["2026-08", "01", "10", "10", "10", "31"]]
    r = ler_relatorio("Passageiros_Mensal.html",
                      arquivo(documento("São Caetano do Sul - Passageiros do Sistema", colunas, linhas)))
    assert not r.ok


COLS_SALDO = ["Mês", "Dia", "Série", "Créditos transferidos para cartões", "Saldo Final"]
COLS_VENDA = ["Mês", "Dia", "Total Vendas", "Total Utilização", "Crédito Circulante"]


def saldos(com_venda=True):
    docs = [documento("São Caetano do Sul - Saldo de créditos do sistema", COLS_SALDO, [
        ["2026-08", "02", "1", "4.805,00", "20.434.667,35"],
        ["2026-08", "03", "1", "11.932,00", "20.422.735,35"],
        ["2026-08", "Total Mês", "", "16.737,00", ""]])]
    if com_venda:
        docs.append(documento("São Caetano do Sul - Venda x Utilização", COLS_VENDA, [
            ["2026-08", "02", "0,00", "1.980,00", "-1.980,00"],
            ["2026-08", "03", "11.692,00", "8.610,00", "3.082,00"],
            ["2026-08", "Total Mês", "11.692,00", "10.590,00", "1.102,00"]]))
    return arquivo(*docs)


def test_saldos_le_as_duas_tabelas():
    r = ler_relatorio("Saldos_Mensal.html", saldos())
    assert r.ok, r.erros
    assert r.tipo == "saldos"
    assert len(r.tabelas["saldos"]) == 2 and len(r.tabelas["vendas_utilizacao"]) == 2
    assert r.tabelas["saldos"][0]["saldo_final"] == 20434667.35


def test_saldos_sem_uma_das_tabelas_e_erro():
    r = ler_relatorio("Saldos_Mensal.html", saldos(com_venda=False))
    assert not r.ok


# ---------------------------------------------------------------
# Conferências entre relatórios
# ---------------------------------------------------------------
def fcv(realizadas_dia2="703"):
    colunas = ["Data", "manha_p", "manha_r", "tarde_p", "tarde_r", "noite_p", "noite_r",
               "programadas", "realizadas"]
    return arquivo(documento("Mensal - Fator de Cumprimento de Viagem", colunas, [
        ["01/08/2026", "372", "372", "303", "303", "249", "249", "924", "924"],
        ["02/08/2026", "274", "274", "244", "238", "192", "191", "710", realizadas_dia2],
        ["", "646", "646", "547", "541", "441", "440", "1634", "1627"]]))


def test_conferencia_fcv_x_resumo_bate():
    rels = [ler_relatorio("Mensal_202608.html", resumo_geral("1627")),
            ler_relatorio("Mensal_FCV_202608.html", fcv())]
    assert all(r.ok for r in rels), [r.erros for r in rels]
    conf = conferir_relatorios(rels)
    assert len(conf) == 1 and conf[0].ok


def test_conferencia_acha_diferenca_entre_relatorios():
    # FCV internamente consistente, mas com 1 viagem a menos que o Resumo geral no dia 02
    colunas = ["Data", "manha_p", "manha_r", "tarde_p", "tarde_r", "noite_p", "noite_r",
               "programadas", "realizadas"]
    outro = arquivo(documento("Mensal - Fator de Cumprimento de Viagem", colunas, [
        ["01/08/2026", "372", "372", "303", "303", "249", "249", "924", "924"],
        ["02/08/2026", "274", "274", "244", "237", "192", "191", "710", "702"],
        ["", "646", "646", "547", "540", "441", "440", "1634", "1626"]]))
    rels = [ler_relatorio("Mensal_202608.html", resumo_geral("1627")),
            ler_relatorio("Mensal_FCV_202608.html", outro)]
    assert all(r.ok for r in rels), [r.erros for r in rels]
    conf = conferir_relatorios(rels)
    assert not conf[0].ok and "02/08/2026" in conf[0].detalhe


def test_conferencia_so_roda_quando_os_dois_relatorios_estao_presentes():
    assert conferir_relatorios([ler_relatorio("Mensal_202608.html", resumo_geral("1627"))]) == []


def test_conferencia_ignora_relatorio_com_erro():
    ruim = ler_relatorio("Mensal_202608.html", resumo_geral("1999"))
    assert not ruim.ok
    assert conferir_relatorios([ruim, ler_relatorio("Mensal_FCV_202608.html", fcv())]) == []


def test_cadeia_do_saldo_quebrada_e_apontada():
    r = ler_relatorio("Saldos_Mensal.html", saldos().replace(b"20.422.735,35", b"20.422.000,00"))
    assert r.ok  # cada arquivo, sozinho, está consistente
    conf = conferir_relatorios([r])
    assert len(conf) == 1 and not conf[0].ok


# ---------------------------------------------------------------
# Relatórios reais (opcional)
# ---------------------------------------------------------------
@pytest.mark.skipif(not os.getenv("SEMOB_HTMLS"), reason="defina SEMOB_HTMLS com a pasta dos relatórios reais")
def test_relatorios_reais_de_agosto():
    pasta = os.environ["SEMOB_HTMLS"]
    rels = []
    for nome in sorted(os.listdir(pasta)):
        if nome.lower().endswith(".html"):
            with open(os.path.join(pasta, nome), "rb") as f:
                rels.append(ler_relatorio(nome, f.read()))
    assert all(r.ok for r in rels), {r.nome_arquivo: r.erros for r in rels if not r.ok}
    falhas = [c for c in conferir_relatorios(rels) if not c.ok]
    assert not falhas, [(c.nome, c.detalhe) for c in falhas]
