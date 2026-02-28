# WorkstationManager (Ansible)

Starter Ansible project to manage mixed `macOS`, `Windows`, and `Linux` workstations.

Current baseline:

- Keeps OS packages/updates current per platform
- Installs and updates:
  - PrusaSlicer
  - Firefox
  - Chrome
  - Docker
  - OpenCode (best effort where package/cask exists)
  - GIMP (all platforms where available)
  - Arduino IDE (all platforms where available)
  - Audacity (all platforms where available)
  - Copilot tooling (best effort where package exists)
  - FreeCAD (all platforms where available)
  - HandBrake (all platforms where available)
  - HDHomeRun tools (best effort where package exists)
  - OpenSCAD nightly from official release assets
  - Raspberry Pi Imager (all platforms where available)
  - SubEthaEdit (best effort where package exists)
  - Visual Studio Code (all platforms where available)
  - Wireshark (all platforms where available)
  - Zoom (all platforms where available)
  - Blender (all platforms where available)
  - KiCad (all platforms where available)
  - MeshMixer (best effort where package/cask exists)
  - iTerm2 (or platform equivalent)
  - Emacs, Git, Vim (all platforms)
  - Aquamacs (macOS)
  - Ollama (macOS)
  - llama.cpp (macOS)
- Enforces browser home/start page to `http://ctrlh` (HTTP intentionally, not HTTPS)

## Project layout

- `ansible.cfg`: local Ansible defaults
- `requirements.yml`: required Ansible collections
- `inventories/production/hosts.yml`: inventory (example hosts)
- `group_vars/all.yml`: software lists and shared variables
- `playbooks/site.yml`: top-level multi-OS playbook
- `roles/macos`: macOS update + Homebrew casks
- `roles/linux`: Linux update + package install
- `roles/windows`: Windows updates + Chocolatey packages

## Prerequisites

- Control node has Ansible installed (and Python)
- SSH access to macOS/Linux hosts
- WinRM access to Windows hosts
- Sudo/admin privileges on managed machines

For Windows over WinRM:

- Enable WinRM on targets
- Open firewall as needed
- Use a secure auth/transport configuration for your environment

## Setup

Install required collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

Edit inventory:

- Update `inventories/production/hosts.yml` with real hosts/users
- Prefer Ansible Vault for credentials/secrets

### Add managed machines to `hosts.yml`

`inventories/production/hosts.yml` is grouped by OS (`macos`, `linux`, `windows`).
Add each new machine under the correct group with a unique host alias.

Minimal examples:

```yaml
all:
  children:
    macos:
      hosts:
        macbook-pro-01:
          ansible_host: 192.168.1.51
          ansible_user: admin
    linux:
      hosts:
        ubuntu-dev-02:
          ansible_host: 192.168.1.61
          ansible_user: ansible
    windows:
      hosts:
        win11-workstation-02:
          ansible_host: 192.168.1.71
          ansible_user: Administrator
          ansible_password: "{{ vault_windows_admin_password }}"
          ansible_connection: winrm
          ansible_winrm_transport: ntlm
          ansible_port: 5985
          ansible_winrm_server_cert_validation: ignore
```

Useful host variables:

- `ansible_host`: IP or DNS name of target
- `ansible_user`: remote account for SSH/WinRM
- `ansible_password`: password variable (Vault-backed)
- `ansible_port`: override default SSH/WinRM port if needed
- `ansible_connection`: `ssh` (default) or `winrm`

For SSH hosts (macOS/Linux), key-based auth is recommended. If you need
password-based SSH auth, use Vault-backed `ansible_password` variables.

### Use Ansible Vault for SSH credentials (macOS/Linux)

1) Create encrypted Vault files from templates:

```bash
cp group_vars/macos/vault.example.yml group_vars/macos/vault.yml
cp group_vars/linux/vault.example.yml group_vars/linux/vault.yml
ansible-vault encrypt group_vars/macos/vault.yml
ansible-vault encrypt group_vars/linux/vault.yml
```

2) Edit credentials securely:

```bash
ansible-vault edit group_vars/macos/vault.yml
ansible-vault edit group_vars/linux/vault.yml
```

3) In `hosts.yml`, reference Vault variables for password auth:

```yaml
mac-mini-01:
  ansible_host: 192.168.1.10
  ansible_user: admin
  ansible_password: "{{ vault_macos_ssh_password }}"

ubuntu-dev-01:
  ansible_host: 192.168.1.20
  ansible_user: ansible
  ansible_password: "{{ vault_linux_ssh_password }}"
```

4) Run with Vault prompt:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Connectivity checks:

```bash
ansible macos -m ping --ask-vault-pass
ansible linux -m ping --ask-vault-pass
```

If using SSH keys instead of passwords:

- Keep `ansible_password` unset
- Use `~/.ssh` keys and/or `ssh-agent`
- In container mode, `${HOME}/.ssh` is already mounted read-only

Pin OpenSCAD nightly to a specific release tag (optional):

- Set `openscad_nightly_tag` in `group_vars/all.yml`
- Example: `openscad_nightly_tag: "openscad-2026.01.20"`
- Leave empty to use latest prerelease nightly

Run the full management playbook:

```bash
ansible-playbook playbooks/site.yml
```

Limit to one OS group:

```bash
ansible-playbook playbooks/site.yml --limit macos
ansible-playbook playbooks/site.yml --limit linux
ansible-playbook playbooks/site.yml --limit windows
```

## WinRM setup and credentials

### 1) Configure inventory for Windows hosts

The sample `inventories/production/hosts.yml` already includes WinRM settings and
references a Vault-backed password variable:

- `ansible_connection: winrm`
- `ansible_winrm_transport: ntlm`
- `ansible_port: 5985`
- `ansible_password: "{{ vault_windows_admin_password }}"`

### 2) Create encrypted WinRM credentials

Use the template at `group_vars/windows/vault.example.yml`:

```bash
cp group_vars/windows/vault.example.yml group_vars/windows/vault.yml
ansible-vault encrypt group_vars/windows/vault.yml
```

Edit encrypted vars:

```bash
ansible-vault edit group_vars/windows/vault.yml
```

### 3) Enable WinRM on each Windows machine

Run this in elevated PowerShell on the target machine:

```powershell
Enable-PSRemoting -Force
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\NTLM -Value $true
New-NetFirewallRule -DisplayName "WinRM HTTP 5985" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985
```

### 4) Validate connectivity from control node

```bash
ansible windows -m ansible.windows.win_ping --ask-vault-pass
```

If using the containerized control node:

```bash
make playbook EXTRA_ARGS="--ask-vault-pass --limit windows"
```

## Optional: Containerized control node

This repository includes a Docker-based Ansible runner for control-node portability.
It does not change target behavior; it only standardizes the environment that runs Ansible.

Build the runner image:

```bash
make build
```

Run the default playbook:

```bash
make playbook
```

Run with a host/group limit:

```bash
make playbook LIMIT=macos
make playbook LIMIT=windows
```

Run with custom args:

```bash
make playbook EXTRA_ARGS="--check --diff"
```

Open a shell in the container:

```bash
make shell
```

Edit Vault files from container (choose editor each run):

```bash
# build image first after Dockerfile changes
make build

# default editor is vi
make vault-edit VAULT_FILE=group_vars/linux/vault.yml

# use emacs
make vault-edit VAULT_FILE=group_vars/windows/vault.yml EDITOR_CMD=emacs
```

Notes:

- `docker-compose.yml` mounts this repo at `/workspace`.
- `${HOME}/.ssh` is mounted read-only for SSH-based connections.
- `ANSIBLE_CONFIG` is set to `/workspace/ansible.cfg` in the container.
- WinRM-based Windows management works from this container via `pywinrm`.
- Container image includes both `vi` and terminal `emacs` for `ansible-vault edit`.

## GitHub image build workflow

This repo includes a workflow at `.github/workflows/docker-image.yml` that builds and
publishes the control-node image to GHCR (`ghcr.io`) on every push.

Published tags include:

- `latest` (default branch only)
- branch tag (for example `main`, `feature-x`)
- commit SHA tag (`sha-<commit>`)

Default image name:

- `ghcr.io/<repo-owner>/workstationmanager-ansible`

### Use the published image (no local build)

Use `docker-compose.image.example.yml` as a starting point:

```bash
cp docker-compose.image.example.yml docker-compose.image.yml
```

Edit `docker-compose.image.yml` and replace `OWNER` with your GitHub user/org.
Then run:

```bash
docker compose -f docker-compose.image.yml run --rm ansible ansible-playbook playbooks/site.yml
```

You can also use `Makefile` helpers with the published-image compose file:

```bash
make playbook-image
make playbook-image LIMIT=windows
make playbook-image EXTRA_ARGS="--ask-vault-pass --check"
make shell-image
make vault-edit-image VAULT_FILE=group_vars/macos/vault.yml EDITOR_CMD=emacs
```

By default these use `docker-compose.image.yml`. Override with:

```bash
make playbook-image IMAGE_COMPOSE_FILE=docker-compose.image.example.yml
```

## Notes

- Linux package names are distro-specific. Adjust `group_vars/all.yml` for your actual repositories.
- Core tools are centralized in `group_vars/all.yml` as `core_tools_*` variables and merged into each OS package list.
- `google-chrome-stable` often requires adding the Google repository on Linux.
- `prusa-slicer` package naming may differ by distro/version.
- OpenSCAD is handled separately from distro packages and installed from upstream nightly release assets.
- Set `openscad_nightly_tag` in `group_vars/all.yml` to pin OpenSCAD to a specific release tag.
- Linux Docker defaults to Docker's official CE repository and packages (`docker-ce`, `docker-ce-cli`, `containerd.io`, plugins).
- Set `docker_use_official_repo: false` in vars if you need to fall back to distro Docker packages.
- Several cross-platform packages are configured as best effort optional installs, since names and feed availability vary by OS and repository.
- Browser homepage policy is controlled by `browser_homepage_url` in `group_vars/all.yml` and defaults to `http://ctrlh`.
- Windows terminal equivalent is `microsoft-windows-terminal`.
