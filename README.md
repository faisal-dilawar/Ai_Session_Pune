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

### 4. Running the System
You can use the existing orchestration scripts to manage the lifecycle:
*   `./start-all.sh`: Starts all three services.
*   `./stop-all.sh`: Stops all three services.
