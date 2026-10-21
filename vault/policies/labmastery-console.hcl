# Política de Vault de la consola.
#
# La consola es la ÚNICA que escribe (D22 §6.6): la consola escribe el secreto
# en el almacén y guarda la referencia. También lista, porque la vista
# "Magatzems de secrets" explora el catálogo (nombres y versiones, NUNCA
# valores).

path "secret/data/labmastery/console/*" {
  capabilities = ["read", "create", "update"]
}

path "secret/metadata/labmastery/console/*" {
  capabilities = ["read", "list", "delete"]
}

# La consola puede explorar (listar) los secretos que escribe para el resto
# de servicios, pero NO leer sus valores: la referencia ya está en la BD.
path "secret/metadata/labmastery/*" {
  capabilities = ["list"]
}
