# SAP Automation POC — Ansible + GCP

A proof-of-concept demonstrating SAP lifecycle automation using **Ansible** targeting a **GCP VM**. Simulates SAP system install, start, stop, and status checks via a `systemd` service — the same pattern used by real SAP Basis teams.

---

## Architecture

```
Local Machine (Ansible)
        │
        │  SSH / Ansible Playbooks
        ▼
GCP VM — Ubuntu 22.04 (sap-demo-vm)
        │
        ├── /opt/sap/start_sap.sh
        ├── /opt/sap/stop_sap.sh
        ├── /opt/sap/status_sap.sh
        ├── /var/log/sap/sap.log
        └── systemd service: sap.service
```

---

## Prerequisites

| Tool | Install |
|------|---------|
| Ansible | `brew install ansible` |
| gcloud CLI | [Install guide](https://cloud.google.com/sdk/docs/install) |
| SSH key | `ssh-keygen -t rsa -b 4096` |

---

## Step 1 — Install Ansible

```bash
brew install ansible
ansible --version
```

---

## Step 2 — Create GCP VM

Edit `PROJECT_ID` in the script, then run:

```bash
chmod +x scripts/setup_gcp_vm.sh
./scripts/setup_gcp_vm.sh
```

Or manually:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

gcloud compute instances create sap-demo-vm \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=sap-demo

gcloud compute firewall-rules create allow-ssh-sap \
  --allow=tcp:22 --target-tags=sap-demo
```

---

## Step 3 — Configure Inventory

Edit `inventory.ini` and replace `VM_PUBLIC_IP` with your VM's external IP:

```bash
# Get VM IP
gcloud compute instances describe sap-demo-vm \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

```ini
[sapservers]
sap-demo ansible_host=<YOUR_VM_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

---

## Step 4 — Test Connectivity

```bash
ansible -i inventory.ini sapservers -m ping
```

Expected:
```
sap-demo | SUCCESS => { "ping": "pong" }
```

---

## Step 5 — Run Playbooks

### Install / Configure SAP

```bash
ansible-playbook -i inventory.ini sap_install.yml
```

### Start SAP

```bash
ansible-playbook -i inventory.ini sap_start.yml
```

### Check SAP Status

```bash
ansible-playbook -i inventory.ini sap_status.yml
```

### Stop SAP

```bash
ansible-playbook -i inventory.ini sap_stop.yml
```

---

## Project Structure

```
SAP-POC/
├── ansible.cfg            # Ansible configuration
├── inventory.ini          # Target hosts (update VM IP here)
├── sap_install.yml        # Install & configure SAP demo service
├── sap_start.yml          # Start SAP service
├── sap_stop.yml           # Stop SAP service
├── sap_status.yml         # Check SAP service status
├── scripts/
│   └── setup_gcp_vm.sh    # One-shot GCP VM creation script
└── README.md
```

---

## Demo Script (for presentations)

```bash
# 1. Provision SAP environment
ansible-playbook -i inventory.ini sap_install.yml

# 2. Start SAP system
ansible-playbook -i inventory.ini sap_start.yml

# 3. Verify SAP is running
ansible-playbook -i inventory.ini sap_status.yml

# 4. Stop SAP system
ansible-playbook -i inventory.ini sap_stop.yml

# 5. Confirm SAP is stopped
ansible-playbook -i inventory.ini sap_status.yml
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| SSH connection refused | Check firewall rule allows TCP 22 for your IP |
| `UNREACHABLE` in Ansible | Verify `VM_PUBLIC_IP` in `inventory.ini` is correct |
| `python3` not found on VM | Run `sudo apt-get install -y python3` on the VM |
| Permission denied (SSH) | Ensure your SSH public key is added to the VM's `~/.ssh/authorized_keys` |
