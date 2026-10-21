# Política de Vault del web.
#
# Mínimo privilegio (D23 §5.2): el web SOLO resuelve. No escribe, no lista.
# Los valores de los ajustes secrets del web están bajo labmastery/web/.

# Leer un secreto concreto.
path "secret/data/labmastery/web/*" {
  capabilities = ["read"]
}

# Leer los metadatos (versiones) de un secreto: la app necesita la versión
# que declara la referencia, y comprobar que existe.
path "secret/metadata/labmastery/web/*" {
  capabilities = ["read"]
}
