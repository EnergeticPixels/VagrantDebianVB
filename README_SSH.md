# 🟩 Vagrant SSH Workflow — Project Host Key + Two‑Phase Boot

This project uses a secure, deterministic SSH workflow that ensures:

*   **Your own ED25519 keypair** (not Vagrant’s auto-generated one) is used for SSH.
*   **No password authentication** is permitted.
*   Vagrant remains fully **non-interactive** for automation or CI.
*   All SSH keys live neatly under `./.vagrant_keys`.
*   Keys are **auto‑generated** on `vagrant up` and **auto‑removed** on `vagrant destroy -f`.

This workflow is designed for Windows hosts and avoids all typical PowerShell/OpenSSH quoting pitfalls.

***

## 📌 Overview

Vagrant normally injects a random key on first boot.  
This project overrides that using a **two‑phase boot + reload** process:

1.  **Before `vagrant up`**  
    A trigger runs a PowerShell script to generate a strong ED25519 keypair inside:
        <project_root>/.vagrant_keys/

2.  **First boot**
    *   The VM boots using the base box’s default insecure key (only once).
    *   Provisioners run and append **your generated public key** to:
            /home/vagrant/.ssh/authorized_keys

3.  **After provisioning completes**
    *   A trigger writes a marker file:
            .vagrant/hostkey_ready
    *   Then executes:
            vagrant reload --no-provision

4.  **Reload phase**
    *   Vagrant re-reads the Vagrantfile.
    *   The marker is detected.
    *   Vagrant switches SSH to:
        ```ruby
        config.ssh.private_key_path = "./.vagrant_keys/vagrant_ed25519"
        config.ssh.password = nil
        config.ssh.keys_only = true
        ```
    *   From here on: **SSH = key-only authentication. No password fallback.**

5.  **Destroy**
    *   `vagrant destroy -f` triggers cleanup:
        *   deletes your project keys
        *   deletes the marker file
        *   leaves the repo clean

***

## 🗂 Directory Layout

    project/
    │
    ├── .vagrant_keys/
    │     ├── vagrant_ed25519
    │     └── vagrant_ed25519.pub
    │
    ├── scripts/
    │    └── host/
    │         ├── generate_ssh_key.ps1
    │         └── cleanup_ssh_keys.ps1
    │
    ├── .vagrant/
    │    └── hostkey_ready     (created automatically after provision)
    │
    └── Vagrantfile

***

## 🚀 Normal Workflow

### ▶️ `vagrant up`

*   Generates your ED25519 host keypair (if missing).
*   First SSH login uses the box’s insecure key.
*   Provisioners run and append your public key.
*   VM reloads automatically.
*   After reload, Vagrant uses **your** key.

***

### ▶️ `vagrant ssh-config`

After reload, you should see something like:

    Host default
      HostName 127.0.0.1
      User vagrant
      Port 2222
      IdentityFile C:/path/to/project/.vagrant_keys/vagrant_ed25519
      IdentitiesOnly yes
      PasswordAuthentication no

This confirms you're using the correct key.

***

### ▶️ `vagrant ssh`

No password prompt.  
Immediate login via your ED25519 key.

***

### ▶️ `vagrant destroy -f`

*   Non-interactive
*   Cleans up keys
*   Resets ready for next `up`

**Always use `-f`** or you’ll get an interactive confirmation prompt.

***

## 🔐 Verifying the Actual Key Used

### Inside the VM:

```bash
sudo journalctl -u ssh --since "10 minutes ago" | grep Accepted
```

Expected example:

    Accepted publickey for vagrant from 10.0.2.2 ...
      ED25519 SHA256:abcd1234... 

### Compare with your host public key:

```powershell
ssh-keygen -lf .vagrant_keys\vagrant_ed25519.pub
```

Fingerprints must match.

***

## 🛠 Troubleshooting

### ❌ Seeing password prompts?

Check the client config:

```bash
vagrant ssh-config
```

Make sure it shows:

*   `IdentityFile .../.vagrant_keys/vagrant_ed25519`
*   `PasswordAuthentication no`
*   `IdentitiesOnly yes`

If not, run:

```bash
vagrant reload --no-provision
```

***

### ❌ Guest didn’t get your pubkey?

Inside VM:

```bash
grep ssh-ed25519 ~/.ssh/authorized_keys
```

If missing, check the provisioner path in the Vagrantfile.

***

### ❌ Keys not cleaned on destroy?

Use:

```bash
vagrant destroy -f
```

If Windows locked files earlier, also:

```powershell
Remove-Item -Recurse -Force .vagrant_keys
Remove-Item -Recurse -Force .vagrant/hostkey_ready
```

***

## 🧱 How the Two‑Phase Boot Works (Summary)

| Phase           | Behavior                                  |
| --------------- | ----------------------------------------- |
| Before `up`     | Host ED25519 key generated                |
| First boot      | VM accepts insecure key; provisioners run |
| After provision | Marker written, VM reloads automatically  |
| Reload          | Vagrant switches to **your** project key  |
| Steady state    | Key‑only SSH, no password fallback        |
| Destroy         | Keys auto‑removed                         |

***

## 🙌 Notes for Future You

*   `vagrant up` is safe, repeatable and consistent.
*   `vagrant reload` is what locks in the project key for all subsequent SSH.
*   Always use `vagrant destroy -f` to avoid prompts and allow cleanup triggers to run.
*   No sensitive SSH keys are committed to the repository—everything is generated per-machine.



