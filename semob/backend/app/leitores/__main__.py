"""Lê todos os relatórios .html de uma pasta e mostra o que encontrou.

Uso (na pasta da API):
    python -m app.leitores C:\relatorios\agosto

Serve para conferir os arquivos da Smart Data antes de enviar para o sistema.
"""
import os
import sys
import time

from .base import ErroLeitura
from .conferencias import conferir_relatorios
from .relatorios import ler_relatorio


def main() -> int:
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        print("Uso: python -m app.leitores <pasta_com_os_HTML>")
        return 2
    pasta = sys.argv[1]
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # acentos no terminal do Windows
    except Exception:
        pass

    lidos, problemas = [], 0
    for nome in sorted(os.listdir(pasta)):
        if not nome.lower().endswith((".html", ".htm")):
            continue
        inicio = time.time()
        with open(os.path.join(pasta, nome), "rb") as f:
            conteudo = f.read()
        try:
            r = ler_relatorio(nome, conteudo)
        except ErroLeitura as e:
            print(f"[RECUSADO] {nome}: {e}")
            problemas += 1
            continue
        periodo = f"{r.data_inicio:%d/%m/%Y} a {r.data_fim:%d/%m/%Y}" if r.data_inicio else "sem datas"
        print(f"[{'OK' if r.ok else 'ERRO':7}] {nome} -> {r.tipo} ({r.periodicidade or '?'}), "
              f"{periodo}, {r.quantidade} registro(s), {time.time() - inicio:.1f}s")
        for e in r.erros:
            print(f"           erro: {e}")
        for a in r.avisos:
            print(f"           aviso: {a}")
        problemas += 0 if r.ok else 1
        lidos.append(r)

    print("\nConferências entre relatórios:")
    for c in conferir_relatorios(lidos):
        print(f"  [{'OK' if c.ok else 'DIVERGE':7}] {c.nome}\n            {c.detalhe}")
        problemas += 0 if c.ok else 1
    return 1 if problemas else 0


if __name__ == "__main__":
    sys.exit(main())
