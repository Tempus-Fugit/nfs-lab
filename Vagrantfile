# -*- mode: ruby -*-
# vi: set ft=ruby :

# Generate SSH keypair at ssh/id_rsa and ssh/id_rsa.pub if not already present.
# The private key is .gitignored; only the public key matters for provisioning.
SSH_DIR = File.join(File.dirname(__FILE__), "ssh")
SSH_KEY_PRIVATE = File.join(SSH_DIR, "id_rsa")
SSH_KEY_PUBLIC  = File.join(SSH_DIR, "id_rsa.pub")

unless File.exist?(SSH_KEY_PRIVATE)
  puts "==> Generating SSH keypair at ssh/id_rsa ..."
  system("ssh-keygen -t rsa -b 2048 -f #{SSH_KEY_PRIVATE} -N '' -C 'vagrant-nfs-lab' -q")
end

SSH_PUB_KEY = File.exist?(SSH_KEY_PUBLIC) ? File.read(SSH_KEY_PUBLIC).strip : ""

# Pass LAUNCH_DASHBOARD from host environment through to provisioner.
LAUNCH_DASHBOARD = ENV.fetch("LAUNCH_DASHBOARD", "false")

# Optional: prefer local box files to avoid cloud download issues.
BOX_DIR = ENV.fetch("NFS_LAB_BOX_DIR", File.join(File.dirname(__FILE__), "vagrantBoxes"))

def resolve_local_box(box_name, env_key, box_dir)
  env_path = ENV[env_key]
  if env_path && File.exist?(env_path)
    return env_path
  elsif env_path
    warn "==> #{env_key} set but not found at: #{env_path}"
  end

  return nil unless Dir.exist?(box_dir)

  candidates = [
    File.join(box_dir, "#{box_name.tr('/', '-')}.box"),
    File.join(box_dir, "#{box_name.split('/').last}.box"),
  ]

  candidates.find { |path| File.exist?(path) }
end

ALPINE_BOX = resolve_local_box("generic/alpine319", "NFS_LAB_BOX_ALPINE", BOX_DIR)
ROCKY_BOX  = resolve_local_box("generic/rocky9", "NFS_LAB_BOX_ROCKY", BOX_DIR)

puts "==> Using local box for generic/alpine319: #{ALPINE_BOX}" if ALPINE_BOX
puts "==> Using local box for generic/rocky9: #{ROCKY_BOX}" if ROCKY_BOX

Vagrant.configure("2") do |config|

  # ------------------------------------------------------------------ #
  # nfs1 – Alpine 3.19, NFS server, 17 shares                          #
  # ------------------------------------------------------------------ #
  config.vm.define "nfs1" do |nfs1|
    nfs1.vm.box      = "generic/alpine319"
    nfs1.vm.box_url  = ALPINE_BOX if ALPINE_BOX
    nfs1.vm.hostname = "nfs1"
    nfs1.vm.network  "private_network", ip: "192.168.56.10"

    nfs1.vm.provider "virtualbox" do |vb|
      vb.name   = "nfs-lab-nfs1"
      vb.memory = 512
      vb.cpus   = 1
    end

    # Disable default /vagrant synced folder on NFS servers.
    # We use file provisioners to upload the scripts we need instead.
    nfs1.vm.synced_folder ".", "/vagrant", disabled: true

    # Upload required scripts to /tmp/nfs-lab-scripts/ on the VM
    nfs1.vm.provision "file",
      source:      "scripts/generate_shares.sh",
      destination: "/tmp/nfs-lab-scripts/generate_shares.sh"

    nfs1.vm.provision "shell",
      path: "scripts/provision_server.sh",
      args: ["nfs1", SSH_PUB_KEY]
  end

  # ------------------------------------------------------------------ #
  # nfs2 – Alpine 3.19, NFS server, 16 shares                          #
  # ------------------------------------------------------------------ #
  config.vm.define "nfs2" do |nfs2|
    nfs2.vm.box      = "generic/alpine319"
    nfs2.vm.box_url  = ALPINE_BOX if ALPINE_BOX
    nfs2.vm.hostname = "nfs2"
    nfs2.vm.network  "private_network", ip: "192.168.56.11"

    nfs2.vm.provider "virtualbox" do |vb|
      vb.name   = "nfs-lab-nfs2"
      vb.memory = 512
      vb.cpus   = 1
    end

    nfs2.vm.synced_folder ".", "/vagrant", disabled: true

    nfs2.vm.provision "file",
      source:      "scripts/generate_shares.sh",
      destination: "/tmp/nfs-lab-scripts/generate_shares.sh"

    nfs2.vm.provision "shell",
      path: "scripts/provision_server.sh",
      args: ["nfs2", SSH_PUB_KEY]
  end

  # ------------------------------------------------------------------ #
  # nfsclient – Rocky Linux 9, NFS client, dashboard host              #
  # nfsclient must not start provisioning until nfs1 and nfs2 are done #
  # (Vagrant provisions VMs in definition order by default)            #
  # ------------------------------------------------------------------ #
  config.vm.define "nfsclient" do |client|
    client.vm.box      = "generic/rocky9"
    client.vm.box_url  = ROCKY_BOX if ROCKY_BOX
    client.vm.hostname = "nfsclient"
    client.vm.network  "private_network", ip: "192.168.56.20"

    client.vm.provider "virtualbox" do |vb|
      vb.name   = "nfs-lab-nfsclient"
      vb.memory = 1024
      vb.cpus   = 1
    end

    # Live two-way shared folder: ../nas-dashboard → /opt/nas-dashboard
    # Changes on either side are reflected immediately.
    client.vm.synced_folder "../nas-dashboard", "/opt/nas-dashboard",
      type:   "virtualbox",
      create: true

    # Default /vagrant synced folder kept for script access (validate.sh, bootstrap.sh)
    client.vm.synced_folder ".", "/vagrant", type: "virtualbox"

    client.vm.provision "shell",
      path: "scripts/provision_client.sh",
      env:  { "LAUNCH_DASHBOARD" => LAUNCH_DASHBOARD, "NFS_LAB_SSH_PUB_KEY" => SSH_PUB_KEY }
  end

  # Print dashboard URL after everything is up if LAUNCH_DASHBOARD is set
  if LAUNCH_DASHBOARD == "true"
    config.trigger.after :up do |trigger|
      trigger.info = "Dashboard running at: http://192.168.56.20:3000"
    end
  end

end
