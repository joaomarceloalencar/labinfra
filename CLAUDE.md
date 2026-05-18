# CLAUDE.md

This repository has three distinct purposes:

1. **Root directory** — Ansible playbooks and scripts for managing physical lab workstations at UFC Quixadá.
2. **`Tutoriais/`** — Step-by-step networking tutorials applied during classes (written in Portuguese).
3. **`docker/`** — Dockerfiles for the GNS3 container images used in the tutorials.

## Tutorials

Markdown files in `Tutoriais/` are classroom lab guides, not Ansible documentation:

- `01_RoteamentoLinux.md` — Linux router with NAT, DHCP and iptables (classroom script)
- `02_IntroducaoGNS3.md` — Introduction to GNS3 with Docker and Open vSwitch
- `03_PfSenseVLANs.md` — pfSense with VLANs on Open vSwitch
- `04_TrunkInterSwitch.md` — VLANs across two OVS switches with inter-switch trunk and pfSense
- `05_SpanningTree.md` — Spanning Tree Protocol (STP/RSTP) with Open vSwitch: broadcast storms, root bridge election, failover

When editing tutorials, preserve the step-by-step instructional style intended for students.

## GNS3 Templates

The tutorials use two types of templates in GNS3, all running on `insightcluster09` (accessible via `ssh insightlab@insightcluster09`).

### Docker containers

The `docker/` directory contains the Dockerfiles for the container images built and hosted on `insightcluster09`.

| Directory | Image | Tag | Description |
|-----------|-------|-----|-------------|
| `docker/ubuntu-net/` | `insightlab/ubuntu-net` | `1.0` | Ubuntu 22.04 with network tools (iproute2, tcpdump, curl, dig, etc.) |
| `docker/ovs/` | `insightlab/ovs` | `1.1` | Ubuntu 22.04 with Open vSwitch; `start.sh` initialises the OVS daemon and bridge `br0` at startup |

To rebuild an image on `insightcluster09`:

```bash
cd /home/insightlab/<image-dir>
docker build -t insightlab/<name>:<tag> .
```

### QEMU virtual machines

**pfSense** and **UbuntuDesktop** are QEMU VMs configured directly in GNS3 from their official ISO images — no pre-built appliance file is used. Installation was performed inside GNS3 itself by attaching the ISO as a CD-ROM drive to a new QEMU VM template and following each installer normally.

- **pfSense** — downloaded from https://www.pfsense.org/download/
- **UbuntuDesktop** — standard Ubuntu Desktop 22.04 ISO; Firefox is included in the default installation

## Inventory and Configuration

- `inventory.ini` is gitignored and must be created manually with `ativos` group containing reachable machines
- `ansible.cfg` references `inventory.ini` and disables host key checking
- All playbooks target `hosts: ativos` group

## Running Playbooks

Standard execution order for new machines:
1. `ansible-playbook sudo_nopasswd.yml` - Enable passwordless sudo for `ufc` user
2. `ansible-playbook install_prereqs.yml` - Install Python dependencies and sshpass
3. `ansible-playbook create_user.yml` - Create `labinfra` user (password: `15lab66infra`, groups: `dialout,users,wireshark,vboxusers,labinfra`)
4. `ansible-playbook update_system.yml` - Update system packages
5. `ansible-playbook download_isos.yml` - Download Ubuntu 24.04.4 ISOs to `/home/labinfra/iso`

Run with: `ansible-playbook <playbook>.yml`

## SSH Key Management

Use `./add_ssh_keys.sh` to interactively add SSH keys to machines that failed authentication.
The script uses `ssh-copy-id` with `ufc@<ip>` for each listed machine.

## Machine Inventory

`README.md` contains the full IP/MAC address mapping for lab machines (200.129.39.x subnet).
Reference this when creating `inventory.ini`.

## Playbook Quirks

- All playbooks use `shell` module instead of native Ansible modules
- `become: yes` is set but tasks explicitly use `sudo` in shell commands
- `gather_facts: no` on all playbooks for speed
- Hardcoded credentials in `create_user.yml` (var `senha`)
