# TravelEasy — Intelligent Travel & Spend Control Platform
## Architecture Overview

### 1. Architectural Principles
- **Separation of Concerns:** Business logic encapsulated in modular service classes (`SmartExpenseControlService`, `TravelRequestService`, `ReimbursementService`). Triggers delegate exclusively to bulkified handlers (`TravelRequestTriggerHandler`, `ExpenseReportTriggerHandler`, `ExpenseItemTriggerHandler`, `ExpenseValidationExceptionTriggerHandler`).
- **Declarative & Programmatic Harmony:** Flows handle notifications and approval orchestration (`Travel_Request_Submission_Flow`, `Expense_Report_Submission_Flow`, `Expense_Exception_Notification_Flow`). Apex enforces complex policy calculations, multi-day roll-ups, duplicate detection, and asynchronous payment integration.
- **Security by Design:** `WITH USER_MODE` and explicit authorization checks prevent privilege escalation. Untrusted inputs from REST APIs are validated server-side against trusted user identities.
- **Fail-Safe Policy Enforcement:** Role-based policy allowances are driven by Custom Metadata (`Travel_Expense_Policy__mdt`). Unknown roles or missing policies fail safely to authorized review rather than silently bypassing validation.

### 2. High-Level System Architecture Diagram

```
[External / Mobile Client]
         │ (HTTP POST /services/apexrest/traveleasy/travel-requests)
         ▼
[Apex REST Endpoint: TravelRequestRestResource]
         │ Validates Schema, Dates, Server-side Role & Identity
         ▼
[Travel_Request__c Object]
         │ Trigger -> TravelRequestTriggerHandler
         ▼
[Flow: Travel_Request_Submission_Flow] ──► [Manager Approval Process]
                                                    │ (Approved)
                                                    ▼
                                           [Expense_Report__c]
                                                    │
                   ┌────────────────────────────────┴──────────────────────────────┐
                   │                                                               │
         [Expense_Item__c]                                           [SmartExpenseControlService]
                   │                                                               │
                   ├───────────────────────────────────────────────────────────────┤
                   │  - Single Transaction Limit Check                             │
                   │  - Daily Limit Multi-Item Rollup Check                        │
                   │  - Receipt Required Threshold Verification                    │
                   │  - Duplicate Transaction Pattern Detection                    │
                   │  - Travel Budget Overrun Detection                            │
                   └────────────────────────────────┬──────────────────────────────┘
                                                    │
                                     [Expense_Validation_Exception__c]
                                                    │ (High / Critical)
                                                    ▼
                               [Flow: Expense_Exception_Notification_Flow]
                                                    │
                                    [Exception Resolution Panel]
                                                    │ (Resolved / Waived)
                                                    ▼
                                [Sync Status Handler -> Expense_Report__c]
                                                    │ (Cleared)
                                                    ▼
                                    [Expense Report Approval Process]
                                                    │ (Approved)
                                                    ▼
                                     [ReimbursementService / Queueable]
                                                    │ (External Payment Simulator)
                                                    ▼
                                          [Integration_Log__c]
```

### 3. Core Components
- **Apex REST Endpoint:** `/services/apexrest/traveleasy/travel-requests`
- **Smart Control Engine:** `SmartExpenseControlService`
- **Asynchronous Services:**
  - `ProcessReimbursementQueueable` (Chained Queueable processing)
  - `ReimbursementReconciliationBatch` (Nightly reconciliation)
  - `ReimbursementScheduler` (Scheduled batch execution)
- **Declarative Automation:**
  - `Travel_Request_Submission_Flow`
  - `Expense_Report_Submission_Flow`
  - `Expense_Exception_Notification_Flow`
- **Email Notification Service:** `TravelEasyEmailNotificationService` strictly dispatches email notifications (no in-app notifications) for Travel Request decisions, Expense Report decisions, and confirmed Reimbursement outcomes with recursion prevention and error isolation.
- **Integration Logging:** Audits all outbound and inbound transactions in `Integration_Log__c` without storing sensitive tokens.
