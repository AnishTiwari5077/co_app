# SahakariMS — Audit: Compliance

## Overview

SahakariMS is designed to comply with Nepal cooperative regulations, Nepal Rastra Bank guidelines, and international financial data protection standards.

---

## Regulatory Framework

| Regulation | Issuing Body | Applicability |
|-----------|-------------|---------------|
| Nepal Cooperative Act 2074 | Ministry of Land Management, Cooperatives and Poverty Alleviation | Core cooperative operations |
| Cooperative Regulation 2075 | Department of Cooperatives | Accounting, reporting, governance |
| COPOMIS Guidelines | Department of Cooperatives | Digital reporting format |
| NRB Monetary Policy | Nepal Rastra Bank | Interest rate caps, KYC |
| AML/CFT Directives | Financial Intelligence Unit | Anti-money laundering |
| Electronic Transaction Act 2063 | Government of Nepal | Digital records and signatures |
| Personal Privacy Act 2075 | Government of Nepal | Member data protection |

---

## COPOMIS Compliance

COPOMIS (Cooperative Portfolio and Management Information System) is mandatory quarterly reporting.

### Required Data Points

| Category | Fields |
|----------|--------|
| Member Data | Member code, name, gender, DOB, citizenship, phone, address, shares, savings, loans |
| Portfolio Data | Total members, share capital, total savings, total loans, NPA amount |
| Branch Data | Branch name, code, address, manager |
| Financial Data | Income, expenses, profit/loss for the period |

### Export Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<COPOMIS xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Header>
    <CooperativeCode>NP-LPR-001234</CooperativeCode>
    <CooperativeName>XYZ Bachat Tatha Rin Sanstha</CooperativeName>
    <RegistrationNo>2081-LPR-001234</RegistrationNo>
    <FiscalYear>2081/82</FiscalYear>
    <Quarter>Q4</Quarter>
    <ReportDate>2081-04-15</ReportDate>
  </Header>
  <MemberSummary>
    <TotalMembers>1250</TotalMembers>
    <MaleMembers>480</MaleMembers>
    <FemaleMembers>768</FemaleMembers>
    <OtherMembers>2</OtherMembers>
    <DalitMembers>125</DalitMembers>
    <JanjatiMembers>210</JanjatiMembers>
    <NewMembersThisQuarter>45</NewMembersThisQuarter>
  </MemberSummary>
  <Portfolio>
    <ShareCapital>12500000</ShareCapital>
    <TotalSavings>45000000</TotalSavings>
    <TotalLoans>78000000</TotalLoans>
    <NPAAmount>1800000</NPAAmount>
    <LoanLossProvision>900000</LoanLossProvision>
  </Portfolio>
  <!-- Per-member details -->
  <Members>
    <Member>
      ...
    </Member>
  </Members>
</COPOMIS>
```

### Submission Process

1. Navigate to Reports → COPOMIS Export
2. Select fiscal year and quarter
3. System generates XML file
4. Download XML
5. Upload to DoC COPOMIS portal (municipality-level)
6. Receive submission acknowledgment number
7. Store acknowledgment in SahakariMS (Settings → COPOMIS Submissions)

---

## KYC Compliance

### Mandatory KYC Documents

Per Nepal NRB and DoC guidelines, members must provide:

| Document | Required | Purpose |
|----------|----------|---------|
| Citizenship certificate | Mandatory | Identity verification |
| Photograph | Mandatory | Identity |
| Digital signature | Mandatory | Transaction authorization |
| PAN card | For loans > NPR 5 lakh | Tax reporting |
| Income proof | For loans > NPR 2 lakh | Repayment capacity |

### Enhanced Due Diligence (EDD)

EDD required for:
- Politically Exposed Persons (PEPs)
- Members with loans > NPR 10 lakh
- Members with transaction volumes above NRB thresholds
- Members from high-risk districts

---

## AML/CFT Compliance

### Transaction Monitoring Rules

| Rule | Threshold | Action |
|------|-----------|--------|
| Large cash deposit | > NPR 10 lakh single transaction | File STR with FIU |
| Unusual pattern | 10+ transactions in a day | Flag for review |
| Structuring | Multiple deposits just below 10 lakh | Alert AML officer |
| New account large deposit | > NPR 5 lakh within 7 days of opening | Enhanced review |
| Cash withdrawal | > NPR 10 lakh | Record identity |

### Suspicious Transaction Report (STR)

When a suspicious transaction is flagged:

```
1. System flags transaction with reason
2. Branch Manager reviews within 24 hours
3. If confirmed suspicious:
   a. File STR with Financial Intelligence Unit (FIU) Nepal
   b. Do not alert the customer (tipping off offense)
   c. Continue normal operations
4. STR reference stored in audit_logs
```

---

## Data Retention Requirements

| Data Category | Minimum Retention | Legal Basis |
|--------------|------------------|-------------|
| Member KYC records | 10 years after account close | Nepal Cooperative Act |
| Financial transactions | 10 years | Nepal Cooperative Act |
| Audit logs | 7 years | Nepal Tax laws |
| Loan documents | 10 years after closure | Nepal Cooperative Act |
| Board minutes | Permanent | Corporate governance |
| COPOMIS submissions | 7 years | DoC requirement |
| STR filings | 10 years | AML/CFT Directive |

---

## Annual Compliance Checklist

### Before Annual General Meeting (AGM)

- [ ] Fiscal year accounts finalized and audited
- [ ] COPOMIS annual report submitted to DoC
- [ ] PEARLS ratios calculated and reported
- [ ] NPA classification verified
- [ ] Loan loss provision adequately maintained
- [ ] Reserve funds allocated as per Cooperative Act (25% + 5% + 3% + 2%)
- [ ] Dividend rate proposed based on available surplus
- [ ] Audit report from licensed cooperative auditor
- [ ] Annual return filed with DoC within 3 months of year-end

### Quarterly

- [ ] COPOMIS quarterly data submitted to municipality
- [ ] Interest rates reviewed against NRB policy
- [ ] NPA report to board

### Monthly

- [ ] Trial balance verified
- [ ] Cash reconciliation completed
- [ ] Overdue loan report reviewed by management
- [ ] SMS/notification costs reviewed

---

## Audit Trail for Compliance

Every regulatory-relevant action is permanently logged:

```sql
-- Compliance audit query: All large transactions
SELECT
    st.transaction_date_ad,
    st.transaction_date_bs,
    m.member_code,
    m.first_name || ' ' || m.last_name AS member_name,
    m.citizenship_number,
    st.txn_type,
    st.amount,
    st.txn_mode,
    st.receipt_number,
    u.full_name AS processed_by,
    al.ip_address
FROM saving_transactions st
JOIN saving_accounts sa ON sa.id = st.account_id
JOIN members m ON m.id = sa.member_id
JOIN users u ON u.id = st.created_by
JOIN audit.audit_logs al ON al.entity_id = st.id
WHERE st.amount >= 1000000  -- NPR 10 lakh
  AND st.transaction_date_ad BETWEEN '2024-04-14' AND '2025-04-13'
ORDER BY st.amount DESC;
```

---

## Auditor Access

External auditors are given a read-only `Auditor` role:
- Full read access to all financial data
- Cannot modify any records
- All access is logged
- Session is time-limited (configurable, default 30 days)
- Separate login credentials issued per audit engagement
