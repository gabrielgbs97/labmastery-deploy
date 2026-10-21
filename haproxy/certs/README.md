# Certificados TLS

Los certificados **NO** se commitean. El playbook los deja aqui desde el gestor de secrets
del despliegue (o desde el repositorio de IaC).

## Formato

HAProxy espera un unico fichero PEM con la cadena y la clave privada:

```
/etc/haproxy/certs/labmastery.pem
```

Generar uno autofirmado (solo para pruebas):

```bash
openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
  -keyout /tmp/labmastery.key -out /tmp/labmastery.crt \
  -subj "/CN=labmastery.local"
cat /tmp/labmastery.key /tmp/labmastery.crt > /etc/haproxy/certs/labmastery.pem
chmod 600 /etc/haproxy/certs/labmastery.pem
```

En produccion, el certificado lo emite la CA corporativa.
