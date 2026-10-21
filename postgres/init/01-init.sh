#!/bin/bash
# LabMastery - arranque de PostgreSQL.
#
# El DDL canonico (labmastery-db/sql/00_roles_schemas.sql) YA crea los roles;
# aqui solo se les asigna la contrasena y se aplica el resto del DDL.
#
# Se ejecuta UNA vez, en el arranque inicial del contenedor (el entrypoint
# oficial solo corre /docker-entrypoint-initdb.d si el volumen esta vacio).
#
# Contrasenas: las reciben por variables de entorno desde el compose, que las
# genera el playbook de ansible-vault. NUNCA se hardcodean aqui.
set -euo pipefail

DB="${POSTGRES_DB:-labmastery}"
ROLES="${LM_DB_ROLES:-}"
PASSWORDS="${LM_DB_PASSWORDS:-}"

if [[ -z "$ROLES" || -z "$PASSWORDS" ]]; then
  echo "ATENCION: LM_DB_ROLES / LM_DB_PASSWORDS vacios; no se asigna ninguna contrasena." >&2
  exit 0
fi

# Formato: "lm_web=pass,lm_console=pass,..." (el valor puede llevar '=').
IFS=',' read -ra ROLES_ARR <<< "$ROLES"
IFS=',' read -ra PASS_ARR <<< "$PASSWORDS"

for i in "${!ROLES_ARR[@]}"; do
  entry="${ROLES_ARR[$i]}"
  role="${entry%%=*}"
  password="${PASS_ARR[$i]:-}"
  [[ -z "$role" ]] && continue
  if [[ -z "$password" ]]; then
    echo "ATENCION: sin contrasena para el rol $role; se deja sin contrasena." >&2
    continue
  fi
  # ON_ERROR_STOP no debe tumbar el arranque si el rol ya existe.
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" \
    -c "ALTER ROLE \"$role\" LOGIN PASSWORD '$password';" \
    || echo "AVISO: no se pudo asignar la contrasena de $role (ya existe?)." >&2
  echo "  contrasena asignada: $role"
done

# El DDL canonico vive en labmastery-db/sql/*.sql y se aplica en orden.
# En el despliegue lo monta el playbook; si no esta, se avisa.
if [[ -d /ddl/sql ]]; then
  echo "Aplicando el DDL de /ddl/sql ..."
  for f in /ddl/sql/*.sql; do
    [[ -e "$f" ]] || continue
    echo "  -> $(basename "$f")"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" -f "$f"
  done
else
  echo "ATENCION: no existe /ddl/sql; el DDL NO se ha aplicado." >&2
  echo "  Monta labmastery-db en el contenedor o aplica el DDL a mano." >&2
fi

echo "PostgreSQL listo."