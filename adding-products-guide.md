# Shopizer — Adding Products & Fixing the Storefront

## Why "Shop Now" Shows 404

Two separate problems:

### A) The hero slider "Shop Now" button is a placeholder

In `shopizer-shop-reactjs/src/components/hero-slider/HeroSliderStatic.js` (line 13):
```javascript
<a href="!#" className="btn btn-black rounded-0">{pitch3}</a>
```
`href="!#"` is not a valid route. React Router sees `/!` and renders the Not Found page.
That is the 404 you see when clicking it.

### B) Even if you navigate to a category — the database is empty

The storefront calls `http://localhost:8080/api/v1/products/?store=DEFAULT&lang=en...`
and gets nothing back. No categories or products have been created yet.

---

## How to Add Products — Full Flow

Add everything through the admin portal at **http://localhost:4200**

Default login:
```
Email:    admin@shopizer.com
Password: password
```

You need to create these 3 things **in order**:

---

### Step 1 — Create a Category

**Admin → Catalogue → Categories → Add**

| Field | Example |
|---|---|
| Name | Clothing |
| Friendly URL | `clothing` → becomes `/category/clothing` in the storefront |
| Visible | Yes |
| Sort order | 1 |

Save it and note the category name/friendly URL for use in the product and storefront link.

---

### Step 2 — Create a Product

**Admin → Catalogue → Products → Add**

**Required fields:**

| Field | Example |
|---|---|
| Product name | Blue T-Shirt |
| Friendly URL | `blue-t-shirt` |
| SKU | TSHIRT-001 |
| Price | 29.99 |
| Quantity | 100 |
| Category | Select the category from Step 1 |
| Visible | Yes |

**Optional but recommended:**
- **Image** — makes the product grid card look correct
- **Short description** — shown in the product grid card
- **Full description** — shown on the product detail page

> No "Seller" setup is needed. The `DEFAULT` merchant is already configured and mapped automatically.

---

### Step 3 — Create a Manufacturer / Brand (optional)

**Admin → Catalogue → Manufacturers → Add**

Only needed if you want to filter products by brand in the storefront sidebar.
Not required to display a product.

---

## Verify It Works

After saving the product, check these URLs in the browser:

| URL | Expected |
|---|---|
| `http://localhost:8080/api/v1/products/?store=DEFAULT&lang=en&page=0&count=15` | JSON response containing your product |
| `http://localhost:8080/api/v1/category/?store=DEFAULT&lang=en` | JSON response containing your category |
| `http://localhost:3000/category/clothing` | Product grid renders in the storefront |

Replace `clothing` with whatever friendly URL you gave your category.

---

## Fix the "Shop Now" Button

Once you have a category, point the hero slider button to it.

**File:** `shopizer-shop-reactjs/src/components/hero-slider/HeroSliderStatic.js` line 13

Change:
```javascript
<a href="!#" className="btn btn-black rounded-0">{pitch3}</a>
```
To:
```javascript
<a href="/category/clothing" className="btn btn-black rounded-0">{pitch3}</a>
```

Replace `clothing` with your actual category friendly URL.

---

## Summary — Minimum Required to See Products in Storefront

```
Category  (Catalogue → Categories → Add)
    └── Product  (Catalogue → Products → Add)
                  ├── Name, SKU, Price, Quantity
                  ├── Assign to Category
                  └── Add an image (optional but recommended)
```

That is all that is needed. The DEFAULT merchant and store are pre-configured.
