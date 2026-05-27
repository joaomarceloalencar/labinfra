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
        # VNC integrado (Xvnc = servidor X + VNC num único processo)
        tigervnc-standalone-server \
        # gerenciador de janelas leve
        openbox obconf \
        # terminal
        xterm \
        # barra de tarefas
        tint2 \
        # browser
        firefox-esr \
        # editores de texto
        vim nano \
        # rede
        iproute2 isc-dhcp-client \
        iputils-ping net-tools dnsutils \
        tcpdump wget curl \
    && rm -rf /var/lib/apt/lists/*

# 3. Hook dhclient: atualiza /etc/resolv.conf com o DNS recebido via DHCP
RUN mkdir -p /etc/dhcp/dhclient-exit-hooks.d && \
    cat > /etc/dhcp/dhclient-exit-hooks.d/update-resolv-conf << 'EOF'
#!/bin/bash
case "$reason" in
    BOUND|RENEW|REBIND|REBOOT)
        [ -n "$new_domain_name_servers" ] || exit 0
        {
            for ns in $new_domain_name_servers; do
                echo "nameserver $ns"
            done
            [ -n "$new_domain_name" ] && echo "search $new_domain_name"
            [ -n "$new_domain_search" ] && echo "search $new_domain_search"
        } > /etc/resolv.conf
        ;;
esac
EOF
RUN chmod +x /etc/dhcp/dhclient-exit-hooks.d/update-resolv-conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Porta VNC
EXPOSE 5900

CMD ["/start.sh"]
