# Ai Session Pune - Shopizer Project (DevOps Stage)

This is the parent repository for the Shopizer training project. It orchestrates three independent microservices/applications and provides centralized management and CI/CD automation.

## Architecture
This project uses **Git Submodules** to manage the following independent repositories:
*   `shopizer`: Java/Spring Boot Backend.
*   `shopizer-admin`: Angular Admin Panel.
*   `shopizer-shop-reactjs`: React Customer Shop.

## Getting Started

### 1. Cloning the Project
To clone this project along with all its sub-modules, use the `--recursive` flag:
```bash
git clone --recursive <repository-url>
```

If you have already cloned it without the flag, run:
```bash
git submodule update --init --recursive
```

### 2. DevOps & CI/CD (Stage 3)
Each sub-repository contains a GitHub Actions workflow in `.github/workflows/` that:
1.  **Validates:** Runs unit tests and linting.
2.  **Builds:** Compiles the code into production-ready artifacts (`.jar` for backend, `dist/build` for frontends).
3.  **Packages:** Uploads these artifacts to GitHub.

### 3. Local Artifact Synchronization
To download the latest successful builds from GitHub without manually browsing the UI, use the provided script:
```bash
./download-artifacts.sh
```
*Note: Requires [GitHub CLI (gh)](https://cli.github.com/) installed and authenticated (`gh auth login`).*

### 4. Running the System (Local Dev)
You can use the existing orchestration scripts to manage the local lifecycle:
*   `./start-all.sh`: Starts all three services on your host machine.
*   `./stop-all.sh`: Stops all three services on your host machine.

*Note: The system now automatically creates a default `database.properties` file for you on the first run of the backend start script.*

---

## Advanced DevOps (Stage 3 - Infrastructure as Code)
The project is now capable of running inside a fully provisioned Linux Virtual Machine using **Colima** and **Ansible**. This mimics a real cloud environment.

### 1. Requirements
*   [Colima](https://github.com/abiosoft/colima) installed (`brew install colima`).
*   [Ansible](https://www.ansible.com/) installed (`brew install ansible`).

### 2. Automatic Provisioning & Deployment
To start the VM, download the latest artifacts, and configure the entire stack (including MySQL via Docker and Nginx), simply run:
```bash
chmod +x provision-and-deploy.sh
./provision-and-deploy.sh
```

### 3. Accessing the System
Once deployment is complete, the services are available at:
*   **Shop Frontend:** http://localhost/shop
*   **Admin Panel:** http://localhost/admin
*   **API Health:** http://localhost/api/actuator/health
*   **Swagger API:** http://localhost/api/swagger-ui.html

### 4. Management & Logs
*   **Stop the Environment:** `./stop-mini-cloud.sh`
*   **Check Backend Logs:** `colima ssh -- sudo journalctl -u shopizer -f`
*   **Check Database Status:** `colima ssh -- docker ps`
