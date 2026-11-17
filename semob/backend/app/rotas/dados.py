from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query

from ..consulta import disponibilidade, periodo
from ..db import obter_banco
from ..dependencias import usuario_atual

router = APIRouter(prefix="/dados", tags=["dados"])

# Segurança: um pedido não pode puxar o banco inteiro de uma vez
MAX_DIAS = 400


def _data(nome: str, texto: str) -> date:
    try:
        return date.fromisoformat(texto)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"{nome} inválida: use o formato AAAA-MM-DD.")


@router.get("/disponibilidade")
def ver_disponibilidade(_: dict = Depends(usuario_atual), banco=Depends(obter_banco)):
    """Intervalo de datas que tem dados (viagens) e desde quando há passageiros e saldo."""
    return disponibilidade(banco)


@router.get("/periodo")
def ver_periodo(
    inicio: str,
    fim: str,
    anterior_inicio: str | None = Query(None, description="Início do período de comparação"),
    anterior_fim: str | None = Query(None, description="Fim do período de comparação"),
    grafico_inicio: str | None = Query(None, description="Início dos dias usados nos gráficos"),
    atual: dict = Depends(usuario_atual),
    banco=Depends(obter_banco),
):
    """Dias, ocorrências, km por linha e faixas horárias de um período (datas AAAA-MM-DD)."""
    d_inicio, d_fim = _data("inicio", inicio), _data("fim", fim)
    if d_fim < d_inicio:
        raise HTTPException(status_code=422, detail="O fim do período não pode ser antes do início.")

    anterior = None
    if (anterior_inicio is None) != (anterior_fim is None):
        raise HTTPException(status_code=422, detail="Informe anterior_inicio e anterior_fim juntos.")
    if anterior_inicio is not None:
        a_inicio, a_fim = _data("anterior_inicio", anterior_inicio), _data("anterior_fim", anterior_fim)
        if a_fim < a_inicio:
            raise HTTPException(status_code=422, detail="O fim do período anterior não pode ser antes do início.")
        anterior = (a_inicio.isoformat(), a_fim.isoformat())

    g_inicio = _data("grafico_inicio", grafico_inicio) if grafico_inicio else None

    mais_antigo = min([d_inicio] + ([date.fromisoformat(anterior[0])] if anterior else []) + ([g_inicio] if g_inicio else []))
    if (d_fim - mais_antigo).days >= MAX_DIAS:
        raise HTTPException(status_code=422, detail=f"O pedido passa de {MAX_DIAS} dias.")

    return periodo(banco, d_inicio.isoformat(), d_fim.isoformat(), anterior,
                   g_inicio.isoformat() if g_inicio else None,
                   administrador=atual["perfil"] == "administrador")
