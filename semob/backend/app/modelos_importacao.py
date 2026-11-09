from typing import Optional

from pydantic import BaseModel


class PeriodoSaida(BaseModel):
    inicio: Optional[str] = None  # "AAAA-MM-DD"
    fim: Optional[str] = None


class ImportacaoSaida(BaseModel):
    """Resultado do envio de um arquivo."""

    id: str
    arquivo: str
    tipo: str  # resumo_geral, fcv, linhas, ...
    periodicidade: Optional[str] = None
    periodo: PeriodoSaida
    status: str  # concluida, duplicada ou rejeitada
    gravados: dict[str, int] = {}
    avisos: list[str] = []
    erros: list[str] = []


class ImportacaoHistorico(ImportacaoSaida):
    """Uma linha do histórico de envios."""

    enviadoEm: str  # data e hora (UTC) em ISO 8601
    enviadoPor: Optional[str] = None  # nome do usuário
