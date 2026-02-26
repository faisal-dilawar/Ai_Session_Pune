# Stage 3: Advanced DevOps Plan (IaC & Provisioning)

## Objective
To transition from manual local execution to **Automated Infrastructure Provisioning**. We will create a "Mini-Cloud" environment on your Mac using Colima and use code to configure it exactly like a production server.

## 1. The Technology Stack
*   **Colima:** Acts as our "Cloud Provider" on macOS. It spins up a lightweight Linux Virtual Machine (VM).
*   **Ansible (Recommended IaC Tool):** A "Push-based" configuration management tool. We write "Playbooks" (YAML) that describe the state of the server.
*   **Systemd:** The Linux service manager we will use to ensure the Shopizer Backend starts automatically on boot.
*   **Nginx:** A high-performance web server to serve the React and Angular frontends as static files.

## 2. Implementation Strategy

### Phase 1: Virtual Infrastructure Setup
1.  **Initialize Colima:** Create a dedicated VM instance with specific resources (e.g., 2 CPUs, 4GB RAM).
2.  **Network Access:** Ensure the VM has a reachable IP address from the host Mac so we can deploy to it via SSH.

### Phase 2: Infrastructure as Code (Ansible)
We will create an `ansible/` directory containing playbooks to:
1.  **Environment Preparation:** Install essential Linux packages (curl, git, unzip).
2.  **Java Provisioning:** Install OpenJDK 17 (required for the Backend).
3.  **Web Server Setup:** Install and configure Nginx to:
    *   Serve the Admin UI on port 80/admin.
    *   Serve the Shop UI on port 80/shop.
    *   Proxy API requests to the Backend.
4.  **Service Configuration:** Create a Linux "Systemd" service file for `shopizer.jar` so it runs as a background daemon.

### Phase 3: The Deployment Pipeline (The "Bridge")
We will integrate our previous CI artifacts with this new infrastructure:
1.  **Fetch:** Use the `download-artifacts.sh` logic to get the latest builds.
2.  **Transfer:** Use Ansible's `copy` module to securely move the `.jar` and `dist` folders from your Mac into the Colima VM.
3.  **Deploy:** Automate the restart of the Backend service and the reloading of Nginx.

## 3. Why This Matters (Learning Goals)
*   **Idempotency:** You can run the Ansible playbook 100 times, and it will only change what is necessary to reach the "desired state."
*   **Environment Parity:** The VM setup will be nearly identical to a real AWS EC2 instance or a DigitalOcean droplet.
*   **Disaster Recovery:** If the VM is deleted, you can recreate the entire environment from scratch in minutes using your code.

## 4. Execution Steps (For later)
1.  Install Colima and Ansible on Mac (`brew install colima ansible`).
2.  Start Colima: `colima start --cpu 2 --memory 4`.
3.  Write the Ansible inventory and playbooks.
4.  Run `ansible-playbook -i inventory setup.yml` to provision the VM.
