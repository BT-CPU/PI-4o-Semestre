"""Cria o primeiro administrador. Uso: python -m app.criar_admin

Só roda se ainda não existir nenhum administrador no banco.
"""
import getpass
from datetime import datetime, timezone

from pydantic import ValidationError

from .db import garantir_indices, obter_banco
from .modelos import UsuarioEntrada
from .seguranca import gerar_hash


def main() -> None:
    banco = obter_banco()
    garantir_indices(banco)

    if banco.usuarios.count_documents({"perfil": "administrador"}) > 0:
        print("Já existe um administrador. Nada a fazer.")
        return

    usuario = input("Login do administrador [admin]: ").strip() or "admin"
    nome = input("Nome [Administrador do Sistema]: ").strip() or "Administrador do Sistema"
    email = input("E-mail [admin@semob.local]: ").strip() or "admin@semob.local"
    senha = getpass.getpass("Senha (mínimo 6 caracteres): ")
    if senha != getpass.getpass("Repita a senha: "):
        print("As senhas não conferem.")
        return

    try:
        dados = UsuarioEntrada(
            nome=nome, usuario=usuario, email=email, senha=senha, perfil="administrador"
        )
    except ValidationError as erro:
        print("Dados inválidos:")
        for e in erro.errors():
            print(f"  - {e['loc'][0]}: {e['msg']}")
        return

    banco.usuarios.insert_one(
        {
            "nome": dados.nome,
            "usuario": dados.usuario,
            "usuarioNormalizado": dados.usuario.lower(),
            "email": dados.email,
            "senhaHash": gerar_hash(dados.senha),
            "perfil": "administrador",
            "criadoEm": datetime.now(timezone.utc),
        }
    )
    print(f"Administrador '{dados.usuario}' criado.")


if __name__ == "__main__":
    main()
