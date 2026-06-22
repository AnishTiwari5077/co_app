# SahakariMS — CI/CD Pipeline

## Overview

SahakariMS uses **GitHub Actions** for continuous integration and deployment. Every code push triggers automated builds, tests, and (on certain branches) deployments.

---

## Branch Strategy

| Branch | Purpose | Auto-Deploy |
|--------|---------|------------|
| `main` | Production-ready code | → Production server |
| `develop` | Integration branch | → Staging server |
| `feature/*` | Feature development | → Run tests only |
| `hotfix/*` | Production fixes | → Production after approval |
| `release/*` | Release preparation | → Staging server |

---

## Workflow Files

### 1. Build & Test (Every PR and Push)

```yaml
# .github/workflows/build-test.yml
name: Build and Test

on:
  push:
    branches: [main, develop, 'feature/**', 'hotfix/**', 'release/**']
  pull_request:
    branches: [main, develop]

jobs:
  backend-test:
    name: Backend — Build & Test
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: sahakarims_test
          POSTGRES_USER: sahakarims
          POSTGRES_PASSWORD: testpass
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0'

      - name: Cache NuGet packages
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
          restore-keys: ${{ runner.os }}-nuget-

      - name: Restore dependencies
        run: dotnet restore src/backend/SahakariMS.sln

      - name: Build
        run: dotnet build src/backend/SahakariMS.sln --no-restore -c Release

      - name: Run unit tests
        run: |
          dotnet test src/backend/SahakariMS.Tests/SahakariMS.Domain.Tests/SahakariMS.Domain.Tests.csproj \
            --no-build -c Release \
            --collect:"XPlat Code Coverage" \
            --results-directory ./coverage

      - name: Run integration tests
        env:
          ConnectionStrings__DefaultConnection: "Host=localhost;Database=sahakarims_test;Username=sahakarims;Password=testpass"
          Redis__Configuration: "localhost:6379"
        run: |
          dotnet test src/backend/SahakariMS.Tests/SahakariMS.Integration.Tests/SahakariMS.Integration.Tests.csproj \
            --no-build -c Release \
            --collect:"XPlat Code Coverage" \
            --results-directory ./coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/**/coverage.cobertura.xml

  flutter-test:
    name: Flutter — Test & Analyze
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'
          cache: true

      - name: Get dependencies
        run: flutter pub get
        working-directory: src/flutter

      - name: Run analyzer
        run: flutter analyze
        working-directory: src/flutter

      - name: Run tests
        run: flutter test --coverage
        working-directory: src/flutter

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: src/flutter/coverage/lcov.info

  security-scan:
    name: Security — Dependency Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: OWASP Dependency Check (Backend)
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'SahakariMS Backend'
          path: 'src/backend'
          format: 'HTML'
          out: 'reports'
          args: >
            --failOnCVSS 7
            --enableRetired

      - name: Upload Dependency Check Results
        uses: actions/upload-artifact@v4
        with:
          name: dependency-check-report
          path: reports/

  code-quality:
    name: Code Quality — SonarQube
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: SonarQube Scan
        uses: SonarSource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

### 2. Build Docker Image (on main and develop)

```yaml
# .github/workflows/build-image.yml
name: Build Docker Image

on:
  push:
    branches: [main, develop]
  release:
    types: [published]

jobs:
  build-api-image:
    name: Build API Docker Image
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}/sahakarims-api
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=sha,prefix=sha-

      - name: Build and Push
        uses: docker/build-push-action@v6
        with:
          context: src/backend
          file: src/backend/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### 3. Deploy to Staging (on develop push)

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches: [develop]

jobs:
  deploy-staging:
    name: Deploy Staging
    runs-on: ubuntu-latest
    needs: [backend-test, flutter-test]
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/sahakari-ms
            git pull origin develop

            # Pull latest images
            docker compose -f docker-compose.prod.yml pull api

            # Run migrations
            docker compose -f docker-compose.prod.yml run --rm api \
              dotnet ef database update \
              --project SahakariMS.Infrastructure \
              --startup-project SahakariMS.API

            # Restart API with zero downtime
            docker compose -f docker-compose.prod.yml up -d --no-deps api

            # Health check
            sleep 15
            curl -f http://localhost:8080/health || exit 1

            echo "Staging deployment successful!"

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text": "✅ SahakariMS deployed to *staging* — `${{ github.sha }}`"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 4. Deploy to Production (on main push, with approval)

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag to deploy'
        required: true

jobs:
  deploy-production:
    name: Deploy Production
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://api.sahakarims.np
    # Requires manual approval from GitHub Environment protection rules

    steps:
      - uses: actions/checkout@v4

      - name: Create deployment record
        uses: chrnorm/deployment-action@v2
        id: deployment
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          environment: production

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            set -e
            cd /opt/sahakari-ms

            # Backup database before deployment
            /opt/sahakari-ms/scripts/backup.sh

            # Pull latest
            git pull origin main
            docker compose -f docker-compose.prod.yml pull api

            # Run migrations
            docker compose -f docker-compose.prod.yml run --rm api \
              dotnet ef database update

            # Rolling restart
            docker compose -f docker-compose.prod.yml up -d --no-deps api

            # Verify health
            sleep 20
            curl -f https://api.sahakarims.np/health

            echo "Production deployment successful!"

      - name: Update deployment status
        uses: chrnorm/deployment-status@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          deployment-id: ${{ steps.deployment.outputs.deployment_id }}
          state: success
          environment-url: https://api.sahakarims.np
```

---

## Environment Secrets Configuration

Configure these secrets in GitHub repository Settings → Secrets and Variables:

| Secret | Description |
|--------|-------------|
| `CODECOV_TOKEN` | Codecov.io upload token |
| `SONAR_TOKEN` | SonarQube auth token |
| `SONAR_HOST_URL` | SonarQube server URL |
| `STAGING_HOST` | Staging server IP |
| `STAGING_USER` | SSH username |
| `STAGING_SSH_KEY` | SSH private key |
| `PROD_HOST` | Production server IP |
| `PROD_USER` | SSH username |
| `PROD_SSH_KEY` | SSH private key |
| `SLACK_WEBHOOK` | Slack notification webhook |
| `GITHUB_TOKEN` | Auto-provided by GitHub |

---

## Pipeline Status Badges

Add to your README.md:

```markdown
[![Build & Test](https://github.com/your-org/sahakari-ms/actions/workflows/build-test.yml/badge.svg)](https://github.com/your-org/sahakari-ms/actions/workflows/build-test.yml)
[![Deploy Staging](https://github.com/your-org/sahakari-ms/actions/workflows/deploy-staging.yml/badge.svg)](https://github.com/your-org/sahakari-ms/actions/workflows/deploy-staging.yml)
[![Deploy Production](https://github.com/your-org/sahakari-ms/actions/workflows/deploy-prod.yml/badge.svg)](https://github.com/your-org/sahakari-ms/actions/workflows/deploy-prod.yml)
[![codecov](https://codecov.io/gh/your-org/sahakari-ms/branch/main/graph/badge.svg)](https://codecov.io/gh/your-org/sahakari-ms)
```
