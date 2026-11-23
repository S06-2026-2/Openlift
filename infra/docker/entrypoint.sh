#!/bin/sh
# Entrypoint da imagem da API (OPS-07, RNF-10).
#
# Antes do comando do container (uvicorn ou o worker), aplica as migrations e
# o seed idempotente da biblioteca de exercícios, para que `docker compose up`
# (e o deploy no Railway) deixe o app usável sem nenhum comando manual.
#
# RUN_MIGRATIONS=false pula esse passo. O serviço `worker` usa isso: ele sobe
# depois da API (que já migrou) e não deve disputar o `alembic upgrade`.
set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "openlift-entrypoint: aplicando migrations (alembic upgrade head)"
  alembic upgrade head
  echo "openlift-entrypoint: seed da biblioteca de exercícios"
  python -m app.infra.db.seed
fi

exec "$@"
