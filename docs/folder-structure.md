# SahakariMS — Folder Structure

## Root Project Structure

```
sahakari-ms/
├── src/
│   ├── backend/                  # ASP.NET Core 8 backend
│   ├── flutter/                  # Flutter cross-platform frontend
│   └── shared/                   # Shared contracts and DTOs
├── docs/                         # All documentation
├── docker/                       # Docker configuration files
├── scripts/                      # Utility scripts
├── .github/
│   └── workflows/                # GitHub Actions CI/CD workflows
├── .env.example
├── docker-compose.yml
├── docker-compose.dev.yml
├── docker-compose.prod.yml
└── README.md
```

---

## Flutter Application

```
src/flutter/
├── android/
│   └── app/
│       └── build.gradle
├── ios/
│   └── Runner/
├── windows/
│   └── runner/
├── web/
│   └── index.html
├── assets/
│   ├── fonts/
│   │   ├── Preeti.ttf
│   │   └── NotoSansDevanagari.ttf
│   ├── images/
│   │   ├── logo.png
│   │   ├── splash.png
│   │   └── placeholder_member.png
│   ├── lottie/
│   │   ├── loading.json
│   │   └── success.json
│   └── translations/
│       ├── en.json
│       └── np.json
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart
│   │   │   ├── api_config.dart
│   │   │   └── env.dart                        # git-ignored secrets
│   │   ├── api/
│   │   │   ├── api_client.dart                 # Dio setup + interceptors
│   │   │   ├── auth_interceptor.dart           # JWT header injection
│   │   │   ├── refresh_token_interceptor.dart  # Auto token refresh
│   │   │   └── error_interceptor.dart
│   │   ├── di/
│   │   │   ├── providers.dart                  # All Riverpod providers
│   │   │   └── service_locator.dart
│   │   ├── router/
│   │   │   ├── app_router.dart
│   │   │   ├── app_routes.dart
│   │   │   └── route_guards.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   └── app_dimensions.dart
│   │   ├── utils/
│   │   │   ├── nepali_date_utils.dart          # BS/AD conversion
│   │   │   ├── currency_utils.dart             # NPR formatting
│   │   │   ├── validators.dart
│   │   │   ├── extensions.dart
│   │   │   └── logger.dart
│   │   └── constants/
│   │       ├── api_endpoints.dart
│   │       ├── app_strings.dart
│   │       └── storage_keys.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── datasources/auth_remote_datasource.dart
│   │   │   │   ├── models/user_model.dart
│   │   │   │   ├── models/user_model.g.dart
│   │   │   │   └── repositories/auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/user_entity.dart
│   │   │   │   ├── repositories/auth_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── login_usecase.dart
│   │   │   │       ├── logout_usecase.dart
│   │   │   │       └── refresh_token_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── login_page.dart
│   │   │       │   ├── otp_page.dart
│   │   │       │   └── forgot_password_page.dart
│   │   │       ├── widgets/
│   │   │       │   ├── login_form.dart
│   │   │       │   └── otp_input_widget.dart
│   │   │       └── providers/
│   │   │           ├── auth_provider.dart
│   │   │           └── auth_state.dart
│   │   ├── dashboard/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/
│   │   │       ├── pages/dashboard_page.dart
│   │   │       └── widgets/
│   │   │           ├── summary_card.dart
│   │   │           ├── collection_chart.dart
│   │   │           └── recent_transactions.dart
│   │   ├── members/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── member_list_page.dart
│   │   │       │   ├── member_detail_page.dart
│   │   │       │   ├── member_registration_page.dart
│   │   │       │   └── member_kyc_page.dart
│   │   │       └── widgets/
│   │   │           ├── member_card.dart
│   │   │           ├── kyc_form_widget.dart
│   │   │           └── nominee_form_widget.dart
│   │   ├── shares/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/ ...
│   │   ├── savings/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── savings_list_page.dart
│   │   │       │   ├── savings_detail_page.dart
│   │   │       │   ├── deposit_page.dart
│   │   │       │   └── withdrawal_page.dart
│   │   │       └── widgets/ ...
│   │   ├── fixed_deposit/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/ ...
│   │   ├── loans/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── loan_list_page.dart
│   │   │       │   ├── loan_detail_page.dart
│   │   │       │   ├── loan_application_page.dart
│   │   │       │   └── emi_schedule_page.dart
│   │   │       └── widgets/ ...
│   │   ├── accounting/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   ├── journal_entry_page.dart
│   │   │       │   ├── ledger_page.dart
│   │   │       │   └── trial_balance_page.dart
│   │   │       └── widgets/ ...
│   │   ├── cash_counter/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/ ...
│   │   ├── reports/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/ ...
│   │   ├── notifications/
│   │   │   └── presentation/
│   │   │       ├── pages/notification_list_page.dart
│   │   │       └── providers/notification_provider.dart
│   │   ├── hr/
│   │   │   ├── data/ ...
│   │   │   ├── domain/ ...
│   │   │   └── presentation/ ...
│   │   └── settings/
│   │       ├── data/ ...
│   │       ├── domain/ ...
│   │       └── presentation/
│   │           ├── pages/settings_page.dart
│   │           └── pages/user_management_page.dart
│   └── shared/
│       ├── widgets/
│       │   ├── app_button.dart
│       │   ├── app_text_field.dart
│       │   ├── app_dropdown.dart
│       │   ├── app_date_picker.dart
│       │   ├── app_dialog.dart
│       │   ├── confirmation_dialog.dart
│       │   ├── loading_overlay.dart
│       │   ├── error_view.dart
│       │   ├── empty_view.dart
│       │   ├── amount_display.dart
│       │   ├── member_avatar.dart
│       │   ├── status_badge.dart
│       │   └── paginated_list_view.dart
│       ├── models/
│       │   ├── api_response.dart
│       │   ├── pagination_model.dart
│       │   └── result.dart
│       └── services/
│           ├── local_storage_service.dart
│           ├── biometric_service.dart
│           ├── notification_service.dart
│           └── printer_service.dart
├── test/
│   ├── unit/
│   │   ├── domain/
│   │   └── usecases/
│   ├── widget/
│   │   └── features/
│   └── integration/
└── pubspec.yaml
```

---

## ASP.NET Core Backend

```
src/backend/
├── SahakariMS.Domain/
│   ├── Entities/
│   │   ├── Common/
│   │   │   ├── BaseEntity.cs
│   │   │   └── AuditableEntity.cs
│   │   ├── Auth/
│   │   │   ├── User.cs
│   │   │   ├── Role.cs
│   │   │   ├── Permission.cs
│   │   │   └── RefreshToken.cs
│   │   ├── Members/
│   │   │   ├── Member.cs
│   │   │   ├── MemberNominee.cs
│   │   │   ├── MemberDocument.cs
│   │   │   └── MemberFamilyDetail.cs
│   │   ├── Shares/
│   │   │   ├── ShareAccount.cs
│   │   │   └── ShareTransaction.cs
│   │   ├── Savings/
│   │   │   ├── SavingAccount.cs
│   │   │   ├── SavingTransaction.cs
│   │   │   └── FixedDeposit.cs
│   │   ├── Loans/
│   │   │   ├── Loan.cs
│   │   │   ├── LoanSchedule.cs
│   │   │   ├── LoanPayment.cs
│   │   │   ├── LoanGuarantor.cs
│   │   │   └── LoanCollateral.cs
│   │   ├── Accounting/
│   │   │   ├── Account.cs
│   │   │   ├── Voucher.cs
│   │   │   ├── VoucherEntry.cs
│   │   │   └── FiscalYear.cs
│   │   ├── HR/
│   │   │   ├── Employee.cs
│   │   │   ├── Attendance.cs
│   │   │   └── Leave.cs
│   │   └── System/
│   │       ├── Branch.cs
│   │       ├── AuditLog.cs
│   │       └── Notification.cs
│   ├── ValueObjects/
│   │   ├── Money.cs
│   │   ├── MemberCode.cs
│   │   ├── AccountNumber.cs
│   │   ├── LoanNumber.cs
│   │   └── NepaliDate.cs
│   ├── Events/
│   │   ├── MemberRegisteredEvent.cs
│   │   ├── LoanDisbursedEvent.cs
│   │   ├── EMIPaymentReceivedEvent.cs
│   │   └── FDMaturedEvent.cs
│   ├── Repositories/
│   │   ├── IMemberRepository.cs
│   │   ├── ILoanRepository.cs
│   │   ├── ISavingRepository.cs
│   │   ├── IAccountingRepository.cs
│   │   └── IUnitOfWork.cs
│   └── Services/
│       ├── IInterestCalculationService.cs
│       └── IEMIScheduleService.cs
│
├── SahakariMS.Application/
│   ├── Members/
│   │   ├── Commands/
│   │   │   ├── RegisterMember/
│   │   │   │   ├── RegisterMemberCommand.cs
│   │   │   │   ├── RegisterMemberHandler.cs
│   │   │   │   └── RegisterMemberValidator.cs
│   │   │   └── ApproveMembership/
│   │   │       ├── ApproveMembershipCommand.cs
│   │   │       └── ApproveMembershipHandler.cs
│   │   ├── Queries/
│   │   │   ├── GetMemberById/
│   │   │   │   ├── GetMemberByIdQuery.cs
│   │   │   │   └── GetMemberByIdHandler.cs
│   │   │   └── GetMembersList/
│   │   │       ├── GetMembersListQuery.cs
│   │   │       └── GetMembersListHandler.cs
│   │   └── DTOs/
│   │       ├── MemberDto.cs
│   │       ├── MemberSummaryDto.cs
│   │       └── RegisterMemberRequest.cs
│   ├── Loans/
│   │   ├── Commands/ ...
│   │   ├── Queries/ ...
│   │   └── DTOs/ ...
│   ├── Savings/
│   │   ├── Commands/ ...
│   │   ├── Queries/ ...
│   │   └── DTOs/ ...
│   ├── Accounting/
│   │   ├── Commands/ ...
│   │   ├── Queries/ ...
│   │   └── DTOs/ ...
│   ├── Common/
│   │   ├── Behaviors/
│   │   │   ├── ValidationBehavior.cs
│   │   │   ├── LoggingBehavior.cs
│   │   │   └── PerformanceBehavior.cs
│   │   ├── Mappings/
│   │   │   └── MappingProfile.cs
│   │   └── Models/
│   │       ├── Result.cs
│   │       ├── PagedResult.cs
│   │       └── PageRequest.cs
│   └── EventHandlers/
│       ├── MemberRegisteredEventHandler.cs
│       ├── LoanDisbursedEventHandler.cs
│       └── EMIPaymentEventHandler.cs
│
├── SahakariMS.Infrastructure/
│   ├── Persistence/
│   │   ├── SahakariDbContext.cs
│   │   ├── Configurations/
│   │   │   ├── MemberConfiguration.cs
│   │   │   ├── LoanConfiguration.cs
│   │   │   └── AccountConfiguration.cs
│   │   ├── Repositories/
│   │   │   ├── MemberRepository.cs
│   │   │   ├── LoanRepository.cs
│   │   │   └── SavingRepository.cs
│   │   ├── Migrations/
│   │   │   └── *.cs
│   │   └── UnitOfWork.cs
│   ├── Services/
│   │   ├── SmsService.cs              # Sparrow SMS
│   │   ├── EmailService.cs            # SendGrid
│   │   ├── FcmService.cs              # Firebase FCM
│   │   ├── MinioStorageService.cs
│   │   ├── InterestCalculationService.cs
│   │   └── EMIScheduleService.cs
│   └── BackgroundJobs/
│       ├── InterestPostingJob.cs
│       ├── EMIReminderJob.cs
│       └── FDMaturityJob.cs
│
├── SahakariMS.API/
│   ├── Controllers/
│   │   ├── AuthController.cs
│   │   ├── MembersController.cs
│   │   ├── LoansController.cs
│   │   ├── SavingsController.cs
│   │   ├── AccountingController.cs
│   │   ├── ReportsController.cs
│   │   └── DashboardController.cs
│   ├── Middleware/
│   │   ├── JwtMiddleware.cs
│   │   ├── ExceptionHandlingMiddleware.cs
│   │   └── RequestLoggingMiddleware.cs
│   ├── Filters/
│   │   ├── PermissionFilter.cs
│   │   └── AuditFilter.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   └── Program.cs
│
└── SahakariMS.Tests/
    ├── Unit/
    │   ├── Domain/
    │   └── Application/
    └── Integration/
        └── Controllers/
```

---

## Docs Structure

```
docs/
├── README.md
├── planning.md
├── features.md
├── architecture.md
├── folder-structure.md
├── coding-standards.md
├── technology-stack.md
├── database/
│   ├── database-design.md
│   ├── er-diagram.md
│   ├── table-specifications.md
│   ├── indexes.md
│   ├── constraints.md
│   ├── triggers.md
│   ├── stored-procedures.md
│   └── migrations.md
├── api/
│   ├── api-specification.md
│   ├── authentication-api.md
│   ├── member-api.md
│   ├── savings-api.md
│   ├── loan-api.md
│   ├── accounting-api.md
│   ├── reports-api.md
│   └── notification-api.md
├── modules/
│   ├── authentication.md
│   ├── members.md
│   ├── shares.md
│   ├── savings.md
│   ├── fixed-deposit.md
│   ├── loans.md
│   ├── accounting.md
│   ├── cash-counter.md
│   ├── collector-app.md
│   ├── mobile-banking.md
│   ├── notifications.md
│   ├── reports.md
│   ├── hr.md
│   ├── assets.md
│   ├── inventory.md
│   └── dashboard.md
├── business/
│   ├── business-rules.md
│   ├── workflows.md
│   ├── approval-process.md
│   ├── interest-calculation.md
│   ├── loan-rules.md
│   ├── savings-rules.md
│   ├── accounting-rules.md
│   └── audit-rules.md
├── security/
│   ├── security.md
│   ├── permissions.md
│   ├── encryption.md
│   ├── jwt.md
│   ├── backup-recovery.md
│   └── disaster-recovery.md
├── audit/
│   ├── audit-specification.md
│   ├── activity-log.md
│   ├── transaction-log.md
│   ├── login-log.md
│   └── compliance.md
├── testing/
│   ├── testing-plan.md
│   ├── unit-testing.md
│   ├── integration-testing.md
│   ├── ui-testing.md
│   ├── performance-testing.md
│   └── security-testing.md
├── deployment/
│   ├── deployment.md
│   ├── docker.md
│   ├── nginx.md
│   ├── ssl.md
│   ├── monitoring.md
│   └── ci-cd.md
├── ui/
│   ├── ui-guidelines.md
│   ├── theme.md
│   ├── navigation.md
│   └── accessibility.md
└── roadmap/
    ├── development-roadmap.md
    ├── milestones.md
    ├── changelog.md
    └── future-features.md
```

---

## Docker Structure

```
docker/
├── api/
│   └── Dockerfile
├── flutter-web/
│   └── Dockerfile
├── nginx/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── sites/
│       └── sahakarims.conf
└── postgres/
    ├── init.sql
    └── seed.sql
```

---

## Scripts

```
scripts/
├── backup.sh           # PostgreSQL backup to MinIO
├── restore.sh          # Restore from MinIO backup
├── seed.sh             # Seed development data
├── migrate.sh          # Run EF Core migrations
├── generate-cert.sh    # Generate self-signed SSL for dev
└── health-check.sh     # Production health check
```
