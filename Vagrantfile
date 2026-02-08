# -*- mode: ruby -*-
# vi: set ft=ruby :

# Place this blurb at the top of your Vagrantfile to allow the unpatched
# version of the Vagrant vagrant-vbguest plugin to properly execute
# in newer Ruby environments where File.exists is no longer supported.
# Extend the Ruby File class to restore the deprecated exists method
# calls File.exist instead
unless File.respond_to?(:exists?)
  class << File
    def exists?(path)
      warn "File.exists? is deprecated; use File.exist? instead." unless ENV['SUPPRESS_FILE_EXISTS_WARNING']
      exist?(path)
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "boxen/debian-13"
  config.vm.box_version = "2025.08.20.12"
  config.vm.box_check_update = false
  project_root = File.expand_path(ENV['VAGRANT_CWD'] || Dir.pwd)

  # ------------------------------------------------------------------
# SSH KEY MANAGEMENT
# ------------------------------------------------------------------
# --- Switch to host (project) key after the first successful provision+reload ---
if File.exist?(File.join(project_root, '.vagrant', 'hostkey_ready'))
  config.ssh.private_key_path = [
    File.join(project_root, '.vagrant_keys', 'vagrant_ed25519').tr('\\','/')
  ]
  config.ssh.password  = nil
  config.ssh.keys_only = true
end

# ------------------------------------------------------------------
# BEFORE 'vagrant up': generate SSH keypair on the host using Bash
# ------------------------------------------------------------------
config.trigger.before :up do |t|
  t.name = "Generate SSH keypair on host (Bash)"
  t.run  = {
    inline: %Q(sh -lc 'chmod +x "#{project_root}/scripts/host/generate_ssh_keys.sh" "#{project_root}/scripts/host/cleanup_ssh_keys.sh" && "#{project_root}/scripts/host/generate_ssh_keys.sh" --key-dir "#{project_root}/.vagrant_keys" --key-name vagrant_ed25519')
  }
end

# First boot uses the box's default (insecure) key so provisioners can run
config.ssh.insert_key = false

# ------------------------------------------------------------------
# Copy public key into guest, append idempotently to authorized_keys
# ------------------------------------------------------------------
config.vm.provision "file",
  source: File.join(project_root, '.vagrant_keys', 'vagrant_ed25519.pub'),
  destination: "/home/vagrant/vagrant_ed25519.pub"

config.vm.provision "shell", inline: <<-SHELL
  set -e
  SSH_DIR="/home/vagrant/.ssh"
  PUB_KEY="/home/vagrant/vagrant_ed25519.pub"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  chown vagrant:vagrant "$SSH_DIR"

  touch "$SSH_DIR/authorized_keys"
  if ! grep -qxF "$(cat "$PUB_KEY")" "$SSH_DIR/authorized_keys"; then
    cat "$PUB_KEY" >> "$SSH_DIR/authorized_keys"
  fi

  chmod 600 "$SSH_DIR/authorized_keys"
  chown vagrant:vagrant "$SSH_DIR/authorized_keys"
  rm -f "$PUB_KEY"
SHELL

# ------------------------------------------------------------------
# AFTER provision: reload and switch SSH to the host key
# ------------------------------------------------------------------
config.trigger.after :provision do |t|
  t.name = "Switch SSH to host key"
  t.run = {
    inline: %Q(sh -lc 'mkdir -p "#{project_root}/.vagrant" && : > "#{project_root}/.vagrant/hostkey_ready" && vagrant reload --no-provision')
  }
end

# ------------------------------------------------------------------
# BEFORE 'vagrant destroy': cleanup host keys (Bash)
# ------------------------------------------------------------------
config.trigger.before :destroy do |t|
  t.name = "Cleanup SSH keys on host (Bash)"
  t.run  = {
    inline: %Q(sh -lc 'chmod +x "#{project_root}/scripts/host/cleanup_ssh_keys.sh" && "#{project_root}/scripts/host/cleanup_ssh_keys.sh" --key-dir "#{project_root}/.vagrant_keys" --key-name vagrant_ed25519')
  }
end

# Remove the marker once destruction finishes (optional)
config.trigger.after :destroy do |t|
  t.name = "Remove host-key marker"
  t.run = {
    inline: %Q(sh -lc 'rm -f "#{project_root}/.vagrant/hostkey_ready"')
  }
end
# ------------------------------------------------------------------
# END OF SSH MANAGEMENT
# ------------------------------------------------------------------

  # time out increased to see if it will help when building box on serco machine
  config.vm.boot_timeout = 360

  config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # *****  TODO: FIX THIS.  has issues in Serco host machine  ********
  # config.vm.network "private_network", ip: "192.168.33.10"
  
  config.vm.synced_folder "./app_data", "/vagrant_data"

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
  end

# ------------------------------------------------------------------
# PROVISIONING
# ------------------------------------------------------------------
  # install base packages needed for other setups
  config.vm.provision "shell", path: "scripts/guest/install_base.sh"
  # Install NodeJS Version Manager (NVM)
  config.vm.provision "shell", path: "scripts/guest/install_nvm.sh"
  # install sury.php.org repository for multiple php versions
  config.vm.provision "shell", path: "scripts/guest/install_suryphp.sh"
  # install postgresql common to allow specific versions to be installed
  config.vm.provision "shell", path: "scripts/guest/install_pg-common.sh"

  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail

    # **** install specific version of PHP and properly enable
    apt-get update
    apt-get install -y php7.4
    apt-get install -y php7.4-fpm php7.4-cli php7.4-mysql php7.4-pgsql php7.4-curl php7.4-xsl php7.4-gd php7.4-common php7.4-xml php7.4-zip php7.4-xsl php7.4-soap php7.4-bcmath php7.4-mbstring php7.4-gettext php7.4-imagick
    a2enmod proxy_fcgi setenvif
    a2enconf php7.4-fpm

    # *** install apache
    apt-get install -y apache2
    sudo cp /vagrant_data/testphp.php /var/www/html
    chown www-data:www-data /var/www/html/testphp.php
    chmod 0755 /var/www/html/testphp.php

    #  postgres
    sudo apt-get install -y postgresql-15

  SHELL
  
end
