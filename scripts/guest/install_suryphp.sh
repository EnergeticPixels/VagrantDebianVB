# Method on how to get different versions of PHP into Debian 
# Debian deprecated add-apt-repository ppa:.. methods
# reference https://www.devtutorial.io/how-to-install-php-7-4-on-debian-13-p3905.html

set -euo pipefail

wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
apt-get update