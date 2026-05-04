# CLAUDE.md

This repository has two distinct purposes:

1. **Root directory** — Ansible playbooks and scripts for managing physical lab workstations at UFC Quixadá.
2. **`Tutoriais/`** — Step-by-step networking tutorials applied during classes (written in Portuguese).

## Tutorials

Markdown files in `Tutoriais/` are classroom lab guides, not Ansible documentation:

- `IntroducaoGNS3.md` — Introduction to GNS3
- `PfSenseVLANs.md` — pfSense with VLANs on Open vSwitch
- `RoteamentoLinux.md` / `RoteamentoLinuxVersaoAula.md` — Linux routing labs

When editing tutorials, preserve the step-by-step instructional style intended for students.

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
