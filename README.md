<header style="text-align: center";>
    <h1>My Debian 13 Vagrant/VirtualBox</h1>
    <h2>Used for App development and Moodle testing</h2>
</header>

### Developed with
- VM: VirtualBox v7.2.2 with Extension Pack
- Vagrant v2.4.9
- Base Linux: Boxen/debian-13
  - Virtual Memory: 2G
  - CPUs: 2 (dynamic 50% of host machine)
  - Shared 'Data' folder:
    - host: ./app_data
    - guest: /vagrant_data
  - Supplies its own ssh keys (found issues with serco machines.)
    - reference: https://www.devopsroles.com/vagrant-ssh-key-pair/
  - Boot time extended to 6 minutes for implementations with Serco hosts.

### Provisioning with:
- Common: ca-certificates apt-transport-https curl gnupg2 lsb-release git wget build-essential libssl-dev
- Web Dev:
  - Apache2
  - PHP via the Sury package
    - Selectable PHP versions (default 7.4)
    - Sample PHP driven page (testphp.php) to prove PHP was installed correctly. Copied to /var/www/html with appropriate permissions.
  - PostgreSQL via postgresql-common
    - Selectable PG versions (default 15)
    - Description of programming process (readme)[./README_PG-DB.md]
  - SSL support
    - Description of programming process (readme)[./README_SSL.md]
  - Environment variables
    - Copy .env.sample to .env. Change values as required.
  - Node Version Manager (NVM)
    - Selectable node.js version via terminal (no default)

### Constraints
- Built with Vagrant 2.4.9 (other versions, your milage may vary)
- Vagrant plugins installed:
  - vagrant-env
  - vagrant-hostmanager
- Vagrant project only works within bash shell
- User will need admin rights to Windows UAC due hostmanager requirements
 