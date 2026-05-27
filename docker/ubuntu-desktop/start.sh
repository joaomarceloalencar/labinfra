#!/bin/bash
set -e

# ── DHCP em todas as interfaces (exceto lo) ──────────────────────────────────
for iface in $(ls /sys/class/net/ | grep -v lo); do
    echo "[net] Solicitando IP via DHCP em $iface..."
    dhclient -timeout 10 "$iface" 2>/dev/null || true
done

# ── Display virtual ──────────────────────────────────────────────────────────
Xvfb :0 -screen 0 "${RESOLUTION}" -ac +extension GLX +render &
sleep 1

# ── Gerenciador de janelas ───────────────────────────────────────────────────
DISPLAY=:0 openbox &
sleep 1

# ── Barra de tarefas ─────────────────────────────────────────────────────────
DISPLAY=:0 tint2 &
sleep 1

# ── Terminal inicial ─────────────────────────────────────────────────────────
DISPLAY=:0 xterm -geometry 100x30+0+0 &

# ── Servidor VNC (porta 5900, sem senha) ─────────────────────────────────────
x11vnc \
    -display :0 \
    -forever \
    -nopw \
    -rfbport 5900 \
    -quiet \
    -bg

# Mantém o container vivo
tail -f /dev/null
