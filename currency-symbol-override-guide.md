# How to Override Currency Symbols in Shopizer

Shopizer allows you to override the default currency symbols provided by Java (e.g., changing `Rs.` to `₹` for Indian Rupee). This is a global setting that affects how prices are displayed across the storefront, admin panel, and invoices.

## Step-by-Step Guide

### 1. Access Store Management
1.  Log in to your **Shopizer Admin Panel**.
2.  From the left-hand sidebar, navigate to **Store Management**.
3.  Click on **Store Details** (or the name of the store you wish to configure).

### 2. Configure the Override
1.  Locate the **Currency** dropdown.
2.  Select the currency you wish to modify (e.g., `INR`).
3.  Once selected, the **Currency Symbol Override** field will appear below it, showing the current symbol.
4.  Enter your preferred symbol (e.g., `₹`) into the **Currency Symbol Override** field.
    *   *Note: To revert to the default Java symbol, simply clear this field.*

### 3. Save Changes
1.  Scroll to the bottom or top of the page and click the **Save** button.
2.  A success message will appear confirming the update.

## Impact of the Change
Once saved, this override is applied globally for that currency code:
*   **Storefront:** All product prices, cart totals, and checkout pages will use the new symbol.
*   **Admin Panel:** Order lists and order details will display the updated symbol.
*   **Invoices:** Generated PDF or HTML invoices will reflect the change.

## Technical Details for Developers
*   **Database:** The value is stored in the `CURRENCY_SYMBOL_OVERRIDE` column of the `CURRENCY` table.
*   **API:** You can also update this via the REST API:
    ```http
    PUT /api/v1/private/currency/{currencyCode}
    Content-Type: application/json
    Authorization: Bearer {token}

    {
      "symbolOverride": "₹"
    }
    ```
*   **Logic:** The system uses `com.salesmanager.core.model.reference.currency.Currency.getSymbol()`. It checks if the override is present and non-blank; otherwise, it falls back to `java.util.Currency.getSymbol()`.
