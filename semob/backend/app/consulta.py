"""Consultas ao MongoDB para o dashboard.

Devolve, em JSON, os mesmos objetos que o app Flutter já usa (DiaOperacao, Ocorrencia,
KmLinhaDia, FaixaLinhaDia, FaixaSistemaDia). As contas dos períodos (dia, semana,
quinzena, mês, comparação com o período anterior) continuam no app; aqui só se
entregam os registros.

Regras que o servidor aplica ao montar cada dia:
- Só entram os dias que têm o Resumo geral (viagens e km). Um dia que só tem dados
  financeiros (como 01/09 no arquivo de saldos de agosto) não aparece.
- Dado que não existe vira zero (sem passageiros, sem vendas, sem FCV...).
- Saldo do sistema: o relatório só traz os dias com lançamento. Nos outros dias o saldo
  se mantém (repete o último lançamento). Antes do primeiro lançamento, usa-se o saldo
  anterior a ele (saldo do lançamento + o que foi transferido nele).
- O número do motorista é dado pessoal (LGPD): só o administrador recebe o número real.
  Os demais recebem um código fixo (M-xxxxxxxx), que permite agrupar as ocorrências do
  mesmo motorista sem revelar quem é.
"""
import hashlib
import hmac

from .config import config


# ---------------------------------------------------------------
# O que existe no banco
# ---------------------------------------------------------------
def disponibilidade(banco) -> dict:
    dias = banco.dias_operacao
    primeiro = dias.find_one({"origens.resumo": {"$exists": True}}, sort=[("data", 1)])
    if primeiro is None:
        return {"temDados": False, "dataMinima": None, "dataMaxima": None, "atualizadoEm": None,
                "passageirosDesde": None, "saldoDesde": None}

    ultimo = dias.find_one({"origens.resumo": {"$exists": True}}, sort=[("data", -1)])
    passageiros = dias.find_one({"origens.passageiros": {"$exists": True}}, sort=[("data", 1)])
    saldo = dias.find_one({"financeiro.saldoSistema": {"$exists": True}}, sort=[("data", 1)])
    # "geradoEm" = quando a Smart Data gerou o relatório (os de passageiros/saldos não trazem o ano)
    gerado = banco.importacoes.find_one({"status": "concluida", "geradoEm": {"$ne": None}},
                                        sort=[("geradoEm", -1)])
    return {
        "temDados": True,
        "dataMinima": primeiro["data"],
        "dataMaxima": ultimo["data"],
        "atualizadoEm": gerado["geradoEm"] if gerado else None,
        "passageirosDesde": passageiros["data"] if passageiros else None,
        "saldoDesde": saldo["data"] if saldo else None,
    }


# ---------------------------------------------------------------
# Saldo do sistema
# ---------------------------------------------------------------
def _lancamentos(banco, inicio: str, fim: str) -> list[tuple[str, float, float]]:
    """(data, saldo, transferido) dos lançamentos que bastam para dar saldo a cada dia de inicio..fim."""
    dias = banco.dias_operacao
    tem_saldo = {"financeiro.saldoSistema": {"$exists": True}}
    anterior = dias.find_one({**tem_saldo, "data": {"$lt": inicio}}, sort=[("data", -1)])
    dentro = list(dias.find({**tem_saldo, "data": {"$gte": inicio, "$lte": fim}}).sort("data", 1))
    docs = ([anterior] if anterior else []) + dentro
    if not docs:  # todos os dias do período são anteriores ao primeiro lançamento
        depois = dias.find_one({**tem_saldo, "data": {"$gt": fim}}, sort=[("data", 1)])
        docs = [depois] if depois else []
    return [(d["data"], d["financeiro"]["saldoSistema"], d["financeiro"].get("creditosTransferidos", 0.0))
            for d in docs]


def _saldo_do_dia(data: str, lancamentos: list[tuple[str, float, float]]) -> float:
    saldo = None
    for dia, valor, _ in lancamentos:
        if dia > data:
            break
        saldo = valor
    if saldo is not None:
        return saldo
    if lancamentos:  # antes do primeiro lançamento
        _, valor, transferido = lancamentos[0]
        return round(valor + transferido, 2)
    return 0.0


# ---------------------------------------------------------------
# Conversão dos documentos para o formato do app
# ---------------------------------------------------------------
def _dia(doc: dict, saldo: float) -> dict:
    v, km = doc.get("viagens", {}), doc.get("km", {})
    p, f = doc.get("passageiros", {}), doc.get("financeiro", {})

    def faixa(nome):
        g = v.get(nome, {})
        return g.get("programadas", 0), g.get("realizadas", 0)

    manha, tarde, noite = faixa("manha"), faixa("tarde"), faixa("noite")
    return {
        "data": doc["data"],
        "veiculos": doc.get("veiculos", 0),
        "maxVeiculosFaixa": doc.get("maxVeiculosFaixa", 0),
        "viagensProgramadas": v.get("programadas", 0),
        "viagensRealizadas": v.get("realizadas", 0),
        "manhaProgramadas": manha[0], "manhaRealizadas": manha[1],
        "tardeProgramadas": tarde[0], "tardeRealizadas": tarde[1],
        "noiteProgramadas": noite[0], "noiteRealizadas": noite[1],
        "kmProdutivo": float(km.get("produtivo", 0)),
        "kmImprodutivo": float(km.get("improdutivo", 0)),
        "passageirosCatraca": p.get("catraca", 0),
        "passageirosAntecipados": p.get("antecipados", 0),
        "passageirosNaoPagantes": p.get("naoPagantes", 0),
        "vendas": float(f.get("vendas", 0)),
        "utilizacao": float(f.get("utilizacao", 0)),
        "creditosTransferidos": float(f.get("creditosTransferidos", 0)),
        "saldoSistema": float(saldo),
    }


def _motorista(numero: str, administrador: bool) -> str:
    if administrador or not numero:
        return numero
    chave = (config.jwt_segredo or "semob").encode()
    return "M-" + hmac.new(chave, numero.encode(), hashlib.sha256).hexdigest()[:8]


def _ocorrencia(doc: dict, administrador: bool) -> dict:
    return {
        "data": doc["data"], "linha": doc["linha"], "tipo": doc["tipo"],
        "atendimento": doc.get("atendimento", ""), "prefixo": doc.get("prefixo", ""),
        "motorista": _motorista(doc.get("motorista", ""), administrador),
        "sentido": doc.get("sentido", ""), "tabela": doc.get("tabela", ""),
        "inicioProgramado": doc.get("inicioProgramado"), "inicioRealizado": doc.get("inicioRealizado"),
        "fimProgramado": doc.get("fimProgramado"), "fimRealizado": doc.get("fimRealizado"),
    }


def _entre(registros: list[dict], inicio: str, fim: str) -> list[dict]:
    return [r for r in registros if inicio <= r["data"] <= fim]


# ---------------------------------------------------------------
# Consulta principal
# ---------------------------------------------------------------
def periodo(banco, inicio: str, fim: str, anterior: tuple[str, str] | None = None,
            grafico_inicio: str | None = None, administrador: bool = False) -> dict:
    """Tudo o que uma tela precisa para um período (datas em "AAAA-MM-DD").

    anterior:       (inicio, fim) do período de comparação, se houver
    grafico_inicio: início dos dias usados nos gráficos (se omitido, é o próprio inicio)
    """
    inicios = [inicio] + ([anterior[0]] if anterior else []) + ([grafico_inicio] if grafico_inicio else [])
    desde = min(inicios)

    # Os dias (todos de uma vez, depois separados)
    docs = list(banco.dias_operacao.find(
        {"data": {"$gte": desde, "$lte": fim}, "origens.resumo": {"$exists": True}}).sort("data", 1))
    lancamentos = _lancamentos(banco, desde, fim)
    todos = [_dia(d, _saldo_do_dia(d["data"], lancamentos)) for d in docs]

    # Ocorrências e km por linha: o período e o anterior
    desde_comparacao = min(inicio, anterior[0]) if anterior else inicio
    filtro = {"data": {"$gte": desde_comparacao, "$lte": fim}}
    ocorrencias = [_ocorrencia(o, administrador)
                   for o in banco.ocorrencias.find(filtro).sort([("data", 1), ("inicioProgramado", 1)])]
    km = [{"data": k["data"], "linha": k["linha"], "kmProdutivo": float(k["kmProdutivo"]), "viagens": k["viagens"]}
          for k in banco.linhas_dia.find(filtro).sort([("data", 1), ("linha", 1)])]

    # Faixas horárias: só do período escolhido
    janela = {"data": {"$gte": inicio, "$lte": fim}}
    faixas_linha = [{"data": g["data"], "linha": g["linha"], "hora": g["hora"],
                     "veiculos": g["veiculos"], "viagens": g["viagens"]}
                    for g in banco.faixas_linha.find(janela).sort([("data", 1), ("linha", 1), ("hora", 1)])]
    faixas_sistema = [{"data": g["data"], "hora": g["hora"], "veiculos": g["veiculos"], "viagens": g["viagens"]}
                      for g in banco.faixas_sistema.find(janela).sort([("data", 1), ("hora", 1)])]

    dias = _entre(todos, inicio, fim)
    return {
        "dias": dias,
        "diasAnteriores": _entre(todos, *anterior) if anterior else [],
        "diasGrafico": _entre(todos, grafico_inicio, fim) if grafico_inicio else dias,
        "ocorrencias": _entre(ocorrencias, inicio, fim),
        "ocorrenciasAnteriores": _entre(ocorrencias, *anterior) if anterior else [],
        "kmLinhas": _entre(km, inicio, fim),
        "kmLinhasAnteriores": _entre(km, *anterior) if anterior else [],
        "faixasLinha": faixas_linha,
        "faixasSistema": faixas_sistema,
    }
