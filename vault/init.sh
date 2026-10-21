#!/bin/bash
# LabMastery — inicializacion de Vault.
#
# La ejecuta el playbook de ansible (o a mano, en el PRIMER despliegue).
# En despliegues posteriores, el playbook detecta que Vault ya esta
# inicializado y no vuelve a ejecutar este script (el token raiz no se
# regenera nunca: habria que rotar todos los tokens de servicio).
#
# Idempotente: si Vault ya esta inicializado, no hace nada.

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
MOUNT="${VAULT_MOUNT:-secret}"
POLICY_DIR="${POLICY_DIR:-$(dirname "$0")/policies}"

export VAULT_ADDR

if [[ -z "$VAULT_TOKEN" ]]; then
  echo "ERROR: falta VAULT_TOKEN (el token raiz)." >&2
  exit 1
fi

vault_status() { vault status >/dev/null 2>&1; }

# --- ¿Esta inicializado? ----------------------------------------------------
if vault status 2>/dev/null | grep -q '"initialized":true'; then
  echo "Vault ya esta inicializado. No se hace nada."
  exit 0
fi

echo ">> Inicializando Vault (modo server)..."
INIT_JSON=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
UNSEAL_KEY=$(echo "$INIT_JSON" | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo "$INIT_JSON" | jq -r '.root_token')

echo ">> Desatascando..."
vault operator unseal "$UNSEAL_KEY" >/dev/null

export VAULT_TOKEN="$ROOT_TOKEN"

echo ">> Publicando las politicas..."
for f in "$POLICY_DIR"/*.hcl; do
  [[ -e "$f" ]] || continue
  name=$(basename "$f" .hcl)
  vault policy write "$name" - < "$f"
  echo "   politica: $name"
done

echo ">> Activando el mount KV v2 en '$MOUNT'..."
vault secrets enable -path="$MOUNT" -version=2 kv 2>/dev/null || echo "   (el mount ya existe)"

echo
echo "=============================================================="
echo " TOKEN RAIZ (guárdalo en el gestor de secrets del despliegue):"
echo " $ROOT_TOKEN"
echo "=============================================================="
echo
echo "Ahora:"
echo "  1. Guarda el token raiz en el gestor de secrets (NO en el repo)."
echo "  2. Crea el token de servicio de la consola:"
echo "       vault token create -policy=labmastery-console -ttl=0"
echo "  3. Ponlo en SETTINGS_SECRET_STORES (web, consola y orquestrador,"
echo "     el MISMO valor) con la forma: [{\"<UUID>\":\"hvs.TOKEN\"}]"
echo "  4. Repite para web (policy labmastery-web) y orquestador."