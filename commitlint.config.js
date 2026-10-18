// Conventional Commits no OpenLift (OPS-02). Usado pelo workflow
// .github/workflows/commitlint.yml em todo PR.
//
// Formato: <tipo>(escopo opcional): descrição
//   feat(api): expõe /api/v1/workouts
//   fix: corrige refresh do token
//
// Commits de merge ("Merge pull request #N ...") são ignorados por padrão.

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // O time escreve a descrição em português, com ou sem maiúscula e com
    // siglas (API, JWT, NOSTR): não restringir o "case" do assunto.
    'subject-case': [0],
    // Mensagens geradas com corpo longo (ex.: listas, links) não devem falhar.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
