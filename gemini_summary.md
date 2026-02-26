# Shopizer Technical Architecture Summary

This summary provides a high-level overview of the Shopizer e-commerce platform for developers joining the project.

---

## 1. High-Level Purpose
Shopizer is an **open-source, self-hosted e-commerce platform** designed as an alternative to SaaS solutions. It provides a full-featured commerce engine, a multi-tenant backend, an Angular-based administration panel, and a React-based customer storefront. It supports multi-currency, multi-language, and multi-store deployments out of the box.

## 2. Architecture & Design
Shopizer follows a **Modular Monolith** architecture with a classic layered pattern.

*   **Layered Pattern:** `Controller (REST API) -> Facade (Orchestration/DTO) -> Service (Business Logic) -> Repository (JPA/Hibernate) -> MySQL`.
*   **Facade Pattern:** Decouples API controllers from domain services, handling complex orchestration and DTO (Data Transfer Object) mappings.
*   **Populator Pattern:** Specialized classes (Populators) are used to map domain entities to readable/writable DTOs for the API.
*   **Multi-tenancy:** Every entity is scoped to a `MerchantStore`. All queries and logic require a store context to ensure data isolation.
*   **Plug-in Module System:** Payments, shipping, and email integrations are handled via a pluggable module system in `sm-core-modules`.
*   **Rules Engine:** **Drools** is used for dynamic business logic such as pricing calculations, tax rules, and shipping eligibility.

## 3. Tech Stack
| Component | Technologies |
| :--- | :--- |
| **Backend** | Java 17, Spring Boot 2.5.12, Hibernate/JPA, MySQL 8, Drools, Infinispan (Caching), JWT Security |
| **Admin UI** | Angular 11, Nebular UI, Bootstrap 4, TypeScript |
| **Storefront** | React 16, Redux, Axios, Stripe SDK |
| **Build Tools** | Maven (Backend), npm/Angular CLI (Admin), npm (React) |

## 4. Entry Points
*   **Backend Application:** `shopizer/sm-shop/src/main/java/com/salesmanager/shop/application/ShopApplication.java` (Spring Boot main).
*   **REST API Controllers:** `shopizer/sm-shop/src/main/java/com/salesmanager/shop/store/api/v1/` (API base: `/api/v1/`).
*   **Admin UI:** `shopizer-admin/src/main.ts` (Angular bootstrap).
*   **Storefront:** `shopizer-shop-reactjs/src/index.js` (React entry).

## 5. Core Logic Flow (Checkout Example)
1.  **API Call:** Client sends `POST /api/v1/auth/cart/{code}/checkout`.
2.  **Facade:** `OrderFacade` orchestrates the process: loads the `ShoppingCart`, validates the `Customer`, and identifies the `MerchantStore`.
3.  **Payment:** `PaymentService` interacts with a pluggable module (e.g., Stripe) to authorize the transaction.
4.  **Service:** `OrderService` persists the order and creates line items (`OrderProduct`).
5.  **Rules Engine:** Drools calculates final taxes, shipping costs, and totals.
6.  **Email:** `EmailService` sends a confirmation (SMTP or AWS SES).
7.  **Response:** A `ReadableOrder` DTO is returned to the client.

## 6. Data Model
*   **MerchantStore:** The root tenant entity.
*   **Product:** Includes `ProductDescription` (multilingual), `ProductPrice`, `ProductInventory`, and `ProductImage`.
*   **Category:** Self-referential tree structure for product classification.
*   **Customer:** Manages user accounts, billing, and shipping addresses.
*   **Order:** Tracks transactions, status history, and `OrderTotal` components (tax, shipping, subtotal).
*   **ShoppingCart:** Transient entity for managing items before checkout.

## 7. Project Structure
```text
/
├── shopizer/                  ← Java Backend (Maven Monorepo)
│   ├── sm-core-model/         ← Domain Entities (JPA)
│   ├── sm-core/               ← Business Services & Repositories
│   ├── sm-core-modules/       ← Pluggable Integrations (Payment/Shipping)
│   ├── sm-shop-model/         ← API DTOs
│   └── sm-shop/               ← Spring Boot App & REST Controllers
├── shopizer-admin/            ← Angular Administration Panel
└── shopizer-shop-reactjs/     ← React Customer Storefront
```

## 8. External Dependencies
*   **Database:** MySQL (Primary storage).
*   **Storage:** AWS S3 or Google Cloud Storage for product images.
*   **Payment:** Stripe, PayPal, Braintree (Pluggable modules).
*   **Email:** SMTP or AWS SES.
*   **Search:** Elasticsearch (Optional/Configurable).

## 9. Getting Started
1.  **Database:** Start MySQL and create a database named `SALESMANAGER`.
2.  **Backend Configuration:** You **must** create `shopizer/sm-shop/src/main/resources/database.properties` manually (it is gitignored). Use `database.properties.example` if available.
3.  **Run All:** Use the provided master script: `./start-all.sh`.
    *   **Backend:** `cd shopizer && ./mvnw spring-boot:run -pl sm-shop`
    *   **Admin:** `cd shopizer-admin && npm start`
    *   **Storefront:** `cd shopizer-shop-reactjs && npm start`

## 10. Potential Complexity & 'Gotchas'
*   **Mixed Configuration:** Shopizer uses both **XML Spring configuration** (`shopizer-core-config.xml`) and **Java Annotations**. Ensure you check both when modifying core wiring.
*   **Security Chains:** There are **4 overlapping security chains** in `MultipleEntryPointsSecurityConfig.java`. Be careful when defining new API paths; they must match the correct order/chain.
*   **Synchronous Processing:** Most order processing (payments, emails) happens synchronously in the request thread. Large volumes may require refactoring towards an event-driven model.
*   **M1/M2 Mac Issues:** The `fibers` package in the Angular admin can fail on ARM64. Delete `node_modules/fibers` after `npm install` if the build crashes.
