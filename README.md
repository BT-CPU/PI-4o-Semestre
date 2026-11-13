# SEMOB — Operação de Transporte

Aplicativo Flutter/Dart para acompanhar os indicadores da operação de transporte
de São Caetano do Sul, com API Python/FastAPI e MongoDB.

## Executar

Abra a pasta `semob` no VS Code. Instale as dependências e execute:

```sh
cd semob
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

O login é validado exclusivamente pela API. Não há conta ou senha fixas no
aplicativo. Inicie a API e cadastre seu administrador conforme o [guia de instalação](semob/README.md).

## Interface

- Login responsivo e identidade institucional compartilhada.
- Menu recolhível e configurações de zoom, letras, modo escuro e tela cheia.
- Administração e envio de arquivos acessíveis conforme o perfil do usuário.
- Fundos próprios para os temas claro/escuro, VLibras na versão web e notificações fecháveis.
- Cópia de indicadores e tooltips com marcadores dos pontos observados nos gráficos.

Os painéis ainda usam os dados de exemplo de agosto/2026 existentes no projeto;
a importação não atualiza esses indicadores nesta versão.

## Verificar

```sh
cd semob
flutter test
flutter analyze --no-fatal-infos
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
```
