# Problemas comuns

Erros que o time já encontrou, com a causa e a correção. Achou um novo? Adicione aqui no mesmo PR da correção.

## Windows e PowerShell

| Sintoma | Causa | O que fazer |
|---|---|---|
| `O token '&&' não é um separador de instruções válido` | PowerShell 5.1 não tem `&&` | Um comando por linha, ou separe com `;` |
| Acentos aparecem como `Ã©`, `Ã§` no terminal | O console do PowerShell não usa UTF-8 | É só exibição: os dados na API e no banco estão certos. Para ver certo: `[Console]::OutputEncoding = [Text.Encoding]::UTF8` |
| `flutter analyze` trava ou falha sem motivo claro | Caminho do projeto com acento (ex.: `Área de Trabalho`) | `flutter test` e `flutter run` funcionam normalmente. Para o analyze, rode numa cópia do `app/` em pasta sem acento; o CI não tem esse problema |
| `flutter` não é reconhecido no terminal do VS Code | O PATH foi alterado depois de abrir o VS Code | Feche e abra o VS Code inteiro (não só o terminal) |
| Script Python reclama de `UnicodeEncodeError` ao imprimir ✅/❌ | Console em cp1252 | `[Console]::OutputEncoding = [Text.Encoding]::UTF8`, ou rode no Git Bash |
| Arquivo JSON salvo pelo PowerShell dá `Unexpected UTF-8 BOM` | `Set-Content -Encoding utf8` grava BOM no PowerShell 5.1 | Leia com `utf-8-sig` no Python, ou salve pelo editor |

## Docker

| Sintoma | Causa | O que fazer |
|---|---|---|
| `error during connect` / `cannot find the file specified` (pipe do Docker) | Docker Desktop fechado | Abra o Docker Desktop e espere ficar "Running" |
| `port is already allocated` (5432, 8000 ou 8080) | Outro Postgres/serviço usando a porta | Pare o outro serviço, ou mude a porta do lado esquerdo em `infra/docker/docker-compose.yml` (ex.: `"5433:5432"`) |
| API sobe mas `/health` dá erro de banco | O Postgres ainda está iniciando | Espere alguns segundos; o compose já aguarda o healthcheck do `db` |
| Rota responde 500 com `relation "..." does not exist` | Migrations não aplicadas | `docker compose run --rm api alembic upgrade head` |
| Seletor de exercício vazio no app | Seed não rodado | `docker compose run --rm api python -m app.infra.db.seed` |
| Testes do backend tentam conectar no Postgres | Faltou `-e ENV=testing -e DATABASE_URL=sqlite:///:memory:` | Use o comando completo de [`subir-ambiente.md`](subir-ambiente.md#3-testes-mesma-bateria-do-ci) |

## App ↔ API

| Sintoma | Causa | O que fazer |
|---|---|---|
| App mostra "Não foi possível conectar ao servidor" | API fora do ar, ou `API_URL` errada | Confira http://localhost:8000/health; se a API estiver em outra máquina, use `--dart-define=API_URL=...` |
| No Chrome, chamada bloqueada por **CORS** | A origem do app não bate com `CORS_ORIGIN_REGEX` (padrão: só `localhost`/`127.0.0.1`) | Abrindo o app por IP da rede (ex.: celular na demo), defina `CORS_ORIGIN_REGEX` no serviço `api` do compose incluindo essa origem |
| "Sua sessão expirou. Entre novamente." | O refresh token venceu ou o `JWT_SECRET` mudou | Entre de novo. Trocar o `JWT_SECRET` invalida todas as sessões |
| RPE `0` recusado ao salvar | O app aceita 0, a API exige de 1 a 10 | Use 1 a 10 ou deixe vazio (desalinhamento conhecido do front) |
| Histórico mostra só os 50 treinos mais recentes | O app ainda não pagina (a API pagina) | Limitação conhecida do front |

## Git e CI

| Sintoma | Causa | O que fazer |
|---|---|---|
| Check **Conventional Commits** vermelho | Mensagem de commit fora do padrão (`foo`, `update x`) | Último commit: `git commit --amend -m "tipo: descricao"` + `git push --force-with-lease`. Commits anteriores: `git rebase -i main` → `reword` |
| Check **Gitleaks** vermelho | Algo parecido com segredo no PR | Veja "Segurança: segredos no repositório" no [`README.md`](../../README.md) |
| Merge bloqueado com "Review required" | Branch protection: precisa de 1 aprovação de outra pessoa | Peça revisão; o autor não aprova o próprio PR |
| Merge bloqueado com "branch is out-of-date" | A `main` andou depois do PR | Botão **Update branch** no PR e espere o CI rodar de novo |
| `git push origin main` recusado (`protected branch hook declined`) | Push direto na `main` é proibido | Crie uma branch e abra um PR |
