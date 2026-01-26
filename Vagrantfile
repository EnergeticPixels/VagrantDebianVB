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
  config.ssh.insert_key = false
  config.ssh.private_key_path = ["keys/.ssh/vagrant_rsa", "~/.vagrant.d/insecure_private_key"]
  config.vm.provision "file", source: "keys/.ssh/vagrant_rsa.pub", destination: "~/.ssh/authorized_keys"
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
    
    # Node Version Manager (NVM is not a part of debian respositories yet)
    NVM_VERSION="v0.39.7"   # pin nvm version for reproducibility
    NVM_DIR="/home/vagrant/.nvm"
    USER_SHELL_RC="/home/vagrant/.bashrc"   # adjust if you use zsh
    # Create nvm dir and set ownership early (idempotent)
    mkdir -p "$NVM_DIR"
    chown -R vagrant:vagrant "$NVM_DIR"
    # Install nvm only if not already present
    if ! sudo -u vagrant -H bash -lc 'command -v nvm >/dev/null 2>&1'; then
      echo "Installing nvm ${NVM_VERSION} for user 'vagrant'..."
      sudo -u vagrant -H bash -lc "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
    else
      echo "nvm already installed; skipping."
    fi
    # Ensure nvm is loaded in the user's shell (idempotent append)
    if ! sudo -u vagrant -H bash -lc "grep -q 'NVM_DIR' '${USER_SHELL_RC}'"; then
      echo 'export NVM_DIR="$HOME/.nvm"' >> "${USER_SHELL_RC}"
      echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "${USER_SHELL_RC}"
      echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "${USER_SHELL_RC}"
      chown vagrant:vagrant "${USER_SHELL_RC}"
    fi
    # Load nvm in this provisioning session and install Node (optional)
    if sudo -u vagrant -H bash -lc 'command -v nvm >/dev/null 2>&1'; then
      # Install the latest LTS Node if not already present (idempotent)
      sudo -u vagrant -H bash -lc '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        if ! nvm ls --no-colors | grep -q "->.*lts"; then
          nvm install --lts
          nvm alias default lts/*
        fi
      '
    fi

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
end
