#!/bin/bash

# diretórios
mkdir -p /var/run/openvswitch
mkdir -p /var/lib/openvswitch

# criar DB se não existir
if [ ! -f /var/lib/openvswitch/conf.db ]; then
    ovsdb-tool create /var/lib/openvswitch/conf.db \
        /usr/share/openvswitch/vswitch.ovsschema
fi

# iniciar OVS
ovsdb-server \
    --remote=punix:/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile \
    --detach

ovs-vsctl --no-wait init

ovs-vswitchd --pidfile --detach

# criar bridge
ovs-vsctl --may-exist add-br br0

# subir bridge automaticamente
ip link set br0 up

# adicionar interfaces dinamicamente (exceto eth0)
for iface in $(ls /sys/class/net | grep eth); do
    if [ "$iface" != "eth0" ]; then
        ovs-vsctl --may-exist add-port br0 $iface
    fi
done

echo "=== OVS PRONTO ==="
echo "Bridge br0 ativa"

# shell interativo (GNS3)
exec /bin/bash
