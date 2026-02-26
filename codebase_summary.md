# Shopizer — Comprehensive Technical Summary

> Generated for developers new to the project. Covers the full mono-repo:
> `shopizer/` (backend), `shopizer-admin/` (admin UI), `shopizer-shop-reactjs/` (storefront).

---

## 1. High-Level Purpose

Shopizer is an **open-source, self-hosted e-commerce platform**. It solves the problem of businesses needing a fully-owned online store without paying SaaS fees (Shopify, BigCommerce, etc.).

It provides:
- A **REST API backend** that powers all commerce operations
- An **Angular admin dashboard** for store managers (products, orders, users, config)
- A **React storefront** for customers to browse and purchase

It supports **multi-tenancy** (multiple merchant stores from one deployment), **multi-language**, and **multi-currency** out of the box.

---

## 2. Architecture & Design

### Pattern: Layered Monolith with Pluggable Modules

Shopizer is **not microservices** — it is a modular monolith following a classic **layered architecture**:

```
Controller (REST API)
    ↓
Facade (orchestration / DTO translation)
    ↓
Service (business logic)
    ↓
Repository (data access via JPA)
    ↓
Database (MySQL)
```

### Key Architectural Decisions

| Decision | Detail |
|---|---|
| **Layered Architecture** | Strict separation: controllers never touch repositories directly |
| **Facade Pattern** | Facades sit between controllers and services, handling DTO↔Entity mapping and orchestration |
| **Populator Pattern** | Dedicated populator classes translate between API models and domain models |
| **Module System** | Payment, shipping, email, CMS are pluggable modules loaded via `ModuleConfigurationService` |
| **Multi-tenancy** | Every entity is scoped to a `MerchantStore` — all queries are tenant-aware |
| **Rules Engine** | Drools is used for pricing, promotions, tax, and shipping rule evaluation |

### Maven Module Breakdown

```
shopizer/                       ← parent POM
├── sm-core-model/              ← JPA entities (domain model)
├── sm-core/                    ← Repositories + business services + Spring config
├── sm-core-modules/            ← Pluggable modules (email, CMS, payments, shipping)
│   ├── sm-core-module/         ← Base module infrastructure
│   ├── sm-module-cms/          ← Content management
│   ├── sm-module-email/        ← Email (default SMTP + AWS SES)
│   ├── sm-module-integration/  ← Payment & shipping integrations
│   └── sm-module-order/        ← Order processing logic
├── sm-shop-model/              ← API request/response DTOs (no JPA)
└── sm-shop/                    ← Spring Boot app: controllers, security, facades
```

---

## 3. Tech Stack

### Backend (`shopizer/`)

| Category | Technology |
|---|---|
| Language | Java 11 |
| Framework | Spring Boot 2.5.12 |
| ORM | Hibernate 5 + Spring Data JPA |
| Database | MySQL 8 (default) |
| Connection Pool | HikariCP |
| Security | Spring Security + JWT (`io.jsonwebtoken:jjwt` 0.8.0) |
| API Docs | SpringFox Swagger 2.9.2 |
| Object Mapping | MapStruct 1.3.0 |
| Rules Engine | Drools 7.32.0 |
| Caching | EhCache + Infinispan 9.4.18 |
| File Upload | Apache Commons FileUpload |
| Email Templates | FreeMarker |
| Password Rules | Passay 1.6.0 |
| XSS Protection | OWASP AntiSamy 1.6.7 |
| Build | Maven |

### Admin UI (`shopizer-admin/`)

| Category | Technology |
|---|---|
| Framework | Angular 11 |
| UI Library | Nebular 5/6 + Bootstrap 4 |
| Language | TypeScript 4.0.8 |
| HTTP Client | Angular HttpClient |
| Charts | NGX-Charts, ECharts |
| Build | Angular CLI 11 |

### Storefront (`shopizer-shop-reactjs/`)

| Category | Technology |
|---|---|
| Framework | React 16 |
| State Management | Redux + redux-thunk |
| HTTP Client | Axios |
| Routing | React Router 5 |
| UI | React-Bootstrap 1 |
| Payment | Stripe React SDK |
| Build | react-scripts (CRA) 4 |

---

## 4. Entry Points

### Backend
- **Main class**: `sm-shop/src/main/java/com/salesmanager/shop/application/ShopApplication.java`
- All REST controllers live in: `sm-shop/src/main/java/com/salesmanager/shop/store/api/v1/`
- API base URL: `http://localhost:8080/api/v1/`

### Admin UI
- Entry: `shopizer-admin/src/main/index.html` → bootstrapped by `src/main/app.module.ts`
- Dev server: `http://localhost:4200`

### Storefront
- Entry: `shopizer-shop-reactjs/src/index.js` → `src/App.js`
- Dev server: `http://localhost:3000`

---

## 5. Core Logic Flow

### Example: Customer Places an Order

```
1. POST /api/v1/auth/cart/{code}/checkout
        ↓
2. OrderFacade.checkout(cart, customer, store)
        ↓
3. ShoppingCartService.getByCode(code)        ← load cart + items
        ↓
4. PaymentService.processPayment(order, tx)   ← charge via Stripe/PayPal/Braintree
        ↓
5. OrderService.processOrder(order)           ← persist Order + OrderProducts
        ↓
6. Drools rules engine evaluates:
   - TaxService.calculateTax(order)
   - ShippingService.calculateShipping(order)
   - OrderTotalService.calculateTotals(order)
        ↓
7. Email notification sent via EmailService (SMTP or SES)
        ↓
8. OrderStatusHistory entry created (ORDERED)
        ↓
9. Response: ReadableOrder DTO returned to client
```

### Example: Browse Products (Public)

```
1. GET /api/v1/products?category=electronics&lang=en&store=DEFAULT
        ↓
2. ProductFacade.getProducts(criteria)
        ↓
3. ProductService.listByStore(store, language, criteria)
        ↓
4. JPA Repository query with Hibernate (joins Category, Price, Inventory, Images)
        ↓
5. ReadableProductPopulator maps Entity → ReadableProduct DTO
        ↓
6. Paginated JSON response
```

---

## 6. Data Model

### Core Entities & Relationships

```
MerchantStore (tenant)
├── Category (tree structure, self-referential parent/child)
│   └── CategoryDescription (multilingual)
├── Product
│   ├── ProductDescription (multilingual)
│   ├── ProductPrice
│   ├── ProductInventory (per store/location)
│   ├── ProductImage (multiple)
│   ├── ProductAttribute → ProductOption + ProductOptionValue
│   ├── ProductVariant
│   └── Manufacturer
├── Customer
│   ├── CustomerAddress (billing/shipping)
│   └── CustomerGroup
├── Order
│   ├── OrderProduct (line items)
│   ├── OrderTotal (subtotal, tax, shipping, grand total)
│   ├── OrderStatusHistory
│   └── Transaction (payment record)
├── ShoppingCart
│   └── ShoppingCartItem
├── Content (CMS pages/blogs)
├── TaxRate + TaxClass
└── ShippingConfiguration
```

### Key Relationships

| Relationship | Type |
|---|---|
| MerchantStore → everything | One-to-Many (all data is tenant-scoped) |
| Product → Category | Many-to-Many |
| Order → Customer | Many-to-One |
| Order → OrderProduct | One-to-Many |
| Product → ProductDescription | One-to-Many (one per language) |
| Category → Category | Self-referential tree (parent/children) |

---

## 7. Project Structure

### Backend (`sm-shop/src/main/java/com/salesmanager/shop/`)

```
shop/
├── application/
│   └── ShopApplication.java          ← Spring Boot main class
├── store/
│   ├── api/v1/                       ← ALL REST controllers (46+ classes)
│   │   ├── catalog/                  ← Product, Category, Manufacturer APIs
│   │   ├── order/                    ← Order, Payment, Shipping APIs
│   │   ├── customer/                 ← Customer, Auth APIs
│   │   ├── cart/                     ← Shopping cart API
│   │   ├── content/                  ← CMS APIs
│   │   ├── system/                   ← Config, Cache, Modules APIs
│   │   └── search/                   ← Search API
│   ├── facade/                       ← Orchestration layer (one facade per domain)
│   └── populator/                    ← Entity ↔ DTO conversion classes
├── security/                         ← JWT filters, auth providers, Spring Security config
└── utils/                            ← Helpers, validators
```

### Core Services (`sm-core/src/main/java/com/salesmanager/core/business/`)

```
business/
├── configuration/                    ← DataConfiguration, DroolsConfig, SearchConfig
├── services/
│   ├── catalog/                      ← ProductService, CategoryService, etc.
│   ├── order/                        ← OrderService, PaymentService, etc.
│   ├── customer/                     ← CustomerService
│   ├── shoppingcart/                 ← ShoppingCartService
│   ├── shipping/                     ← ShippingService
│   ├── tax/                          ← TaxService
│   ├── content/                      ← ContentService, FileContentService
│   └── reference/                    ← Language, Country, Currency services
└── repositories/                     ← Spring Data JPA repositories (one per entity)
```

---

## 8. External Dependencies

| System | Purpose | Implementation |
|---|---|---|
| **MySQL** | Primary database | HikariCP + Hibernate |
| **AWS S3** | Product images & static file storage | `aws-java-sdk-s3` v1.11.640 |
| **AWS SES** | Transactional email delivery | `aws-java-sdk-ses` v1.11.640 |
| **Google Cloud Storage** | Alternative file storage | `google-cloud-storage` v1.74.0 |
| **Stripe** | Payment processing | `stripe-java` v19.5.0 |
| **PayPal** | Payment processing | `merchantsdk` v2.6.109 |
| **Braintree** | Payment processing | `braintree-java` v2.73.0 |
| **Elasticsearch** | Full-text product search | Disabled by default; version 7.5.2 |
| **Drools** | Business rules (pricing, tax, shipping) | v7.32.0 |
| **Google Maps API** | Geolocation features | `google-maps-services` v0.1.6 |
| **MaxMind GeoIP2** | IP-based location detection | `geoip2` v2.7.0 |
| **Infinispan** | Distributed caching | v9.4.18 |

**No message queues** (Kafka, RabbitMQ, SQS) — all processing is synchronous.

---

## 9. Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Java | 11+ (tested on 17) |
| Maven | 3.6+ |
| MySQL | 8.x |
| Node.js | 16.x (via nvm) |
| Python | 3.10.x (for admin npm native builds) |

### Backend Setup

```bash
# 1. Start MySQL and create DB
brew services start mysql
mysql -u root -p -e "CREATE DATABASE SALESMANAGER;"

# 2. Create database config (gitignored — must create manually)
cat > shopizer/sm-shop/src/main/resources/database.properties << EOF
db.jdbcUrl=jdbc:mysql://127.0.0.1:3306/SALESMANAGER?autoReconnect=true&useUnicode=true&characterEncoding=UTF-8
db.user=root
db.password=YOUR_ROOT_PASSWORD
db.driverClass=com.mysql.cj.jdbc.Driver
hibernate.dialect=org.hibernate.dialect.MySQL5InnoDBDialect
db.preferredTestQuery=SELECT 1
db.show.sql=false
db.schema=SALESMANAGER
hibernate.hbm2ddl.auto=update
db.initialPoolSize=4
db.minPoolSize=4
db.maxPoolSize=4
EOF

# 3. Build and run
cd shopizer
mvn spring-boot:run -pl sm-shop
# App starts at http://localhost:8080
# Swagger UI: http://localhost:8080/swagger-ui.html
```

### Admin UI Setup (Angular)

```bash
# Requires Node 16 + Python 3.10 (for native deps)
nvm use 16
cd shopizer-admin
npm install --legacy-peer-deps   # use Python 3.10 if fibers fails
rm -rf node_modules/fibers       # remove fibers (ARM64 incompatible on M1)
npm start
# Runs at http://localhost:4200
```

### Storefront Setup (React)

```bash
nvm use 16
cd shopizer-shop-reactjs
npm install
export NODE_OPTIONS=--openssl-legacy-provider   # required for Node 17+
npm start
# Runs at http://localhost:3000
```

### Run All Three Together

| Terminal | Command | URL |
|---|---|---|
| Tab 1 | `cd shopizer && mvn spring-boot:run -pl sm-shop` | http://localhost:8080 |
| Tab 2 | `cd shopizer-admin && npm start` | http://localhost:4200 |
| Tab 3 | `cd shopizer-shop-reactjs && npm start` | http://localhost:3000 |

---

## 10. Potential Complexity & Gotchas

### Critical Files to Study First

| File | Why |
|---|---|
| `sm-shop/src/main/java/.../security/MultipleEntryPointsSecurityConfig.java` | 4 overlapping security chains — easy to misconfigure auth |
| `sm-core/src/main/java/.../configuration/DataConfiguration.java` | Manual Hibernate + HikariCP wiring (not Spring Boot auto-config) |
| `sm-shop/src/main/java/.../store/facade/` | All business orchestration happens here; most bugs live here |
| `sm-core-modules/sm-module-integration/` | Payment + shipping plugin architecture |
| `sm-core/src/main/resources/spring/shopizer-core-config.xml` | Legacy XML Spring config still wired in alongside annotations |

### Gotchas

1. **`database.properties` is gitignored** — you must create it manually on every fresh clone. This is the #1 reason the app won't start for new developers.

2. **Dual config style** — the project mixes XML Spring config (`shopizer-core-config.xml`) with annotation-based config. Both are active simultaneously. Changes to one may need mirroring in the other.

3. **4 security chains** — `/shop/**`, `/services/**`, `/api/v1/private/**`, `/api/v1/auth/**` each have separate filters and JWT providers. A wrong URL pattern will silently use the wrong auth chain.

4. **Multi-tenancy in every query** — every repository method takes a `MerchantStore` parameter. Forgetting to pass it results in data leakage across stores or empty results.

5. **Drools rules scattered** — pricing, shipping, and tax rules are in `.drl` files loaded at startup via `DroolsConfiguration`. Changes to business rules require modifying these files, not just service code.

6. **Elasticsearch is wired but disabled** — `management.health.elasticsearch.enabled=false`. If you enable it without a running ES instance, the app fails to start.

7. **M1 Mac gotchas** — `fibers` (npm package used by `sass` in the Angular admin) crashes on ARM64. Delete `node_modules/fibers` after install to work around it.

8. **TypeScript version mismatch in admin** — `@types/jquery` installs a version that uses TypeScript 4.1+ syntax, but the project uses TypeScript 4.0.8. Add `"skipLibCheck": true` in `tsconfig.json` to suppress these errors.

9. **Hibernate `hbm2ddl.auto=update`** — tables are auto-created/altered on startup. Never run this against a production database; switch to `validate` in prod.

10. **No message queues** — all order processing, payment, and email sending is synchronous in the request thread. Under load, the checkout endpoint is the primary bottleneck.
