# syntax=docker/dockerfile:1.7
# LabMastery — plantilla CLI base (P6 de 09-driver-docker.md).
#
# Imagen de los labs de TERMINAL: sshd + usuario `student` + herramientas de curso.
# El orquestador la usa como `providerRef` de la plantilla; el contenedor se crea
# con esta imagen y el agente inyecta la identidad (authorized_keys, chpasswd).
#
#   docker build -f labmastery-deploy/docker/lab-cli/Dockerfile -t labmastery/lab-cli:bookworm .
#
# Lo que el DockerProvider espera encontrar:
#   - sshd escuchando en el puerto 22 (provider.docker.sshPort) para que
#     getEndpoints() publique el endpoint ssh y el gateway pueda conectar.
#   - usuario `student` con home propio y sudo sin contraseña (los labs lo usan).
#   - `chpasswd` disponible (injectIdentity lo usa para la contraseña).
#   - Un proceso que mantenga el contenedor vivo (sshd en primer plano).

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Herramientas de curso + sshd. `sudo`, `procps` y `less` son los que más se usan
# en los labs de terminal; el resto son utilidades habituales de administración.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      openssh-server \
      sudo \
      ca-certificates \
      curl \
      wget \
      git \
      vim \
      nano \
      less \
      procps \
      jq \
      tree \
      unzip \
      zip \
      tar \
      gzip \
      python3 \
      python3-pip \
      iproute2 \
      iputils-ping \
      dnsutils \
      netcat-openbsd \
      rsync \
      bash-completion; \
    rm -rf /var/lib/apt/lists/*

# Usuario de los labs: `student`, con sudo sin contraseña (los labs lo necesitan).
# La contraseña la inyecta el orquestador en cada sesión (chpasswd); aquí se deja
# la cuenta bloqueada para que no haya credenciales por defecto.
RUN set -eux; \
    useradd --create-home --shell /bin/bash --uid 1000 student; \
    passwd -l student; \
    echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student; \
    chmod 0440 /etc/sudoers.d/student

# sshd: sin login de root, con claves y contraseña (el orquestador inyecta ambas).
#
# `Subsystem sftp` ya viene en /etc/ssh/sshd_config: repetirlo hace que sshd NO arranque
# («Subsystem 'sftp' already defined»). Se deja el de la imagen base.
#
# El PTY necesita CAP_AUDIT_WRITE (`pam_loginuid` escribe la audit session id): sin esa capacidad,
# toda sesión interactiva muere con «Unable to request a pseudo-terminal». La capacidad la añade
# el orquestador al crear el contenedor (ver `CapAdd` en el DockerProvider), no la imagen.
RUN set -eux; \
    mkdir -p /var/run/sshd /home/student/.ssh; \
    chmod 700 /home/student/.ssh; \
    chown -R student:student /home/student/.ssh; \
    printf '%s\n' \
      'PermitRootLogin no' \
      'PasswordAuthentication yes' \
      'PubkeyAuthentication yes' \
      'UsePAM yes' \
      'X11Forwarding no' \
      'PrintMotd no' \
      'AcceptEnv LANG LC_*' \
      > /etc/ssh/sshd_config.d/labmastery.conf; \
    ssh-keygen -A

EXPOSE 22

# sshd en primer plano: mantiene el contenedor vivo y acepta conexiones.
# `-D` no hace fork; `-e` manda el log a stderr (visible en docker logs).
CMD ["/usr/sbin/sshd", "-D", "-e"]
