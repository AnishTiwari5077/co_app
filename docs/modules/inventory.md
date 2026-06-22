# SahakariMS — Module: Inventory

## Overview

The Inventory module manages stationery and consumables used by the cooperative — passbooks, cheque books, share certificates, receipt pads, and office supplies — to track stock levels and reorder points.

---

## Inventory Categories

| Category | Examples |
|----------|---------|
| Printed Materials | Passbooks, share certificates, receipt books |
| Stationery | Paper, pens, files, stamps |
| Technology | Ink cartridges, toners, USB drives |
| Security Items | Cheque books, FD certificates, security seals |

---

## Data Model

```sql
CREATE TABLE inventory_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID NOT NULL REFERENCES branches(id),
    item_code       VARCHAR(30) NOT NULL,        -- INV-KTM-PASS-001
    item_name       VARCHAR(200) NOT NULL,
    category        VARCHAR(50) NOT NULL,
    unit            VARCHAR(20) NOT NULL,         -- Piece | Pack | Ream | Box
    current_stock   INT NOT NULL DEFAULT 0,
    minimum_stock   INT NOT NULL DEFAULT 10,      -- Reorder point
    unit_cost       NUMERIC(10,2) NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inventory_transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID NOT NULL REFERENCES inventory_items(id),
    branch_id       UUID NOT NULL REFERENCES branches(id),
    txn_type        VARCHAR(20) NOT NULL,         -- Purchase | Issue | Return | Adjustment
    quantity        INT NOT NULL,
    unit_cost       NUMERIC(10,2),
    total_cost      NUMERIC(12,2),
    reference       VARCHAR(100),                 -- Vendor invoice / passbook series
    narration       TEXT,
    processed_by    UUID NOT NULL REFERENCES users(id),
    txn_date        DATE NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Passbook and Certificate Tracking

Passbooks and certificates carry unique serial numbers and must be tracked individually:

```sql
CREATE TABLE passbook_stock (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID NOT NULL REFERENCES branches(id),
    series_from     INT NOT NULL,         -- Starting serial number in batch
    series_to       INT NOT NULL,         -- Ending serial number
    issued_count    INT NOT NULL DEFAULT 0,
    available_count INT GENERATED ALWAYS AS (series_to - series_from + 1 - issued_count) STORED,
    received_date   DATE NOT NULL,
    vendor          VARCHAR(200),
    cost_per_unit   NUMERIC(10,2),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);
```

---

## Low Stock Alerts

```csharp
[DisableConcurrentExecution(60)]
public class LowStockAlertJob
{
    public async Task ExecuteAsync()
    {
        var lowStockItems = await _inventoryRepo.GetLowStockItemsAsync();

        foreach (var item in lowStockItems)
        {
            if (item.CurrentStock <= item.MinimumStock)
            {
                await _notificationService.SendInAppNotificationAsync(
                    new InAppNotification
                    {
                        RecipientRole = "Manager",
                        BranchId = item.BranchId,
                        Title = "Low Stock Alert",
                        Body = $"{item.ItemName} stock is low: {item.CurrentStock} {item.Unit} remaining. Minimum: {item.MinimumStock}",
                        Type = "Inventory"
                    });
            }
        }
    }
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/inventory` | ADMIN | List all inventory items |
| POST | `/inventory` | ADMIN | Add new item |
| GET | `/inventory/{id}` | ADMIN | Item details with stock history |
| POST | `/inventory/{id}/purchase` | ADMIN | Record stock purchase |
| POST | `/inventory/{id}/issue` | ADMIN | Issue stock (passbooks, etc.) |
| GET | `/inventory/low-stock` | ADMIN | Items below minimum stock |
| GET | `/inventory/passbooks` | ADMIN | Passbook serial tracking |
| GET | `/reports/inventory` | ADMIN | Inventory register report |
