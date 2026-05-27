#!/bin/bash
set -e

# ── DHCP em todas as interfaces (exceto lo) ──────────────────────────────────
for iface in $(ls /sys/class/net/ | grep -v lo); do
    echo "[net] Solicitando IP via DHCP em $iface..."
    dhclient -timeout 10 "$iface" 2>/dev/null || true
done

# ── Display: usa o injetado pelo GNS3 ou sobe Xvnc local (modo standalone) ──
if DISPLAY="${DISPLAY:-:0}" xdpyinfo >/dev/null 2>&1; then
    echo "[display] Display externo disponível: $DISPLAY"
    export DISPLAY="${DISPLAY:-:0}"
else
    echo "[display] Nenhum display externo — iniciando Xvnc local em :0"
    GEOM="${RESOLUTION%x*}"    # "1280x768"
    DEPTH="${RESOLUTION##*x}"  # "24"
    Xvnc :0 \
        -geometry "$GEOM" \
        -depth "$DEPTH" \
        -rfbport 5900 \
        -SecurityTypes None \
        -localhost no &
    # Aguarda o servidor X ficar pronto
    for i in $(seq 1 15); do
        DISPLAY=:0 xdpyinfo >/dev/null 2>&1 && break
        sleep 1
    done
    export DISPLAY=:0
fi

echo "[display] Usando: $DISPLAY"

# ── Gerenciador de janelas ───────────────────────────────────────────────────
openbox &
sleep 1

# ── Barra de tarefas ─────────────────────────────────────────────────────────
tint2 &
sleep 1

# ── Terminal inicial ─────────────────────────────────────────────────────────
xterm -geometry 100x30+0+0 &

# Mantém o container vivo
tail -f /dev/null
