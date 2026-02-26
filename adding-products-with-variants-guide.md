# Adding and Testing Products with Multiple Variants

This guide explains how to set up a product like a **Ruler** that has two distinct physical versions: **15 cm** and **30 cm**, each with its own price, stock, and SKU.

---

## 1. Understanding the Terminology

Shopizer uses a layered approach to build variants. Here is how the technical terms map to the "Ruler" example:

| Admin Label | Example for Ruler | Purpose |
| :--- | :--- | :--- |
| **Option** | `Size` | The category of the choice (e.g., Color, Size). |
| **Option Value** | `15 cm` | The actual choice the user clicks (e.g., Red, Small). |
| **Variation** | `Size: 15 cm` | A specific pairing of an Option + Option Value. This is used to track inventory for that exact combination. |
| **Inventory SKU** | `RULER-15` | The actual physical item with its own price and stock levels. |

---

## 2. Step-by-Step: Creating the "Ruler" Variants

### Step 1: Create the Option
This defines the *type* of choice you are offering.
1.  Navigate to **Inventory Management** -> **Options** -> **Options List**.
2.  Click **Create Option**.
3.  **Code:** `size` (A unique internal identifier).
4.  **Type:** `Select` (This will render as a dropdown menu in the storefront).
5.  **Name (English):** `Size` (The label the customer will see).
6.  Click **Save**.

### Step 2: Create Option Values
These are the actual choices available under the "Size" option.
1.  Navigate to **Inventory Management** -> **Options** -> **Option Values List**.
2.  Click **Create Option Value**.
3.  **Code:** `15cm` | **Name (English):** `15 cm`
4.  Click **Save**.
5.  Click **Create Option Value** again.
6.  **Code:** `30cm` | **Name (English):** `30 cm`
7.  Click **Save**.

### Step 3: Create Variations
This step links the Option (`Size`) to the Value (`15 cm`) to create a unique identifier for inventory.
1.  Navigate to **Inventory Management** -> **Options** -> **Variations List**.
2.  Click **Add Variation**.
    *   **Code:** `variation-size-15`
    *   **Option:** Select `Size`
    *   **Option Value:** Select `15 cm`
3.  Click **Save**.
4.  Repeat for the second size:
    *   **Code:** `variation-size-30`
    *   **Option:** Select `Size`
    *   **Option Value:** Select `30 cm`
5.  Click **Save**.

### Step 4: Create the Base Product
1.  Go to **Inventory Management** -> **Products** -> **Products List**.
2.  Click **Create Product**.
3.  **Name:** `Ruler` | **SKU:** `RULER` | **Price:** `0.00`
4.  Click **Save**.
5.  **Note:** After saving, a new row of tabs will appear at the bottom of the page (Images, Category, Options, **Inventory**, etc.).

### Step 5: Assign SKUs to Variations (Inventory Management)
This is where you define the physical items and their prices.
1.  Stay on the same page and click the **Inventory** tab at the bottom.
2.  Click **Add Inventory**.
    *   **SKU:** `RULER-15`
    *   **Variation:** Select `variation-size-15`
    *   **Price:** `5.00`
    *   **Quantity:** `100`
3.  Click **Save**.
4.  Click **Add Inventory** again.
    *   **SKU:** `RULER-30`
    *   **Variation:** Select `variation-size-30`
    *   **Price:** `8.00`
    *   **Quantity:** `50`
5.  Click **Save**.

---

## 3. How to Test

### Storefront Verification
1.  Open the **React Storefront** and search for `Ruler`.
2.  Select the `Ruler` product.
3.  **Check SKU Switching:**
    *   Select **15 cm** from the Size dropdown. The SKU should change to `RULER-15` and price to `$5.00`.
    *   Change the selection to **30 cm**. The SKU should change to `RULER-30` and price to `$8.00`.
4.  **Check Cart:**
    *   Add **30 cm** to the cart. Verify that the cart shows the SKU `RULER-30`.

### Developer Verification (Automated)
Run the backend integration test to verify the logic:
```bash
cd shopizer
./mvnw test -Dtest=ProductVariantIntegrationTest -pl sm-shop
```
