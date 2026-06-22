# SahakariMS — Module: Guarantors

## Overview

Guarantors are members who co-sign a loan and become legally liable if the primary borrower defaults. The Guarantors module tracks guarantor assignments, their exposure limits, and collection workflows.

---

## Guarantor Rules

| Rule | Detail |
|------|--------|
| MIN-GUARANTORS | As configured per loan product (typically 1–2) |
| MUST-BE-MEMBER | Guarantor must be an Active member of the same cooperative |
| CANNOT-BE-BORROWER | Guarantor cannot be the same person as the borrower |
| NPA-FREE | Guarantor must not have any NPA loan themselves |
| MAX-GUARANTEES | A member can guarantee maximum 3 active loans simultaneously |
| EXPOSURE-LIMIT | Total guaranteed amount ≤ 3× guarantor's share capital |
| KYC-REQUIRED | Guarantor's citizenship copy required at application |

---

## Guarantor Data Model

```sql
CREATE TABLE loan_guarantors (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id             UUID NOT NULL REFERENCES loans(id),
    guarantor_member_id UUID NOT NULL REFERENCES members(id),
    relationship        VARCHAR(50) NOT NULL,   -- Friend | Relative | Colleague
    guaranteed_amount   NUMERIC(18,4) NOT NULL, -- Same as loan principal
    citizenship_doc_id  UUID REFERENCES documents(id),
    signature_doc_id    UUID REFERENCES documents(id),
    status              VARCHAR(20) NOT NULL DEFAULT 'Active',
    -- Status: Active | Released | Under_Recovery | Recovered | Written_Off
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_guarantor_per_loan
        UNIQUE (loan_id, guarantor_member_id)
);
```

---

## Guarantor Exposure Calculation

```sql
-- Check a member's total guarantor exposure before adding them
SELECT
    gm.member_code,
    gm.first_name || ' ' || gm.last_name AS guarantor_name,
    COUNT(lg.id) AS active_guarantees,
    SUM(lg.guaranteed_amount) AS total_exposure,
    sa.current_balance AS share_capital,
    3 * sa.current_balance AS max_allowed_exposure,
    SUM(lg.guaranteed_amount) <= 3 * sa.current_balance AS within_limit
FROM members gm
LEFT JOIN loan_guarantors lg ON lg.guarantor_member_id = gm.id
    AND lg.status = 'Active'
LEFT JOIN share_accounts sa ON sa.member_id = gm.id
WHERE gm.id = 'guarantor-member-uuid'
GROUP BY gm.id, gm.member_code, gm.first_name, gm.last_name, sa.current_balance;
```

---

## Guarantor Collection Workflow (Loan Default)

```
Loan becomes NPA (90+ days overdue)
          │
          ▼
System sends alert to Branch Manager
          │
          ▼
Branch Manager initiates collection from guarantor

Collection Steps:
1. Send formal notice to guarantor (by post/hand delivery)
2. Record delivery of notice in system
3. Collect payment from guarantor
4. Apply to original loan account
5. If guarantor also cannot pay → legal proceedings

POST /loans/{id}/guarantor-collection
{
  "guarantorMemberId": "uuid",
  "amount": 50000.00,
  "paymentMode": "Cash",
  "noticeDeliveredAt": "2081-04-10",
  "narration": "Collected from guarantor — loan overdue"
}
```

---

## Guarantor Release

When a loan is fully closed, guarantors are automatically released:

```csharp
// Domain event handler
public class LoanClosedEventHandler : INotificationHandler<LoanClosedEvent>
{
    public async Task Handle(LoanClosedEvent notification, CancellationToken ct)
    {
        // Release all guarantors
        var guarantors = await _guarantorRepo.GetByLoanAsync(notification.LoanId, ct);
        foreach (var guarantor in guarantors)
        {
            guarantor.Release();
            // SMS: "Your guarantee for loan {loanNo} has been released."
            await _notificationService.SendGuarantorReleaseNoticeAsync(guarantor, ct);
        }

        await _guarantorRepo.UpdateRangeAsync(guarantors, ct);
    }
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/loans/{id}/guarantors` | LOANS_VIEW | Get loan's guarantors |
| POST | `/loans/{id}/guarantors` | LOANS_APPLY | Add guarantor to application |
| DELETE | `/loans/{id}/guarantors/{guarantorId}` | LOANS_APPLY | Remove guarantor (pending loans only) |
| GET | `/members/{id}/guarantees` | MEMBERS_VIEW | All active guarantees for a member |
| POST | `/loans/{id}/guarantor-collection` | LOANS_PAYMENT | Record guarantor payment |
| GET | `/reports/guarantor-exposure` | REPORTS_VIEW_BASIC | Guarantor exposure report |
