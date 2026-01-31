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

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "boxen/debian-13"
  config.vm.box_version = "2025.08.20.12"
  config.vm.box_check_update = false
  project_root = File.expand_path(ENV['VAGRANT_CWD'] || Dir.pwd)

  
  # --- Switch to host (project) key after the first successful provision+reload ---
  if File.exist?(File.join(project_root, '.vagrant', 'hostkey_ready'))
    config.ssh.private_key_path = [
      File.join(project_root, '.vagrant_keys', 'vagrant_ed25519').tr('\\','/')
    ]
    # Enforce key-only auth (no password fallback)
    config.ssh.password  = nil
    config.ssh.keys_only = true
  end

  # ------------------------------------------------------------------
  # BEFORE 'vagrant up': generate SSH keypair on the Windows host
  # ------------------------------------------------------------------
  config.trigger.before :up do |t|
    t.name = "Generate SSH keypair on host (Windows)"
    t.run  = {
      inline: "powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"scripts/host/generate_ssh_keys.ps1\" -KeyDir \"#{project_root}/.vagrant_keys\" -KeyName vagrant_ed25519"
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
  # We gate the SSH key path with an env var to avoid first-boot auth failure.
  # ------------------------------------------------------------------
  config.trigger.after :provision do |t|
    t.name = "Switch SSH to host key"
    t.run = {
      inline: "powershell -NoLogo -NoProfile -Command \"New-Item -ItemType File -Force -Path '.vagrant/hostkey_ready' > $null; vagrant reload --no-provision\""
    }
  end

# ------------------------------------------------------------------
# BEFORE 'vagrant destroy': cleanup host keys (Windows host)
# ------------------------------------------------------------------
  config.trigger.before :destroy do |t|
  t.name = "Cleanup SSH keys on host (Windows)"
    t.run  = {
      inline: "powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"scripts/host/cleanup_ssh_keys.ps1\" -KeyDir \"#{project_root}/.vagrant_keys\" -KeyName vagrant_ed25519"
    }
  end
  # Remove the marker once destruction finishes (optional)
  config.trigger.after :destroy do |t|
    t.name = "Remove host-key marker"
    t.run = {
      inline: "powershell -NoLogo -NoProfile -Command \"Remove-Item -Force '.vagrant/hostkey_ready' -ErrorAction SilentlyContinue\""
    }
  end


# ------------------------------------------------------------------
# END OF SSH MANAGEMENT
# ------------------------------------------------------------------



  # time out increased to see if it will help when building box on serco machine
  config.vm.boot_timeout = 360

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # *****  TODO: FIX THIS.  has issues in Serco host machine  ********
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder "./app_data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
    # vb.gui = true
    vb.gui = false
  
    # Customize the amount of memory on the VM:
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
  end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail

    apt-get update
    apt-get dist-upgrade -y
    # common OS modules forming base of other applications
    apt-get install -y ca-certificates apt-transport-https curl gnupg2 lsb-release git wget build-essential libssl-dev
    apt-get update
    
    # Method on how to get different versions of PHP into Debian 
    # Debian deprecated add-apt-repository ppa:.. methods
    # reference https://www.devtutorial.io/how-to-install-php-7-4-on-debian-13-p3905.html
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
    apt-get update
    
    # Node Version Manager moved to an external script

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
    sudo apt-get install -y postgresql-common
    sudo install -d /usr/share/postgresql-common/pgdg
    sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
    . /etc/os-release
    sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
    sudo apt-get update
    sudo apt-get install -y postgresql-15

    
  SHELL

  # Separate NVM provisioning moved to script
  config.vm.provision "shell", path: "scripts/guest/install_nvm.sh"
end
