#!/usr/bin/env bash
# validate.sh – Post-provisioning validation for nfsclient.
# Can be run manually at any time:
#   sudo bash /vagrant/scripts/validate.sh
#
# Exit 0 if all checks pass, exit 1 if any fail.

PASS=0
FAIL=0
RESULTS=()

check() {
  local label="$1"
  local result="$2"
  if [ "${result}" = "pass" ]; then
    RESULTS+=("  [PASS] ${label}")
    (( PASS++ ))
  else
    RESULTS+=("  [FAIL] ${label}")
    (( FAIL++ ))
  fi
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           NFS Lab Validation Report                      ║"
echo "╠══════════════════════════════════════════════════════════╣"

# 1. nfs-utils is installed
if rpm -q nfs-utils &>/dev/null; then
  check "nfs-utils is installed" "pass"
else
  check "nfs-utils is installed" "fail"
fi

# 2. /HNAS directory exists
if [ -d "/HNAS" ]; then
  check "/HNAS directory exists" "pass"
else
  check "/HNAS directory exists" "fail"
fi

# 3. /NetApp directory exists
if [ -d "/NetApp" ]; then
  check "/NetApp directory exists" "pass"
else
  check "/NetApp directory exists" "fail"
fi

# 4. /opt/nas-dashboard exists and is non-empty
if [ -d "/opt/nas-dashboard" ] && [ -n "$(ls -A /opt/nas-dashboard 2>/dev/null)" ]; then
  check "/opt/nas-dashboard exists and is non-empty" "pass"
else
  check "/opt/nas-dashboard exists and is non-empty" "fail"
fi

# 5. nfs1 (192.168.56.10) is reachable
if ping -c 1 -W 2 192.168.56.10 &>/dev/null; then
  check "nfs1 (192.168.56.10) is reachable" "pass"
else
  check "nfs1 (192.168.56.10) is reachable" "fail"
fi

# 6. nfs2 (192.168.56.11) is reachable
if ping -c 1 -W 2 192.168.56.11 &>/dev/null; then
  check "nfs2 (192.168.56.11) is reachable" "pass"
else
  check "nfs2 (192.168.56.11) is reachable" "fail"
fi

# 7. Node.js is installed
if command -v node &>/dev/null; then
  NODE_VER=$(node -v 2>/dev/null || echo "unknown")
  check "Node.js installed (${NODE_VER})" "pass"
else
  # Also check via nvm for devuser
  if [ -s "/home/devuser/.nvm/nvm.sh" ]; then
    NODE_VER=$(sudo -i -u devuser bash -c "source ~/.nvm/nvm.sh && node -v" 2>/dev/null || echo "")
    if [ -n "${NODE_VER}" ]; then
      check "Node.js installed via nvm (${NODE_VER})" "pass"
    else
      check "Node.js is installed" "fail"
    fi
  else
    check "Node.js is installed" "fail"
  fi
fi

# 8. /opt/nas-dashboard/config/filers.json exists and is non-empty
if [ -f "/opt/nas-dashboard/config/filers.json" ] && \
   [ -s "/opt/nas-dashboard/config/filers.json" ]; then
  check "config/filers.json exists and is non-empty" "pass"
else
  check "config/filers.json exists and is non-empty" "fail"
fi

# Print results
for line in "${RESULTS[@]}"; do
  echo "${line}"
done

echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Total: ${PASS} passed, ${FAIL} failed"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

if [ "${FAIL}" -gt 0 ]; then
  exit 1
else
  echo "All checks passed."
  exit 0
fi
