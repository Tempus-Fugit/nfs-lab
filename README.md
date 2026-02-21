# nfs-lab

Vagrant lab with three VMs on a private host-only network simulating an enterprise NFS environment.

| VM         | OS            | IP              | Role                        |
|------------|---------------|-----------------|-----------------------------|
| nfs1       | Alpine 3.19   | 192.168.56.10   | NFS server, 17 shares       |
| nfs2       | Alpine 3.19   | 192.168.56.11   | NFS server, 16 shares       |
| nfsclient  | Rocky Linux 9 | 192.168.56.20   | NFS client, dashboard host  |

---

## Prerequisites

- **VirtualBox 7.0+** — https://www.virtualbox.org/wiki/Downloads
- **Vagrant 2.3.4+** — https://developer.hashicorp.com/vagrant/downloads
- The `../nas-dashboard` directory must exist relative to `nfs-lab/` (it is mounted into nfsclient as `/opt/nas-dashboard`)

### Optional: Local box cache

If Vagrant cannot download boxes from the cloud, you can place local box files in `nfs-lab/vagrantBoxes/` and they will be used first.

Supported filenames:

- `nfs-lab/vagrantBoxes/generic-alpine319.box` or `nfs-lab/vagrantBoxes/alpine319.box`
- `nfs-lab/vagrantBoxes/generic-rocky9.box` or `nfs-lab/vagrantBoxes/rocky9.box`

You can also point directly to box files with environment variables:

- `NFS_LAB_BOX_ALPINE` (full path to Alpine box)
- `NFS_LAB_BOX_ROCKY` (full path to Rocky box)
- `NFS_LAB_BOX_DIR` (override the `vagrantBoxes/` directory)

---

## Quickstart

### Provision without starting the dashboard

```bash
vagrant up
```

All three VMs are provisioned. The NFS servers export their shares. The client mounts them. The dashboard application is installed but not started.

### Provision and auto-start the dashboard

```bash
LAUNCH_DASHBOARD=true vagrant up
```

After provisioning completes, the dashboard will be available at:

```
http://192.168.56.20:3000
```

---

## Connecting to VMs

### vagrant ssh (recommended)

```bash
vagrant ssh nfs1
vagrant ssh nfs2
vagrant ssh nfsclient
```

### Direct SSH using generated keypair

An SSH keypair is generated automatically at `ssh/id_rsa` on first `vagrant up`. The private key is `.gitignore`d.

```bash
ssh -i ssh/id_rsa devuser@192.168.56.10   # nfs1
ssh -i ssh/id_rsa devuser@192.168.56.11   # nfs2
ssh -i ssh/id_rsa devuser@192.168.56.20   # nfsclient
```

### SSH config block (add to `~/.ssh/config`)

```
Host nfs1
  HostName 192.168.56.10
  User devuser
  IdentityFile /path/to/nfs-lab/ssh/id_rsa

Host nfs2
  HostName 192.168.56.11
  User devuser
  IdentityFile /path/to/nfs-lab/ssh/id_rsa

Host nfsclient
  HostName 192.168.56.20
  User devuser
  IdentityFile /path/to/nfs-lab/ssh/id_rsa
```

---

## NFS Share Structure

### nfs1 (192.168.56.10) — 17 shares

| Export Path              |
|--------------------------|
| /exports/finance         |
| /exports/hr              |
| /exports/engineering     |
| /exports/legal           |
| /exports/operations      |
| /exports/marketing       |
| /exports/devops          |
| /exports/security        |
| /exports/compliance      |
| /exports/research        |
| /exports/it-support      |
| /exports/executive       |
| /exports/logistics       |
| /exports/procurement     |
| /exports/infrastructure  |
| /exports/analytics       |
| /exports/training        |

### nfs2 (192.168.56.11) — 16 shares

| Export Path              |
|--------------------------|
| /exports/operations      |
| /exports/marketing       |
| /exports/devops          |
| /exports/security        |
| /exports/compliance      |
| /exports/research        |
| /exports/it-support      |
| /exports/executive       |
| /exports/logistics       |
| /exports/procurement     |
| /exports/infrastructure  |
| /exports/analytics       |
| /exports/training        |
| /exports/facilities      |
| /exports/qa-testing      |
| /exports/product         |

Each share contains 15–20 subdirectories. Each subdirectory contains 15–20 files with realistic department-appropriate names and dummy content.

---

## Mounting Shares

The `mount_shares.sh` script reads `config/filers.json` and `config/shares.json` from the nas-dashboard repo and mounts each share at its configured target folder.

**nfs1 shares** mount under `/HNAS/` (e.g., `/HNAS/engineering`)
**nfs2 shares** mount under `/NetApp/` (e.g., `/NetApp/product`)

### Run mount script manually (on nfsclient)

```bash
sudo bash /opt/nas-dashboard/scripts/mount_shares.sh

# Dry run (see what would be mounted):
sudo bash /opt/nas-dashboard/scripts/mount_shares.sh --dry-run

# Unmount all configured shares:
sudo bash /opt/nas-dashboard/scripts/mount_shares.sh --unmount-all

# Discover available exports:
sudo bash /opt/nas-dashboard/scripts/mount_shares.sh --discover
```

---

## Day-to-Day Operations

### Start all VMs

```bash
vagrant up
```

### Stop all VMs (saves state)

```bash
vagrant halt
```

### Start the dashboard on a running nfsclient

```bash
vagrant ssh nfsclient -- "LAUNCH_DASHBOARD=true bash /vagrant/scripts/bootstrap.sh"
```

Or SSH in directly and run:

```bash
cd /opt/nas-dashboard
npm run dev
```

### Re-run provisioning (re-provision without destroying)

```bash
vagrant provision nfsclient
```

### Re-run bootstrap only (faster than full re-provision)

```bash
vagrant ssh nfsclient -- "sudo bash /vagrant/scripts/bootstrap.sh"
```

### Rebuild a single VM from scratch

```bash
vagrant destroy nfsclient -f
vagrant up nfsclient
```

### Rebuild everything from scratch

```bash
vagrant destroy -f
vagrant up
```

---

## Re-running Validation

Run from inside nfsclient:

```bash
sudo bash /vagrant/scripts/validate.sh
```

Or from the host:

```bash
vagrant ssh nfsclient -- "sudo bash /vagrant/scripts/validate.sh"
```

---

## Troubleshooting

### Mounts fail silently (SELinux)

Rocky Linux 9 has SELinux enforcing by default. If mounts succeed (`mount` output shows them) but files are inaccessible, check for AVC denials:

```bash
ausearch -m avc -ts recent
```

To allow NFS mounts temporarily for debugging:

```bash
setenforce 0
```

To make it permanent (not recommended for production):

```bash
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### showmount timeout

If `showmount -e 192.168.56.10` hangs, the NFS server may not be running. Check:

```bash
vagrant ssh nfs1 -- "rc-service nfs status && exportfs -v"
```

All showmount calls in this project enforce a 10-second timeout.

### Shared folder `/opt/nas-dashboard` not mounting

The VirtualBox Guest Additions must be installed on nfsclient. If the synced folder fails:

```bash
vagrant plugin install vagrant-vbguest
vagrant up --provision
```

Or check the VirtualBox Guest Additions version:

```bash
vagrant ssh nfsclient -- "VBoxClient --version"
```

### Dashboard not starting

1. Check if port 3000 is listening:
   ```bash
   vagrant ssh nfsclient -- "ss -tlnp | grep 3000"
   ```

2. Check systemd-run unit:
   ```bash
   vagrant ssh nfsclient -- "systemctl status nas-dashboard"
   ```

3. Check if Node is installed for devuser:
   ```bash
   vagrant ssh nfsclient -- "sudo -i -u devuser bash -c 'node -v'"
   ```

4. Re-run bootstrap manually with dashboard launch:
   ```bash
   vagrant ssh nfsclient -- "LAUNCH_DASHBOARD=true sudo bash /vagrant/scripts/bootstrap.sh"
   ```

### npm install fails during provisioning (vboxsf symlink error)

VirtualBox shared folders (vboxsf) cannot create symlinks. bootstrap.sh handles this
automatically by bind-mounting local ext4 directories over the `node_modules` paths
inside the vboxsf mount, so npm writes to native ext4 where symlinks work normally.

During provisioning you should see:

```
==> nfsclient: ==> [bootstrap] vboxsf detected – bind-mounting node_modules onto local ext4 ...
==> nfsclient: ==> [bootstrap] Bind-mounted client/node_modules → ext4
==> nfsclient: ==> [bootstrap] Bind-mounted server/node_modules → ext4
==> nfsclient: added N packages ...
```

If `npm install` still fails, check that bootstrap.sh is running as root (it is by
default via the Vagrant shell provisioner — do not run it as devuser directly).

**After a VM reboot (not destroy)** the bind mounts are gone but the modules are still
present on ext4 at `/home/devuser/.nas-dashboard-modules/`. Re-run bootstrap to
restore them and restart the dashboard:

```bash
vagrant ssh nfsclient -- "sudo bash /vagrant/scripts/bootstrap.sh"
```

To verify the bind mounts are active:

```bash
vagrant ssh nfsclient -- "mount | grep nas-dashboard"
```

You should see two `bind` entries — one for `client/node_modules` and one for
`server/node_modules`.

### VM gets wrong IP / network conflict

If `192.168.56.x` conflicts with an existing host network, edit `Vagrantfile` and change the IPs in the `private_network` lines and update `filers.json` accordingly.

---

## Teardown

```bash
# Stop VMs, preserve disk state
vagrant halt

# Destroy all VMs completely (prompts for each)
vagrant destroy

# Destroy all VMs without prompts
vagrant destroy -f
```

After `vagrant destroy`, the `ssh/` keypair is preserved on disk. Delete manually if desired:

```bash
rm ssh/id_rsa ssh/id_rsa.pub
```
