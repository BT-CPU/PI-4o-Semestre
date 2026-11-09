"""Grava no MongoDB os relatórios já lidos e validados por app.leitores.

Fluxo de importar():
  1. relatório com erros      -> só registra em "importacoes" (status rejeitada); nada é gravado
  2. mesmo arquivo já enviado -> não faz nada (status duplicada), a não ser que forcar=True
  3. caso contrário           -> registra a importação, grava os dados e conclui

Como os dados ficam:
  dias_operacao   UM documento por dia, com uma parte por relatório (viagens, km,
                  passageiros, financeiro). Cada relatório preenche só a sua parte
                  ($set por caminho), então os outros relatórios do mesmo dia NÃO são apagados.
  linhas_dia, faixas_linha, faixas_sistema, ocorrencias
                  um documento por registro. Reenviar atualiza o que já existe e remove
                  o que sumiu do período do arquivo (sem tocar em datas fora do período).

Todas as gravações são idempotentes: se der erro no meio, é só enviar de novo.
O detalhe de cada viagem (relatório "Viagens") é conferido, mas NÃO é gravado.
"""
import hashlib
from datetime import date, datetime, timezone

from pymongo import UpdateOne

from .leitores import Relatorio


def _data(d: date | None) -> str | None:
    return d.isoformat() if d else None


def _hora(x: datetime | None) -> str | None:
    return x.isoformat(timespec="seconds") if x else None


# ---------------------------------------------------------------
# dias_operacao: uma parte do documento do dia para cada relatório.
# (tipo do relatório) -> [(tabela lida, nome da parte, função registro -> campos)]
# Os nomes com ponto ("viagens.manha.programadas") são caminhos dentro do documento.
# ---------------------------------------------------------------
_PARTES_DO_DIA = {
    "resumo_geral": [(
        "dias", "resumo",
        lambda g: {
            "diaSemana": g["dia_semana"],
            "veiculos": g["veiculos"],
            "maxVeiculosFaixa": g["max_veiculos_faixa"],
            "viagens.programadas": g["viagens_programadas"],
            "viagens.realizadas": g["viagens_realizadas"],
            "km.produtivo": g["km_produtivo"],
            "km.improdutivo": g["km_improdutivo"],
        },
    )],
    "fcv": [(
        "dias", "fcv",
        lambda g: {
            "viagens.manha.programadas": g["manha_programadas"],
            "viagens.manha.realizadas": g["manha_realizadas"],
            "viagens.tarde.programadas": g["tarde_programadas"],
            "viagens.tarde.realizadas": g["tarde_realizadas"],
            "viagens.noite.programadas": g["noite_programadas"],
            "viagens.noite.realizadas": g["noite_realizadas"],
        },
    )],
    "passageiros": [(
        "passageiros", "passageiros",
        lambda g: {
            "passageiros.catraca": g["catraca"],
            "passageiros.antecipados": g["antecipados"],
            "passageiros.naoPagantes": g["nao_pagantes"],
            "passageiros.total": g["total"],
        },
    )],
    "saldos": [
        ("vendas_utilizacao", "vendas", lambda g: {
            "financeiro.vendas": g["vendas"],
            "financeiro.utilizacao": g["utilizacao"],
        }),
        # Só existem os dias com lançamento. Nos outros dias o saldo se mantém:
        # quem lê os dados (a API de consulta) é quem repete o último saldo.
        ("saldos", "saldos", lambda g: {
            "financeiro.creditosTransferidos": g["creditos_transferidos"],
            "financeiro.saldoSistema": g["saldo_final"],
        }),
    ],
}

# ---------------------------------------------------------------
# Coleções com um documento por registro.
# (tipo do relatório) -> (tabela lida, coleção, campos que identificam o registro, conversor)
# ---------------------------------------------------------------
def _ocorrencia(g):
    return {
        "data": _data(g["data"]), "linha": g["linha"], "tipo": g["tipo"],
        "atendimento": g["atendimento"], "prefixo": g["prefixo"], "motorista": g["motorista"],
        "sentido": g["sentido"], "tabela": g["tabela"],
        "inicioProgramado": _hora(g["inicio_programado"]), "inicioRealizado": _hora(g["inicio_realizado"]),
        "fimProgramado": _hora(g["fim_programado"]), "fimRealizado": _hora(g["fim_realizado"]),
    }


_CHAVE_OCORRENCIA = ("tipo", "data", "linha", "sentido", "tabela", "motorista", "inicioProgramado")

_LISTAS = {
    "linhas": ("linhas_dia", "linhas_dia", ("data", "linha"), lambda g: {
        "data": _data(g["data"]), "linha": g["linha"],
        "kmProdutivo": g["km_produtivo"], "viagens": g["viagens"],
    }),
    # Os minutos de cada partida (g["partidas"]) ficam de fora: não estão no modelo do banco.
    "fxhr": ("faixas_linha", "faixas_linha", ("data", "linha", "hora"), lambda g: {
        "data": _data(g["data"]), "linha": g["linha"], "hora": g["hora"],
        "veiculos": g["veiculos"], "viagens": g["viagens"],
    }),
    "resumo_fxhr": ("faixas_sistema", "faixas_sistema", ("data", "hora"), lambda g: {
        "data": _data(g["data"]), "hora": g["hora"], "veiculos": g["veiculos"], "viagens": g["viagens"],
    }),
    "viag_nrealiz": ("ocorrencias", "ocorrencias", _CHAVE_OCORRENCIA, _ocorrencia),
    "viag_ninic": ("ocorrencias", "ocorrencias", _CHAVE_OCORRENCIA, _ocorrencia),
    "viag_nterm": ("ocorrencias", "ocorrencias", _CHAVE_OCORRENCIA, _ocorrencia),
}


# ---------------------------------------------------------------
# Gravação
# ---------------------------------------------------------------
def _gravar_dias(banco, r: Relatorio, importacao_id, agora) -> dict[str, int]:
    gravados = {}
    for tabela, parte, campos in _PARTES_DO_DIA[r.tipo]:
        operacoes = [
            UpdateOne(
                {"data": _data(g["data"])},
                {
                    # Campo em branco no relatório (None) NÃO é gravado: outro relatório pode ter o valor
                    "$set": {**{k: v for k, v in campos(g).items() if v is not None},
                             f"origens.{parte}": importacao_id, "atualizadoEm": agora},
                    "$setOnInsert": {"criadoEm": agora},
                },
                upsert=True,
            )
            for g in r.tabelas[tabela]
        ]
        if operacoes:
            banco.dias_operacao.bulk_write(operacoes, ordered=False)
        gravados[f"dias_operacao.{parte}"] = len(operacoes)
    return gravados


def _gravar_lista(banco, r: Relatorio, importacao_id, avisos: list[str]) -> dict[str, int]:
    tabela, nome_colecao, chave, converter = _LISTAS[r.tipo]
    colecao = banco[nome_colecao]
    docs = [converter(g) for g in r.tabelas[tabela]]
    if not docs:
        return {nome_colecao: 0}

    filtros = [{campo: d[campo] for campo in chave} for d in docs]
    if len({tuple(f.values()) for f in filtros}) < len(docs):
        avisos.append("Há registros com a mesma identificação no arquivo: só o último de cada um foi mantido.")

    colecao.bulk_write(
        [UpdateOne(f, {"$set": {**d, "importacaoId": importacao_id}}, upsert=True)
         for f, d in zip(filtros, docs)],
        ordered=False,
    )

    # Remove o que existia no período do arquivo e não veio nele (veio de um envio anterior).
    # Em ocorrencias, cada tipo (não realizada, ...) vem de um relatório diferente.
    apagar = {
        "data": {"$gte": _data(r.data_inicio), "$lte": _data(r.data_fim)},
        "importacaoId": {"$ne": importacao_id},
    }
    if nome_colecao == "ocorrencias":
        apagar["tipo"] = docs[0]["tipo"]
    removidos = colecao.delete_many(apagar).deleted_count
    if removidos:
        avisos.append(f"{removidos} registro(s) de envios anteriores, que não estão neste arquivo, foram removidos.")
    return {nome_colecao: len(docs)}


def _resumo(doc: dict, duplicada: bool = False) -> dict:
    """Resposta de uma importação, pronta para virar JSON."""
    return {
        "id": str(doc["_id"]),
        "arquivo": doc["nomeArquivo"],
        "tipo": doc["tipoRelatorio"],
        "periodicidade": doc.get("periodicidade"),
        "periodo": doc.get("periodo"),
        "status": "duplicada" if duplicada else doc["status"],
        "gravados": doc.get("gravados", {}),
        "avisos": doc.get("avisos", []),
        "erros": doc.get("erros", []),
    }


def importar(banco, relatorio: Relatorio, conteudo: bytes, enviado_por=None, forcar: bool = False) -> dict:
    """Grava um relatório no banco. enviado_por é o _id do usuário (ou None)."""
    agora = datetime.now(timezone.utc)
    avisos = list(relatorio.avisos)
    hash_arquivo = hashlib.sha256(conteudo).hexdigest()

    doc = {
        "nomeArquivo": relatorio.nome_arquivo,
        "tipoRelatorio": relatorio.tipo,
        "periodicidade": relatorio.periodicidade,
        "periodo": {"inicio": _data(relatorio.data_inicio), "fim": _data(relatorio.data_fim)},
        "geradoEm": _hora(relatorio.gerado_em),
        "enviadoPor": enviado_por,
        "enviadoEm": agora,
        "tamanhoBytes": len(conteudo),
        "hash": hash_arquivo,
        "avisos": avisos,
        "erros": list(relatorio.erros),
    }

    if not relatorio.ok:
        doc["status"] = "rejeitada"
        doc["_id"] = banco.importacoes.insert_one(doc).inserted_id
        return _resumo(doc)

    if not forcar:
        anterior = banco.importacoes.find_one({"hash": hash_arquivo, "status": "concluida"})
        if anterior:
            return _resumo(anterior, duplicada=True)

    doc["status"] = "processando"
    importacao_id = banco.importacoes.insert_one(doc).inserted_id
    doc["_id"] = importacao_id

    try:
        if relatorio.tipo in _PARTES_DO_DIA:
            gravados = _gravar_dias(banco, relatorio, importacao_id, agora)
        elif relatorio.tipo in _LISTAS:
            gravados = _gravar_lista(banco, relatorio, importacao_id, avisos)
        else:  # "viagens": conferido, mas o detalhe de cada viagem não é gravado
            gravados = {}
            avisos.append("Relatório conferido, mas o detalhe de cada viagem não é gravado no banco.")
    except Exception as erro:
        banco.importacoes.update_one(
            {"_id": importacao_id}, {"$set": {"status": "erro", "erros": [f"Falha ao gravar: {erro}"[:500]]}}
        )
        raise

    doc.update(status="concluida", gravados=gravados, avisos=avisos)
    banco.importacoes.update_one(
        {"_id": importacao_id}, {"$set": {"status": "concluida", "gravados": gravados, "avisos": avisos}}
    )
    return _resumo(doc)
