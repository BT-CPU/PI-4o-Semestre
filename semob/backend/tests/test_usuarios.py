from tests.conftest import NOVO, cabecalho


def test_login_certo_devolve_token_e_perfil(client, admin):
    resp = client.post("/login", json={"usuario": "ADMIN", "senha": "admin123"})
    assert resp.status_code == 200
    corpo = resp.json()
    assert corpo["token"]
    assert corpo["usuario"]["perfil"] == "administrador"
    # nunca devolve senha nem hash
    assert "senha" not in corpo["usuario"]
    assert "senhaHash" not in corpo["usuario"]


def test_login_errado_devolve_401_com_a_mesma_mensagem(client, admin):
    senha_errada = client.post("/login", json={"usuario": "admin", "senha": "x"})
    sem_usuario = client.post("/login", json={"usuario": "ninguem", "senha": "x"})
    assert senha_errada.status_code == sem_usuario.status_code == 401
    assert senha_errada.json() == sem_usuario.json()


def test_sem_token_ou_token_falso_devolve_401(client, admin):
    assert client.get("/usuarios").status_code == 401
    falso = {"Authorization": "Bearer lixo"}
    assert client.get("/usuarios", headers=falso).status_code == 401


def test_funcionario_nao_acessa_rotas_de_administrador(client, admin, func):
    h = cabecalho(client, "func", "123456")
    assert client.get("/usuarios/eu", headers=h).status_code == 200
    assert client.get("/usuarios", headers=h).status_code == 403
    assert client.post("/usuarios", json=NOVO, headers=h).status_code == 403
    assert client.delete("/usuarios/abc", headers=h).status_code == 403


def test_admin_cria_e_lista(client, admin):
    h = cabecalho(client, "admin", "admin123")
    resp = client.post("/usuarios", json=NOVO, headers=h)
    assert resp.status_code == 201
    assert "senha" not in resp.json()
    nomes = [u["usuario"] for u in client.get("/usuarios", headers=h).json()]
    assert sorted(nomes) == ["admin", "maria"]
    # o novo usuário consegue entrar
    assert client.post("/login", json={"usuario": "maria", "senha": "maria123"}).status_code == 200


def test_login_repetido_ignora_maiusculas(client, admin):
    h = cabecalho(client, "admin", "admin123")
    resp = client.post("/usuarios", json={**NOVO, "usuario": "ADMIN"}, headers=h)
    assert resp.status_code == 409
    assert "login" in resp.json()["detail"]


def test_validacoes_de_entrada(client, admin):
    h = cabecalho(client, "admin", "admin123")
    assert client.post("/usuarios", json={**NOVO, "senha": "123"}, headers=h).status_code == 422
    assert client.post("/usuarios", json={**NOVO, "usuario": "a b"}, headers=h).status_code == 422
    assert client.post("/usuarios", json={**NOVO, "email": "sem-arroba"}, headers=h).status_code == 422
    assert client.post("/usuarios", json={**NOVO, "perfil": "root"}, headers=h).status_code == 422


def test_atualizar_sem_senha_mantem_a_senha(client, admin, func, usuarios):
    h = cabecalho(client, "admin", "admin123")
    alvo = str(usuarios.find_one({"usuario": "func"})["_id"])
    corpo = {"nome": "Novo Nome", "usuario": "func", "email": "f@x.com", "perfil": "funcionario"}
    assert client.put(f"/usuarios/{alvo}", json=corpo, headers=h).status_code == 200
    assert client.post("/login", json={"usuario": "func", "senha": "123456"}).status_code == 200


def test_atualizar_com_senha_troca_a_senha(client, admin, func, usuarios):
    h = cabecalho(client, "admin", "admin123")
    alvo = str(usuarios.find_one({"usuario": "func"})["_id"])
    corpo = {"nome": "F", "usuario": "func", "email": "f@x.com", "perfil": "funcionario", "senha": "nova1234"}
    assert client.put(f"/usuarios/{alvo}", json=corpo, headers=h).status_code == 200
    assert client.post("/login", json={"usuario": "func", "senha": "123456"}).status_code == 401
    assert client.post("/login", json={"usuario": "func", "senha": "nova1234"}).status_code == 200


def test_nao_rebaixa_o_unico_administrador(client, admin, usuarios):
    h = cabecalho(client, "admin", "admin123")
    meu_id = str(usuarios.find_one({"usuario": "admin"})["_id"])
    corpo = {"nome": "A", "usuario": "admin", "email": "a@x.com", "perfil": "funcionario"}
    resp = client.put(f"/usuarios/{meu_id}", json=corpo, headers=h)
    assert resp.status_code == 409


def test_nao_exclui_a_si_mesmo(client, admin, usuarios):
    h = cabecalho(client, "admin", "admin123")
    meu_id = str(usuarios.find_one({"usuario": "admin"})["_id"])
    assert client.delete(f"/usuarios/{meu_id}", headers=h).status_code == 400


def test_excluido_perde_o_acesso_na_hora(client, admin, func, usuarios):
    h_admin = cabecalho(client, "admin", "admin123")
    h_func = cabecalho(client, "func", "123456")
    alvo = str(usuarios.find_one({"usuario": "func"})["_id"])
    assert client.delete(f"/usuarios/{alvo}", headers=h_admin).status_code == 204
    assert client.get("/usuarios/eu", headers=h_func).status_code == 401


def test_id_invalido_ou_inexistente_devolve_404(client, admin):
    h = cabecalho(client, "admin", "admin123")
    assert client.delete("/usuarios/nao-e-um-id", headers=h).status_code == 404
    assert client.delete("/usuarios/507f1f77bcf86cd799439011", headers=h).status_code == 404
