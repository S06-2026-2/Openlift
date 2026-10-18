# Exemplo — revisar-pr

> PR **fictício**, criado só para mostrar o formato. Os números de PR e issue não existem.

## Revisão — PR #99 (issue #98, BE-05 — `POST /me/nostr-identity`)

**Resumo:** adiciona a rota que registra o `npub` do usuário logado. Cumpre o caminho feliz da issue, mas aceita um campo que nunca pode chegar ao backend.

### Bloqueia o merge

- `api/app/domain/schemas/auth.py:61` — `NostrIdentityIn` tem `nsec: str | None`. Mesmo opcional, isso abre a porta para a chave privada trafegar até o servidor e cair em log de requisição: quebra a regra inviolável 1 do `AGENTS.md` (RNF-01, ADR-0006). Sugestão: remover o campo e configurar `model_config = ConfigDict(extra="forbid")`, para que qualquer campo extra resulte em 422.
- `api/tests/test_nostr_identity.py` — falta o teste do critério "enviar chave privada é recusado (422)" de `docs/qa/sprint-2.md` (S2-02).

### Sugestões (não bloqueiam)

- `api/app/services/auth_service.py:140` — o erro de `npub` malformado usa `code="bad_npub"`; os outros códigos do projeto são descritivos (`invalid_npub` seguiria o padrão de `invalid_token`).
- `api/README.md` — a tabela de rotas ainda não lista `POST /me/nostr-identity`.

### Conferido

- [x] Escopo da issue (só a rota, sem mexer no app)
- [ ] Regras invioláveis — campo `nsec` no schema
- [x] ADRs (0004, 0005, 0006)
- [x] Isolamento por usuário (`current_user.id`)
- [ ] Testes cobrem os critérios de aceite — falta o caso da chave privada
- [x] Lint e CI verdes
- [x] Uso de IA declarado (ferramenta, o que gerou e o que foi revisado)
