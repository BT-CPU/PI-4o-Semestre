from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Perfil = Literal["administrador", "funcionario"]

_PADRAO_EMAIL = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"


class LoginEntrada(BaseModel):
    usuario: str
    senha: str


class UsuarioEntrada(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    nome: str = Field(min_length=1, max_length=120)
    usuario: str = Field(min_length=3, max_length=40, pattern=r"^\S+$")
    email: str = Field(max_length=200, pattern=_PADRAO_EMAIL)
    senha: str = Field(min_length=6, max_length=128)
    perfil: Perfil


class UsuarioAtualizacao(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    nome: str = Field(min_length=1, max_length=120)
    usuario: str = Field(min_length=3, max_length=40, pattern=r"^\S+$")
    email: str = Field(max_length=200, pattern=_PADRAO_EMAIL)
    # Em branco (None) = manter a senha atual
    senha: Optional[str] = Field(default=None, min_length=6, max_length=128)
    perfil: Perfil


class UsuarioSaida(BaseModel):
    id: str
    nome: str
    usuario: str
    email: str
    perfil: Perfil


class LoginSaida(BaseModel):
    token: str
    usuario: UsuarioSaida
