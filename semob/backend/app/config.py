import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
    mongo_banco = os.getenv("MONGO_BANCO", "semob")
    # Sem segredo definido a API recusa gerar tokens (veja seguranca.py)
    jwt_segredo = os.getenv("JWT_SEGREDO", "")
    jwt_horas = int(os.getenv("JWT_HORAS", "8"))
    # Origens permitidas (CORS). O padrão libera só localhost, para o
    # "flutter run -d chrome". Em produção, troque pelo endereço real do app.
    cors_regex = os.getenv("CORS_REGEX", r"http://(localhost|127\.0\.0\.1)(:\d+)?")


config = Config()
