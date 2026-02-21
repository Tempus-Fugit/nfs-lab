#!/usr/bin/env bash
# bootstrap.sh – Dashboard setup on nfsclient.
# Called by provision_client.sh. Also the standalone entry point for
# post-build deployment on other machines.
#
# SYNC NOTE: This file is kept in sync with nfs-project/bootstrap.sh.
# Both files must be updated together whenever changes are made here.
#
# Usage:
#   bash bootstrap.sh                         # Install + mount, no dashboard
#   LAUNCH_DASHBOARD=true bash bootstrap.sh   # Install + mount + start dashboard

set -euo pipefail

LAUNCH_DASHBOARD="${LAUNCH_DASHBOARD:-false}"
DASHBOARD_DIR="/opt/nas-dashboard"
LOG_DIR="/var/log/nas_monitor"
NVM_DIR="${HOME}/.nvm"

echo "==> [bootstrap] Starting dashboard setup ..."
echo "==> [bootstrap] LAUNCH_DASHBOARD=${LAUNCH_DASHBOARD}"

# ── 1. Guard: nas-dashboard must exist ────────────────────────────────────────
if [ ! -d "${DASHBOARD_DIR}" ] || [ -z "$(ls -A "${DASHBOARD_DIR}" 2>/dev/null)" ]; then
  echo ""
  echo "ERROR: ${DASHBOARD_DIR} is empty. Ensure the nas-dashboard repo is"
  echo "       present at this path before running bootstrap.sh."
  echo ""
  exit 1
fi

# ── 2. Install Node.js via nvm ────────────────────────────────────────────────
echo "==> [bootstrap] Checking Node.js installation ..."

# Source nvm if it exists (nvm is not set -u safe)
if [ -s "${NVM_DIR}/nvm.sh" ]; then
  set +u
  # shellcheck source=/dev/null
  source "${NVM_DIR}/nvm.sh"
  set -u
fi

NODE_INSTALLED=false
if command -v node &>/dev/null && command -v npm &>/dev/null; then
  NODE_VERSION=$(node -v)
  echo "==> [bootstrap] Node.js already installed: ${NODE_VERSION}"
  NODE_INSTALLED=true
fi

if [ "${NODE_INSTALLED}" = "false" ]; then
  echo "==> [bootstrap] Installing nvm ..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

  # Source nvm for current session (nvm is not set -u safe)
  export NVM_DIR="${HOME}/.nvm"
  set +u
  # shellcheck source=/dev/null
  [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"

  echo "==> [bootstrap] Installing Node.js 22 LTS ..."
  nvm install 22
  nvm use 22
  set -u
  NODE_VERSION=$(node -v)
  echo "==> [bootstrap] Node.js installed: ${NODE_VERSION}"
  # Symlink into /usr/local/bin so node is findable without nvm in PATH
  ln -sf "$(command -v node)" /usr/local/bin/node
  ln -sf "$(command -v npm)" /usr/local/bin/npm
else
  NODE_VERSION=$(node -v)
fi

# ── 3. npm install – node_modules on local ext4 to avoid vboxsf symlink errors ──
# vboxsf (VirtualBox shared folders) returns EPERM on symlink() syscalls.
# --no-bin-links only suppresses .bin/ entries; many packages (vite, esbuild,
# better-sqlite3 native build) still create internal symlinks and will fail.
# Fix: bind-mount local ext4 directories over the vboxsf node_modules paths.
# npm writes to ext4 transparently; source files stay on vboxsf for live editing.

is_vboxsf=false
if stat -f -c %T "${DASHBOARD_DIR}" 2>/dev/null | grep -q "vboxsf"; then
  is_vboxsf=true
fi

if [ "${is_vboxsf}" = "true" ]; then
  echo "==> [bootstrap] vboxsf detected – bind-mounting node_modules onto local ext4 ..."
  LOCAL_MOD_BASE="/home/devuser/.nas-dashboard-modules"
  mkdir -p "${LOCAL_MOD_BASE}/client/node_modules" \
           "${LOCAL_MOD_BASE}/server/node_modules"
  mkdir -p "${DASHBOARD_DIR}/client/node_modules" \
           "${DASHBOARD_DIR}/server/node_modules"

  if ! mountpoint -q "${DASHBOARD_DIR}/client/node_modules" 2>/dev/null; then
    mount --bind "${LOCAL_MOD_BASE}/client/node_modules" \
                 "${DASHBOARD_DIR}/client/node_modules"
    echo "==> [bootstrap] Bind-mounted client/node_modules → ext4"
  fi
  if ! mountpoint -q "${DASHBOARD_DIR}/server/node_modules" 2>/dev/null; then
    mount --bind "${LOCAL_MOD_BASE}/server/node_modules" \
                 "${DASHBOARD_DIR}/server/node_modules"
    echo "==> [bootstrap] Bind-mounted server/node_modules → ext4"
  fi
fi

echo "==> [bootstrap] Running npm install in client/ ..."
npm install --prefix "${DASHBOARD_DIR}/client"

echo "==> [bootstrap] Running npm install in server/ ..."
npm install --prefix "${DASHBOARD_DIR}/server"

# ── 4. Pre-populate filers.json if not already configured ─────────────────────
FILERS_JSON="${DASHBOARD_DIR}/config/filers.json"
mkdir -p "${DASHBOARD_DIR}/config"

should_write_filers=true
if [ -f "${FILERS_JSON}" ]; then
  # Check if it has actual filer entries (non-empty filers array)
  if command -v node &>/dev/null; then
    filer_count=$(node -e "
      try {
        const d = JSON.parse(require('fs').readFileSync('${FILERS_JSON}', 'utf8'));
        console.log(d.filers && d.filers.length > 0 ? 'has_filers' : 'empty');
      } catch(e) { console.log('empty'); }
    " 2>/dev/null || echo "empty")
    if [ "${filer_count}" = "has_filers" ]; then
      echo "==> [bootstrap] filers.json already configured, skipping."
      should_write_filers=false
    fi
  fi
fi

if [ "${should_write_filers}" = "true" ]; then
  echo "==> [bootstrap] Writing default filers.json ..."
  FILERS_TMP="${FILERS_JSON}.tmp.$$"
  cat > "${FILERS_TMP}" << 'EOF'
{
  "filers": [
    {
      "name": "nfs1",
      "type": "HNAS",
      "host": "192.168.56.10",
      "target_folder": "/HNAS/",
      "mount_options": "ro,soft,vers=3"
    },
    {
      "name": "nfs2",
      "type": "NetApp",
      "host": "192.168.56.11",
      "target_folder": "/NetApp/",
      "mount_options": "ro,soft,vers=3"
    }
  ]
}
EOF
  mv "${FILERS_TMP}" "${FILERS_JSON}"
fi

# ── 5. Discover exports and populate shares.json ──────────────────────────────
SHARES_JSON="${DASHBOARD_DIR}/config/shares.json"

should_write_shares=true
if [ -f "${SHARES_JSON}" ]; then
  if command -v node &>/dev/null; then
    share_count=$(node -e "
      try {
        const d = JSON.parse(require('fs').readFileSync('${SHARES_JSON}', 'utf8'));
        console.log(d.shares && d.shares.length > 0 ? 'has_shares' : 'empty');
      } catch(e) { console.log('empty'); }
    " 2>/dev/null || echo "empty")
    if [ "${share_count}" = "has_shares" ]; then
      echo "==> [bootstrap] shares.json already populated, skipping discovery."
      should_write_shares=false
    fi
  fi
fi

if [ "${should_write_shares}" = "true" ]; then
  echo "==> [bootstrap] Discovering NFS exports via showmount ..."

  declare -a ALL_SHARES=()

  # Discover from nfs1 with 10-second timeout
  echo "  -> Running: timeout 10 showmount -e 192.168.56.10"
  NFS1_OUTPUT=$(timeout 10 showmount -e 192.168.56.10 --no-headers 2>/dev/null || echo "TIMEOUT_OR_ERROR")
  if [ "${NFS1_OUTPUT}" = "TIMEOUT_OR_ERROR" ]; then
    echo "  -> WARNING: showmount timed out or failed for 192.168.56.10 (nfs1)"
  else
    while IFS= read -r line; do
      export_path=$(echo "${line}" | awk '{print $1}')
      [ -z "${export_path}" ] && continue
      ALL_SHARES+=("{\"filer\":\"nfs1\",\"export\":\"${export_path}\"}")
    done <<< "${NFS1_OUTPUT}"
    echo "  -> Discovered $(echo "${NFS1_OUTPUT}" | wc -l) exports from nfs1"
  fi

  # Discover from nfs2 with 10-second timeout
  echo "  -> Running: timeout 10 showmount -e 192.168.56.11"
  NFS2_OUTPUT=$(timeout 10 showmount -e 192.168.56.11 --no-headers 2>/dev/null || echo "TIMEOUT_OR_ERROR")
  if [ "${NFS2_OUTPUT}" = "TIMEOUT_OR_ERROR" ]; then
    echo "  -> WARNING: showmount timed out or failed for 192.168.56.11 (nfs2)"
  else
    while IFS= read -r line; do
      export_path=$(echo "${line}" | awk '{print $1}')
      [ -z "${export_path}" ] && continue
      ALL_SHARES+=("{\"filer\":\"nfs2\",\"export\":\"${export_path}\"}")
    done <<< "${NFS2_OUTPUT}"
    echo "  -> Discovered $(echo "${NFS2_OUTPUT}" | wc -l) exports from nfs2"
  fi

  # Write shares.json atomically
  SHARES_TMP="${SHARES_JSON}.tmp.$$"
  {
    echo '{"shares":['
    joined=""
    for entry in "${ALL_SHARES[@]+"${ALL_SHARES[@]}"}"; do
      if [ -z "${joined}" ]; then
        joined="${entry}"
      else
        joined="${joined},${entry}"
      fi
    done
    echo "${joined}"
    echo ']}'
  } > "${SHARES_TMP}"
  mv "${SHARES_TMP}" "${SHARES_JSON}"
  echo "==> [bootstrap] shares.json written with ${#ALL_SHARES[@]} entries."
fi

# ── 6. Run mount_shares.sh ────────────────────────────────────────────────────
echo "==> [bootstrap] Running mount_shares.sh ..."
if bash "${DASHBOARD_DIR}/scripts/mount_shares.sh"; then
  MOUNT_EXIT=0
else
  MOUNT_EXIT=$?
  echo "==> [bootstrap] WARNING: mount_shares.sh exited with code ${MOUNT_EXIT}. Continuing."
fi

# Count how many shares are now mounted
MOUNTED_COUNT=$(mount | grep -c "nfs" 2>/dev/null || echo "0")

# ── 7. Optionally start dashboard ─────────────────────────────────────────────
DASHBOARD_STARTED="no"
if [ "${LAUNCH_DASHBOARD}" = "true" ]; then
  echo "==> [bootstrap] Starting dashboard via systemd-run ..."

  # Source nvm for devuser context
  DEVUSER_NVM="${NVM_DIR}/nvm.sh"

  systemd-run \
    --unit=nas-dashboard \
    --uid="$(id -u devuser)" \
    --working-directory="${DASHBOARD_DIR}" \
    /bin/bash -c "source ${DEVUSER_NVM} && nvm use 22 && npm run dev" \
    2>/dev/null || true

  # Wait up to 15 seconds for port 3000
  echo "==> [bootstrap] Waiting for port 3000 ..."
  for i in $(seq 1 15); do
    if bash -c "echo > /dev/tcp/localhost/3000" 2>/dev/null; then
      DASHBOARD_STARTED="yes"
      break
    fi
    sleep 1
  done

  if [ "${DASHBOARD_STARTED}" = "yes" ]; then
    echo ""
    echo "Dashboard running at: http://192.168.56.20:3000"
    echo ""
  else
    echo "==> [bootstrap] WARNING: Port 3000 not available after 15 seconds."
    echo "==> [bootstrap] Dashboard may still be starting. Check: systemctl status nas-dashboard"
  fi
fi

# ── 8. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  Bootstrap Summary                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║ Node.js version : ${NODE_VERSION:-unknown}"
echo "║ Shares mounted  : ${MOUNTED_COUNT}"
echo "║ Dashboard started: ${DASHBOARD_STARTED}"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
