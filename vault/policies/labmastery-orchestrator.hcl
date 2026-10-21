# Política de Vault del orquestador.
#
# El orquestador resuelve los ajustes secrets propios (labmastery/orch/*) y
# los escribe cuando la consola los delega por la API /v1/settings (D22 §6.6).

path "secret/data/labmastery/orch/*" {
  capabilities = ["read", "create", "update"]
}

path "secret/metadata/labmastery/orch/*" {
  capabilities = ["read", "list", "delete"]
}
