# Java 21 Upgrade Plan — Shopizer Backend

**Created:** 2026-02-27
**Last Reviewed:** 2026-02-27
**Scope:** `shopizer` submodule (Spring Boot backend)
**Goal:** Upgrade from Java 17 (sm-core-model: Java 11) to Java 21 LTS

---

## ⚠️ Critical Finding — This Is Not Just a Java Version Bump

Upgrading to Java 21 requires upgrading Spring Boot from **2.5.12 → 3.x**.
Spring Boot 3 forces all of the following simultaneously — they cannot be deferred:
- All `javax.*` imports → `jakarta.*` (1,000+ files)
- Spring Security 5 → 6 (`WebSecurityConfigurerAdapter` **removed**, not deprecated)
- Springfox Swagger **removed** (incompatible with Spring Boot 3 WebMvc)
- H2 1.x → 2.x (test database breaking changes)

This is a **major multi-phase upgrade**. Each phase must be completed, tested, and committed before the next begins.

---

## Current State

| Component | Current Version | Target Version | Risk |
|-----------|----------------|----------------|------|
| Java | 17 (sm-core-model: 11) | 21 | Low |
| Spring Boot | 2.5.12 | 3.3.x | High |
| Spring Security | 5.5.x | 6.x | **Critical** |
| javax namespace | javax.* (1,000+ usages) | jakarta.* | High |
| Hibernate | 5.6.x | 6.x (via Boot 3) | High |
| jjwt | 0.8.0 | 0.12.x | High — full API rewrite |
| Springfox Swagger | 2.9.2 | ❌ Replace with SpringDoc 2.x | High |
| Lombok | verify version | 1.18.30+ required for Java 21 | Medium |
| MapStruct | 1.3.0.Final | 1.5.5.Final | Low |
| Drools | 7.32.0 | 8.44.x ⚠️ Phase 4 only | Medium |
| Infinispan | 9.4.18 | 14.x+ ⚠️ Phase 4 only | Medium |
| Elasticsearch | 7.5.2 | 8.x or replace with starter | Medium |
| MySQL Connector | 8.0.21 (wrong coords) | com.mysql:mysql-connector-j | Medium |
| H2 (test) | 1.x (via Boot 2) | 2.x (via Boot 3) | Medium |
| Guava | 27.1-jre | 33.x | Low |
| SpotBugs Plugin | 3.1.8 | 4.8.x | Medium |
| Maven Wrapper | 3.5.2 | 3.9.x | Low |

---

## Production Guardrails (Non-Negotiable)

1. **Branch per phase.** Never upgrade on `main` directly. Each phase gets its own branch (`upgrade/phase-N-name`) and a PR.
2. **All tests must pass before merging any phase.** CI must be green. No exceptions.
3. **Never delete a phase branch** until the next phase is stable — needed for rollback.
4. **Smoke tests written in Phase 0 are the definition of "working".** If they pass, the phase is safe to merge.
5. **Run `mvn enforcer:enforce` at the end of every phase** to catch version mismatches early.
6. **Keep a rollback tag.** Created in Phase 0 — always available.

---

## Phase 0 — Safety Net (Do This Before Anything Else)

**Goal:** Capture the current working behaviour as automated tests and fully understand the dependency landscape. Nothing else starts until this phase is complete.

---

### 0a. Tag the Current Stable State
```bash
git tag stable-pre-java21-upgrade
git push origin stable-pre-java21-upgrade
```

---

### 0b. Verify Existing Test Suite Passes Cleanly
```bash
mvn clean test
```
Fix any pre-existing failures before proceeding. Do not upgrade a broken codebase.

**⚠️ Known Issue — `AbstractSalesManagerCoreTestCase` is `@Ignore`**

The base class for all `sm-core` tests is marked `@Ignore`:
```java
@Ignore
public class AbstractSalesManagerCoreTestCase { ... }
```
This means the **entire sm-core test suite is silently skipped** during every test run.
The test count will look healthy but a large portion of the codebase has no test coverage running.

Action before proceeding:
- Document this as a known gap
- Do NOT count the skipped sm-core tests toward the baseline
- Treat the smoke tests written in step 0c as the only reliable safety net

---

### 0c. Run Dependency Tree Audit (Before Any Code Changes)

Capture the full dependency state as a baseline. This must be done before touching any version.

```bash
# Full tree — save for diffing after each phase
mvn dependency:tree -Dverbose > dependency-tree-phase-0.txt

# Surface all version conflicts — where Maven silently picked one version over another
mvn dependency:tree -Dverbose | grep "omitted for conflict"

# Run the enforcer explicitly to surface all violations
mvn enforcer:enforce
```

After every subsequent phase, re-run and diff:
```bash
mvn dependency:tree -Dverbose > dependency-tree-phase-N.txt
diff dependency-tree-phase-0.txt dependency-tree-phase-N.txt
```

**What to look for:**
- `omitted for conflict` lines — Maven picked a version you did not explicitly choose
- Multiple versions of the same library (Jackson, Netty, Guava)
- Drools, Infinispan, Elasticsearch pulling in old transitive versions that conflict with Spring Boot
- Spring Boot BOM silently overriding versions you declared

---

### 0d. Write Functional Smoke Tests

Write `@SpringBootTest(webEnvironment = RANDOM_PORT)` tests in:
`sm-shop/src/test/java/com/salesmanager/test/shop/smoke/`

All tests use the H2 in-memory database already configured.

**Priority 1 — Core API flows:**

| Flow | Endpoint | Method | Verify |
|------|----------|--------|--------|
| Health check | `/api/actuator/health` | GET | `status: UP` |
| Admin login | `/api/v1/private/login` | POST | 200 + token returned |
| List products | `/api/v2/products` | GET | 200 + non-empty list |
| Get product by code | `/api/v2/product/{code}` | GET | 200 + product fields |
| Create category | `/api/v1/private/category` | POST | 201 |
| Create product | `/api/v1/private/product` | POST | 201 |
| Add to cart | `/api/v1/cart/` | POST | 201 |
| Get cart | `/api/v1/cart/{code}` | GET | 200 |
| Customer register | `/api/v1/customer/register` | POST | 201 |
| Get store | `/api/v1/store/DEFAULT` | GET | 200 |
| List orders | `/api/v1/private/orders` | GET | 200 |

**Priority 2 — Full JWT token flow (critical after jjwt rewrite):**

Write a dedicated test that covers the complete authentication cycle:

```
1. POST /api/v1/private/login  → expect 200 + JWT token
2. GET  /api/v1/private/orders (no token) → expect 401
3. GET  /api/v1/private/orders (valid admin token) → expect 200
4. GET  /api/v1/private/orders (customer token on admin endpoint) → expect 403
5. POST /api/v1/auth/login (customer) → expect 200 + token
6. Use expired/malformed token → expect 401
```

If this test fails after the jjwt migration in Phase 4, the new token signing is broken.

---

### 0e. Record Baseline Test Count
```bash
mvn test 2>&1 | grep "Tests run:"
```
Save the total. After each phase, this number must be **equal or higher**. A drop means tests were accidentally removed or are now being skipped.

---

### 0f. Document All Currently Working API Endpoints
Start the app locally, open Swagger at `http://localhost:8080/swagger-ui.html`, and export or screenshot the full endpoint list. This is the functional specification. After Phase 4 (SpringDoc replaces Springfox), the same endpoints must appear at `http://localhost:8080/swagger-ui/index.html`.

---

## Phase 1 — Fix Existing Java Version Inconsistency

**Branch:** `upgrade/phase-1-fix-java-version`
**Risk:** Low

### Problem
`sm-core-model/pom.xml` explicitly declares Java 11 while the parent and all other modules use Java 17:
```xml
<maven.compiler.source>11</maven.compiler.source>
<maven.compiler.target>11</maven.compiler.target>
```

### Steps
1. Remove both properties from `sm-core-model/pom.xml` so it inherits Java 17 from the parent.
2. `mvn clean install -DskipTests`
3. `mvn test`
4. `mvn enforcer:enforce`
5. All Phase 0 smoke tests must pass.
6. Commit, push, PR → merge.

---

## Phase 2 — Spring Boot 2.5.12 → 2.7.18

**Branch:** `upgrade/phase-2-spring-boot-27`
**Risk:** Low-Medium
**Goal:** Move to the last Spring Boot 2.x release before the big jump. Still on `javax.*` — no migration needed yet.

### Steps
1. Update root `pom.xml`:
   ```xml
   <parent>
     <groupId>org.springframework.boot</groupId>
     <artifactId>spring-boot-starter-parent</artifactId>
     <version>2.7.18</version>
   </parent>
   ```
2. `mvn clean install -DskipTests`
3. Fix any compilation errors (Spring Boot 2.7 has minor deprecation changes).
4. `mvn test`
5. `mvn enforcer:enforce`
6. All Phase 0 smoke tests must pass.
7. Diff dependency tree: `mvn dependency:tree -Dverbose > dependency-tree-phase-2.txt`
8. Commit, push, PR → merge.

### Known Changes in Spring Boot 2.7
- `spring.security.oauth2` property restructuring — check `application.properties`
- Actuator endpoint changes — covered by smoke test
- Some WebMvc auto-configuration changes

---

## Phase 3 — Pre-Upgrade Dependency Updates

**Branch:** `upgrade/phase-3-dependencies`
**Risk:** Medium
**Goal:** Update third-party dependencies that are safe to upgrade **while still on Spring Boot 2.7 (javax namespace)**. This isolates dependency failures from framework failures.

### ⚠️ Namespace Constraint — Not Everything Can Be Upgraded Here

Some libraries have migrated to the `jakarta.*` namespace in their newer versions:
- **Drools 8.x** — jakarta-native
- **Infinispan 14.x** — jakarta-native

Upgrading these while still on Spring Boot 2.7 (`javax.*`) will cause `NoClassDefFoundError`
or `IncompatibleClassChangeError` at runtime — the library expects Jakarta Servlet/Persistence
APIs that do not exist on the classpath yet.

**These two must be upgraded in Phase 4 (the Mega Phase) where the whole project moves to jakarta simultaneously.**

Only the following javax-safe upgrades happen in this phase:

---

### 3a. Lombok (verify and upgrade to 1.18.30+)

Lombok below 1.18.26 does not support Java 21 annotation processing. If too old, generated getters/setters/builders silently disappear at compile time, causing hundreds of confusing errors.

1. Check current version in pom.xml.
2. Upgrade to `1.18.30`.
3. Ensure Lombok appears **before** MapStruct in the annotation processor list:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <annotationProcessorPaths>
      <path>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>1.18.30</version>
      </path>
      <!-- MapStruct MUST come after Lombok -->
      <path>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct-processor</artifactId>
        <version>1.5.5.Final</version>
      </path>
    </annotationProcessorPaths>
  </configuration>
</plugin>
```

---

### 3b. MapStruct (1.3.0.Final → 1.5.5.Final)
Update version in pom.xml. Mostly backwards compatible.
Verify annotation processor order per 3a above.

---

### 3c. Drools and Infinispan — DEFERRED TO PHASE 4

Do not upgrade these here. Both Drools 8.x and Infinispan 14.x are jakarta-native.
Upgrading them now on Spring Boot 2.7 will break the application at runtime.

**Prepare only** — audit actual usage so Phase 4 has a clear picture:
```bash
# Drools usage
grep -r "org.kie\|org.drools" sm-shop/src/main/java --include="*.java" -l

# Infinispan usage
grep -r "infinispan\|org.infinispan" sm-shop/src/main/java --include="*.java" -l
```
Record the findings. Upgrades happen in Phase 4.

---

### 3e. Elasticsearch (7.5.2 — Needs Decision)

Elasticsearch 7.5.2 is from 2020 and is **not compatible with Java 21**.
There is already a `TODO replace with starter` comment in the pom.

**Option A — Upgrade to Elasticsearch 8.x client:**
- Significant API changes between 7.x and 8.x
- Requires an Elasticsearch 8.x server

**Option B — Replace with `spring-boot-starter-data-elasticsearch`:**
- Spring-managed, compatible with Spring Boot 3
- Preferred if Elasticsearch usage is limited

1. Audit actual Elasticsearch usage:
   ```bash
   grep -r "elasticsearch\|ElasticsearchClient\|SearchRequest" sm-shop/src/main/java --include="*.java" -l
   ```
2. Choose Option A or B based on usage scope.
3. Implement and test.

---

### 3f. Guava (27.1-jre → 33.x)
Update version in pom.xml. No API breaking changes for standard usage.

---

### 3g. SpotBugs Plugin (3.1.8 → 4.8.3)

SpotBugs 3.1.8 produces false positives and failures on Java 21 bytecode.

```xml
<plugin>
  <groupId>com.github.spotbugs</groupId>
  <artifactId>spotbugs-maven-plugin</artifactId>
  <version>4.8.3</version>
</plugin>
```

Also update the `spotbugs` core dependency if declared separately in the pom.

---

### 3h. Build, Test, Enforce
```bash
mvn clean install -DskipTests
mvn test
mvn enforcer:enforce
mvn dependency:tree -Dverbose > dependency-tree-phase-3.txt
```
All Phase 0 smoke tests must pass.

### 3i. Commit, push, PR → merge.

---

## Phase 4 — Mega Phase: Spring Boot 3 + jakarta + Security 6 + Springfox

**Branch:** `upgrade/phase-4-spring-boot-3-mega`
**Risk:** VERY HIGH — the largest and most complex phase
**Goal:** Upgrade Spring Boot to 3.x. This forces jakarta migration, Spring Security 6 rewrite, and Springfox removal simultaneously. These cannot be separated.

### Why Everything Must Happen Together

| Change | Why It Cannot Be Deferred |
|--------|--------------------------|
| `javax.*` → `jakarta.*` | Spring Boot 3 internals use `jakarta.*` — mixed namespaces will not compile |
| Spring Security 6 | `WebSecurityConfigurerAdapter` is **removed** — project will not compile without rewrite |
| Springfox removal | Causes `BeanDefinitionOverrideException` at startup with Spring Boot 3 WebMvc |
| MySQL coordinates | Spring Boot 3 BOM expects `com.mysql:mysql-connector-j` |
| jjwt 0.12.x | Security rewrite touches JWT code — cleaner to do together |

**Strategy:** Update Spring Boot version first. The build will be broken. Work through the failures in order until it compiles. Then run tests.

---

### 4a. Update Spring Boot Version

```xml
<parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>3.3.8</version>
</parent>
```

The build **will fail** at this point. That is expected. Do not attempt to run it yet.

---

### 4b. Remove Springfox — Replace with SpringDoc

Springfox causes a startup crash with Spring Boot 3. Remove it first.

```xml
<!-- REMOVE -->
<dependency>
  <groupId>io.springfox</groupId>
  <artifactId>springfox-swagger2</artifactId>
</dependency>
<dependency>
  <groupId>io.springfox</groupId>
  <artifactId>springfox-swagger-ui</artifactId>
</dependency>

<!-- ADD -->
<dependency>
  <groupId>org.springdoc</groupId>
  <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
  <version>2.3.0</version>
</dependency>
```

Replace Springfox annotations in all controllers:
| Old | New |
|-----|-----|
| `@Api` | `@Tag` |
| `@ApiOperation` | `@Operation` |
| `@ApiParam` | `@Parameter` |
| `@ApiResponse` | `@ApiResponse` (SpringDoc) |

Update Nginx config (`ansible/templates/nginx.conf.j2`):
```
Old: /api/swagger-ui.html
New: /api/swagger-ui/index.html
```

---

### 4c. Update MySQL Maven Coordinates

```xml
<!-- OLD -->
<dependency>
  <groupId>mysql</groupId>
  <artifactId>mysql-connector-java</artifactId>
  <version>8.0.21</version>
</dependency>

<!-- NEW — let Spring Boot BOM manage the version -->
<dependency>
  <groupId>com.mysql</groupId>
  <artifactId>mysql-connector-j</artifactId>
</dependency>
```

`com.mysql.cj.jdbc.Driver` class name is unchanged — no properties file edits needed.

---

### 4d. Run OpenRewrite javax → jakarta Migration

```bash
mvn org.openrewrite.maven:rewrite-maven-plugin:run \
  -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-migrate-java:RELEASE \
  -Drewrite.activeRecipes=org.openrewrite.java.migrate.jakarta.JavaxMigrationToJakarta
```

Review the diff before proceeding.

**⚠️ Do NOT migrate these — they are JDK classes, not Jakarta EE:**
- `javax.crypto.*` — stays as `javax.crypto.*`
- `javax.imageio.*` — stays as `javax.imageio.*`

**After migration, verify `jakarta.inject` dependency is in the POM:**
```xml
<dependency>
  <groupId>jakarta.inject</groupId>
  <artifactId>jakarta.inject-api</artifactId>
</dependency>
```

**⚠️ Multi-Module Build Order — Always Run from Root:**
```bash
mvn clean install -DskipTests
```
Never run `mvn install` inside a submodule directory during this phase. Stale `javax.*` JARs in `.m2` from earlier modules will cause confusing classpath errors in later modules.

**Scope of changes:**

| Namespace | Occurrences |
|-----------|-------------|
| `javax.persistence.*` | ~900 |
| `javax.validation.*` | ~100 |
| `javax.servlet.*` | ~85 |
| `javax.inject.*` | ~171 |
| `javax.annotation.*` | ~7 |
| `javax.mail.*` | ~10 |

---

### 4e. Upgrade Drools (7.32.0 → 8.44.Final) and Infinispan (9.4.18 → 14.x)

These are now safe to upgrade because the project is on `jakarta.*` at this point.
Both libraries require jakarta-native classpath — which is exactly what Phase 4 provides.

**Drools:**
1. Update to `8.44.Final` in pom.xml.
2. Drools 8.x restructured some packages — fix any import errors flagged during the Phase 3 audit.
3. Run tests.

**Infinispan:**
1. Check Phase 3 audit results — is it directly used or only transitive?
2. If transitive only: Spring Boot 3 BOM may manage it automatically — check dependency tree.
3. If directly used: upgrade to `14.0.x` and fix configuration API changes.

---

### 4f. Spring Security 6 Rewrite

`WebSecurityConfigurerAdapter` is completely **removed** in Spring Security 6.
The project has 5 adapter classes in `MultipleEntryPointsSecurityConfig.java`.
Each must become a `@Bean SecurityFilterChain` method.

**Complete API change table:**

| Spring Security 5 | Spring Security 6 |
|------------------|------------------|
| `extends WebSecurityConfigurerAdapter` | `@Bean SecurityFilterChain` method |
| `http.antMatcher("/path/**")` | `http.securityMatcher("/path/**")` |
| `http.authorizeRequests()` | `http.authorizeHttpRequests()` |
| `.antMatchers("/path").permitAll()` | `.requestMatchers("/path").permitAll()` |
| `.hasRole("ROLE_AUTH")` | `.hasRole("AUTH")` — prefix auto-stripped |
| `@EnableGlobalMethodSecurity(...)` | `@EnableMethodSecurity(...)` |
| `extends GlobalMethodSecurityConfiguration` | Not needed — remove the extends |
| `http.apply(customDsl)` | Direct filter registration |

**Example rewrite — Admin API adapter:**
```java
// OLD
@Configuration
@Order(5)
public class UserApiConfigurationAdapter extends WebSecurityConfigurerAdapter {
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http.antMatcher("/api/v*/private/**")
            .csrf().disable()
            .authorizeRequests()
            .antMatchers(HttpMethod.OPTIONS).permitAll()
            .antMatchers("/api/v*/private/login*").permitAll()
            .anyRequest().hasRole("ROLE_AUTH");
    }
}

// NEW
@Bean
@Order(5)
public SecurityFilterChain adminApiSecurityChain(HttpSecurity http) throws Exception {
    http.securityMatcher("/api/v*/private/**")
        .csrf(csrf -> csrf.disable())
        .authorizeHttpRequests(auth -> auth
            .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
            .requestMatchers("/api/v*/private/login*").permitAll()
            .anyRequest().hasRole("AUTH")
        );
    return http.build();
}
```

**Fix Method Security config:**
```java
// OLD
@EnableGlobalMethodSecurity(prePostEnabled = true, securedEnabled = true, jsr250Enabled = true)
public class MethodSecurityConfig extends GlobalMethodSecurityConfiguration { ... }

// NEW
@EnableMethodSecurity(prePostEnabled = true, securedEnabled = true, jsr250Enabled = true)
public class MethodSecurityConfig { }
```

**Fix CORS — move out of filter into proper config:**
```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedMethods(List.of("POST", "GET", "PUT", "OPTIONS", "DELETE", "PATCH"));
    config.setAllowedHeaders(List.of("X-Auth-Token", "Content-Type", "Authorization", "Cache-Control"));
    config.setAllowCredentials(true);
    config.addAllowedOriginPattern("*");
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```
Then in each `SecurityFilterChain`: `http.cors(cors -> cors.configurationSource(corsConfigurationSource()))`.

**Fix AuthenticationManager — no longer auto-exposed:**
```java
@Bean
public AuthenticationManager authenticationManager(AuthenticationConfiguration config)
    throws Exception {
    return config.getAuthenticationManager();
}
```

**⚠️ Fix Password Encoding Bug — Security Vulnerability:**

Found in both authentication providers. The username is being passed where the raw password should be:
```java
// CURRENT (WRONG) — in JWTAdminAuthenticationProvider.java and JWTCustomerAuthenticationProvider.java
passwordEncoder.matches(username, storedHash)   // ← username, not password

// CORRECT
passwordEncoder.matches(rawPasswordFromRequest, user.getPassword())
```
Fix both files. This is a security vulnerability — fix it here while the security code is already being touched.

---

### 4g. Upgrade jjwt (0.8.0 → 0.12.x)

The jjwt API was completely rewritten. The old API does not exist.

Replace single dependency with three:
```xml
<!-- REMOVE -->
<dependency>
  <groupId>io.jsonwebtoken</groupId>
  <artifactId>jjwt</artifactId>
  <version>0.8.0</version>
</dependency>

<!-- ADD -->
<dependency>
  <groupId>io.jsonwebtoken</groupId>
  <artifactId>jjwt-api</artifactId>
  <version>0.12.6</version>
</dependency>
<dependency>
  <groupId>io.jsonwebtoken</groupId>
  <artifactId>jjwt-impl</artifactId>
  <version>0.12.6</version>
  <scope>runtime</scope>
</dependency>
<dependency>
  <groupId>io.jsonwebtoken</groupId>
  <artifactId>jjwt-jackson</artifactId>
  <version>0.12.6</version>
  <scope>runtime</scope>
</dependency>
```

Rewrite `JWTTokenUtil.java`:
```java
// OLD API (0.8.0)
Jwts.builder().signWith(SignatureAlgorithm.HS512, secret).compact();
Jwts.parser().setSigningKey(secret).parseClaimsJws(token).getBody();

// NEW API (0.12.x)
SecretKey key = Keys.hmacShaKeyFor(Decoders.BASE64.decode(secret));
Jwts.builder().signWith(key).compact();
Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
```

---

### 4h. Enable Maven Compiler -parameters Flag

Spring Framework 6.1+ no longer deduces parameter names from bytecode unless explicitly told to.
Without this, `@PathVariable`, `@RequestParam`, and Spring Data JPA named queries fail at **runtime**
(not compile time) with: `Name for argument of type [X] not specified`.

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <parameters>true</parameters>
  </configuration>
</plugin>
```

The Phase 0 smoke test for `/api/v2/product/{code}` will catch this if it is missing.

---

### 4i. Fix H2 1.x → 2.x Breaking Changes

Spring Boot 3 upgrades H2 from 1.x to 2.x. H2 2.x is stricter with SQL syntax.

Common failures after upgrade:
- Column/table names that were previously case-insensitive may now be case-sensitive
- Some H2 1.x syntax is no longer accepted in 2.x compatibility mode
- `INIT=RUNSCRIPT` paths may behave differently

The test `database.properties` files use H2 — run the full test suite immediately after Phase 4 compiles. Any H2 failures will be SQL-related, not application bugs. Fix them by adjusting the SQL or H2 init scripts, not the application code.

---

### 4j. Fix Spring Boot 3 Property Changes

| Property | Action |
|----------|--------|
| `spring.mvc.pathmatch.use-suffix-pattern` | **Remove** — no longer supported |
| `spring.jpa.hibernate.ddl-auto` | Validate value is still valid (`update`, `create`, etc.) |
| `spring.data.jpa.repositories.bootstrap-mode` | Verify default change doesn't affect startup |
| `management.health.probes.enabled` | Unchanged — no action needed |

---

### 4k. Fix HttpMethod Enum Change

`HttpMethod` changed from String constants to an enum in Spring 6.
Search for usages:
```bash
grep -r "HttpMethod\." sm-shop/src/main/java --include="*.java"
```
Update any direct String comparisons to use the enum properly.

---

### 4l. Build, Test, Verify Security Boundaries

```bash
mvn clean install -DskipTests   # get it to compile first
mvn test                        # then run everything
mvn enforcer:enforce
mvn dependency:tree -Dverbose > dependency-tree-phase-4.txt
```

All Phase 0 smoke tests must pass, including the full JWT flow test.

Then manually verify security boundaries are correct:

| Request | Expected |
|---------|----------|
| `GET /api/v1/private/orders` — no token | 401 |
| `GET /api/v1/private/orders` — valid admin token | 200 |
| `POST /api/v1/private/login` — no token | 200 (public) |
| `GET /api/v2/products` — no token | 200 (public) |
| `POST /api/v1/auth/register` — no token | 200 (public) |
| `GET /api/v1/private/orders` — customer token on admin endpoint | 403 |

### 4m. Commit, push, PR → merge.

---

## Phase 5 — Spring Boot 3 Follow-up Fixes

**Branch:** `upgrade/phase-5-followup`
**Risk:** Medium
**Goal:** Clean up remaining issues that are safer to address after Phase 4 is stable.

---

### 5a. Hibernate 6 — Sequence Naming Strategy (Existing Database Risk)

Hibernate 6 changed the default ID generation strategy. On a live database with existing data,
this can cause "sequence not found" errors or silent ID collisions.

Audit all entities:
```bash
grep -r "GeneratedValue" sm-core-model/src/main/java/ --include="*.java"
```

If any entity uses `GenerationType.AUTO` or `GenerationType.SEQUENCE` without an explicit
`@SequenceGenerator`, Hibernate 6 defaults to a single shared sequence `hibernate_sequence`
which may not exist in the database schema.

**Preferred fix — add explicit generators to all affected entities.**

**Temporary workaround only (remove after proper fix):**
```properties
spring.jpa.properties.hibernate.id.new_generator_mappings=false
```
Document any temporary workaround with a `TODO` comment and track it to completion.

---

### 5b. Hibernate 6 — Review Breaking Changes in Entities

Run full test suite and treat every Hibernate 6 warning as an error to fix:

| Breaking Change | Old (5.x) | New (6.x) |
|----------------|-----------|-----------|
| `@Type(type="...")` | String type name | `@Type(value = MyType.class)` |
| `@TypeDef` annotation | Used on package/class | **Removed** — delete entirely |
| HQL `DISTINCT` | Flexible | More restrictive |
| `Criteria` API generics | Lenient | Stricter signatures |
| Implicit join paths | Allowed | Explicit joins required |

---

### 5c. Externalise JWT Secret

`authentication.properties` contains a hardcoded default secret:
```properties
jwt.secret=aSecret
```
`aSecret` is publicly visible in source control and provides zero security.

Replace with environment variable injection:
```properties
jwt.secret=${JWT_SECRET:change-me-in-production}
```
Set the actual secret via environment variable in:
- `shopizer.service.j2` (Ansible systemd template)
- Local development `application.properties` (excluded from git via `.gitignore`)
- GitHub Actions secrets for CI if needed

---

### 5d. JUnit 4 → JUnit 5 Standardisation (Optional Clean-up)

The codebase mixes:
- JUnit 4: `@RunWith(SpringRunner.class)`
- JUnit 5: `@ExtendWith(SpringExtension.class)`

Spring Boot 3 supports both, so this will not break anything. However, this is a good time
to standardise on JUnit 5 across the entire test codebase for consistency.

This is optional — only do it if time allows and after all other fixes are stable.

Migration per class:
```java
// OLD (JUnit 4)
@RunWith(SpringRunner.class)

// NEW (JUnit 5)
@ExtendWith(SpringExtension.class)
```

---

### 5e. Build, Test, Enforce
```bash
mvn clean test
mvn enforcer:enforce
mvn dependency:tree -Dverbose > dependency-tree-phase-5.txt
```
All Phase 0 smoke tests must pass.

### 5f. Commit, push, PR → merge.

---

## Phase 6 — Java 17 → Java 21

**Branch:** `upgrade/phase-6-java21`
**Risk:** Low — the hard work is done. This is mostly configuration changes.

---

### 6a. Update Java Version in pom.xml
```xml
<java.version>21</java.version>
```
Update Maven Enforcer to enforce Java 21:
```xml
<!-- Change from [17,18) to: -->
<version>[21,22)</version>
```

---

### 6b. Update Maven Wrapper
```bash
mvn wrapper:wrapper -Dmaven=3.9.6
```

---

### 6c. Update GitHub Actions Workflow
```yaml
- name: Set up JDK 21
  uses: actions/setup-java@v4
  with:
    java-version: '21'
    distribution: 'temurin'
    cache: maven
```

---

### 6d. Update Ansible Playbook (`ansible/site.yml`)
```yaml
# Change:
- openjdk-17-jdk
# To:
- openjdk-21-jdk
```
Check `shopizer.service.j2` for any hardcoded Java binary path and update if present.

---

### 6e. Update Dockerfile

Current `sm-shop/Dockerfile` uses Java 11 and a deprecated image:
```dockerfile
# OLD — Java 11, adoptopenjdk is no longer maintained
FROM adoptopenjdk/openjdk11-openj9:alpine
RUN mkdir /opt/app
RUN mkdir /files
COPY target/shopizer.jar /opt/app
COPY SALESMANAGER.h2.db /
COPY ./files /files
CMD ["java", "-jar", "/opt/app/shopizer.jar"]
```

Updated:
```dockerfile
# NEW — Java 21 LTS, actively maintained Eclipse Temurin
FROM eclipse-temurin:21-jre-alpine
RUN mkdir /opt/app
COPY target/shopizer.jar /opt/app/shopizer.jar
CMD ["java", "-jar", "/opt/app/shopizer.jar"]
```

**⚠️ Note:** The old Dockerfile copies `SALESMANAGER.h2.db` and `/files`. The production setup uses MySQL (not H2). Verify these are not needed before removing them. If they are only for local testing, remove them from the production Dockerfile.

---

### 6f. Build, Test, Enforce
```bash
mvn clean test
mvn enforcer:enforce
mvn dependency:tree -Dverbose > dependency-tree-phase-6.txt
```
All Phase 0 smoke tests must pass.

### 6g. Commit, push, PR → merge.

---

## Phase 7 — Validation and Production Deployment

**Goal:** Verify the fully upgraded system works end-to-end in the Colima VM.

### 7a. Final Full Test Run
```bash
mvn clean test 2>&1 | grep "Tests run:"
```
Record total. Must be ≥ Phase 0 baseline. A lower count means tests were lost.

### 7b. Build the Artifact
```bash
mvn clean install -DskipTests
```
Verify `sm-shop/target/shopizer.jar` is produced.

### 7c. Deploy to Colima
```bash
./provision-and-deploy.sh
```

### 7d. Smoke Test the Live System

| Check | Expected |
|-------|----------|
| `http://localhost/api/actuator/health` | `{"status":"UP"}` |
| `http://localhost/api/swagger-ui/index.html` | Swagger UI loads with all endpoints |
| `http://localhost/shop` | React shop loads |
| `http://localhost/admin` | Angular admin loads |
| Admin login works | JWT token returned |
| Products visible in shop | Data loads from MySQL |
| Create product via admin | Persists correctly |

### 7e. Tag the Release
```bash
git tag stable-java21-upgrade
git push origin stable-java21-upgrade
```

---

## Rollback Plan

If any phase introduces an unresolvable failure:

1. Do NOT merge the phase branch.
2. The last stable state is always accessible:
   ```bash
   git checkout stable-pre-java21-upgrade
   ```
3. Each phase is an isolated PR — only merged phases are on `main`.
4. The tag is permanent and safe to return to from any phase.

---

## Summary Timeline

```
Phase 0  — Safety net, dependency audit, smoke tests    (mandatory, 1-2 days)
    │      Includes: JWT flow test, @Ignore callout,
    │      full dependency tree baseline
    │
Phase 1  — Fix Java 11 inconsistency                   (low risk, 1 day)
    │
Phase 2  — Spring Boot 2.5 → 2.7                       (low-medium risk, 1-2 days)
    │
Phase 3  — Pre-upgrade dependencies (javax-safe only)  (medium risk, 2-3 days)
    │      Lombok, MapStruct, Elasticsearch, Guava,
    │      SpotBugs
    │      Drools/Infinispan: audit only, NOT upgraded
    │      (both are jakarta-native — unsafe on SB 2.7)
    │
Phase 4  — MEGA PHASE: Spring Boot 3 + jakarta         (VERY HIGH risk, 4-6 days)
    │      + Drools 8.x + Infinispan 14.x (now safe)
    │      + Spring Security 6 rewrite (5 adapters)
    │      + Springfox → SpringDoc
    │      + MySQL coordinate change
    │      + jjwt API rewrite
    │      + -parameters compiler flag
    │      + H2 2.x fixes
    │      + Password encoding bug fix
    │      All must compile and pass together
    │
Phase 5  — Follow-up fixes                             (medium risk, 1-2 days)
    │      Hibernate sequences, JWT secret,
    │      property cleanup, optional JUnit 5 migration
    │
Phase 6  — Java 17 → Java 21                           (low risk, 1 day)
    │      + Dockerfile, GitHub Actions, Ansible
    │
Phase 7  — Full validation + production deploy          (1 day)
```

**Total estimated effort:** 12–18 days for a careful, production-safe upgrade.

---

## Key Rules to Remember

1. **Phase 3 (dependencies) must come before Phase 4 (Spring Boot 3)** — fix Lombok, MapStruct, and build tooling on stable ground before the mega-phase.
2. **Phase 4 is atomic** — Spring Boot 3, jakarta migration, Security 6, and Springfox removal cannot be split into sub-phases because none of them will compile until all are done.
3. **Never run `mvn install` inside a submodule** during Phase 4 — always run from project root.
4. **`mvn enforcer:enforce` after every phase** — catches version mismatches before they cause mysterious runtime failures.
5. **H2 failures in Phase 4 are SQL issues, not application bugs** — fix them in the test SQL scripts, not the application code.
