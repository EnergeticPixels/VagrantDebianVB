# installs base components needed for other full build-out apps
set -euo pipefail

apt-get update
apt-get dist-upgrade -y
apt-get install -y ca-certificates apt-transport-https curl gnupg2 lsb-release git wget build-essential libssl-dev
apt-get update