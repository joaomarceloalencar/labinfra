#!/bin/bash
set -e

# ── DHCP em todas as interfaces (exceto lo) ──────────────────────────────────
for iface in $(ls /sys/class/net/ | grep -v lo); do
    echo "[net] Solicitando IP via DHCP em $iface..."
    dhclient -timeout 10 "$iface" 2>/dev/null || true
done

# ── Extrair geometria e profundidade de cor de RESOLUTION (ex: 1280x768x24) ──
GEOM="${RESOLUTION%x*}"    # "1280x768"
DEPTH="${RESOLUTION##*x}"  # "24"

# ── Xvnc: servidor X + VNC num único processo (sem race condition) ────────────
Xvnc :0 \
    -geometry "$GEOM" \
    -depth "$DEPTH" \
    -rfbport 5900 \
    -SecurityTypes None \
    -localhost no &
sleep 2

# ── Gerenciador de janelas ───────────────────────────────────────────────────
DISPLAY=:0 openbox &
sleep 1

# ── Barra de tarefas ─────────────────────────────────────────────────────────
DISPLAY=:0 tint2 &
sleep 1

# ── Terminal inicial ─────────────────────────────────────────────────────────
DISPLAY=:0 xterm -geometry 100x30+0+0 &

# Mantém o container vivo
tail -f /dev/null
