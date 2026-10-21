#!/bin/bash
# LabMastery — despliegue (wrapper de ansible-playbook).
#
#   ./scripts/deploy.sh                    # despliegue normal
#   ./scripts/deploy.sh --check            # solo comprobacion (--check de ansible)
#   ./scripts/deploy.sh --extra-vars k=v   # variables adicionales
#
# El playbook:
#   1. descifra el vault de ansible
#   2. inicializa Vault (root token + politica + mount KV v2)
#   3. genera el .env del compose con las variables de arranque (capa 1)
#   4. levanta el compose
#   5. verifica (scripts/smoke.sh)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$HOME/.labmastery-vault-pass}"
INVENTORY="${INVENTORY:-ansible/inventory/hosts.ini}"

if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
  echo "ERROR: no existe el fichero de contrasena del vault: $VAULT_PASSWORD_FILE" >&2
  echo "  Crealo con permisos 0600. La contrasena la entrega el CI o el operador." >&2
  exit 1
fi

echo "==> Desplegando LabMastery desde $ROOT"

ansible-playbook \
  --inventory "$INVENTORY" \
  --vault-password-file "$VAULT_PASSWORD_FILE" \
  "$@" \
  ansible/site.yml

echo "==> Verificacion post-despliegue"
./scripts/smoke.sh
