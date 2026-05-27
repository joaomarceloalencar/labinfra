FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    VNC_PORT=5900 \
    RESOLUTION=1280x768x24

# 1. Repositório Mozilla (Firefox .deb real, sem snap)
RUN apt-get update && apt-get install -y \
        software-properties-common gnupg curl \
    && add-apt-repository -y ppa:mozillateam/ppa \
    && printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
        > /etc/apt/preferences.d/mozilla-firefox \
    && apt-get update

# 2. Ambiente gráfico mínimo + ferramentas de rede
RUN apt-get install -y \
        # display virtual + VNC
        xvfb x11vnc \
        # gerenciador de janelas leve
        openbox obconf \
        # terminal
        xterm \
        # barra de tarefas
        tint2 \
        # browser
        firefox-esr \
        # rede
        iproute2 isc-dhcp-client \
        iputils-ping net-tools dnsutils \
        tcpdump wget curl \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Porta VNC
EXPOSE 5900

CMD ["/start.sh"]
