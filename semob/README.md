# SEMOB — Operação de Transporte

Aplicativo Flutter/Dart para acompanhar a operação de transporte de São Caetano do Sul. A API Python/FastAPI original foi preservada.

## Executar o aplicativo

Instale um Flutter estável que inclua Dart 3.13.5 ou superior. A validação desta entrega utilizou Flutter 3.50.0 / Dart 3.14.0.

```sh
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

Para Windows, com o suporte de desktop do Flutter instalado:

```sh
flutter run -d windows --dart-define=API_URL=http://localhost:8000
```

Para emulador Android, use `http://10.0.2.2:8000` como API_URL. Em um aparelho físico, informe o endereço de rede do computador que executa a API. API_URL é uma configuração de compilação; recompile após alterá-la.

## Autenticação

O login consulta exclusivamente a API em todos os modos de execução.
Não há usuário, senha ou desvio de autenticação fixos no aplicativo.
Inicie a API e o MongoDB e cadastre o administrador conforme as instruções abaixo.
Se a API estiver indisponível, o aplicativo informa o erro e não permite a entrada.
Os testes automatizados usam respostas HTTP simuladas apenas dentro de `test/`.

## Preparar a API original

É necessário Python 3.10+ e MongoDB em execução. Na pasta `backend`:

```sh
python -m venv .venv
```

Ative o ambiente no Windows com `.venv\Scripts\activate` ou no Linux/macOS com `source .venv/bin/activate`. Depois:

```sh
pip install -r requirements.txt
```

Copie `.env.example` para `.env`. Configure `MONGO_URI`, `MONGO_BANCO` e um `JWT_SEGREDO` próprio. Para gerar o segredo:

```sh
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Crie o administrador, escolhendo seu usuário e senha:

```sh
python -m app.criar_admin
uvicorn app.main:app --reload
```

A instalação não cria contas automaticamente. Execute `python -m app.criar_admin` para cadastrar seu administrador e escolher sua senha.

## Identidade visual

- Azul-escuro `#1D5399`, azul-médio `#1B72C1` e turquesa `#43B9C7` preservados.
- Brasão original preservado; assinatura textual institucional ao lado.
- Fundo original inspirado em papéis de parede do Windows, em `assets/images/fundo_institucional.png`, sem marcas da Microsoft.
- Painéis brancos sobre fundo neutro, bordas discretas e tipografia Inter armazenada no aplicativo.
- Menu fixo a partir de 1120 pixels; gaveta em telas menores.
- Botões com transições de cor de 150 ms ao passar o mouse, focar e pressionar. A preferência de movimento reduzido do sistema desativa a duração dessas transições.

O fundo é usado na tela de acesso. As telas com gráficos usam fundo neutro para priorizar a leitura. Os indicadores continuam usando os dados de exemplo existentes de agosto/2026, com aviso visível. A integração entre importação e indicadores não foi alterada.

## Verificar e compilar

```sh
flutter test
flutter analyze --no-fatal-infos
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define=API_URL=http://localhost:8000
```

Para servir o pacote web localmente, entre em `build/web` e execute `python -m http.server 8080`. A API deve continuar em execução. Para hospedagem remota, compile com a URL HTTPS real da API e configure o CORS da API para a origem do aplicativo. Não abra `index.html` diretamente por `file://`.

Os arquivos Inter e Roboto possuem licença SIL Open Font License, incluída em `assets/fonts`.

## Interface e acessibilidade

Login em cartão central, fundo vetorial azul/prateado e menu lateral recolhível.
A engrenagem no canto superior direito reúne zoom (80–130%), letras (85–130%),
modo escuro e tela cheia. As preferências são mantidas durante a sessão e entre
as telas; o zoom ajusta também a largura útil e a navegação responsiva.
O botão Admin aparece apenas para administradores e abre Administração de
Usuários ou Enviar Arquivo. Sair fica ao lado da engrenagem.

Avisos de dados de exemplo e de dados provisórios abrem pop-ups com Fechar.
Mensagens de sucesso/erro são flutuantes e têm botão de fechar.
Os cartões possuem Copiar informações; gráficos incluem valores das séries,
identificados pela posição no eixo X, além dos textos do painel.

O VLibras usa o script oficial em `web/index.html`, com a árvore semântica web
habilitada em `main.dart`. Requer internet para carregar o serviço e os avatares.
Integração conforme https://vlibras.gov.br/doc/widget/installation/webpageintegration.html.
O widget VLibras pertence à versão web; não é um plugin Flutter para Windows.
Tela cheia funciona no navegador com Fullscreen API e no Windows pelo canal
`semob/janela`; Esc restaura a janela. Android/iOS usam modo imersivo.

Reinicie a execução após atualizar os arquivos web/nativos. O login utiliza exclusivamente a API.

## Ajustes de interface — símbolo, tabelas e navegação

Os fundos ativos estão em `assets/images/fundo_institucional_claro.png` e `assets/images/fundo_institucional_escuro.png`.
O símbolo do login tem 128 pixels de altura sobre uma área branca e sem a legenda SEMOB.
O usuário conectado aparece antes da engrenagem na barra superior.
Os cabeçalhos e as linhas de totais das tabelas acompanham o tema claro/escuro.
Tooltips de gráficos de linhas e barras usam a sobreposição raiz, acima dos cartões,
com posicionamento limitado à janela, incluindo quando o zoom está ativo.
A seta e o voltar do sistema em Administração de Usuários/Envio de arquivos
retornam diretamente à Visão Geral com o menu. O login utiliza exclusivamente a API.

## Fundos institucionais e indicação de pontos

As versões clara e escura têm a mesma composição simples, com centro livre e
um detalhe azul na borda inferior. Foram geradas pela ferramenta integrada de
imagens, em 1672 × 941 pixels (aproximadamente 16:9), e são escolhidas pelo tema.
A imagem mantém sua proporção, ajusta-se à largura e fica alinhada à borda
inferior; o campo liso completa telas mais altas sem distorção ou recorte do detalhe.

Nos gráficos de linhas, um círculo destaca o ponto observado em cada série,
usando a posição real do dado. Nas barras, o marcador indica a extremidade da
barra selecionada. Os marcadores acompanham a seleção e somem ao sair do gráfico;
o tooltip continua acima dos cartões. A autenticação depende da API.
