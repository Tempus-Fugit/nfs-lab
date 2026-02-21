#!/usr/bin/env bash
# provision_client.sh – Idempotent Rocky Linux 9 NFS client provisioner.
# Called by Vagrantfile. Reads LAUNCH_DASHBOARD and NFS_LAB_SSH_PUB_KEY
# from environment.

set -euo pipefail

LAUNCH_DASHBOARD="${LAUNCH_DASHBOARD:-false}"
SSH_PUB_KEY="${NFS_LAB_SSH_PUB_KEY:-}"

echo "==> [nfsclient] Starting provisioning ..."
echo "==> [nfsclient] LAUNCH_DASHBOARD=${LAUNCH_DASHBOARD}"

# ── 1. Install nfs-utils ──────────────────────────────────────────────────────
echo "==> [nfsclient] Installing nfs-utils ..."
dnf install -y -q nfs-utils

# ── 2. Create devuser ─────────────────────────────────────────────────────────
echo "==> [nfsclient] Creating devuser account ..."
if ! id devuser &>/dev/null; then
  useradd -m -s /bin/bash devuser
fi
echo "devuser:devpass123" | chpasswd

# Passwordless sudo
if ! grep -q "^devuser" /etc/sudoers 2>/dev/null; then
  echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# ── 3. Install SSH public key for devuser ─────────────────────────────────────
if [ -n "${SSH_PUB_KEY}" ]; then
  echo "==> [nfsclient] Installing SSH public key for devuser ..."
  SSH_AUTH_DIR="/home/devuser/.ssh"
  mkdir -p "${SSH_AUTH_DIR}"
  chmod 700 "${SSH_AUTH_DIR}"
  echo "${SSH_PUB_KEY}" > "${SSH_AUTH_DIR}/authorized_keys"
  chmod 600 "${SSH_AUTH_DIR}/authorized_keys"
  chown -R devuser:devuser "${SSH_AUTH_DIR}"
fi

# ── 4. Disable firewalld ──────────────────────────────────────────────────────
echo "==> [nfsclient] Disabling firewalld ..."
systemctl disable --now firewalld 2>/dev/null || true

# ── 5. Enable NFS client services ─────────────────────────────────────────────
echo "==> [nfsclient] Enabling NFS client services ..."
systemctl enable --now rpcbind
systemctl enable --now nfs-client.target

# ── 6. Create top-level mount point directories ───────────────────────────────
echo "==> [nfsclient] Creating mount point directories ..."
mkdir -p /HNAS
mkdir -p /NetApp

# ── 7. Create log directory ───────────────────────────────────────────────────
echo "==> [nfsclient] Creating /var/log/nas_monitor/ ..."
mkdir -p /var/log/nas_monitor
chown devuser:devuser /var/log/nas_monitor

# ── 8. Run bootstrap.sh ───────────────────────────────────────────────────────
echo "==> [nfsclient] Running bootstrap.sh ..."
export LAUNCH_DASHBOARD
bash /vagrant/scripts/bootstrap.sh

# ── 9. Run validate.sh ────────────────────────────────────────────────────────
echo "==> [nfsclient] Running validate.sh ..."
bash /vagrant/scripts/validate.sh || true

echo "==> [nfsclient] Provisioning complete."
