# SahakariMS — Testing: Performance Testing

## Overview

Performance tests ensure SahakariMS meets response time SLAs and handles peak cooperative load without degradation. We use **k6** for load testing.

---

## Performance Targets (SLAs)

| Endpoint Type | P50 | P95 | P99 | Error Rate |
|--------------|-----|-----|-----|-----------|
| Read (GET) | < 100ms | < 300ms | < 500ms | < 0.1% |
| Write (POST) | < 200ms | < 500ms | < 1000ms | < 0.5% |
| Report generation | < 1000ms | < 3000ms | < 5000ms | < 1% |
| Statement PDF | < 2000ms | < 5000ms | < 10000ms | < 1% |

**Peak load:** 500 concurrent users (branch + collectors + mobile banking at month end)

---

## k6 Load Test Scripts

### Baseline Test (50 users, 5 minutes)

```javascript
// tests/k6/baseline.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const depositDuration = new Trend('deposit_duration');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up
    { duration: '4m', target: 50 },    // Sustained
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    errors: ['rate<0.01'],
    deposit_duration: ['p(95)<500'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://api.sahakarims.np';
let accessToken = '';

export function setup() {
  const loginRes = http.post(`${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ username: __ENV.TEST_USER, password: __ENV.TEST_PASS }),
    { headers: { 'Content-Type': 'application/json' } });

  return { token: loginRes.json('accessToken') };
}

export default function (data) {
  const headers = {
    'Authorization': `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };

  // 60% of requests: read operations
  if (Math.random() < 0.6) {
    const membersRes = http.get(`${BASE_URL}/api/v1/members?page=1&pageSize=20`, { headers });
    check(membersRes, {
      'members list 200': (r) => r.status === 200,
      'members list fast': (r) => r.timings.duration < 300,
    });
    errorRate.add(membersRes.status !== 200);
  }

  // 30% of requests: deposit transactions
  else if (Math.random() < 0.9) {
    const start = Date.now();
    const depositRes = http.post(
      `${BASE_URL}/api/v1/savings/accounts/${__ENV.TEST_ACCOUNT_ID}/deposit`,
      JSON.stringify({ amount: 1000, depositMode: 'Cash', narration: 'k6 load test' }),
      { headers });

    depositDuration.add(Date.now() - start);
    check(depositRes, {
      'deposit 201': (r) => r.status === 201,
    });
    errorRate.add(depositRes.status !== 201);
  }

  // 10%: reports
  else {
    const reportRes = http.get(`${BASE_URL}/api/v1/reports/daily-collection`, { headers });
    check(reportRes, {
      'report 200': (r) => r.status === 200,
      'report within 3s': (r) => r.timings.duration < 3000,
    });
  }

  sleep(1);  // Think time
}
```

### Peak Load Test (500 users, 10 minutes)

```javascript
// tests/k6/peak-load.js
export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp to 100
    { duration: '2m', target: 300 },   // Ramp to 300
    { duration: '2m', target: 500 },   // Ramp to peak 500
    { duration: '4m', target: 500 },   // Sustain peak
    { duration: '1m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000', 'p(99)<5000'],
    http_req_failed: ['rate<0.05'],  // < 5% error at peak
  },
};
```

### Stress Test (find breaking point)

```javascript
// tests/k6/stress.js
export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 400 },
    { duration: '2m', target: 600 },
    { duration: '2m', target: 800 },
    { duration: '2m', target: 1000 },  // Find where it breaks
    { duration: '2m', target: 0 },
  ],
};
```

---

## Running Load Tests

```bash
# Install k6
choco install k6  # Windows
# or: brew install k6  # Mac

# Run baseline test
k6 run \
  -e BASE_URL=https://api.sahakarims.np \
  -e TEST_USER=perf_test_user@sahakarims.np \
  -e TEST_PASS=PerfTest@1234 \
  -e TEST_ACCOUNT_ID=uuid-of-test-account \
  tests/k6/baseline.js

# Run with HTML report
k6 run --out json=results.json tests/k6/baseline.js
k6-reporter --data results.json --output report.html

# Run against local Docker
k6 run \
  -e BASE_URL=http://localhost:8080 \
  tests/k6/baseline.js
```

---

## Database Performance

### Slow Query Monitoring

```sql
-- Enable slow query logging in PostgreSQL
ALTER SYSTEM SET log_min_duration_statement = '500';  -- 500ms threshold
SELECT pg_reload_conf();

-- Find slow queries (pg_stat_statements)
SELECT
    query,
    calls,
    mean_exec_time AS avg_ms,
    max_exec_time AS max_ms,
    stddev_exec_time AS stddev_ms,
    rows / calls AS avg_rows
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Connection Pool Monitoring

```csharp
// Optimal pool settings for 500 concurrent users
services.AddDbContextPool<SahakariMSDbContext>(options =>
    options.UseNpgsql(connectionString, npgsql =>
    {
        npgsql.CommandTimeout(30);
    }),
    poolSize: 128  // DB context pool size
);

// In connection string:
// MinPoolSize=5;MaxPoolSize=100;ConnectionLifetime=300;
```

---

## Expected Results Summary

| Test | Target | Pass Criteria |
|------|--------|--------------|
| Baseline (50 users) | P95 < 500ms | Must pass before deployment |
| Peak (500 users) | P95 < 2s | Must pass before production |
| Stress | Find limit | Document capacity ceiling |
| Endurance (8h) | Memory stable | No memory leak |
| Spike (0→500 in 30s) | No crash | Recovery in < 2 min |

---

## Performance Optimization Checklist

- [ ] All high-traffic endpoints have Redis caching
- [ ] Database connection pool sized correctly
- [ ] N+1 queries eliminated (use `.Include()` or raw SQL)
- [ ] Large result sets paginated (max 100 per page)
- [ ] Heavy reports run as background jobs (Hangfire)
- [ ] PDF generation cached (same params = same PDF for 5 min)
- [ ] Database indexes created for all WHERE/ORDER BY columns
- [ ] PostgreSQL autovacuum configured
- [ ] `EXPLAIN ANALYZE` run on top 20 slowest queries
