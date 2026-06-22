# SahakariMS — Module: Collector App

## Overview

The Collector App is an Android application for field collectors who visit members at their homes or businesses to collect savings and loan repayments. The app operates **fully offline** and syncs data when internet connectivity is available.

---

## Key Capabilities

| Feature | Description |
|---------|-------------|
| **Offline Operation** | Full operation without internet; sync when back at branch |
| **Member Search** | Offline search in downloaded member list |
| **Collection** | Record deposits and EMI payments |
| **GPS Tagging** | Geolocation stamp on each collection |
| **Bluetooth Printing** | Print receipt via portable Bluetooth thermal printer |
| **Signature Capture** | Digital signature from member on receipt |
| **Photo Receipt** | Take photo of handwritten receipt |
| **Daily Summary** | End-of-day collection report |
| **Cash Handover** | Cash handover to branch cashier |

---

## Offline Architecture

```dart
// lib/collector/data/local/collector_database.dart

@DriftDatabase(tables: [
  OfflineMembers,
  OfflineSavingAccounts,
  OfflineLoanSchedules,
  PendingTransactions,   // Queue of transactions to sync
  SyncLog,               // Sync history and errors
])
class CollectorDatabase extends _$CollectorDatabase {
  // SQLite database for offline storage

  Stream<List<OfflineMember>> watchMembersForRoute(String routeCode) {
    return (select(offlineMembers)
      ..where((m) => m.routeCode.equals(routeCode))
      ..orderBy([(m) => OrderingTerm(expression: m.fullName)]))
        .watch();
  }

  Future<void> queueTransaction(PendingTransactionsCompanion txn) async {
    await into(pendingTransactions).insert(txn);
  }
}
```

### Sync Process

```dart
class CollectorSyncService {
  final CollectorDatabase _localDb;
  final CollectorApiService _apiService;

  // DOWNLOAD: Morning sync — download today's route
  Future<void> downloadRouteAsync() async {
    final members = await _apiService.getRouteMembers(_routeCode);
    final accounts = await _apiService.getAccountsForRoute(_routeCode);
    final schedules = await _apiService.getLoanSchedulesForRoute(_routeCode);

    await _localDb.refreshOfflineData(members, accounts, schedules);
  }

  // UPLOAD: Sync pending transactions when connected
  Future<SyncResult> uploadPendingTransactionsAsync() async {
    final pending = await _localDb.getPendingTransactions();
    if (pending.isEmpty) return SyncResult.empty();

    final result = await _apiService.bulkSyncTransactions(pending);

    for (final txn in result.successful) {
      await _localDb.markTransactionSynced(txn.localId, txn.serverId);
    }

    for (final failed in result.failed) {
      await _localDb.markTransactionFailed(failed.localId, failed.reason);
    }

    return result;
  }
}
```

---

## Collection Flow

```
1. Collector logs in with PIN
       │
       ▼
2. App checks for internet
   - Online: Download today's route (member list, due EMIs)
   - Offline: Use last downloaded data
       │
       ▼
3. Collector sees today's route
   - List of members with pending collections
   - Color coded: Green (savings), Orange (EMI due), Red (overdue)
       │
       ▼
4. For each member:
   a. Find member (search or list tap)
   b. View account summary and amounts due
   c. Enter amount collected
   d. Collect digital signature from member
   e. Print Bluetooth receipt
   f. Record GPS location (auto)
   g. Transaction saved to local SQLite queue
       │
       ▼
5. End of day:
   a. View daily collection summary
   b. Return to branch
   c. Connect to WiFi → Auto-sync triggers
   d. Print handover receipt
   e. Hand cash to cashier
```

---

## Bluetooth Printing

```dart
// lib/collector/services/bluetooth_printer_service.dart
class BluetoothPrinterService {
  static const String ESC = '\x1B';
  static const String GS = '\x1D';

  Future<void> printReceipt(CollectionReceipt receipt) async {
    final printer = await _connectToDefaultPrinter();

    final builder = BytesBuilder();

    // ESC/POS commands for thermal printer
    builder.addByte(0x1B); builder.addByte(0x40); // Initialize printer
    builder.addByte(0x1B); builder.addByte(0x61); builder.addByte(0x01); // Center align

    // Logo / header
    builder.add(utf8.encode('SahakariMS\n'));
    builder.add(utf8.encode('${receipt.branchName}\n'));
    builder.add(utf8.encode('─' * 32 + '\n'));

    // Receipt details
    builder.addByte(0x1B); builder.addByte(0x61); builder.addByte(0x00); // Left align
    builder.add(utf8.encode('Receipt: ${receipt.receiptNumber}\n'));
    builder.add(utf8.encode('Date: ${receipt.date}\n'));
    builder.add(utf8.encode('Member: ${receipt.memberName}\n'));
    builder.add(utf8.encode('Account: ${receipt.accountNumber}\n'));
    builder.add(utf8.encode('─' * 32 + '\n'));
    builder.add(utf8.encode('Type: ${receipt.type}\n'));
    builder.add(utf8.encode('Amount: NPR ${receipt.amount.toStringAsFixed(2)}\n'));
    builder.add(utf8.encode('Balance: NPR ${receipt.balanceAfter.toStringAsFixed(2)}\n'));
    builder.add(utf8.encode('─' * 32 + '\n'));
    builder.add(utf8.encode('Collector: ${receipt.collectorName}\n'));

    // Feed and cut
    builder.addByte(0x1B); builder.addByte(0x64); builder.addByte(0x04); // Feed 4 lines
    builder.addByte(0x1D); builder.addByte(0x56); builder.addByte(0x42); // Cut paper

    await printer.write(builder.toBytes());
    await printer.disconnect();
  }
}
```

---

## Route Management (Backend)

```csharp
// Collector is assigned a route (geographic area or member group)
public class CollectorRoute
{
    public Guid Id { get; private set; }
    public Guid CollectorId { get; private set; }     // User (Collector role)
    public string RouteName { get; private set; }
    public string RouteCode { get; private set; }
    public List<Guid> AssignedMemberIds { get; private set; }  // Which members this collector visits
    public bool IsActive { get; private set; }
}
```

---

## GPS and Location Features

```dart
// Capture location on each transaction
Future<Position> _captureLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) throw LocationException('GPS disabled');

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied)
    permission = await Geolocator.requestPermission();

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
    timeLimit: const Duration(seconds: 10),
  );
}

// Store with each transaction
await _localDb.queueTransaction(PendingTransactionsCompanion(
  memberId: Value(member.id),
  amount: Value(amount),
  gpsLat: Value(position.latitude),
  gpsLng: Value(position.longitude),
  // ...
));
```

---

## Conflict Resolution

When the same account is transacted on both the collector app and at the counter before sync:

```
Server Conflict Resolution Rules:
1. All transactions are timestamped with UTC time
2. Both transactions are applied sequentially by timestamp
3. If balance goes negative after applying both — reject collector txn
4. Notify collector of rejection with reason
5. Collector must reconcile with branch

Priority:
  Server (counter) transactions > Collector app transactions
  (Counter cashier has authoritative access to real-time balances)
```

---

## App Security

| Feature | Implementation |
|---------|---------------|
| Login | 6-digit PIN (hashed bcrypt locally) |
| Session | 24-hour PIN session |
| Biometric | Fingerprint unlock (android.hardware.fingerprint) |
| Data encryption | SQLite encrypted with SQLCipher |
| Network | All sync over HTTPS only |
| Certificate pinning | Pinned SSL cert for API domain |
| Rooted device detection | SafetyNet / Play Integrity API |

---

## API Endpoints (Collector Sync)

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/collector/route` | COLLECTOR | Get today's route |
| GET | `/collector/members` | COLLECTOR | Download member list for route |
| GET | `/collector/accounts` | COLLECTOR | Download account balances |
| POST | `/collector/sync` | COLLECTOR | Bulk upload collected transactions |
| GET | `/collector/summary` | COLLECTOR | Today's summary |
| POST | `/collector/handover` | COLLECTOR | Record cash handover |
