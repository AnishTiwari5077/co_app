# SahakariMS — API: Notification API

## Base URL
`/api/v1/notifications`

All endpoints require `Authorization: Bearer {token}`.

---

## Member Notifications

### GET /notifications
Get the current user's (or member's) notification inbox.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `isRead` | bool | Filter by read/unread |
| `type` | string | SMS \| Email \| Push \| InApp |
| `page` | int | |
| `pageSize` | int | |

**Response 200:**
```json
{
  "items": [
    {
      "id": "uuid",
      "title": "Deposit Received",
      "body": "NPR 5,000 credited to your account SAV-KTM-2081-456. Balance: NPR 45,238.",
      "type": "InApp",
      "isRead": false,
      "createdAt": "2081-04-15T09:32:11Z",
      "referenceType": "SavingTransaction",
      "referenceId": "uuid"
    }
  ],
  "totalCount": 15,
  "unreadCount": 3
}
```

---

### PUT /notifications/{id}/read
Mark a single notification as read.

**Response 204:** No content.

---

### PUT /notifications/read-all
Mark all notifications as read.

**Response 204:** No content.

---

## Notification Preferences

### GET /notifications/preferences
Get member's notification preferences.

**Response 200:**
```json
{
  "smsEnabled": true,
  "emailEnabled": true,
  "pushEnabled": true,
  "smsTransactions": true,
  "smsEmiReminder": true,
  "smsMarketing": false,
  "emailStatements": true,
  "emailMarketing": false
}
```

---

### PUT /notifications/preferences
Update notification preferences.

**Request:**
```json
{
  "smsMarketing": false,
  "emailMarketing": false
}
```

---

## Admin Notification Endpoints

### GET /admin/notifications/sms-logs
View SMS delivery logs and success rates.

**Permission:** `ADMIN`

**Query Parameters:** `from`, `to` (dates), `gateway`, `status`, `phone`

**Response 200:**
```json
{
  "items": [
    {
      "id": "uuid",
      "phoneNumber": "9841234567",
      "messagePreview": "DEPOSIT: NPR 5,000 credited...",
      "gateway": "SparrowSMS",
      "status": "Delivered",
      "sentAt": "2081-04-15T09:32:11Z",
      "deliveredAt": "2081-04-15T09:32:14Z",
      "deliverySeconds": 3,
      "cost": 1.00
    }
  ],
  "stats": {
    "totalSent": 1250,
    "delivered": 1237,
    "failed": 13,
    "successRate": 98.96,
    "totalCostNPR": 1250.00
  }
}
```

---

### POST /admin/notifications/send-bulk
Send a bulk SMS to selected members.

**Permission:** `ADMIN`

**Request:**
```json
{
  "memberIds": ["uuid1", "uuid2"],
  "message": "सहकारी वार्षिक साधारण सभा 2081-05-01 मा हुने भएकाले उपस्थित हुनुहोला।",
  "scheduleAt": null
}
```

**Response 202:**
```json
{
  "jobId": "uuid",
  "recipientCount": 1250,
  "estimatedCost": 1250.00,
  "message": "Bulk SMS job queued successfully."
}
```

---

### GET /admin/notifications/stats
Summary statistics for the notifications system.

**Permission:** `ADMIN`

**Response 200:**
```json
{
  "sms": {
    "today": { "sent": 87, "delivered": 85, "successRate": 97.7 },
    "thisMonth": { "sent": 1250, "delivered": 1237, "successRate": 98.96 },
    "costThisMonth": 1250.00
  },
  "email": {
    "today": { "sent": 12, "delivered": 12, "successRate": 100 },
    "thisMonth": { "sent": 145, "delivered": 142, "successRate": 97.93 }
  },
  "push": {
    "today": { "sent": 230, "delivered": 218, "successRate": 94.78 },
    "thisMonth": { "sent": 4500, "delivered": 4230, "successRate": 94.0 }
  }
}
```

---

## Device Registration (Mobile App)

### POST /notifications/devices
Register a device for push notifications.

**Request:**
```json
{
  "fcmToken": "firebase-fcm-token-here",
  "deviceId": "device-uuid",
  "deviceName": "Samsung Galaxy S21",
  "os": "Android 13",
  "appVersion": "1.0.0"
}
```

**Response 201:**
```json
{ "message": "Device registered for push notifications." }
```

---

### DELETE /notifications/devices/{deviceId}
Unregister device (on logout from mobile app).

**Response 204:** No content.
