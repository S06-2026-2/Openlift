# Contribuindo com o OpenLift

Regras completas, incluindo a Definition of Done, em [`CLAUDE.md`](CLAUDE.md) e [`AGENTS.md`](AGENTS.md). Valem para humanos e agentes de IA. Para subir o ambiente local, veja [`docs/runbook/subir-ambiente.md`](docs/runbook/subir-ambiente.md).

## O essencial

- **Toda tarefa nasce de uma issue.** Uma issue, uma branch, um PR (`feat/…`, `fix/…`, `docs/…`, `chore/…`).
- Commits em [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix(api):`, `docs:` …). O CI recusa mensagem fora do padrão.
- Merge em `main` só via PR com **ao menos 1 aprovação**. O PR referencia a issue (`Closes #N`) e declara o uso de IA.
- ADRs em [`docs/adr/`](docs/adr/) não se reabrem sem discussão no grupo.

## Testes

```bash
# Backend: mesma bateria do CI (de dentro de infra/docker)
docker compose run --rm --no-deps -e ENV=testing -e DATABASE_URL=sqlite:///:memory: api \
  sh -c "ruff check . && black --check . && mypy . && pytest --cov=app"

# App
cd app
flutter analyze
flutter test
```

Rotas, testes de integração e migrations do backend: [`api/README.md`](api/README.md).

## Hooks locais

O backend tem hooks de `ruff` e `black` que barram commit mal formatado antes do CI. Instale uma vez por clone, na raiz do repositório:

```bash
pip install pre-commit
pre-commit install --config api/.pre-commit-config.yaml
```

Se um hook corrigir algum arquivo, o commit é interrompido: confira a mudança, faça `git add` e repita o commit.

## Segredos

O CI roda o **gitleaks** em todo PR e fica vermelho se achar chave, token ou senha. Ele protege o RNF-01: a chave privada (`nsec`) nunca entra no repositório. Para rodar antes de abrir o PR: `gitleaks git --config .gitleaks.toml --redact .`

Se ele apontar algo:

1. **Segredo real:** não libere. Considere-o vazado mesmo que o commit seja desfeito: troque-o na origem, remova do código, leia de variável de ambiente (`api/.env`, fora do git) e avise o grupo.
2. **Falso positivo:** use o menor escopo possível — `# gitleaks:allow` no fim da linha, uma regex comentada em `regexes` no [`.gitleaks.toml`](.gitleaks.toml), ou o caminho em `paths` (só para arquivos de exemplo, como `api/.env.example`). Explique a liberação na descrição do PR.

## Deploy e releases

- **Web e API:** todo push na `main` publica no staging do Railway (`frontend-cd.yml`, `backend-cd.yml`). Produção é por execução manual dessas actions, escolhendo `production`.
- **APK:** uma tag `v*` gera o APK e cria a Release no GitHub (`release-apk.yml`):

  ```bash
  git tag v0.4.0
  git push origin v0.4.0
  ```

  O APK aponta para a API de produção (variável `APK_API_URL` do repositório, se definida). Os secrets da chave de assinatura estão descritos no topo do workflow.
