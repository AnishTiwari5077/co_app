# SahakariMS — API: Member API

## Base URL
`/api/v1/members`

All endpoints require `Authorization: Bearer {token}`.

---

## Member Registration

### POST /members
Register a new member.

**Permission:** `MEMBERS_CREATE`

**Request:**
```json
{
  "firstName": "Ram",
  "lastName": "Shrestha",
  "firstNameNp": "राम",
  "lastNameNp": "श्रेष्ठ",
  "gender": "Male",
  "dateOfBirthAd": "1985-06-15",
  "bloodGroup": "O+",
  "citizenshipNumber": "01-01-75-12345",
  "citizenshipIssuedDistrict": "Kathmandu",
  "citizenshipIssuedDate": "2040-03-10",
  "panNumber": "123456789",
  "phonePrimary": "9841234567",
  "phoneSecondary": null,
  "email": "ram@example.com",
  "occupation": "Businessman",
  "address": {
    "province": "Bagmati",
    "district": "Kathmandu",
    "municipality": "Kathmandu Metropolitan City",
    "ward": "15",
    "street": "New Road"
  },
  "permanentAddress": {
    "province": "Gandaki",
    "district": "Kaski",
    "municipality": "Pokhara Metropolitan City",
    "ward": "10"
  },
  "familyDetails": {
    "fatherName": "Hari Shrestha",
    "motherName": "Gita Shrestha",
    "spouseName": "Sita Shrestha",
    "grandfatherName": "Gopal Shrestha"
  },
  "nominees": [
    {
      "name": "Sita Shrestha",
      "relationship": "Spouse",
      "percentage": 100,
      "phoneNumber": "9851234567"
    }
  ],
  "initialShares": 10
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "memberCode": "KTM-2081-00523",
  "status": "Pending",
  "message": "Registration submitted. Awaiting KYC verification and approval."
}
```

---

### GET /members
List members with search and filtering.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `search` | string | Name, code, or phone (trigram) |
| `status` | string | Pending \| Active \| Suspended \| Closed |
| `kycVerified` | bool | Filter KYC status |
| `gender` | string | Male \| Female \| Other |
| `fromDate` | string | Membership from date (BS) |
| `page` | int | |
| `pageSize` | int | max 100 |

**Response 200:**
```json
{
  "items": [
    {
      "id": "uuid",
      "memberCode": "KTM-2081-00001",
      "fullName": "Ram Bahadur Shrestha",
      "gender": "Male",
      "phonePrimary": "9841234567",
      "status": "Active",
      "kycVerified": true,
      "shareCapital": 10000.00,
      "totalSavings": 45238.00,
      "loanOutstanding": 450000.00,
      "memberSinceDate": "2081-01-15"
    }
  ],
  "totalCount": 1250
}
```

---

### GET /members/{id}
Full member profile.

**Response 200:**
```json
{
  "id": "uuid",
  "memberCode": "KTM-2081-00001",
  "firstName": "Ram",
  "lastName": "Shrestha",
  "firstNameNp": "राम",
  "lastNameNp": "श्रेष्ठ",
  "gender": "Male",
  "dateOfBirthAd": "1985-06-15",
  "dateOfBirthBs": "2042-02-31",
  "age": 39,
  "bloodGroup": "O+",
  "citizenshipNumber": "01-01-75-12345",
  "panNumber": null,
  "phonePrimary": "9841234567",
  "email": "ram@example.com",
  "occupation": "Businessman",
  "address": { ... },
  "permanentAddress": { ... },
  "familyDetails": { ... },
  "nominees": [ ... ],
  "kycVerified": true,
  "status": "Active",
  "membershipDateBs": "2081-01-15",
  "photoUrl": "https://api.sahakarims.np/files/members/uuid/photo.jpg",
  "signatureUrl": "https://api.sahakarims.np/files/members/uuid/signature.jpg",
  "shareAccount": {
    "totalShares": 100,
    "shareValue": 10000.00
  },
  "financialSummary": {
    "totalSavings": 45238.00,
    "totalFdAmount": 500000.00,
    "loanOutstanding": 450000.00,
    "totalDividendReceived": 1500.00
  }
}
```

---

### PUT /members/{id}
Update member information.

**Permission:** `MEMBERS_EDIT`

**Request:** Partial update — include only changed fields.
```json
{
  "phonePrimary": "9851234567",
  "email": "ram.new@example.com",
  "address": { "ward": "16" }
}
```

---

### POST /members/{id}/kyc-verify
Mark KYC as verified after document review.

**Permission:** `MEMBERS_KYC_VERIFY`

**Request:**
```json
{ "remarks": "Citizenship verified. Photo matches." }
```

---

### POST /members/{id}/approve
Approve pending membership.

**Permission:** `MEMBERS_APPROVE`

**Request:**
```json
{ "remarks": "All documents in order." }
```

**Side effects:**
- Status → Active
- Share account opened
- Welcome SMS sent

---

### POST /members/{id}/suspend
**Permission:** `MEMBERS_EDIT`

```json
{ "reason": "Irregular loan repayment behaviour" }
```

---

### POST /members/{id}/reactivate
**Permission:** `MEMBERS_APPROVE`

---

### GET /members/{id}/documents
List uploaded KYC documents.

### POST /members/{id}/documents
Upload document (multipart/form-data).

**Fields:** `file`, `documentType` (Citizenship \| PanCard \| IncomeProof \| Other), `description`

---

### GET /members/search
Quick search for collector/cashier use.

**Query:** `q` — name, code, or phone (returns max 10 results instantly)

### GET /members/export
Export member list as Excel.

**Permission:** `REPORTS_EXPORT`

### GET /members/copomis
Export COPOMIS XML for the current quarter.

**Permission:** `REPORTS_COPOMIS`
