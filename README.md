# TravelEasy — Intelligent Travel & Spend Control Platform
### 2027 NPN Salesforce Developer Catalyst Hackathon

**Repository:** [TravelEasy-Salesforce-Intelligent-Travel-Expenses](https://github.com/charan-25022005/TravelEasy-Salesforce-Intelligent-Travel-Expenses)  
**Target Playground Org:** `charankarnam71@wise-fox-rmu03e.com`

---

## 🚀 Overview
**TravelEasy** is an enterprise-grade travel and spend control platform built natively on the Salesforce Lightning Platform. It operationalizes the core principle: **"Automate normal cases. Escalate exceptions."**

TravelEasy centralizes employee travel requests, role-based policy enforcement, exception detection, multi-tier approvals, asynchronous reimbursement, and executive analytics into a seamless, auditable workflow.

---

## 🌟 Key Capabilities
1. **Zero-Trust Travel Request REST API:** Secure Apex REST API (`/services/apexrest/traveleasy/travel-requests`) accepting travel requests with server-side employee and role verification.
2. **Role-Based Policy Configuration:** Dynamic Custom Metadata (`Travel_Expense_Policy__mdt`) with granular single-transaction and daily limits across all 6 expense categories for Employees and Managers.
3. **Smart Expense Control Engine:** Automated Apex service (`SmartExpenseControlService`) detecting single-transaction breaches, multi-day roll-up limits, missing mandatory receipts, potential duplicate transactions, and cumulative budget overruns.
4. **Resilient Status Synchronization:** Real-time trigger handler on `Expense_Validation_Exception__c` ensuring parent expense reports remain locked until all blocking exceptions are resolved or waived.
5. **Asynchronous Payment & Reconciliation:** Queueable Apex (`ProcessReimbursementQueueable`) and Batch Apex (`ReimbursementReconciliationBatch`) with Scheduled Apex (`ReimbursementScheduler`) and secure `Integration_Log__c` auditing.
6. **Triad of Declarative Flows:**
   - `Travel_Request_Submission_Flow`
   - `Expense_Report_Submission_Flow`
   - `Expense_Exception_Notification_Flow`
7. **Executive Reporting & Dashboards:** Real-time visibility into travel requests, spend variance, policy exception trends, and reimbursement SLA.
8. **Dedicated Email Notification Engine:** `TravelEasyEmailNotificationService` dispatches clean email alerts exclusively (no in-app notifications) for Travel Request decisions, Expense Report decisions, and confirmed Reimbursement outcomes with recursion prevention and error isolation.

---

## 📂 Project Structure
```text
TravelEasy-Salesforce/
├── force-app/
│   └── main/
│       └── default/
│           ├── applications/        # TravelEasy Lightning App
│           ├── objects/             # Custom Objects & Fields
│           ├── classes/             # Apex Controllers, Services, Tests
│           ├── triggers/            # Object Triggers (1 per object)
│           ├── flows/               # Record-Triggered Flows
│           ├── layouts/             # Page Layouts
│           ├── permissionsets/      # Role Permission Sets
│           ├── flexipages/          # Lightning Record Pages
│           ├── customMetadata/      # Travel Expense Policy Records
│           ├── lwc/                 # Interactive Lightning Components
│           ├── tabs/                # Custom App Tabs
│           ├── reports/             # Travel & Spend Reports
│           └── dashboards/          # Executive Spend Dashboard
├── docs/                            # Comprehensive Architecture & API Guides
├── postman/                         # Complete Postman Collection & Environment
├── scripts/                         # Apex & SOQL Utility Scripts
├── manifest/                        # Package.xml Manifest
├── sfdx-project.json
└── README.md
```

---

## 🛠️ Deployment & Setup Instructions

### 1. Authenticate to the Target Playground
```bash
sf org login web --alias TravelEasyPlayground --instance-url https://login.salesforce.com
```
*Note: Confirm the authenticated username is exactly `charankarnam71@wise-fox-rmu03e.com`.*

### 2. Deploy Source to Org
```bash
sf project deploy start --target-org charankarnam71@wise-fox-rmu03e.com
```

### 3. Assign Permission Sets
```bash
sf org assign permset --name TravelEasy_Finance_Admin --target-org charankarnam71@wise-fox-rmu03e.com
```

### 4. Run Apex Tests
```bash
sf apex run test --test-level RunLocalTests --target-org charankarnam71@wise-fox-rmu03e.com --code-coverage --result-format human
```
>>>>>>> e899abc (feat(traveleasy): initial complete implementation of data model, Apex services, triggers, flows, LWCs, reports, and tests)
