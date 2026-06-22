# SahakariMS — Monitoring & Observability

## Overview

SahakariMS uses **Prometheus + Grafana** for metrics, **Serilog → Elasticsearch** for structured logs, and **UptimeRobot** for external uptime monitoring.

---

## Metrics (Prometheus)

### prometheus.yml

```yaml
# docker/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: 'sahakarims-api'
    static_configs:
      - targets: ['api:8080']
    metrics_path: /metrics

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### ASP.NET Core Metrics (Prometheus-net)

```csharp
// Program.cs
builder.Services.AddMetrics();
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddPrometheusExporter();
    });

// Custom business metrics
public class CooperativeMetrics
{
    private static readonly Counter TransactionCounter = Metrics
        .CreateCounter("sahakarims_transactions_total",
            "Total financial transactions",
            new[] { "type", "branch" });

    private static readonly Histogram TransactionAmount = Metrics
        .CreateHistogram("sahakarims_transaction_amount_npr",
            "Transaction amounts in NPR",
            new HistogramConfiguration
            {
                Buckets = new[] { 100.0, 500.0, 1000.0, 5000.0, 10000.0,
                                  50000.0, 100000.0, 500000.0, 1000000.0 },
                LabelNames = new[] { "type" }
            });

    private static readonly Gauge ActiveLoansGauge = Metrics
        .CreateGauge("sahakarims_active_loans",
            "Number of active loans",
            new[] { "branch" });

    public static void RecordTransaction(string type, string branch, decimal amount)
    {
        TransactionCounter.WithLabels(type, branch).Inc();
        TransactionAmount.WithLabels(type).Observe((double)amount);
    }
}
```

---

## Key Metrics to Track

### API Health

| Metric | Alert Threshold |
|--------|----------------|
| Request rate | Baseline ± 50% |
| Error rate (5xx) | > 1% |
| P95 response time | > 2 seconds |
| P99 response time | > 5 seconds |
| Active connections | > 1000 |

### Database Health

| Metric | Alert Threshold |
|--------|----------------|
| Connection pool usage | > 80% |
| Query duration P95 | > 500ms |
| Deadlock count | > 0 |
| Replication lag | > 30s |
| Table bloat | > 20% |
| Cache hit ratio | < 95% |

### Business Metrics

| Metric | Description |
|--------|-------------|
| `transactions_total` | Total by type per day |
| `active_loans` | Current active loan count |
| `savings_balance_total` | Total savings in system |
| `emi_overdue_count` | Count of overdue EMIs |
| `failed_logins_total` | Security monitoring |
| `sms_delivery_rate` | SMS gateway health |
| `backup_success` | Backup job success/failure |

---

## Grafana Dashboards

### Dashboard 1: Executive Overview

```
┌─────────────────┬─────────────────┬─────────────────┐
│ Total Members   │ Active Loans    │ Total Savings   │
│    1,250        │     423         │ NPR 4.5 Cr      │
├─────────────────┴─────────────────┴─────────────────┤
│         Today's Transaction Volume (Bar Chart)       │
│   Deposits: NPR 2.5L  │  Withdrawals: NPR 1.2L       │
├────────────────────────────────────────────────────┤
│      Loan Recovery Rate (Gauge)    94.5%           │
├─────────────────────┬──────────────────────────────┤
│ NPA Amount          │ Cash Position                │
│ NPR 3.2L (2.3%)    │ NPR 8.5L                     │
└─────────────────────┴──────────────────────────────┘
```

### Dashboard 2: API Performance

- Request rate (RPS) — time series
- Error rate % — time series with alert line at 1%
- P50 / P95 / P99 response time — time series
- Slowest endpoints — table
- Active connections — gauge
- Cache hit rate — gauge

### Dashboard 3: Database Performance

- Queries per second
- Active connections vs pool size
- Query duration histogram
- Deadlocks and lock waits
- Table sizes (top 10)
- Vacuum status

---

## Alert Rules

```yaml
# docker/prometheus/rules/alerts.yml
groups:
  - name: sahakarims-api
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High API error rate"
          description: "API error rate is {{ $value | humanizePercentage }}"

      - alert: SlowAPIResponse
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow API responses"
          description: "P95 response time is {{ $value }}s"

      - alert: DatabaseConnectionsHigh
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL connections near limit"

      - alert: BackupFailed
        expr: sahakarims_backup_success == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database backup failed!"
          description: "Nightly backup has not completed successfully"

      - alert: DiskSpaceLow
        expr: node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space — {{ $value | humanizePercentage }} remaining"
```

---

## Structured Logging (Serilog)

```csharp
// Program.cs — Serilog configuration
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.EntityFrameworkCore.Database.Command", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithEnvironmentName()
    .Enrich.WithProperty("Application", "SahakariMS")
    .WriteTo.Console(outputTemplate:
        "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.Elasticsearch(new ElasticsearchSinkOptions(
        new Uri(Configuration["Elasticsearch:Uri"]))
    {
        AutoRegisterTemplate = true,
        IndexFormat = "sahakarims-logs-{0:yyyy.MM.dd}",
        NumberOfReplicas = 0,
        NumberOfShards = 1
    })
    .CreateLogger();
```

### Log Templates

```csharp
// Structured log examples (searchable in Kibana)

// Financial transaction
_logger.LogInformation(
    "Transaction {TransactionType} completed. " +
    "MemberId={MemberId}, AccountId={AccountId}, " +
    "Amount={Amount}, ReceiptNumber={Receipt}",
    "Deposit", memberId, accountId, amount, receiptNumber);

// Loan disbursement
_logger.LogInformation(
    "Loan {LoanNumber} disbursed. " +
    "MemberId={MemberId}, Amount={Amount}, DisbursedBy={UserId}",
    loan.LoanNumber, loan.MemberId, amount, currentUserId);

// Security event
_logger.LogWarning(
    "Failed login attempt. Username={Username}, " +
    "IP={IpAddress}, Attempt={AttemptNumber}",
    username, ipAddress, attemptNumber);
```

---

## Uptime Monitoring

Configure **UptimeRobot** (free tier) to monitor:

| Monitor | URL | Interval | Alert |
|---------|-----|---------|-------|
| API Health | `https://api.sahakarims.np/health` | 5 min | Email + SMS |
| Web App | `https://app.sahakarims.np` | 5 min | Email |
| SSL Certificate | API domain | Daily | Email (30 days before expiry) |

---

## Log Retention Policy

| Log Type | Retention | Storage |
|----------|----------|---------|
| Application logs (INFO+) | 30 days | Elasticsearch |
| Error logs (ERROR+) | 90 days | Elasticsearch |
| Security events | 1 year | Elasticsearch |
| Audit logs (PostgreSQL) | 7 years | PostgreSQL + archived to MinIO |
| Nginx access logs | 7 days | Server filesystem |
| Prometheus metrics | 15 days | Prometheus TSDB |
| Grafana dashboards | Indefinite | Grafana database |
