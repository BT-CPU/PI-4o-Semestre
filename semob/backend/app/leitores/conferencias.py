"""Conferências ENTRE relatórios da Smart Data.

São as mesmas conferências que o gerar_dados.py fazia (e que os testes de
dados_exemplo_test.dart guardam), mais as do relatório "Viagens".

Como os arquivos chegam um de cada vez, cada conferência só roda quando os
relatórios que ela compara estão presentes. Uma conferência que falha NÃO
impede a gravação: serve de aviso de "dados inconsistentes" (os relatórios
mais recentes da Smart Data podem estar provisórios).
"""
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date

from .base import Relatorio

TOLERANCIA_KM_DIA = 0.2  # o Resumo Geral e as linhas arredondam em 1 casa
TOLERANCIA_REAIS = 0.01


@dataclass
class Conferencia:
    nome: str
    ok: bool
    detalhe: str  # o que foi conferido, ou o que não bateu
    diferencas: list[str] = field(default_factory=list)  # lista completa, uma por linha ("dd/mm/aaaa: ...")


def _rotulo(chave) -> str:
    partes = chave if isinstance(chave, tuple) else (chave,)
    return " / ".join(p.strftime("%d/%m/%Y") if isinstance(p, date) else str(p) for p in partes)


def _comparar(a: dict, b: dict, nome_a: str, nome_b: str, tolerancia=0.0):
    """Compara dois dicionários chave -> valor. Devolve (conferidos, diferenças)."""
    difs = []
    for k in sorted(set(a) | set(b)):
        if k not in a:
            difs.append(f"{_rotulo(k)}: só aparece em {nome_b}")
        elif k not in b:
            difs.append(f"{_rotulo(k)}: só aparece em {nome_a}")
        elif abs(a[k] - b[k]) > tolerancia:
            difs.append(f"{_rotulo(k)}: {nome_a} = {a[k]:g}, {nome_b} = {b[k]:g}")
    return len(set(a) | set(b)), difs


def _soma_por(registros: list[dict], chave, campo=None, filtro=None) -> dict:
    """Soma 'campo' (ou conta os registros, se campo for None) por chave."""
    total = defaultdict(float)
    for g in registros:
        if filtro is None or filtro(g):
            total[chave(g)] += 1 if campo is None else g[campo]
    return dict(total)


def _montar(nome: str, unidade: str, conferidos: int, difs: list[str]) -> Conferencia:
    if not difs:
        return Conferencia(nome, True, f"{conferidos} {unidade} conferido(s), tudo certo.")
    exemplos = "; ".join(difs[:3])
    mais = f" (e mais {len(difs) - 3})" if len(difs) > 3 else ""
    return Conferencia(nome, False, f"{len(difs)} diferença(s): {exemplos}{mais}", list(difs))


def _por_dia(g):
    return g["data"]


def _por_dia_linha(g):
    return (g["data"], g["linha"])


def _por_dia_hora(g):
    return (g["data"], g["hora"])


def _viagem_normal(g):
    return g["atividade"] == "Viagem Normal"


def _cobertura(nome: str, dias: list[date], com_dados: set[date]) -> Conferencia:
    """Os dias do Resumo geral têm dados? Só buracos NO MEIO do período são divergência.
    Dias antes do primeiro dado (o relatório só começa depois) e depois do último
    (dado provisório, ainda não chegou) viram apenas observação."""
    if not com_dados:
        return Conferencia(nome, False, "o relatório não tem nenhum dia.")
    primeiro, ultimo = min(com_dados), max(com_dados)
    buracos = [d for d in dias if primeiro < d < ultimo and d not in com_dados]
    antes = [d for d in dias if d < primeiro]
    depois = [d for d in dias if d > ultimo]

    notas = []
    if antes:
        notas.append(f"{len(antes)} dia(s) do Resumo geral antes de {_rotulo(primeiro)} sem dados (o relatório começa aí)")
    if depois:
        notas.append(f"{len(depois)} dia(s) depois de {_rotulo(ultimo)} sem dados ainda (provisório?)")
    obs = (" Obs.: " + "; ".join(notas) + ".") if notas else ""

    if buracos:
        lista = ", ".join(_rotulo(d) for d in buracos[:3]) + (f" (e mais {len(buracos) - 3})" if len(buracos) > 3 else "")
        return Conferencia(nome, False, f"{len(buracos)} dia(s) sem dados no meio do período: {lista}.{obs}",
                           [f"{_rotulo(d)}: sem dados" for d in buracos])
    dentro = len([d for d in dias if primeiro <= d <= ultimo])
    return Conferencia(nome, True, f"{dentro} dia(s) conferido(s), sem buracos.{obs}")


def conferir_relatorios(relatorios: list[Relatorio]) -> list[Conferencia]:
    """Roda as conferências possíveis com os relatórios recebidos.
    Relatórios com erros são ignorados. Se o mesmo tipo vier duas vezes, vale o último."""
    por_tipo = {r.tipo: r for r in relatorios if r.ok}
    resultado: list[Conferencia] = []

    def tabela(tipo, nome):
        return por_tipo[tipo].tabelas[nome]

    def tem(*tipos):
        return all(t in por_tipo for t in tipos)

    if tem("resumo_geral"):
        resumo = tabela("resumo_geral", "dias")
        programadas = {d["data"]: d["viagens_programadas"] for d in resumo}
        realizadas = {d["data"]: d["viagens_realizadas"] for d in resumo}
        km_prod = {d["data"]: d["km_produtivo"] for d in resumo}
        km_imp = {d["data"]: d["km_improdutivo"] for d in resumo}
        veic_max = {d["data"]: d["max_veiculos_faixa"] for d in resumo}
        dif = {d["data"]: d["dif_viagens"] for d in resumo}

    if tem("resumo_geral", "fcv"):
        fcv = tabela("fcv", "dias")
        n, d1 = _comparar({g["data"]: g["viagens_programadas"] for g in fcv}, programadas, "FCV", "Resumo geral")
        _, d2 = _comparar({g["data"]: g["viagens_realizadas"] for g in fcv}, realizadas, "FCV", "Resumo geral")
        resultado.append(_montar("FCV x Resumo geral (viagens programadas e realizadas)", "dia(s)", n, d1 + d2))

    if tem("resumo_geral", "linhas"):
        linhas = tabela("linhas", "linhas_dia")
        n, d1 = _comparar(_soma_por(linhas, _por_dia, "km_produtivo"), km_prod,
                          "Linhas", "Resumo geral", TOLERANCIA_KM_DIA)
        _, d2 = _comparar(_soma_por(linhas, _por_dia, "viagens"), realizadas, "Linhas", "Resumo geral")
        resultado.append(_montar("Linhas x Resumo geral (km produtivo e viagens por dia)", "dia(s)", n, d1 + d2))

    if tem("linhas", "fxhr"):
        n, d = _comparar(
            _soma_por(tabela("fxhr", "faixas_linha"), _por_dia_linha, "viagens"),
            {(g["data"], g["linha"]): g["viagens"] for g in tabela("linhas", "linhas_dia")},
            "Faixas por linha", "Linhas")
        resultado.append(_montar("Faixas por linha x Linhas (viagens por linha e dia)", "combinação(ões)", n, d))

    if tem("resumo_geral", "resumo_fxhr"):
        fx = tabela("resumo_fxhr", "faixas_sistema")
        n, d1 = _comparar(_soma_por(fx, _por_dia, "viagens"), realizadas, "Faixas do sistema", "Resumo geral")
        maximos = defaultdict(int)
        for g in fx:
            maximos[g["data"]] = max(maximos[g["data"]], g["veiculos"])
        _, d2 = _comparar(dict(maximos), veic_max, "Faixas do sistema", "Resumo geral")
        resultado.append(_montar("Faixas do sistema x Resumo geral (viagens e pico de veículos)", "dia(s)", n, d1 + d2))

    if tem("fxhr", "resumo_fxhr"):
        n, d = _comparar(
            _soma_por(tabela("fxhr", "faixas_linha"), _por_dia_hora, "viagens"),
            {(g["data"], g["hora"]): g["viagens"] for g in tabela("resumo_fxhr", "faixas_sistema")},
            "Faixas por linha", "Faixas do sistema")
        resultado.append(_montar("Faixas por linha x Faixas do sistema (viagens por hora)", "hora(s)", n, d))

    if tem("resumo_geral", "viag_nrealiz", "viag_ninic", "viag_nterm"):
        todas = [g for t in ("viag_nrealiz", "viag_ninic", "viag_nterm") for g in tabela(t, "ocorrencias")]
        contagem = _soma_por(todas, _por_dia)
        # dias sem ocorrência valem 0 (não aparecem nos relatórios)
        n, d = _comparar({k: contagem.get(k, 0) for k in dif}, dif, "Ocorrências", "Resumo geral")
        resultado.append(_montar("Ocorrências x Resumo geral (programadas - realizadas)", "dia(s)", n, d))

    if tem("resumo_geral", "viagens"):
        v = tabela("viagens", "viagens")
        n, d1 = _comparar(_soma_por(v, _por_dia, "km_produtivo"), km_prod, "Viagens", "Resumo geral", TOLERANCIA_KM_DIA)
        _, d2 = _comparar(_soma_por(v, _por_dia, "km_improdutivo"), km_imp, "Viagens", "Resumo geral", TOLERANCIA_KM_DIA)
        _, d3 = _comparar(_soma_por(v, _por_dia, filtro=_viagem_normal), realizadas, "Viagens normais", "Resumo geral")
        resultado.append(_montar("Viagens x Resumo geral (km e nº de viagens por dia)", "dia(s)", n, d1 + d2 + d3))

    if tem("linhas", "viagens"):
        v = tabela("viagens", "viagens")
        ref = tabela("linhas", "linhas_dia")
        n, d1 = _comparar(_soma_por(v, _por_dia_linha, "km_produtivo", _viagem_normal),
                          {(g["data"], g["linha"]): g["km_produtivo"] for g in ref},
                          "Viagens", "Linhas", TOLERANCIA_KM_DIA)
        _, d2 = _comparar(_soma_por(v, _por_dia_linha, filtro=_viagem_normal),
                          {(g["data"], g["linha"]): g["viagens"] for g in ref}, "Viagens", "Linhas")
        resultado.append(_montar("Viagens x Linhas (km e viagens por linha e dia)", "combinação(ões)", n, d1 + d2))

    if tem("saldos"):
        # saldo = saldo do lançamento anterior - créditos transferidos.
        # (Nos dias sem lançamento o saldo se mantém, então a cadeia vale entre lançamentos.)
        por_serie = defaultdict(list)
        for g in tabela("saldos", "saldos"):
            por_serie[g["serie"]].append(g)
        difs, pares = [], 0
        for lista in por_serie.values():
            lista.sort(key=lambda g: g["data"])
            for antes, depois in zip(lista, lista[1:]):
                if depois["creditos_transferidos"] is None:
                    continue  # em branco no relatório: não dá para conferir
                pares += 1
                esperado = antes["saldo_final"] - depois["creditos_transferidos"]
                if abs(esperado - depois["saldo_final"]) > TOLERANCIA_REAIS:
                    difs.append(f"{_rotulo(depois['data'])}: saldo = {depois['saldo_final']:,.2f}, "
                                f"esperado = {esperado:,.2f}")
        resultado.append(_montar("Saldo do sistema (saldo = saldo anterior - transferido)",
                                 "lançamento(s)", pares, difs))

    if tem("resumo_geral", "passageiros"):
        resultado.append(_cobertura("Passageiros cobrem os dias do Resumo geral", sorted(programadas),
                                    {g["data"] for g in tabela("passageiros", "passageiros")}))

    if tem("resumo_geral", "saldos"):
        # Dias sem movimento (sem venda e sem uso) parecem não ter linha no relatório.
        # Por isso aqui é só informação: nunca marca divergência.
        com_linha = {g["data"] for g in tabela("saldos", "vendas_utilizacao")}
        sem_linha = [d for d in sorted(programadas) if d not in com_linha]
        if sem_linha:
            lista = ", ".join(_rotulo(d) for d in sem_linha[:5]) + (" ..." if len(sem_linha) > 5 else "")
            resultado.append(Conferencia(
                "Vendas x utilização: dias do Resumo geral sem linha", True,
                f"{len(sem_linha)} dia(s) sem linha ({lista}); provavelmente dias sem movimento."))

    return resultado
