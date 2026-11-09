import os

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse

from ..db import obter_banco
from ..dependencias import usuario_atual
from ..importador import importar
from ..leitores import ErroLeitura, ler_relatorio
from ..modelos_importacao import ImportacaoHistorico, ImportacaoSaida

router = APIRouter(prefix="/importacoes", tags=["importações"])

# O maior relatório (Mensal_Viagens) tem uns 13 MB.
TAMANHO_MAXIMO = 25 * 1024 * 1024


def _nome_seguro(nome: str | None) -> str:
    # Só o nome do arquivo, sem pasta, e com tamanho limitado
    return os.path.basename((nome or "").replace("\\", "/"))[:200]


# "def" (e não "async def") de propósito: ler e gravar um relatório grande leva
# alguns segundos, e o FastAPI roda funções "def" fora do laço principal, para
# não travar as outras requisições.
@router.post("", response_model=ImportacaoSaida)
def enviar(
    arquivo: UploadFile = File(...),
    forcar: bool = Query(False, description="Regrava mesmo que este arquivo já tenha sido enviado."),
    atual: dict = Depends(usuario_atual),  # funcionário ou administrador
    banco=Depends(obter_banco),
):
    nome = _nome_seguro(arquivo.filename)
    if not nome.lower().endswith((".html", ".htm")):
        raise HTTPException(status_code=400, detail="Envie um relatório da Smart Data em HTML (.html).")

    conteudo = arquivo.file.read(TAMANHO_MAXIMO + 1)
    if len(conteudo) > TAMANHO_MAXIMO:
        raise HTTPException(
            status_code=413, detail=f"O arquivo passa do tamanho máximo de {TAMANHO_MAXIMO // (1024 * 1024)} MB."
        )

    try:
        relatorio = ler_relatorio(nome, conteudo)
    except ErroLeitura as erro:
        raise HTTPException(status_code=422, detail=str(erro))

    try:
        resultado = importar(banco, relatorio, conteudo, enviado_por=atual["_id"], forcar=forcar)
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível gravar os dados no banco. O envio foi registrado com erro: tente de novo.",
        )

    if resultado["status"] == "rejeitada":
        erros = resultado["erros"]
        resumo = " ".join(erros[:3]) + (f" (e mais {len(erros) - 3})" if len(erros) > 3 else "")
        return JSONResponse(
            status_code=422,
            content={"detail": f"Arquivo recusado, com {len(erros)} erro(s): {resumo}", "resultado": resultado},
        )
    return resultado


@router.get("", response_model=list[ImportacaoHistorico])
def historico(
    limite: int = Query(50, ge=1, le=200),
    _: dict = Depends(usuario_atual),
    banco=Depends(obter_banco),
):
    """Últimos arquivos enviados, do mais novo para o mais antigo."""
    docs = list(banco.importacoes.find().sort("enviadoEm", -1).limit(limite))
    ids = {d["enviadoPor"] for d in docs if d.get("enviadoPor")}
    nomes = {u["_id"]: u["nome"] for u in banco.usuarios.find({"_id": {"$in": list(ids)}})}
    return [
        ImportacaoHistorico(
            id=str(d["_id"]),
            arquivo=d["nomeArquivo"],
            tipo=d["tipoRelatorio"],
            periodicidade=d.get("periodicidade"),
            periodo=d.get("periodo") or {},
            status=d["status"],
            gravados=d.get("gravados", {}),
            avisos=d.get("avisos", []),
            erros=d.get("erros", []),
            enviadoEm=d["enviadoEm"].isoformat(),
            enviadoPor=nomes.get(d.get("enviadoPor")),
        )
        for d in docs
    ]
