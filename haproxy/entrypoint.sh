#!/bin/sh
# Arranque de HAProxy + el sidecar de la Data Plane API.
#
# El config que HAProxy carga NO es el fichero montado en solo lectura (la plantilla
# gestionada por git), sino una copia en el volumen de estado: el sidecar tiene que
# poder reescribirla para materializar los backends de los labs.
#
#   /etc/haproxy/haproxy.cfg.base   plantilla (solo lectura, la del repo)
#   /var/lib/dataplaneapi/haproxy.cfg  config efectivo (escribible)
set -e

EFFECTIVE=/var/lib/dataplaneapi/haproxy.cfg
mkdir -p /var/lib/dataplaneapi /run/haproxy
cp -f /etc/haproxy/haproxy.cfg.base "$EFFECTIVE"

# master-worker (-W): el master relee la config al recibir USR2 y levanta workers
# nuevos sin cortar las conexiones abiertas. Es lo que permite publicar rutas de lab
# sin.drop de trafico.
/usr/local/sbin/haproxy -W -p /run/haproxy/haproxy.pid -f "$EFFECTIVE" &
HA_PID=$!

# El sidecar queda en primer plano: si cae, el contenedor cae y Docker lo reinicia.
exec /usr/local/sbin/dataplaneapi -f /etc/haproxy/dataplaneapi.yaml