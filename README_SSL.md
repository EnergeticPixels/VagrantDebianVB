# SSL/HTTPS Development Setup

This Vagrant project is configured to automatically generate and manage self-signed SSL certificates for HTTPS development.

## Overview

The SSL setup includes:
- **Automatic certificate generation** via `install_ssl.sh`
- **Apache HTTPS configuration** with HTTP→HTTPS redirects
- **Clean certificate removal** via `destroy_ssl.sh`
- **Domain name management** using vagrant-hostmanager plugin

## Scripts

### `install_ssl.sh` — SSL Certificate Installation

**Location:** `scripts/guest/install_ssl.sh`

**What it does:**
1. Generates a self-signed SSL certificate (valid for 365 days)
2. Creates a private key (2048-bit RSA)
3. Configures Apache virtual hosts for HTTP and HTTPS
4. Enables required Apache modules: `mod_ssl`, `mod_rewrite`, `mod_headers`
5. Sets up automatic HTTP→HTTPS redirection
6. Validates Apache configuration before reload

**Key features:**
- **Idempotent** — Safe to run multiple times, won't regenerate certificates if they already exist
- **Domain-aware** — Uses `WEB_DNS` environment variable from `.env` file
- **Graceful errors** — Validates Apache config and shows clear error messages

**When it runs:**
- Automatically during `vagrant up` (first provisioning)
- Can be manually re-run: `vagrant provision`
- Does **NOT** run on `vagrant resume` (certificates already exist)

**Generated files:**
```
/etc/ssl/certs/web.local.crt        # Self-signed certificate
/etc/ssl/private/web.local.key      # Private key (600 permissions)
/etc/apache2/sites-available/web.local.conf  # Virtual host configuration
```

---

### `destroy_ssl.sh` — SSL Certificate Cleanup

**Location:** `scripts/guest/destroy_ssl.sh`

**What it does:**
1. Disables the Apache site configuration
2. Removes the virtual host configuration file
3. Deletes the private key and certificate
4. Validates Apache configuration
5. Reloads Apache to apply changes

**When it runs:**
- Automatically during `vagrant destroy` (before VM destruction)
- Ensures clean removal of all SSL-related files and configurations
- Runs via SSH before the VM is shut down

---

## Vagrantfile Configuration

The following changes were made to support SSL:

### 1. **Domain/Hostname Setup**
```ruby
domain_name = ENV['WEB_DNS'] || 'web.local'
config.vm.hostname = domain_name
```
Reads the domain from your `.env` file, falls back to `web.local`.

### 2. **Port Forwarding for HTTPS**
```ruby
config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
config.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1"
```
- Guest HTTP (80) → Host localhost:8080
- Guest HTTPS (443) → Host localhost:8443

### 3. **Host Manager Plugin**
```ruby
config.hostmanager.manage_host = true
config.hostmanager.manage_guest = true
config.hostmanager.aliases = ["www.#{domain_name}"]

config.vm.provision :hostmanager
```
Manages `/etc/hosts` on both host and guest machines.

### 4. **SSL Installation Provisioner**
```ruby
config.vm.provision "shell", path: "scripts/guest/install_ssl.sh", args: [ENV['WEB_DNS']]
```
Runs the SSL setup script during provisioning, passing the domain name.

### 5. **Destroy Trigger**
```ruby
config.trigger.before :destroy do |t|
  t.name = "Clean up SSL certificates"
  t.run = {
    inline: %Q(sh -lc 'vagrant ssh -c "bash /vagrant/scripts/guest/destroy_ssl.sh #{domain_name}"')
  }
end
```
Automatically cleans up SSL files when running `vagrant destroy`.

---

## Usage

### First-time Setup

```bash
vagrant up
```

**What to expect:**
1. VM boots and provisioning begins
2. SSL script generates certificates
3. **⚠️ Windows UAC Popup** — The vagrant-hostmanager plugin will request elevated privileges to update your Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`)
   - Click **Yes** to allow it
   - This only happens once (or when you reload the VM)
4. Apache is configured and reloaded
5. VM is ready for HTTPS development

### Working with your App

**From your host machine:**
```bash
# Access via domain with HTTPS
curl -k https://web.local:8443

# Access via IP address
curl -k https://127.0.0.1:8443

# In a browser
# https://web.local:8443
# (ignore the self-signed cert warning)
```

**From within the guest:**
```bash
vagrant ssh
curl -k https://web.local:443
```

### Between Development Sessions

```bash
# End session
vagrant halt

# Resume next time (no provisioning, instant startup)
vagrant resume
```

The certificates and configurations persist across `halt`/`resume` cycles.

### Clean Teardown

```bash
vagrant destroy -f
```

This will:
1. Run `destroy_ssl.sh` to cleanly remove certificates and configurations
2. Destroy the VM
3. Clean up SSH keys

### Changing Domains

To use a different domain:

1. **Edit `.env`:**
   ```bash
   export WEB_DNS=myapp.local
   ```

2. **Reload Vagrant:**
   ```bash
   vagrant reload
   ```

3. **Update your hosts file manually** (UAC may not work for domain changes):
   ```powershell
   # As Administrator
   Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1  myapp.local www.myapp.local" -Encoding UTF8
   ```

---

## SSL Certificate Details

### Self-Signed Certificates
The certificates generated are **self-signed**, meaning:
- ✅ Browsers will show a security warning (expected)
- ✅ Valid for development and testing
- ✅ Not suitable for production
- ✅ No cost or manual signing needed

### Certificate Validity
- **Validity period:** 365 days from generation
- **Key type:** RSA 2048-bit
- **Subject:** `/C=US/ST=Development/L=Development/O=Development/CN=web.local`

### Inspect Certificate (in guest)
```bash
vagrant ssh
openssl x509 -in /etc/ssl/certs/web.local.crt -text -noout
```

---

## Troubleshooting

### "Cannot resolve web.local" from Host

**Symptom:** `curl -k https://web.local:8443` fails with "Cannot resolve host"

**Solution:** The hosts file wasn't updated. Check if the entry exists:
```powershell
type C:\Windows\System32\drivers\etc\hosts
```

If missing, add it manually (as Administrator):
```powershell
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1  web.local www.web.local" -Encoding UTF8
```

### "Works from 127.0.0.1 but not web.local"

Same as above — DNS resolution issue. Verify the hosts file entry exists.

### Apache Configuration Errors

If provisioning fails with an Apache error:
1. Run `vagrant provision` again
2. Check the error message — usually indicates a syntax error in the generated vhost config
3. Manually SSH in and check: `sudo apache2ctl configtest`

### Certificates Already Exist Warning

If you see "SSL certificates already exist", that's **normal behavior**. The script is idempotent and won't regenerate certificates unnecessarily.

---

## How It Integrates with Vagrant Workflow

| Command | What Happens | SSL Status |
|---------|-------------|-----------|
| `vagrant up` | First boot + provisioning | Certificates generated ✓ |
| `vagrant halt` | Graceful shutdown | Certificates persist ✓ |
| `vagrant resume` | Boot (no provision) | Uses existing certificates ✓ |
| `vagrant reload` | Reboot + provision | Certificates regenerated |
| `vagrant reload --no-provision` | Reboot only | Certificates unchanged ✓ |
| `vagrant destroy` | Cleanup + remove VM | Certificates deleted via script ✓ |

---

## Environment Configuration

The SSL setup reads from your `.env` file:

```bash
# .env
export BOX_NAME=boxen/debian-13
export WEB_DNS=web.local           # ← This controls the domain
export DB_NEEDED=postgresql
export WEB_SERVER=apache
```

Create a `.env` file from `.env.sample` if you haven't already:
```bash
cp .env.sample .env
```

Each developer can customize `WEB_DNS` in their local `.env` file without affecting others.

---

## Related Files

- `scripts/guest/install_ssl.sh` — SSL certificate generation
- `scripts/guest/destroy_ssl.sh` — SSL certificate cleanup
- `Vagrantfile` — Vagrant configuration with SSL triggers and provisioning
- `.env` — Environment variables (including `WEB_DNS`)
- `.env.sample` — Template for `.env`

---

## Notes

- The SSL setup is **automatic** — no manual certificate signing or configuration needed
- Certificates are generated on the **guest** only, not on the host
- The vagrant-hostmanager plugin handles both guest and host `/etc/hosts` management
- All operations are idempotent and safe to repeat
- Clean removal via `destroy_ssl.sh` prevents leftover configuration files
