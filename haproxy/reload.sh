#!/bin/sh
# Recarga HAProxy en caliente. Con master-worker (-W), USR2 al master hace que rellegi
# la configuracion y levante workers nous sense tallar les connexions obertes.
#
# El master es el proceso con el pid del fichero pidfile (no el PID 1: en el contenedor
# el PID 1 es el sidecar de la Data Plane API).
set -e
PIDFILE=/run/haproxy/haproxy.pid
if [ ! -f "$PIDFILE" ]; then
    echo "lm-reload: no hi ha $PIDFILE" >&2
    exit 1
fi
kill -USR2 "$(cat "$PIDFILE")"