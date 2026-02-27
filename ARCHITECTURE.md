# Shopizer Deployment Architecture

## How `provision-and-deploy.sh` Works

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                          HOW provision-and-deploy.sh WORKS                      ║
╚══════════════════════════════════════════════════════════════════════════════════╝

 ┌─────────────────────────────────────────────────────────────────────────────┐
 │  YOUR MAC (Host Machine)                                                     │
 │                                                                              │
 │   $ ./provision-and-deploy.sh                                                │
 │         │                                                                    │
 │         ├── STEP 1: Start Colima VM ──────────────────────────────────┐     │
 │         │          colima start --cpu 2 --memory 4 --disk 20          │     │
 │         │                                                              │     │
 │         ├── STEP 2: ./download-artifacts.sh                           │     │
 │         │          Uses GitHub CLI (gh) to fetch:                     │     │
 │         │           • shopizer.jar       → ./ci-artifacts/            │     │
 │         │           • shopizer-admin/    → ./ci-artifacts/            │     │
 │         │           • shop-react/        → ./ci-artifacts/            │     │
 │         │          (Smart sync: skips if Run ID unchanged)            │     │
 │         │                                                              │     │
 │         └── STEP 3: ansible-playbook site.yml                         │     │
 │                     SSH into VM  ────────────────────────────────────►│     │
 │                     (auto-detected port from colima ssh-config)       │     │
 │                                                                        │     │
 │   ci-artifacts/                                                        │     │
 │   ├── shopizer.jar           (Spring Boot backend)                     │     │
 │   ├── shopizer-admin/        (Angular build dist)                      │     │
 │   └── shop-react/            (React build)                             │     │
 └────────────────────────────────────────────────────────────────────────┼─────┘
                                                                           │ SSH
 ┌─────────────────────────────────────────────────────────────────────────▼─────┐
 │  COLIMA VM  (Linux/Ubuntu, 127.0.0.1:auto-port, 2 CPU / 4GB RAM / 20GB Disk) │
 │                                                                                │
 │  Ansible configures everything inside here:                                    │
 │                                                                                │
 │  Packages installed: openjdk-17-jdk, nginx, python3-docker                    │
 │                                                                                │
 │  ┌─────────────────────────────────────────────────────────────────────────┐  │
 │  │  NGINX  (Port 80)  ←── All public traffic enters here                  │  │
 │  │  /etc/nginx/sites-available/default                                     │  │
 │  │                                                                          │  │
 │  │   http://localhost/          → 301 redirect → /shop/                    │  │
 │  │                                                                          │  │
 │  │   http://localhost/shop/     ──────────────────────────────────────►    │  │
 │  │                               alias /var/www/shop/  (React SPA)         │  │
 │  │                               try_files → index.html (client routing)   │  │
 │  │                                                                          │  │
 │  │   http://localhost/admin/    ──────────────────────────────────────►    │  │
 │  │                               alias /var/www/admin/  (Angular SPA)      │  │
 │  │                               try_files → index.html (client routing)   │  │
 │  │                                                                          │  │
 │  │   http://localhost/api/      ──────────────────────────────────────►    │  │
 │  │                               proxy_pass http://localhost:8080           │  │
 │  │                               (Spring Boot, keeps /api/ prefix)          │  │
 │  │                                                                          │  │
 │  │   http://localhost/assets/   → tries /var/www/admin/assets/ first,      │  │
 │  │                                 then /var/www/shop/assets/ (catch-all)   │  │
 │  └─────────────────────────────────────────────────────────────────────────┘  │
 │         │                    │                      │                          │
 │         ▼                    ▼                      ▼                          │
 │  ┌─────────────┐    ┌──────────────────┐   ┌──────────────────┐               │
 │  │  /var/www/  │    │  /var/www/shop/  │   │  SHOPIZER        │               │
 │  │  admin/     │    │                  │   │  BACKEND         │               │
 │  │             │    │  React static    │   │  Port :8080      │               │
 │  │  Angular    │    │  build files     │   │                  │               │
 │  │  static     │    │  (HTML/JS/CSS)   │   │  systemd service │               │
 │  │  build files│    │                  │   │  /opt/shopizer/  │               │
 │  │  + env.js   │    │  Copied from     │   │  shopizer.jar    │               │
 │  │  (patched   │    │  ci-artifacts/   │   │                  │               │
 │  │  for API    │    │  shop-react/     │   │  Copied from     │               │
 │  │  endpoint)  │    │                  │   │  ci-artifacts/   │               │
 │  │             │    └──────────────────┘   │  shopizer.jar    │               │
 │  │  Copied from│                           │                  │               │
 │  │  ci-artifacts/                          │  Runs as:        │               │
 │  │  shopizer-admin/                        │  java -cp .      │               │
 │  └─────────────┘                          │  shopizer.jar    │               │
 │                                            └────────┬─────────┘               │
 │                                                     │ JDBC mysql://localhost   │
 │                                                     │ :3306/SALESMANAGER       │
 │                                                     ▼                          │
 │                                          ┌──────────────────┐                 │
 │                                          │  MYSQL 8.0       │                 │
 │                                          │  Docker Container│                 │
 │                                          │  name: shopizer-db                 │
 │                                          │  Port :3306      │                 │
 │                                          │  DB: SALESMANAGER│                 │
 │                                          │  restart: always │                 │
 │                                          └──────────────────┘                 │
 └────────────────────────────────────────────────────────────────────────────────┘
```

---

## Ansible Task Execution Order

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                          ANSIBLE TASK EXECUTION ORDER                           ║
╠══════════════════════════════════════════════════════════════════════════════════╣
║  1. apt update + install  openjdk-17, nginx, python3-docker                     ║
║  2. Docker → start MySQL container  (shopizer-db, port 3306)                    ║
║  3. mkdir  /opt/shopizer                                                         ║
║  4. copy   shopizer.jar     → /opt/shopizer/shopizer.jar                        ║
║  5. template database.properties.j2 → /opt/shopizer/database.properties        ║
║  6. template shopizer.service.j2    → /etc/systemd/system/shopizer.service      ║
║  7. mkdir  /var/www/admin   /var/www/shop                                        ║
║  8. copy   ci-artifacts/shopizer-admin/ → /var/www/admin/                       ║
║  9. template env.js.j2      → /var/www/admin/assets/env.js  (API URL patch)     ║
║ 10. copy   ci-artifacts/shop-react/    → /var/www/shop/                         ║
║ 11. template nginx.conf.j2  → /etc/nginx/sites-available/default                ║
║ 12. systemctl enable+start  shopizer  nginx                                      ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

---

## Final Access Points

| URL | Description |
|-----|-------------|
| `http://localhost/shop` | React customer storefront |
| `http://localhost/admin` | Angular admin panel |
| `http://localhost/api/actuator/health` | Spring Boot health check |
| `http://localhost/api/swagger-ui.html` | Swagger API docs |

---

## Key Design Notes

- **Backend (Spring Boot)** runs as a **systemd service** directly on the VM (not in Docker) so it can be managed with `journalctl` and auto-restarts on failure.
- **MySQL** runs as a **Docker container** — easiest way to get a clean DB without installing MySQL natively.
- **React & Angular** are **static files** — no Node.js server needed. Nginx serves them directly from `/var/www/`.
- **Nginx** is the single entry point on port 80, routing traffic by URL path prefix (`/api/`, `/admin/`, `/shop/`).
- **`env.js`** is a Jinja2 template patched at deploy time so the Angular admin knows the correct API URL — this is how a static SPA gets runtime config.
- **Smart sync** in `download-artifacts.sh` compares GitHub Actions Run IDs so it doesn't re-download unchanged artifacts.
