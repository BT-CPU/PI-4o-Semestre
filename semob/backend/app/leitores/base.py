"""Peças básicas para ler os relatórios HTML da Smart Data.

Usa só a biblioteca padrão do Python (nenhum pacote extra).

Como é um arquivo da Smart Data:
- Vários documentos HTML colados um no outro. O 1º é só o cabeçalho
  ("Gerado por Smart Report", com a data e a hora). Os seguintes têm um <h1>
  com o título e uma tabela de dados (<table class='data'>).
- Os <th> do cabeçalho podem ficar soltos, fora de um <tr>.
- Codificação Cp1252 (acentos do Windows).
- Números no padrão brasileiro: 6889,4 ou 1.050.248.
"""
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from html.parser import HTMLParser


class ErroLeitura(Exception):
    """O arquivo não é (ou não parece ser) um relatório que a gente entende."""


# ---------------------------------------------------------------
# Texto e números
# ---------------------------------------------------------------
def decodificar(conteudo: bytes) -> str:
    """Os relatórios declaram Cp1252. Se o arquivo foi regravado em UTF-8
    (acentos válidos nessa codificação), aceita também."""
    try:
        return conteudo.decode("utf-8")
    except UnicodeDecodeError:
        return conteudo.decode("cp1252", errors="replace")


def limpar(texto: str) -> str:
    return re.sub(r"\s+", " ", texto.replace("\xa0", " ")).strip()


def num_br(texto: str) -> float:
    """'6889,4' -> 6889.4   |   '1.050.248' -> 1050248.0   |   '' -> erro"""
    t = limpar(texto)
    if not re.fullmatch(r"-?[\d.]*\d(,\d+)?", t):
        raise ValueError(f"número inválido: {texto!r}")
    return float(t.replace(".", "").replace(",", "."))


def int_br(texto: str) -> int:
    valor = num_br(texto)
    if valor != int(valor):
        raise ValueError(f"esperava número inteiro: {texto!r}")
    return int(valor)


def data_br(texto: str) -> date:
    """'01/08/2026' -> date(2026, 8, 1)"""
    try:
        return datetime.strptime(limpar(texto), "%d/%m/%Y").date()
    except ValueError:
        raise ValueError(f"data inválida: {texto!r}") from None


def data_mes_dia(mes: str, dia: str) -> date:
    """Passageiros e Saldos: mês '2026-08' e dia '01'."""
    try:
        return datetime.strptime(f"{limpar(mes)}-{limpar(dia)}", "%Y-%m-%d").date()
    except ValueError:
        raise ValueError(f"data inválida: mês {mes!r}, dia {dia!r}") from None


def data_hora(texto: str) -> datetime | None:
    """'2026-08-02 14:35:00' -> datetime. Vazio -> None (viagem sem registro)."""
    t = limpar(texto)
    if not t:
        return None
    try:
        return datetime.strptime(t, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        raise ValueError(f"data e hora inválidas: {texto!r}") from None


def faixa_hora(texto: str) -> int:
    """'4hs' -> 4   |   '23hs' -> 23   |   '4' -> 4"""
    m = re.fullmatch(r"(\d{1,2})(hs)?", limpar(texto))
    if not m or int(m.group(1)) > 23:
        raise ValueError(f"faixa horária inválida: {texto!r}")
    return int(m.group(1))


# ---------------------------------------------------------------
# Tabelas HTML
# ---------------------------------------------------------------
class _LeitorTabelas(HTMLParser):
    """Junta, para cada <table>, o cabeçalho (th) e as linhas de dados (td)."""

    def __init__(self):
        super().__init__(convert_charrefs=True)  # &gt; vira >, &nbsp; vira espaço
        self.tabelas: list[dict] = []
        self._tabela = None
        self._linha = None  # lista de (tag, texto) da linha aberta
        self._celula = None  # pedaços de texto da célula aberta

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self._tabela = {
                "classe": dict(attrs).get("class") or "",
                "cabecalho": [],
                "linhas": [],
            }
            self.tabelas.append(self._tabela)
        elif self._tabela is None:
            return
        elif tag == "tr":
            self._linha = []
        elif tag in ("td", "th"):
            self._celula = []
        elif tag == "br" and self._celula is not None:
            self._celula.append(" ")

    def handle_data(self, dados):
        if self._celula is not None:
            self._celula.append(dados)

    def handle_endtag(self, tag):
        if self._tabela is None:
            return
        if tag in ("td", "th") and self._celula is not None:
            texto = limpar("".join(self._celula))
            self._celula = None
            if self._linha is not None:
                self._linha.append((tag, texto))
            elif tag == "th":  # <th> solto (fora de <tr>)
                self._tabela["cabecalho"].append(texto)
        elif tag == "tr" and self._linha is not None:
            tds = [t for g, t in self._linha if g == "td"]
            ths = [t for g, t in self._linha if g == "th"]
            if tds:
                self._tabela["linhas"].append(tds)
            elif ths and not self._tabela["cabecalho"]:
                self._tabela["cabecalho"] = ths
            self._linha = None
        elif tag == "table":
            self._tabela = None


@dataclass
class Documento:
    titulo: str  # texto do <h1>
    cabecalho: list[str]
    linhas: list[list[str]]


def separar_documentos(texto: str) -> tuple[datetime | None, list[Documento]]:
    """Devolve (quando a Smart Data gerou o relatório, documentos com <h1>)."""
    partes = re.split(r"<!DOCTYPE HTML[^>]*>", texto, flags=re.I)[1:]
    if not partes:
        raise ErroLeitura("O arquivo não tem estrutura HTML de relatório.")

    gerado_em = None
    m = re.search(r"(\d{2}/\d{2}/\d{4} \d{2}:\d{2})", partes[0])
    if m:  # Passageiros/Saldos trazem só "04-Set 08:01": ficam sem data
        gerado_em = datetime.strptime(m.group(1), "%d/%m/%Y %H:%M")

    documentos = []
    for parte in partes:
        h1 = re.search(r"<h1>(.*?)</h1>", parte, re.S | re.I)
        if not h1:
            continue
        leitor = _LeitorTabelas()
        leitor.feed(parte)
        dados = [t for t in leitor.tabelas if t["classe"] == "data"]
        if not dados:
            continue
        documentos.append(Documento(limpar(h1.group(1)), dados[0]["cabecalho"], dados[0]["linhas"]))
    return gerado_em, documentos


# ---------------------------------------------------------------
# Resultado da leitura
# ---------------------------------------------------------------
@dataclass
class Relatorio:
    tipo: str  # resumo_geral, fcv, linhas, fxhr, resumo_fxhr, viagens, ...
    nome_arquivo: str
    periodicidade: str | None  # Mensal, Quinzenal, Semanal (None se não der para saber)
    gerado_em: datetime | None
    data_inicio: date | None = None
    data_fim: date | None = None
    # Registros lidos, por nome. Ex.: {"dias": [...]} ou {"linhas_dia": [...]}
    tabelas: dict[str, list[dict]] = field(default_factory=dict)
    # Linha de total que vem no próprio relatório
    totais: dict = field(default_factory=dict)
    # erros: o arquivo NÃO deve ser gravado. avisos: gravar, mas mostrar.
    erros: list[str] = field(default_factory=list)
    avisos: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.erros

    @property
    def quantidade(self) -> int:
        return sum(len(v) for v in self.tabelas.values())


class Coletor:
    """Guarda as mensagens de erro de um relatório (no máximo 15 por tipo,
    para um arquivo todo quebrado não gerar milhares de linhas)."""

    LIMITE = 15

    def __init__(self, relatorio: Relatorio):
        self.r = relatorio
        self._cortados = 0

    def erro(self, mensagem: str):
        if len(self.r.erros) < self.LIMITE:
            self.r.erros.append(mensagem)
        else:
            self._cortados += 1
            if self._cortados == 1:
                self.r.erros.append("... e mais erros parecidos (lista cortada).")

    def aviso(self, mensagem: str):
        if len(self.r.avisos) < self.LIMITE:
            self.r.avisos.append(mensagem)
