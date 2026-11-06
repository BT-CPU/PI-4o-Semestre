"""Um leitor para cada tipo de relatório da Smart Data.

Uso:
    relatorio = ler_relatorio("Mensal_202608.html", bytes_do_arquivo)
    if relatorio.ok:
        relatorio.tabelas["dias"]   # lista de dicionários
    else:
        relatorio.erros             # o que está errado no arquivo

Cada leitor confere o arquivo SOZINHO (colunas esperadas, números válidos e a
linha de total do próprio relatório). As conferências ENTRE relatórios ficam em
conferencias.py, porque os arquivos chegam um de cada vez.
"""
import re
from collections import defaultdict
from datetime import date

from .base import (
    Coletor,
    Documento,
    ErroLeitura,
    Relatorio,
    data_br,
    data_hora,
    data_mes_dia,
    decodificar,
    faixa_hora,
    int_br,
    num_br,
    separar_documentos,
)

TOLERANCIA_KM = 0.05
TOLERANCIA_REAIS = 0.01


# ---------------------------------------------------------------
# Peças comuns
# ---------------------------------------------------------------
def _percorrer(doc: Documento, esperado: list[str], c: Coletor, eh_total, converter):
    """Lê as linhas de uma tabela. Devolve (registros, linhas_de_total).

    esperado:  nomes das colunas (se o relatório mudar de layout, dá erro)
    eh_total:  função(células) -> True se a linha é de total
    converter: função(células) -> dicionário (pode lançar ValueError)
    """
    if doc.cabecalho != esperado:
        c.erro(f"Colunas diferentes do esperado. Esperado: {esperado}. Veio: {doc.cabecalho}.")
        return [], []
    registros, totais = [], []
    for n, cel in enumerate(doc.linhas, start=1):
        if len(cel) != len(esperado):
            c.erro(f"Linha {n}: {len(cel)} colunas em vez de {len(esperado)}.")
        elif eh_total(cel):
            totais.append(cel)
        else:
            try:
                registros.append(converter(cel))
            except ValueError as e:
                c.erro(f"Linha {n}: {e}")
    return registros, totais


def _tem_dados(c: Coletor, registros: list, nome: str) -> bool:
    if not registros and c.r.ok:
        c.erro(f"{nome}: nenhum registro encontrado.")
    return bool(registros)


def _conferir_soma(c: Coletor, nome: str, registros: list[dict], campo: str, esperado, tolerancia=0.0):
    """Soma de uma coluna x linha de total do próprio relatório."""
    soma = sum(r[campo] for r in registros)
    if abs(soma - esperado) > tolerancia:
        c.erro(f"{nome}: a soma das linhas ({soma:g}) não bate com o total do relatório ({esperado:g}).")


def _sem_total(c: Coletor, totais: list, qtd_esperada=1):
    if len(totais) != qtd_esperada:
        c.erro(f"Linha de total do relatório: esperava {qtd_esperada}, encontrei {len(totais)}.")
        return False
    return True


def _unico_por_chave(c: Coletor, registros: list[dict], chave, nome: str):
    vistos = set()
    for r in registros:
        k = chave(r)
        if k in vistos:
            c.erro(f"{nome}: registro repetido {k}.")
            return
        vistos.add(k)


# ---------------------------------------------------------------
# Resumo geral (viagens, veículos e km por dia)
# ---------------------------------------------------------------
def _ler_resumo_geral(docs, r, c):
    esperado = ["Data", "diaSem", "nrVeiculos", "nrMaxVeicFx", "nrViagensProgr",
                "nrViagensRealiz", "Dif Viagens", "kmProd", "kmImprod", "kmTotal"]

    def converter(x):
        return dict(
            data=data_br(x[0]), dia_semana=x[1], veiculos=int_br(x[2]),
            max_veiculos_faixa=int_br(x[3]), viagens_programadas=int_br(x[4]),
            viagens_realizadas=int_br(x[5]), dif_viagens=int_br(x[6]),
            km_produtivo=num_br(x[7]), km_improdutivo=num_br(x[8]), km_total=num_br(x[9]),
        )

    dias, totais = _percorrer(docs[0], esperado, c, lambda x: x[0] == "Total Geral", converter)
    r.tabelas["dias"] = dias
    if not _tem_dados(c, dias, "Resumo geral"):
        return

    for d in dias:
        if d["viagens_programadas"] - d["viagens_realizadas"] != d["dif_viagens"]:
            c.erro(f"{d['data']}: programadas - realizadas não é igual a 'Dif Viagens'.")
        if abs(d["km_produtivo"] + d["km_improdutivo"] - d["km_total"]) > TOLERANCIA_KM:
            c.erro(f"{d['data']}: km produtivo + improdutivo não é igual ao km total.")
    _unico_por_chave(c, dias, lambda d: d["data"], "Resumo geral")

    if _sem_total(c, totais):
        t = totais[0]
        try:
            r.totais = dict(
                viagens_programadas=int_br(t[4]), viagens_realizadas=int_br(t[5]), dif_viagens=int_br(t[6]),
                km_produtivo=num_br(t[7]), km_improdutivo=num_br(t[8]), km_total=num_br(t[9]),
            )
        except ValueError as e:
            c.erro(f"Total geral: {e}")
            return
        _conferir_soma(c, "Viagens programadas", dias, "viagens_programadas", r.totais["viagens_programadas"])
        _conferir_soma(c, "Viagens realizadas", dias, "viagens_realizadas", r.totais["viagens_realizadas"])
        _conferir_soma(c, "Km produtivo", dias, "km_produtivo", r.totais["km_produtivo"], TOLERANCIA_KM)
        _conferir_soma(c, "Km improdutivo", dias, "km_improdutivo", r.totais["km_improdutivo"], TOLERANCIA_KM)


# ---------------------------------------------------------------
# Fator de cumprimento de viagem (FCV) por faixa do dia
# ---------------------------------------------------------------
def _ler_fcv(docs, r, c):
    esperado = ["Data", "manha_p", "manha_r", "tarde_p", "tarde_r", "noite_p", "noite_r",
                "programadas", "realizadas"]

    def converter(x):
        v = [int_br(i) for i in x[1:]]
        return dict(
            data=data_br(x[0]),
            manha_programadas=v[0], manha_realizadas=v[1],
            tarde_programadas=v[2], tarde_realizadas=v[3],
            noite_programadas=v[4], noite_realizadas=v[5],
            viagens_programadas=v[6], viagens_realizadas=v[7],
        )

    dias, totais = _percorrer(docs[0], esperado, c, lambda x: x[0] == "", converter)
    r.tabelas["dias"] = dias
    if not _tem_dados(c, dias, "FCV"):
        return

    for d in dias:
        p = d["manha_programadas"] + d["tarde_programadas"] + d["noite_programadas"]
        re_ = d["manha_realizadas"] + d["tarde_realizadas"] + d["noite_realizadas"]
        if p != d["viagens_programadas"] or re_ != d["viagens_realizadas"]:
            c.erro(f"{d['data']}: manhã + tarde + noite não fecha com o total do dia.")
    _unico_por_chave(c, dias, lambda d: d["data"], "FCV")

    if _sem_total(c, totais):
        try:
            p, re_ = int_br(totais[0][7]), int_br(totais[0][8])
        except ValueError as e:
            c.erro(f"Total: {e}")
            return
        r.totais = dict(viagens_programadas=p, viagens_realizadas=re_)
        _conferir_soma(c, "Programadas", dias, "viagens_programadas", p)
        _conferir_soma(c, "Realizadas", dias, "viagens_realizadas", re_)


# ---------------------------------------------------------------
# Resumo por linha (km produtivo e viagens por linha e dia)
# ---------------------------------------------------------------
def _ler_linhas(docs, r, c):
    # ATENÇÃO: a coluna se chama "kmTotal", mas a soma dela é o km PRODUTIVO
    # (conferido contra o Resumo Geral).
    esperado = ["Data", "Linha", "kmTotal", "nrViagens"]

    def converter(x):
        if not x[1]:
            raise ValueError("linha sem número da linha de ônibus")
        return dict(data=data_br(x[0]), linha=x[1], km_produtivo=num_br(x[2]), viagens=int_br(x[3]))

    regs, totais = _percorrer(docs[0], esperado, c, lambda x: x[0] == "", converter)
    r.tabelas["linhas_dia"] = regs
    if not _tem_dados(c, regs, "Linhas"):
        return
    _unico_por_chave(c, regs, lambda d: (d["data"], d["linha"]), "Linhas")

    if _sem_total(c, totais):
        try:
            km, viagens = num_br(totais[0][2]), int_br(totais[0][3])
        except ValueError as e:
            c.erro(f"Total: {e}")
            return
        r.totais = dict(km_produtivo=km, viagens=viagens)
        _conferir_soma(c, "Km produtivo", regs, "km_produtivo", km, TOLERANCIA_KM)
        _conferir_soma(c, "Viagens", regs, "viagens", viagens)


# ---------------------------------------------------------------
# Partidas por faixa horária (por linha)
# ---------------------------------------------------------------
def _ler_fxhr(docs, r, c):
    esperado = ["Data", "Linha", "Fx_Hor", "Nr_Veiculos", "Nr_Viagens", "Partidas"]

    def converter(x):
        # "34 > 57 > 59" = minutos de cada partida dentro da hora
        partidas = [int_br(p) for p in x[5].split(">")] if x[5] else []
        return dict(data=data_br(x[0]), linha=x[1], hora=faixa_hora(x[2]),
                    veiculos=int_br(x[3]), viagens=int_br(x[4]), partidas=partidas)

    regs, totais = _percorrer(docs[0], esperado, c, lambda x: x[0] == "", converter)
    r.tabelas["faixas_linha"] = regs
    if not _tem_dados(c, regs, "Faixas por linha"):
        return
    _unico_por_chave(c, regs, lambda d: (d["data"], d["linha"], d["hora"]), "Faixas por linha")

    diferentes = sum(1 for g in regs if len(g["partidas"]) != g["viagens"])
    if diferentes:
        c.aviso(f"{diferentes} faixa(s) em que o nº de partidas listadas difere do nº de viagens.")

    if _sem_total(c, totais):
        try:
            viagens = int_br(totais[0][4])
        except ValueError as e:
            c.erro(f"Total: {e}")
            return
        r.totais = dict(viagens=viagens)
        _conferir_soma(c, "Viagens", regs, "viagens", viagens)


# ---------------------------------------------------------------
# Resumo por faixa horária (sistema todo)
# ---------------------------------------------------------------
def _ler_resumo_fxhr(docs, r, c):
    esperado = ["Data", "Fx_Hor", "Nr_Veiculos", "Nr_Viagens"]

    def converter(x):
        return dict(data=data_br(x[0]), hora=faixa_hora(x[1]), veiculos=int_br(x[2]), viagens=int_br(x[3]))

    regs, totais = _percorrer(docs[0], esperado, c, lambda x: x[0] == "", converter)
    r.tabelas["faixas_sistema"] = regs
    if not _tem_dados(c, regs, "Faixas do sistema"):
        return
    _unico_por_chave(c, regs, lambda d: (d["data"], d["hora"]), "Faixas do sistema")

    if _sem_total(c, totais):
        try:
            viagens = int_br(totais[0][3])
        except ValueError as e:
            c.erro(f"Total: {e}")
            return
        r.totais = dict(viagens=viagens)
        _conferir_soma(c, "Viagens", regs, "viagens", viagens)


# ---------------------------------------------------------------
# Viagens (detalhe de cada viagem e de cada trecho improdutivo)
# ---------------------------------------------------------------
def _ler_viagens(docs, r, c):
    esperado = ["Data", "Linha", "Prefixo", "Atividade", "Sentido", "Fx_Hor",
                "inicioRealizado", "fimRealizado", "kmProd", "kmImprod", "kmTotal"]

    def converter(x):
        return dict(
            data=data_br(x[0]), linha=x[1], prefixo=x[2], atividade=x[3], sentido=x[4],
            hora=faixa_hora(x[5]), inicio_realizado=data_hora(x[6]), fim_realizado=data_hora(x[7]),
            km_produtivo=num_br(x[8]), km_improdutivo=num_br(x[9]), km_total=num_br(x[10]),
        )

    regs, totais = _percorrer(docs[0], esperado, c, lambda x: x[0] == "", converter)
    r.tabelas["viagens"] = regs
    if not _tem_dados(c, regs, "Viagens"):
        return

    if _sem_total(c, totais):
        try:
            kp, ki = num_br(totais[0][8]), num_br(totais[0][9])
        except ValueError as e:
            c.erro(f"Total: {e}")
            return
        r.totais = dict(km_produtivo=kp, km_improdutivo=ki)
        _conferir_soma(c, "Km produtivo", regs, "km_produtivo", kp, TOLERANCIA_KM)
        _conferir_soma(c, "Km improdutivo", regs, "km_improdutivo", ki, TOLERANCIA_KM)


# ---------------------------------------------------------------
# Ocorrências: não realizadas, não iniciadas e não terminadas
# ---------------------------------------------------------------
_COLUNAS_OCORRENCIA = ["Data", "Linha", "Atendimento", "Prefixo", "Atividade", "Motorista",
                       "Sentido", "Tabela", "statusSaida", "statusChegada", "inicioProgramado",
                       "inicioRealizado", "fimProgramado", "fimRealizado", "kmProd"]

_TIPO_OCORRENCIA = {
    "viag_nrealiz": "naoRealizada",
    "viag_ninic": "naoIniciada",
    "viag_nterm": "naoTerminada",
}


def _ler_ocorrencias(docs, r, c):
    tipo = _TIPO_OCORRENCIA[r.tipo]

    def converter(x):
        return dict(
            data=data_br(x[0]), linha=x[1], tipo=tipo, atendimento=x[2], prefixo=x[3],
            atividade=x[4], motorista=x[5], sentido=x[6], tabela=x[7],
            status_saida=x[8], status_chegada=x[9],
            inicio_programado=data_hora(x[10]), inicio_realizado=data_hora(x[11]),
            fim_programado=data_hora(x[12]), fim_realizado=data_hora(x[13]),
            km_produtivo=num_br(x[14]),
        )

    regs, _ = _percorrer(docs[0], _COLUNAS_OCORRENCIA, c, lambda x: False, converter)
    r.tabelas["ocorrencias"] = regs
    # Sem registros NÃO é erro: um mês sem ocorrências é um bom mês.

    # Regra de cada tipo (descrita na tela de Ocorrências):
    #   não realizada: sem saída e sem chegada | não iniciada: só chegada | não terminada: só saída
    regra = {
        "naoRealizada": lambda g: g["inicio_realizado"] is None and g["fim_realizado"] is None,
        "naoIniciada": lambda g: g["inicio_realizado"] is None and g["fim_realizado"] is not None,
        "naoTerminada": lambda g: g["inicio_realizado"] is not None and g["fim_realizado"] is None,
    }[tipo]
    fora = sum(1 for g in regs if not regra(g))
    if fora:
        c.aviso(f"{fora} registro(s) cujos horários realizados não combinam com o tipo '{tipo}'.")


# ---------------------------------------------------------------
# Passageiros
# ---------------------------------------------------------------
def _ler_passageiros(docs, r, c):
    esperado = ["Mês", "Dia", "Catraca", "Antecipados", "Não Pagantes", "Total Passageiros"]

    def converter(x):
        return dict(data=data_mes_dia(x[0], x[1]), catraca=int_br(x[2]), antecipados=int_br(x[3]),
                    nao_pagantes=int_br(x[4]), total=int_br(x[5]))

    regs, totais = _percorrer(docs[0], esperado, c, lambda x: x[1] == "Total Mês", converter)
    r.tabelas["passageiros"] = regs
    if not _tem_dados(c, regs, "Passageiros"):
        return
    _unico_por_chave(c, regs, lambda d: d["data"], "Passageiros")

    for d in regs:
        if d["catraca"] + d["antecipados"] + d["nao_pagantes"] != d["total"]:
            c.erro(f"{d['data']}: catraca + antecipados + não pagantes não é igual ao total.")

    por_mes = defaultdict(list)
    for d in regs:
        por_mes[d["data"].strftime("%Y-%m")].append(d)
    for t in totais:  # uma linha "Total Mês" para cada mês do arquivo
        mes = t[0]
        try:
            esperado_mes = dict(catraca=int_br(t[2]), antecipados=int_br(t[3]),
                                nao_pagantes=int_br(t[4]), total=int_br(t[5]))
        except ValueError as e:
            c.erro(f"Total de {mes}: {e}")
            continue
        r.totais[mes] = esperado_mes
        for campo, valor in esperado_mes.items():
            _conferir_soma(c, f"Passageiros ({campo}) em {mes}", por_mes.get(mes, []), campo, valor)


# ---------------------------------------------------------------
# Saldos: saldo de créditos do sistema + vendas x utilização
# ---------------------------------------------------------------
def _ler_saldos(docs, r, c):
    saldo = next((d for d in docs if "Saldo de cr" in d.titulo), None)
    venda = next((d for d in docs if "Venda x Utiliza" in d.titulo), None)
    if saldo is None or venda is None:
        c.erro("O arquivo de saldos precisa ter as duas tabelas: 'Saldo de créditos do sistema' "
               "e 'Venda x Utilização'.")
        return

    # --- Saldo de créditos do sistema (só existem os dias com lançamento)
    def conv_saldo(x):
        return dict(data=data_mes_dia(x[0], x[1]), serie=x[2],
                    creditos_transferidos=num_br(x[3]), saldo_final=num_br(x[4]))

    regs, totais = _percorrer(
        saldo, ["Mês", "Dia", "Série", "Créditos transferidos para cartões", "Saldo Final"],
        c, lambda x: x[1] == "Total Mês", conv_saldo)
    r.tabelas["saldos"] = regs
    _tem_dados(c, regs, "Saldo do sistema")
    _unico_por_chave(c, regs, lambda d: (d["data"], d["serie"]), "Saldo do sistema")
    _conferir_totais_mes(c, r, "transferidos", regs, totais, 3, "creditos_transferidos")

    # --- Venda x Utilização (um registro por dia)
    def conv_venda(x):
        return dict(data=data_mes_dia(x[0], x[1]), vendas=num_br(x[2]), utilizacao=num_br(x[3]),
                    credito_circulante=num_br(x[4]))

    regs_v, totais_v = _percorrer(
        venda, ["Mês", "Dia", "Total Vendas", "Total Utilização", "Crédito Circulante"],
        c, lambda x: x[1] == "Total Mês", conv_venda)
    r.tabelas["vendas_utilizacao"] = regs_v
    _tem_dados(c, regs_v, "Vendas x utilização")
    _unico_por_chave(c, regs_v, lambda d: d["data"], "Vendas x utilização")
    for d in regs_v:
        if abs(d["vendas"] - d["utilizacao"] - d["credito_circulante"]) > TOLERANCIA_REAIS:
            c.erro(f"{d['data']}: vendas - utilização não é igual ao crédito circulante.")
    _conferir_totais_mes(c, r, "vendas", regs_v, totais_v, 2, "vendas")
    _conferir_totais_mes(c, r, "utilizacao", regs_v, totais_v, 3, "utilizacao")


def _conferir_totais_mes(c, r, nome, regs, totais, coluna, campo):
    """Cada 'Total Mês' do arquivo tem que ser a soma dos dias daquele mês."""
    por_mes = defaultdict(list)
    for d in regs:
        por_mes[d["data"].strftime("%Y-%m")].append(d)
    for t in totais:
        try:
            esperado = num_br(t[coluna])
        except ValueError as e:
            c.erro(f"Total de {t[0]} ({nome}): {e}")
            continue
        r.totais.setdefault(t[0], {})[nome] = esperado
        _conferir_soma(c, f"{nome} em {t[0]}", por_mes.get(t[0], []), campo, esperado, TOLERANCIA_REAIS)


# ---------------------------------------------------------------
# Descobrir o tipo e chamar o leitor certo
# ---------------------------------------------------------------
_LEITORES = {
    "resumo_geral": _ler_resumo_geral,
    "fcv": _ler_fcv,
    "linhas": _ler_linhas,
    "fxhr": _ler_fxhr,
    "resumo_fxhr": _ler_resumo_fxhr,
    "viagens": _ler_viagens,
    "viag_nrealiz": _ler_ocorrencias,
    "viag_ninic": _ler_ocorrencias,
    "viag_nterm": _ler_ocorrencias,
    "passageiros": _ler_passageiros,
    "saldos": _ler_saldos,
}

# O tipo é descoberto pelo TÍTULO (<h1>) do relatório, que é mais confiável que
# o nome do arquivo. A ordem importa: "Viagens" (só) fica depois das variantes.
_TITULOS = [
    (r"Resumo Geral", "resumo_geral"),
    (r"Fator de Cumprimento de Viagem", "fcv"),
    (r"Resumo por Linha", "linhas"),
    (r"Partidas por Faixa Hor", "fxhr"),
    (r"Resumo por Faixa Hor", "resumo_fxhr"),
    (r"Viagens n.o Realizadas", "viag_nrealiz"),
    (r"Viagens n.o Iniciadas", "viag_ninic"),
    (r"Viagens n.o Terminadas", "viag_nterm"),
    (r"- Viagens$", "viagens"),
    (r"Passageiros do Sistema", "passageiros"),
    (r"Saldo de cr.ditos do sistema", "saldos"),
    (r"Venda x Utiliza", "saldos"),
]


def _tipo_do_titulo(titulo: str) -> str | None:
    for padrao, tipo in _TITULOS:
        if re.search(padrao, titulo, re.I):
            return tipo
    return None


def _periodicidade(titulo: str, nome_arquivo: str) -> str | None:
    for texto in (titulo, nome_arquivo):
        m = re.search(r"(?<![a-zA-Z])(mensal|quinzenal|semanal)(?![a-zA-Z])", texto, re.I)
        if m:
            return m.group(1).capitalize()
    return None


def ler_relatorio(nome_arquivo: str, conteudo: bytes) -> Relatorio:
    """Lê um relatório da Smart Data. Lança ErroLeitura se o arquivo não for um
    relatório conhecido. Problemas dentro de um relatório conhecido ficam em
    relatorio.erros (grave no banco só se relatorio.ok)."""
    if not conteudo:
        raise ErroLeitura("O arquivo está vazio.")
    texto = decodificar(conteudo)
    # Todos os relatórios trazem "SmartDataSource" logo no começo
    if "SmartDataSource" not in texto[:6000]:
        raise ErroLeitura("O conteúdo não parece um relatório da Smart Data.")

    gerado_em, documentos = separar_documentos(texto)
    por_tipo: dict[str, list[Documento]] = defaultdict(list)
    for doc in documentos:
        tipo = _tipo_do_titulo(doc.titulo)
        if tipo:
            por_tipo[tipo].append(doc)
    if not por_tipo:
        raise ErroLeitura("Não reconheci o tipo de relatório (título não conhecido).")
    if len(por_tipo) > 1:
        raise ErroLeitura("O arquivo mistura relatórios de tipos diferentes.")

    tipo, docs = next(iter(por_tipo.items()))
    r = Relatorio(tipo=tipo, nome_arquivo=nome_arquivo,
                  periodicidade=_periodicidade(docs[0].titulo, nome_arquivo), gerado_em=gerado_em)
    _LEITORES[tipo](docs, r, Coletor(r))

    datas: list[date] = [g["data"] for lista in r.tabelas.values() for g in lista]
    if datas:
        r.data_inicio, r.data_fim = min(datas), max(datas)
    return r
