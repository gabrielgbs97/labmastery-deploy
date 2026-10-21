#!/bin/bash
# LabMastery — verificación posterior al despliegue.
#
# Comprueba lo que §9 de 08-despliegue.md exige antes de dar por bueno un
# despliegue. Sale con código 1 si algo falla.
set -uo pipefail

STACK="${STACK_NAME:-labmastery}"
fail=0
ok()   { printf '  OK    %s\n' "$1"; }
bad()  { printf '  FALLO %s\n' "$1"; fail=1; }
step() { printf '\n== %s\n' "$1"; }

step "1. Servicios y su estado de salud"
if command -v docker >/dev/null 2>&1; then
  docker compose ps --format 'table {{.Service}}\t{{.Status}}' 2>/dev/null || docker compose ps
  unhealthy=$(docker compose ps --format '{{.Service}} {{.Status}}' 2>/dev/null \
    | grep -Ei 'unhealthy|starting|exited' | awk '{print $1}')
  if [[ -n "$unhealthy" ]]; then
    bad "servicios no sanos: $unhealthy"
  else
    ok "todos los servicios estan sanos"
  fi
else
  bad "docker no disponible"
fi

step "2. DDL aplicado"
if command -v psql >/dev/null 2>&1; then
  for schema in portal console orch; do
    n=$(psql "${DATABASE_URL_ADMIN:-}" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='$schema';" 2>/dev/null || echo 0)
    if [[ "${n:-0}" -gt 0 ]]; then ok "esquema $schema: $n tablas"; else bad "esquema $schema vacio o inaccesible"; fi
  done
else
  bad "psql no disponible en el host (usa: docker compose exec postgres psql ...)"
fi

step "3. Vault responde y esta sellado"
if command -v vault >/dev/null 2>&1; then
  vault status >/dev/null 2>&1 && ok "vault responde" || bad "vault no responde"
  vault status 2>/dev/null | grep -q 'Sealed: *false' && ok "vault no sellat" || bad "vault sellat"
else
  bad "la CLI de vault no esta instalada en el host"
fi

step "4. Politicas de Vault (minimo privilegio)"
if command -v vault >/dev/null 2>&1; then
  for p in labmastery-web labmastery-console labmastery-orchestrator; do
    if vault policy read "$p" >/dev/null 2>&1; then ok "politica $p"; else bad "falta la politica $p"; fi
  done
  # El web NO debe poder escribir.
  if vault policy read labmastery-web 2>/dev/null | grep -qE '"(create|update|delete)"'; then
    bad "la politica del web permite escribir (deberia ser solo read)"
  else
    ok "la politica del web es solo de lectura"
  fi
else
  bad "la CLI de vault no esta instalada en el host"
fi

step "5. Los tres servicios resuelven un secret"
# La consola lo comprueba desde la vista "Magatzems de secrets" -> "Comprobar".
# Aqui solo verificamos que la variable de entorno llega a los tres procesos.
for svc in web console orchestrator; do
  if docker compose exec -T "$svc" printenv SETTINGS_SECRET_STORES 2>/dev/null | grep -q .; then
    ok "$svc tiene SETTINGS_SECRET_STORES"
  else
    bad "$svc NO tiene SETTINGS_SECRET_STORES"
  fi
done

step "6. HAProxy enruta"
if command -v curl >/dev/null 2>&1; then
  code=$(curl -sk -o /dev/null -w '%{http_code}' "https://localhost/health" 2>/dev/null || echo 000)
  case "$code" in
    200|302|301) ok "GET /health -> $code" ;;
    000) bad "HAProxy no responde en https://localhost/health" ;;
    *)   bad "GET /health -> $code (inesperado)" ;;
  esac
else
  bad "curl no disponible"
fi

step "7. Copias de seguridad"
if command -v pgbackrest >/dev/null 2>&1; then
  pgbackrest info 2>/dev/null | grep -q 'status.*ok\|repo.*:.*ok' && ok "pgbackrest informa de un backup ok" || bad "pgbackrest no ve un backup ok"
else
  bad "pgbackrest no instalado en el host (puede correr dentro del contenedor)"
fi
# El backup de Vault es el MAS SENSIBLE: contiene los valores.
if [[ -d "/var/lib/labmastery/${STACK}/vaultdata" ]]; then
  ok "existe el volumen de datos de Vault"
else
  bad "no se encuentra el volumen de datos de Vault"
fi

printf '\n'
if [[ $fail -eq 0 ]]; then
  echo "RESULTADO: todas las comprobaciones han pasado."
else
  echo "RESULTADO: hay comprobaciones que fallan (ver arriba)."
fi
exit $fail
