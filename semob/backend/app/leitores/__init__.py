"""Leitura dos relatórios HTML da Smart Data."""
from .base import ErroLeitura, Relatorio
from .conferencias import Conferencia, conferir_relatorios
from .relatorios import ler_relatorio

__all__ = ["ErroLeitura", "Relatorio", "Conferencia", "conferir_relatorios", "ler_relatorio"]
