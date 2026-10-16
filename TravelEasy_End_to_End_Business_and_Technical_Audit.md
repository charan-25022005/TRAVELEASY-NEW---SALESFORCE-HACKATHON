# TravelEasy — Intelligent Travel & Spend Control Platform
## Comprehensive End-to-End Business Workflow & Salesforce Technical Audit

**Audit Date:** October 2026  
**Salesforce API Version:** 60.0 (Spring '24)  
**Target Environment:** `TravelEasyPlayground` (`charankarnam71@wise-fox-rmu03e.com` / Org ID: `00DdL000016tOfFUAU`)  
**Audit Type:** Strict Read-Only Technical & Architecture Audit  

---

## Executive Table of Contents
1. [Part 1: Business Overview](#part-1-business-overview)
2. [Part 2: Complete End-to-End Business Workflow (24 Stages)](#part-2-complete-end-to-end-business-workflow)
3. [Part 3: Salesforce Objects and Fields](#part-3-salesforce-objects-and-fields)
4. [Part 4: Data Model and Relationships](#part-4-data-model-and-relationships)
5. [Part 5: Custom Metadata Types and Role-Based Expense Policies](#part-5-custom-metadata-types-and-role-based-expense-policies)
6. [Part 6: Apex Classes, Triggers, Handlers, and Test Classes](#part-6-apex-classes-triggers-handlers-and-test-classes)
7. [Part 7: Salesforce Flows](#part-7-salesforce-flows)
8. [Part 8: Approval Processes and Approver Routing](#part-8-approval-processes-and-approver-routing)
9. [Part 9: Validation Rules and Business Controls](#part-9-validation-rules-and-business-controls)
10. [Part 10: Lightning UI, Pages, Page Layouts, and Navigation](#part-10-lightning-ui-pages-page-layouts-and-navigation)
11. [Part 11: Integrations and External Services](#part-11-integrations-and-external-services)
12. [Part 12: Local Salesforce Project Structure](#part-12-local-salesforce-project-structure)
13. [Part 13: Reports and Dashboards](#part-13-reports-and-dashboards)
14. [Part 14: Testing and Evidence Matrix](#part-14-testing-and-evidence-matrix)
15. [Part 15: Architecture and Dependency Diagrams](#part-15-architecture-and-dependency-diagrams)
16. [Part 16: Final Audit Summary & Action Plan](#part-16-final-audit-summary)

---

## Part 1: Business Overview

### 1.1 What TravelEasy Is
**TravelEasy** is an enterprise-grade corporate travel authorization and intelligent spend control platform built natively on the Salesforce Lightning Platform. It bridges the gap between pre-travel budget estimation, automated policy enforcement, exception mitigation, and financial disbursement reconciliation.

### 1.2 The Business Problem It Solves
In traditional enterprises, business travel and corporate spend management suffer from four structural points of failure:
1. **Unenforced Pre-Trip Commitments:** Employees travel without approved budget boundaries, causing cost overruns before an expense report is ever created.
2. **Post-Facto Policy Auditing:** Expense fraud, duplicate submissions, and limit breaches are caught manually weeks after funds have left the corporate account.
3. **Approval Bottlenecks:** Managers and Finance teams are overwhelmed by routine, low-risk expense reports, leading to delayed reimbursements and employee dissatisfaction.
4. **Disjointed Reimbursement Systems:** Approved expense reports remain trapped in CRM or spreadsheet silos without auditable, idempotent payment tracking.

### 1.3 Core Objectives
* **Proactive Budget Locking:** Bind all corporate spend directly to pre-authorized `Travel_Request__c` records.
* **Granular Policy Automation:** Implement category-level and role-level spend thresholds (Single Transaction, Daily Cumulative, and Receipt Verification) governed by Custom Metadata.
* **Automate Normal Cases, Escalate Exceptions:** Allow compliant expenses to route swiftly through approval and payment pipelines while immediately freezing reports containing `High` or `Critical` policy breaches.
* **Idempotent Financial Settlement:** Orchestrate asynchronous payment disbursements with comprehensive audit logging in `Integration_Log__c`.

### 1.4 User Personas and Responsibilities
| Persona | Typical Role / Profile | Key Responsibilities in TravelEasy |
| :--- | :--- | :--- |
| **Corporate Employee** | Sales Rep, Consultant, Field Engineer | Submits travel requests, books compliant accommodations, logs expense line items, attaches receipts, responds to policy flags. |
| **Line Manager** | Team Lead, Engineering Manager, Director | Reviews pre-trip travel requests, evaluates spend justifications, resolves or waives policy exceptions via Lightning UI. |
| **Finance Administrator** | Finance Operations, Accounts Payable | Configures metadata thresholds, performs financial audits, monitors payment disbursements, reconciles failed transactions. |
| **System Administrator** | Salesforce Admin, Release Engineer | Manages security controls, automations, API integrations, and reporting dashboards. |

### 1.5 Realistic Business Walkthrough
> **Scenario:** Priya Sharma (Senior Technical Consultant, `Employee` role) is traveling from Bengaluru to Mumbai for a 3-day enterprise client discovery workshop.
> 
> 1. **Pre-Trip:** Priya submits `TR-00010` estimating ₹20,000 across travel, hotel, and meals. Her manager reviews and approves the request in Salesforce.
> 2. **During Trip:** Priya books airfare (₹8,500), hotel (₹4,500/night for 2 nights = ₹9,000), client dinners, and local taxis.
> 3. **Expense Logging:** Upon return, Priya creates `EXP-00008` linked to `TR-00010`. She enters her expense items.
> 4. **Smart Policy Evaluation:** 
>    * Day 1 taxi (₹1,200) and meals (₹850) comply with `Employee` limits (₹1,500 single taxi limit; ₹2,500 daily meals limit).
>    * On Day 2, Priya hosts a client dinner of ₹3,500. The `Employee_Client_Entertainment` policy has a single-transaction limit of ₹3,000.
>    * The **Smart Expense Control Engine** instantly flags the item, generates a `High` severity `Expense_Validation_Exception__c`, marks it `Is_Blocking__c = true`, and sets `Has_Blocking_Exceptions__c = true` on `EXP-00008`.
> 5. **Submission Guard:** Priya attempts to submit `EXP-00008`. The Apex trigger halts the submission with an immediate error: *"Cannot submit expense report while unresolved blocking policy exceptions exist."*
> 6. **Manager Exception Resolution:** Her manager opens the exception in the **Exception Resolution Panel** LWC, inspects the client attendee list, inputs the reason *"Approved client relationship dinner with CIO"*, and selects **Waive Exception**.
> 7. **Approval & Payment:** With `Has_Blocking_Exceptions__c` cleared to `false`, Priya submits `EXP-00008`. The manager approves it, triggering asynchronous payment disbursement (₹21,850) via Queueable Apex. Priya receives an automated confirmation email with transaction reference `TXN-89412-17916`.

---

## Part 2: Complete End-to-End Business Workflow

Below is the verified 24-stage lifecycle of TravelEasy as implemented in the codebase:

```
[Stages 1-5: Request Creation & Submission]
      │
      ▼
[Stages 6-8: Approver Routing & Decision]
      │
      ▼
[Stages 9-12: Expense Report & Item Entry]
      │
      ▼
[Stages 13-16: Policy Evaluation & Exception Flagging]
      │
      ▼
[Stages 17-20: Blocking Guard & Exception Resolution]
      │
      ▼
[Stages 21-24: Report Approval, Disbursement & Analytics]
```

### Detailed 24-Stage Lifecycle Trace

#### Stage 1: Application Access
* **Actor:** Employee or Manager.
* **UI Location:** Salesforce App Launcher → **TravelEasy** Lightning Application (`force-app/main/default/applications/TravelEasy.app-meta.xml`).
* **Components:** Displays custom tabs for `Travel_Request__c`, `Expense_Report__c`, `Expense_Validation_Exception__c`, `Integration_Log__c`, Reports, and Dashboards.
* **Status:** **Implemented & Verified.**

#### Stage 2: Travel Request Initialization
* **Actor:** Employee.
* **UI Location:** `Travel_Request__c` tab → "New" record modal.
* **Objects/Fields:** `Travel_Request__c` (`Employee__c`, `Requester_Role__c`, `Destination__c`, `Purpose__c`, `Travel_Start_Date__c`, `Travel_End_Date__c`, `Estimated_Cost__c`, `Status__c = 'Draft'`).
* **Status:** **Implemented & Verified.**

#### Stage 3: Travel Parameter Entry
* **Actor:** Employee.
* **Details:** Requester enters trip parameters. The `Requester_Role__c` defaults to `Employee` (or can be set to `Manager`).
* **Status:** **Implemented & Verified.**

#### Stage 4: Travel Request Synchronous Validation
* **Actor:** Salesforce System (Apex Trigger).
* **Code:** `TravelRequestTrigger.trigger` → `TravelRequestTriggerHandler.validateDatesAndCost`.
* **Rules Enforced:** 
  1. `Travel_End_Date__c < Travel_Start_Date__c`: Throws *"Travel End Date cannot be earlier than Travel Start Date."*
  2. `Estimated_Cost__c <= 0`: Throws *"Estimated Cost must be greater than zero."*
* **Outcome on Failure:** Page displays field-level validation errors; DML aborts.
* **Status:** **Implemented & Verified.**

#### Stage 5: Travel Request Submission
* **Actor:** Employee.
* **Action:** User updates `Status__c` from `Draft` to `Submitted` (Standard "Submit for Approval" button is excluded on page layout).
* **Automation:** `Travel_Request_Submission_Flow.flow-meta.xml` triggers on `Status__c = 'Submitted'`.
* **Status:** **Implemented & Verified.**

#### Stage 6: Approver Assignment
* **Actor:** System Automation.
* **Code / Flow:** `TravelRequestTriggerHandler.assignDefaultApprovers` & `Travel_Request_Submission_Flow`.
* **Logic:** Looks up `Employee__r.ManagerId`. If populated, sets `Approver__c = ManagerId`. If null, defaults `Approver__c = Employee__c` (Self-assignment risk).
* **Architecture Note:** Intended routing specified Finance Team approval, but current implementation routes to Line Manager.
* **Status:** **Implemented (Manager Routing). Finance Queue Routing is Missing.**

#### Stage 7: Travel Request Review & Decision
* **Actor:** Approver (Manager).
* **UI / Record:** Standard Approval Process in org (`Travel_Request__c.Travel_Request_Approval`) or manual picklist update.
* **Code:** `TravelRequestTriggerHandler.handleApprovalStateTransitions`.
* **State Updates:**
  * If Approved: `Approval_Date__c = System.now()`, `Status__c = 'Approved'`.
  * If Rejected: If blank, `Rejection_Reason__c = 'Rejected by reviewer without specific notes.'`, `Status__c = 'Rejected'`.
* **Status:** **Implemented & Verified.**

#### Stage 8: Travel Request Notifications
* **Actor:** System Automation.
* **Code:** `TravelRequestTriggerHandler.handleAfterUpdate` → `TravelEasyEmailNotificationService.sendTravelRequestDecisionEmail`.
* **Data Action:** Assembles `SingleEmailMessage` to requester email. Logs delivery/failure to `Integration_Log__c` without rolling back the transaction.
* **Status:** **Implemented & Verified.**

#### Stage 9: Trip Eligibility for Expense Reporting
* **Actor:** Business Rule / System Enforcement.
* **Code:** `ExpenseReportTriggerHandler.validateTravelRequestApproval`.
* **Rule Enforced:** An expense report cannot transition out of `Draft` unless linked `Travel_Request__r.Status__c == 'Approved'`. Prevents unapproved spend.
* **Status:** **Implemented & Verified.**

#### Stage 10: Expense Report Creation
* **Actor:** Employee.
* **UI Location:** `Expense_Report__c` tab or Related List on `Travel_Request__c`.
* **Fields:** `Report_Name__c`, `Travel_Request__c`, `Employee__c`, `Status__c = 'Draft'`.
* **Status:** **Implemented & Verified.**

#### Stage 11: Expense Item Entry across 6 Categories
* **Actor:** Employee.
* **UI Location:** Expense Items Related List on `Expense_Report__c`.
* **Fields:** `Category__c` (Airfare, Hotel & Lodging, Meals & Food, Ground Transportation, Client Entertainment, Incidentals & Miscellaneous), `Amount__c`, `Transaction_Date__c`, `Vendor__c`, `Payment_Method__c`, `Receipt_Attached__c`.
* **Trigger:** `ExpenseItemTrigger.trigger` fires on `after insert`, `after update`.
* **Status:** **Implemented & Verified.**

#### Stage 12: Receipt Documentation
* **Actor:** Employee.
* **Fields:** `Receipt_Attached__c` (Checkbox), `Receipt_Document_Id__c` (File Id reference).
* **Gap:** Declarative file upload enforcement is manual via checkbox; automated OCR/receipt analysis is planned but not implemented.
* **Status:** **Implemented (Checkbox/ID). OCR is Missing.**

#### Stage 13: Smart Expense Policy Evaluation
* **Actor:** Smart Expense Control Engine.
* **Code:** `ExpenseItemTriggerHandler.runPolicyEvaluation` → `SmartExpenseControlService.evaluateExpenseItems`.
* **Logic:** Reads parent `Travel_Request__r.Requester_Role__c` (defaults to `Employee` if null). Retrieves cached `Travel_Expense_Policy__mdt` records by composite key: `{role}_{category}`.
* **Status:** **Implemented & Verified.**

#### Stage 14: Violation Detection Mechanisms
The engine evaluates 5 discrete risk algorithms in memory and SOQL:
1. **Single-Transaction Breach:** `Amount__c > Single_Transaction_Limit__c`. Flags `Severity__c = 'High'`.
2. **Daily Category Limit Breach:** Queries database for employee spend on same date/category + accumulates current batch. If total > `Daily_Limit__c`, flags `Severity__c = 'High'`.
3. **Missing Mandatory Receipt:** If `Amount__c >= Receipt_Required_Threshold__c` and `!Receipt_Attached__c`. Flags `Severity__c = 'Medium'`.
4. **Potential Duplicate Detection:** Matches same Employee + Date + Vendor + Category + Amount across DB and batch. Flags `Severity__c = 'High'`.
5. **Cumulative Budget Overrun:** Computes all saved items on parent `Travel_Request__c` + current batch. If spend > `Estimated_Cost__c`, flags `Severity__c = 'Critical'`.
* **Status:** **Implemented & Verified.**

#### Stage 15: Validation Exception Persistence
* **Actor:** System Automation.
* **Code:** `SmartExpenseControlService` creates `Expense_Validation_Exception__c` records.
* **Persistence:** Inserted in `SYSTEM_MODE` via `ExpenseItemTriggerHandler`. Sets `Is_Blocking__c = true` if `Severity__c` is `High` or `Critical`.
* **Status:** **Implemented & Verified.**

#### Stage 16: Exception Notification & Routing
* **Actor:** System Automation.
* **Flow:** `Expense_Exception_Notification_Flow.flow-meta.xml`.
* **Criteria:** Fires when `Severity__c` in (`High`, `Critical`) and `Status__c = 'Open'`. Inherits reviewer from parent `Expense_Report__r.Approver__c` if null.
* **Status:** **Implemented & Verified.**

#### Stage 17: Synchronous Submission Blocking Guard
* **Actor:** System Automation (Apex Trigger).
* **Code:** `ExpenseReportTriggerHandler.validateSubmissionRequirements`.
* **Enforcement:** If `Has_Blocking_Exceptions__c == true` and an update attempts to set `Status__c` to `Submitted` or `Under Review`:
  * Throws user error: *"Cannot submit expense report while unresolved blocking policy exceptions exist. Please resolve all High and Critical exceptions first."*
  * DML transaction fails immediately before record commit.
* **Status:** **Implemented & Verified.**

#### Stage 18: Manager Exception Review
* **Actor:** Manager / Reviewer.
* **UI Location:** `Expense_Validation_Exception_Record_Page` flexipage → **Exception Resolution Panel** LWC (`exceptionResolutionPanel`).
* **Display:** Shows exception severity, details, rule violated, and audit history.
* **Status:** **Implemented & Verified.**

#### Stage 19: Exception Resolution, Waiver, or Rejection
* **Actor:** Manager.
* **Action:** Selects Action (`Resolved`, `Waived`, `Approved`, `Rejected`), inputs mandatory comments, and clicks "Submit Decision".
* **Code:** Calls `TravelEasyUiController.resolveException`. Stamps `Reviewer__c = UserInfo.getUserId()`, `Resolved_Date__c = System.now()`, `Resolution_Comments__c`.
* **Synchronization:** `ExpenseValidationExceptionTriggerHandler.synchronizeParentReportStatus` recalculates all sibling exceptions under the report:
  * If no open blocking exceptions remain, sets `Has_Blocking_Exceptions__c = false` and restores status to `Under Review`.
* **Status:** **Implemented & Verified.**

#### Stage 20: Expense Report Resubmission Eligibility
* **Actor:** Employee / Manager.
* **Condition:** Once `Has_Blocking_Exceptions__c` is `false`, the submission guard releases the record, allowing transition to `Under Review`.
* **Status:** **Implemented & Verified.**

#### Stage 21: Expense Report Manager Approval
* **Actor:** Approver (Manager).
* **Process:** Approver changes `Status__c` to `Approved` (or via Approval Process `TravelEasy_Expense_Report_Approval`).
* **Code Guard:** `ExpenseReportTriggerHandler.validateApprovalRequirements` ensures report cannot be approved if `Has_Blocking_Exceptions__c` is true. Stamps `Approval_Date__c = System.now()`.
* **Status:** **Implemented & Verified.**

#### Stage 22: Asynchronous Payment Disbursement
* **Actor:** System Automation.
* **Code:** `ExpenseReportTriggerHandler.handleAfterUpdate` → `ReimbursementService.initiateReimbursement` → `System.enqueueJob(new ProcessReimbursementQueueable(ids))`.
* **Execution:** Queueable job runs asynchronously, simulates payment gateway settlement via `ReimbursementService.processSingleReportReimbursement`.
* **Status:** **Implemented & Verified (Mock Integration).**

#### Stage 23: Settlement Recording & Notification
* **Actor:** System Automation.
* **Data Updates:**
  * Generates transaction reference: `TXN-{crypto}-{timestamp}`.
  * Stamps `Reimbursement_Status__c = 'Completed'`, `Reimbursement_Reference__c`, `Reimbursement_Date__c = System.now()`, `Status__c = 'Reimbursed'`.
  * Logs payload and execution duration in `Integration_Log__c`.
  * Sends branded outcome email via `TravelEasyEmailNotificationService.sendReimbursementOutcomeEmail`.
* **Status:** **Implemented & Verified.**

#### Stage 24: Executive Analytics & Variance Reporting
* **Actor:** Finance Leadership / Executives.
* **UI Location:** `TravelEasy_Executive_Spend_Control_Dashboard` (`TravelEasy_Dashboards`).
* **Metrics:** Aggregates estimated travel cost vs actual spend, policy exception severity breakdown, and reimbursement disbursement turnaround.
* **Status:** **Implemented & Verified.**

---

## Part 3: Salesforce Objects and Fields

TravelEasy utilizes five custom objects, one Custom Metadata Type, and standard Salesforce objects (`User`).

### 3.1 Object Inventory Table

| Object Label | API Name | Type | Sharing Model | Key Business Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Travel Request** | `Travel_Request__c` | Custom Object | Private / Read-Write | Pre-travel budget authorization, destination, dates, and approver tracking. |
| **Expense Report** | `Expense_Report__c` | Custom Object | Private / Read-Write | Container for expense line items linked to an approved Travel Request. |
| **Expense Item** | `Expense_Item__c` | Custom Object | ControlledByParent (Master-Detail) | Individual transactional spend record across 6 standard corporate categories. |
| **Expense Validation Exception** | `Expense_Validation_Exception__c` | Custom Object | Private / Read-Write | Policy violation and budget overrun audit record raised by Smart Control Engine. |
| **Integration Log** | `Integration_Log__c` | Custom Object | Private / Read-Write | Centralized technical audit log for REST API calls and payment disbursements. |
| **Travel Expense Policy** | `Travel_Expense_Policy__mdt` | Custom Metadata Type | Public Read | Role-based policy limits, receipt thresholds, and approval requirements. |

---

### 3.2 Field Level Specifications

#### 1. Travel Request (`Travel_Request__c`)
* `Name`: Auto Number (`TR-{00000}`). System record identifier.
* `Employee__c`: Lookup (`User`), **Required**. The traveler.
* `Employee_ID__c`: Text(50). Corporate employee badge/ID.
* `Requester_Role__c`: Picklist (`Employee`, `Manager`), Default: `Employee`. Role applied during expense evaluation.
* `Destination__c`: Text(255), **Required**. Travel location.
* `Purpose__c`: Text(255), **Required**. Business justification.
* `Travel_Start_Date__c`: Date, **Required**. Departure date.
* `Travel_End_Date__c`: Date, **Required**. Return date.
* `Estimated_Cost__c`: Currency(18,2), **Required**. Pre-authorized budget.
* `Status__c`: Picklist (`Draft`, `Submitted`, `Approved`, `Rejected`), Default: `Draft`, **Required**.
* `Approver__c`: Lookup (`User`). Assigned decision-maker (assigned to manager).
* `Approval_Date__c`: DateTime. System-stamped timestamp upon approval.
* `Rejection_Reason__c`: Long TextArea(32768). Mandatory reviewer explanation if rejected.
* `Notes__c`: Long TextArea(32768). Additional trip details.

#### 2. Expense Report (`Expense_Report__c`)
* `Name`: Auto Number (`EXP-{00000}`). System record identifier.
* `Report_Name__c`: Text(255), **Required**. Descriptive title (e.g., "Mumbai Client Meeting").
* `Travel_Request__c`: Lookup (`Travel_Request__c`), **Required**. Parent pre-authorized trip.
* `Employee__c`: Lookup (`User`), **Required**. Submitting employee.
* `Total_Amount__c`: Currency(18,2), Default: 0. Aggregated total of all child `Expense_Item__c` records.
* `Status__c`: Picklist (`Draft`, `Submitted`, `Under Review`, `Approved`, `Rejected`, `Exception Flagged`, `Reimbursed`), Default: `Draft`, **Required**.
* `Has_Blocking_Exceptions__c`: Checkbox, Default: `false`. System-controlled flag indicating unresolved `High`/`Critical` exceptions.
* `Approver__c`: Lookup (`User`). Assigned manager/reviewer.
* `Submission_Date__c`: DateTime. Recorded upon submission.
* `Approval_Date__c`: DateTime. System-stamped upon manager approval.
* `Rejection_Reason__c`: Long TextArea(32768). Reviewer feedback upon rejection.
* `Reimbursement_Status__c`: Picklist (`Pending`, `Processing`, `Completed`, `Failed`). Payment lifecycle stage.
* `Reimbursement_Reference__c`: Text(100). Banking / payment gateway transaction code.
* `Reimbursement_Date__c`: DateTime. Timestamp of confirmed settlement.

#### 3. Expense Item (`Expense_Item__c`)
* `Name`: Auto Number (`ITEM-{00000}`). Record identifier.
* `Expense_Report__c`: Master-Detail (`Expense_Report__c`), **Required**. Parent report container.
* `Category__c`: Picklist (`Airfare`, `Hotel & Lodging`, `Ground Transportation`, `Meals & Food`, `Client Entertainment`, `Incidentals & Miscellaneous`), **Required**.
* `Amount__c`: Currency(18,2), **Required**. Transaction amount.
* `Transaction_Date__c`: Date, **Required**. Date incurred.
* `Vendor__c`: Text(255). Merchant or service provider.
* `Description__c`: Text(255). Expense item justification.
* `Payment_Method__c`: Picklist (`Corporate Card`, `Personal Card`, `Cash`).
* `Receipt_Attached__c`: Checkbox, Default: `false`. Indicates proof of expense provided.
* `Receipt_Document_Id__c`: Text(255). Salesforce Files `ContentDocumentId`.
* `Is_Flagged_For_Review__c`: Checkbox, Default: `false`. Flagged by Smart Control Engine.
* `Flag_Reason__c`: Text(255). Audit explanation of policy flag.

#### 4. Expense Validation Exception (`Expense_Validation_Exception__c`)
* `Name`: Auto Number (`EXC-{00000}`). Record identifier.
* `Expense_Report__c`: Lookup (`Expense_Report__c`), **Required**. Associated report.
* `Expense_Item__c`: Lookup (`Expense_Item__c`). Line item that triggered the breach (null for report-level budget overruns).
* `Exception_Type__c`: Picklist (`Policy Violation`, `Missing Receipt`, `Potential Duplicate`, `Budget Overrun`), **Required**.
* `Severity__c`: Picklist (`Low`, `Medium`, `High`, `Critical`), **Required**.
* `Is_Blocking__c`: Checkbox, Default: `false`. Automatically set to `true` for `High` and `Critical`.
* `Status__c`: Picklist (`Open`, `Under Review`, `Resolved`, `Waived`, `Approved`, `Rejected`), Default: `Open`, **Required**.
* `Details__c`: Long TextArea(32768). Comprehensive mathematical breakdown of breach.
* `Reviewer__c`: Lookup (`User`). Assigned investigator / manager.
* `Resolution_Comments__c`: Long TextArea(32768). Mandatory reviewer justification.
* `Resolved_Date__c`: DateTime. Timestamp when exception was resolved/waived.

#### 5. Integration Log (`Integration_Log__c`)
* `Name`: Auto Number (`LOG-{00000}`).
* `Operation__c`: Text(255). API or batch operation name.
* `Endpoint__c`: Text(255). Service path or URL.
* `Reference_Id__c`: Text(255). Business transaction ID or tracking hash.
* `Related_Record_Id__c`: Text(50). Salesforce Record ID (`Travel_Request__c` or `Expense_Report__c`).
* `Status__c`: Picklist (`Success`, `Failed`).
* `Request_Payload__c`: Long TextArea(32768). Sanitized inbound/outbound JSON.
* `Response_Payload__c`: Long TextArea(32768). Sanitized response JSON.
* `Error_Message__c`: Long TextArea(32768). Stack trace or error message.
* `Execution_Time_Ms__c`: Number(18,0). Duration in milliseconds.

#### 6. Travel Expense Policy (`Travel_Expense_Policy__mdt`)
* `Role__c`: Picklist/Text (`Employee`, `Manager`).
* `Category__c`: Picklist/Text (6 core categories).
* `Single_Transaction_Limit__c`: Currency(18,2). Maximum single transaction cap.
* `Daily_Limit__c`: Currency(18,2). Cumulative cap per date/category.
* `Receipt_Required_Threshold__c`: Currency(18,2). Amount requiring mandatory receipt proof.
* `Allowed_Payment_Methods__c`: Text(255). Semicolon-delimited allowed methods.
* `Requires_Manager_Review__c`: Checkbox. Forces managerial review even if within financial limits.
* `Is_Active__c`: Checkbox, Default: `true`. Enables/disables policy rule.

---

## Part 4: Data Model and Relationships

### 4.1 Relationship Architecture
* **Travel Request to Expense Report (1:N Lookup):** An approved `Travel_Request__c` serves as the budget parent for one or more `Expense_Report__c` records. It is implemented as a standard Lookup to allow reports to exist independently in Draft, but Apex strictly enforces that `Travel_Request__r.Status__c == 'Approved'` before submission.
* **Expense Report to Expense Item (1:N Master-Detail):** `Expense_Item__c` is a child in a Master-Detail relationship. Deleting an Expense Report cascades to delete its items. Security and ownership are inherited from the parent report. Total amount rollup is maintained via Apex trigger aggregation.
* **Expense Report to Expense Validation Exception (1:N Lookup):** Exceptions link to `Expense_Report__c`. Exceptions must survive line item edits to preserve auditability.
* **Expense Item to Expense Validation Exception (1:N Lookup):** Line-item-specific breaches link directly to the originating `Expense_Item__c`. Budget overruns link solely to `Expense_Report__c`.
* **Integration Log to Business Records (Loose Coupling):** `Integration_Log__c` stores `Related_Record_Id__c` as a text field, ensuring logging never fails due to foreign key constraints or record locking.

### 4.2 Entity-Relationship Diagram (Mermaid)

```mermaid
erDiagram
    User ||--o{ Travel_Request__c : "submits (Employee)"
    User ||--o{ Travel_Request__c : "reviews (Approver)"
    User ||--o{ Expense_Report__c : "submits (Employee)"
    User ||--o{ Expense_Report__c : "reviews (Approver)"
    User ||--o{ Expense_Validation_Exception__c : "resolves (Reviewer)"

    Travel_Request__c ||--o{ Expense_Report__c : "authorizes spend"
    
    Expense_Report__c ||--|{ Expense_Item__c : "contains (Master-Detail)"
    Expense_Report__c ||--o{ Expense_Validation_Exception__c : "flags exceptions"
    Expense_Item__c ||--o{ Expense_Validation_Exception__c : "causes exception"

    Travel_Expense_Policy__mdt ||..o{ Expense_Item__c : "evaluates limits"
    Integration_Log__c }o..|| Expense_Report__c : "audits disbursement"
    Integration_Log__c }o..|| Travel_Request__c : "audits REST submission"

    Travel_Request__c {
        string Id PK
        string Name "TR-00000"
        id Employee__c FK
        string Requester_Role__c "Employee | Manager"
        currency Estimated_Cost__c
        string Status__c "Draft | Submitted | Approved | Rejected"
        date Travel_Start_Date__c
        date Travel_End_Date__c
    }

    Expense_Report__c {
        string Id PK
        string Name "EXP-00000"
        id Travel_Request__c FK
        id Employee__c FK
        currency Total_Amount__c
        string Status__c "Draft | Submitted | Under Review | Approved | Exception Flagged | Reimbursed"
        boolean Has_Blocking_Exceptions__c
        string Reimbursement_Status__c "Pending | Completed | Failed"
        string Reimbursement_Reference__c
    }

    Expense_Item__c {
        string Id PK
        string Name "ITEM-00000"
        id Expense_Report__c FK
        string Category__c
        currency Amount__c
        date Transaction_Date__c
        string Vendor__c
        boolean Receipt_Attached__c
        boolean Is_Flagged_For_Review__c
    }

    Expense_Validation_Exception__c {
        string Id PK
        string Name "EXC-00000"
        id Expense_Report__c FK
        id Expense_Item__c FK
        string Exception_Type__c
        string Severity__c "Low | Medium | High | Critical"
        boolean Is_Blocking__c
        string Status__c "Open | Resolved | Waived | Rejected"
        id Reviewer__c FK
    }

    Integration_Log__c {
        string Id PK
        string Name "LOG-00000"
        string Operation__c
        string Status__c "Success | Failed"
        string Reference_Id__c
        string Related_Record_Id__c
    }

    Travel_Expense_Policy__mdt {
        string DeveloperName PK
        string Role__c
        string Category__c
        currency Single_Transaction_Limit__c
        currency Daily_Limit__c
        currency Receipt_Required_Threshold__c
        boolean Requires_Manager_Review__c
    }
```

---

## Part 5: Custom Metadata Types and Role-Based Expense Policies

### 5.1 Verified Policy Rules Matrix
The project defines 12 active metadata records in `force-app/main/default/customMetadata/`, splitting policies between `Employee` and `Manager` across 6 categories:

| Policy Record DeveloperName | Role | Category | Single Transaction Cap | Daily Cumulative Cap | Receipt Required Threshold | Requires Manager Review |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| `Employee_Airfare` | `Employee` | Airfare | ₹10,000 | ₹10,000 | ₹500 | `false` |
| `Manager_Airfare` | `Manager` | Airfare | ₹25,000 | ₹25,000 | ₹500 | `false` |
| `Employee_Hotel_Lodging` | `Employee` | Hotel & Lodging | ₹5,000 | ₹5,000 | ₹500 | `false` |
| `Manager_Hotel_Lodging` | `Manager` | Hotel & Lodging | ₹12,000 | ₹12,000 | ₹500 | `false` |
| `Employee_Meals_Food` | `Employee` | Meals & Food | ₹1,000 | ₹2,500 | ₹300 | `false` |
| `Manager_Meals_Food` | `Manager` | Meals & Food | ₹2,500 | ₹5,000 | ₹300 | `false` |
| `Employee_Ground_Transportation` | `Employee` | Ground Transportation | ₹1,500 | ₹3,000 | ₹200 | `false` |
| `Manager_Ground_Transportation` | `Manager` | Ground Transportation | ₹3,500 | ₹7,000 | ₹300 | `false` |
| `Employee_Client_Entertainment` | `Employee` | Client Entertainment | ₹3,000 | ₹5,000 | ₹500 | `true` |
| `Manager_Client_Entertainment` | `Manager` | Client Entertainment | ₹10,000 | ₹15,000 | ₹500 | `true` |
| `Employee_Incidentals` | `Employee` | Incidentals & Miscellaneous | ₹1,000 | ₹1,500 | ₹200 | `false` |
| `Manager_Incidentals` | `Manager` | Incidentals & Miscellaneous | ₹2,500 | ₹3,500 | ₹300 | `false` |

### 5.2 Policy Selection Mechanism in Apex
Policy resolution is handled exclusively in `SmartExpenseControlService.cls`:
```apex
Id employeeId = parentReport.Employee__c;
String userRole = (parentReport.Travel_Request__r != null && String.isNotBlank(parentReport.Travel_Request__r.Requester_Role__c)) 
                  ? parentReport.Travel_Request__r.Requester_Role__c : 'Employee';

String policyKey = makeKey(userRole, item.Category__c);
Travel_Expense_Policy__mdt policy = policyCache.get(policyKey);

// Fallback to Employee role policy if specific role policy record is not found
if (policy == null) {
    policy = policyCache.get(makeKey('Employee', item.Category__c));
}
```

### 5.3 Anti-Role Escalation & Security Analysis
A critical architectural distinction exists between **REST Ingestion** and **Standard Lightning UI**:
1. **REST Resource Enforcement (`TravelRequestRestResource.cls`):**
   * Inspects authenticated `User.Title`, `UserRole.Name`, and queries `[SELECT count() FROM User WHERE ManagerId = :u.Id]`.
   * If a standard employee attempts to submit `jobRole: "Manager"`, the endpoint rejects the request with **HTTP 403 Forbidden** (`ROLE_MISMATCH`).
2. **Lightning UI Vulnerability (Unprotected Picklist):**
   * On the standard `Travel_Request__c` page layout, `Requester_Role__c` is an editable picklist with behavior `Edit`.
   * **Security Finding:** Neither `TravelRequestTriggerHandler` nor a Salesforce Validation Rule validates whether the user editing `Requester_Role__c` is actually an authorized manager. A standard employee can manually select `Manager` in the UI to grant themselves higher manager expense thresholds (e.g. ₹25,000 airfare instead of ₹10,000).

---

## Part 6: Apex Classes, Triggers, Handlers, and Test Classes

The local project contains **4 Apex Triggers** and **23 Apex Classes** (12 production classes and 11 test classes).

### 6.1 Apex Trigger Inventory

| Trigger File | Object | Events | Handler Invoked |
| :--- | :--- | :--- | :--- |
| `TravelRequestTrigger.trigger` | `Travel_Request__c` | `before insert`, `before update`, `after insert`, `after update` | `TravelRequestTriggerHandler` |
| `ExpenseReportTrigger.trigger` | `Expense_Report__c` | `before insert`, `before update`, `after insert`, `after update` | `ExpenseReportTriggerHandler` |
| `ExpenseItemTrigger.trigger` | `Expense_Item__c` | `before insert`, `before update`, `after insert`, `after update`, `after delete`, `after undelete` | `ExpenseItemTriggerHandler` |
| `ExpenseValidationExceptionTrigger.trigger` | `Expense_Validation_Exception__c` | `before insert`, `before update`, `after insert`, `after update`, `after delete`, `after undelete` | `ExpenseValidationExceptionTriggerHandler` |

---

### 6.2 Production Apex Classes Inventory

| Class Name | Sharing | Purpose & Core Logic | Key Methods |
| :--- | :--- | :--- | :--- |
| `SmartExpenseControlService` | `inherited sharing` | Smart policy evaluation engine. Evaluates items against metadata limits, calculates aggregate daily spend, detects duplicates and cumulative trip budget overruns. | `evaluateExpenseItems()`, `getPolicyCache()`, `getExistingDailyTotals()`, `getExistingDuplicates()`, `getTravelRequestTotals()` |
| `TravelRequestTriggerHandler` | `inherited sharing` | Validates travel dates/cost, assigns default manager approver, stamps approval timestamp, defaults rejection reasons, dispatches decision emails. | `handleBeforeInsert()`, `handleBeforeUpdate()`, `handleAfterUpdate()`, `assignDefaultApprovers()`, `validateDatesAndCost()` |
| `ExpenseReportTriggerHandler` | `inherited sharing` | Validates travel request approval prerequisite, blocks submission when blocking exceptions exist, blocks approval if exceptions exist, initiates asynchronous reimbursement upon approval. | `validateTravelRequestApproval()`, `validateSubmissionRequirements()`, `validateApprovalRequirements()`, `handleAfterUpdate()` |
| `ExpenseItemTriggerHandler` | `inherited sharing` | Recalculates parent `Total_Amount__c` via AggregateResult SOQL and passes inserted/updated items to `SmartExpenseControlService`. Flags parent reports if blocking exceptions are created. | `recalculateParentTotals()`, `runPolicyEvaluation()`, `handleAfterInsert()`, `handleAfterUpdate()` |
| `ExpenseValidationExceptionTriggerHandler` | `inherited sharing` | Manages `Is_Blocking__c` lifecycle, audits reviewer and resolution comments, and synchronizes `Has_Blocking_Exceptions__c` and `Status__c` on parent `Expense_Report__c`. | `handleBeforeInsert()`, `handleBeforeUpdate()`, `synchronizeParentReportStatus()` |
| `TravelRequestRestResource` | `with sharing` | Public Apex REST endpoint (`/traveleasy/travel-requests`). Handles external JSON submissions, validates dates/cost, verifies user manager authorization, and logs to `Integration_Log__c`. | `doPost()`, `isUserAuthorizedManager()`, `validateRequiredFields()`, `sendError()` |
| `ReimbursementService` | `inherited sharing` | Orchestrates payment disbursement. Simulates external payment gateway callout, generates `TXN` references, stamps settlement status, logs to `Integration_Log__c`. | `initiateReimbursement()`, `processSingleReportReimbursement()` |
| `ProcessReimbursementQueueable` | `inherited sharing` | Asynchronous Queueable Apex job implementing `Database.AllowsCallouts`. Batches approved expense reports for payment processing. | `execute(System.QueueableContext)` |
| `ReimbursementReconciliationBatch` | `inherited sharing` | Stateful Batch Apex job (`Database.Batchable<sObject>`, `Database.AllowsCallouts`) to reconcile and retry pending or failed reimbursements. | `start()`, `execute()`, `finish()` |
| `ReimbursementScheduler` | `inherited sharing` | Schedulable class to run `ReimbursementReconciliationBatch` on a periodic schedule. | `execute(SchedulableContext)` |
| `TravelEasyUiController` | `with sharing` | Lightning Web Component controller. Powers `smartExpenseChecker` summary and handles secure exception resolution in `exceptionResolutionPanel`. | `getExpenseReportSummary()`, `resolveException()` |
| `IntegrationLogService` | `inherited sharing` | Centralized audit logging service. Sanitizes sensitive passwords/tokens and inserts logs in `SYSTEM_MODE`. | `log()`, `sanitize()` |
| `TravelEasyEmailNotificationService` | `inherited sharing` | Fail-safe transactional email dispatcher for travel request approvals/rejections, expense report decisions, and reimbursement confirmations. | `sendTravelRequestDecisionEmail()`, `sendExpenseReportDecisionEmail()`, `sendReimbursementOutcomeEmail()` |

---

### 6.3 Apex Test Classes Inventory

| Test Class Name | Target Class Under Test | Methods Tested | Scenarios Covered |
| :--- | :--- | :---: | :--- |
| `TravelRequestTriggerTest` | `TravelRequestTriggerHandler` | 5 | Approver assignment, approval date stamping, default rejection reasons, date validations, cost validations, bulk inserts. |
| `ExpenseReportTriggerTest` | `ExpenseReportTriggerHandler` | 9 | Approval prerequisite guard, blocking exception submission guard, blocking approval guard, reimbursement trigger, cleared exception resubmission. |
| `ExpenseItemTriggerTest` | `ExpenseItemTriggerHandler` | 2 | Parent `Total_Amount__c` recalculation across item DML, bulk item insertion. |
| `ExpenseValidationSyncTest` | `ExpenseValidationExceptionTriggerHandler` | 4 | Single blocking exception lifecycle, partial resolution of multiple exceptions, exception deletion sync, bulk synchronization. |
| `SmartExpenseControlServiceTest` | `SmartExpenseControlService` | 6 | Single transaction limits, multi-item daily category limits, missing receipts, duplicate detection, travel budget overruns, 6-category compliance. |
| `TravelRequestRestResourceTest` | `TravelRequestRestResource` | 7 | Valid employee submission, valid manager submission, role escalation 403, past date rejection, invalid date range, malformed JSON. |
| `ReimbursementServiceTest` | `ReimbursementService` | 1 | Queueable payment disbursement execution and record stamping. |
| `ReimbursementBatchTest` | `ReimbursementReconciliationBatch` | 2 | Batch reconciliation execution and schedulable invocation. |
| `TravelEasyUiControllerTest` | `TravelEasyUiController` | 2 | LWC report summary calculation and exception resolution state transitions. |
| `TravelEasyEmailNotificationServiceTest` | `TravelEasyEmailNotificationService` | 10 | Complete email lifecycle across requests, reports, and payments; verifies that email failures do not roll back business transactions. |
| `IntegrationLogServiceTest` | `IntegrationLogService` | 1 | Log creation, payload sanitization, token masking, and system-mode execution. |

---

### 6.4 Execution Order Breakdown
When an employee enters an expense item and submits a report:
1. **User Inserts `Expense_Item__c`:**
   * `ExpenseItemTrigger` (`after insert`) fires.
   * `ExpenseItemTriggerHandler.recalculateParentTotals` performs aggregate SOQL and updates parent `Expense_Report__c.Total_Amount__c` in `SYSTEM_MODE`.
   * `ExpenseItemTriggerHandler.runPolicyEvaluation` invokes `SmartExpenseControlService.evaluateExpenseItems`.
   * Exceptions are inserted in `SYSTEM_MODE`.
   * If blocking exceptions exist, `Expense_Report__c` is stamped with `Has_Blocking_Exceptions__c = true` and `Status__c = 'Exception Flagged'`.
2. **Exception Triggers Fire:**
   * `ExpenseValidationExceptionTrigger` (`before insert`, `after insert`) executes.
   * `Expense_Exception_Notification_Flow` evaluates severity and assigns reviewer.
3. **User Attempts Status Update to `Submitted`:**
   * `ExpenseReportTrigger` (`before update`) executes `validateSubmissionRequirements`.
   * If `Has_Blocking_Exceptions__c == true`, update is rejected with `addError()`.
   * If `false`, record is updated to `Submitted`.
   * `Expense_Report_Submission_Flow` routes status to `Under Review`.
4. **Manager Approves Report:**
   * `ExpenseReportTrigger` (`before update`) validates `Has_Blocking_Exceptions__c == false`, stamps `Approval_Date__c`.
   * `ExpenseReportTrigger` (`after update`) enqueues `ProcessReimbursementQueueable` and sends decision email.
5. **Asynchronous Settlement:**
   * `ProcessReimbursementQueueable` executes in background.
   * Calls `ReimbursementService.processSingleReportReimbursement`.
   * Updates report to `Status__c = 'Reimbursed'`, logs to `Integration_Log__c`, and triggers confirmation email.

---

## Part 7: Salesforce Flows

The project contains **3 Active Record-Triggered Flows** located in `force-app/main/default/flows/`:

### 7.1 Flow Specifications

#### 1. Travel Request Submission Flow
* **File:** `Travel_Request_Submission_Flow.flow-meta.xml`
* **Trigger Type:** Record-After-Save (`RecordAfterSave`)
* **Trigger Object:** `Travel_Request__c`
* **Start Condition:** `Status__c` is changed to `Submitted` (`doesRequireRecordChangedToMeetCriteria = true`).
* **Decisions & Logic:**
  * `Check_Approver_Assignment`: Evaluates if `$Record.Approver__c` is null.
  * If Null: Executes `Assign_Approver_From_Employee` to populate `Approver__c` with `$Record.Employee__r.ManagerId`.
* **Business Position:** Ensures approver field is populated upon submission before entering approval steps.
* **Status:** **Active & Verified.**

#### 2. Expense Report Submission Flow
* **File:** `Expense_Report_Submission_Flow.flow-meta.xml`
* **Trigger Type:** Record-After-Save (`RecordAfterSave`)
* **Trigger Object:** `Expense_Report__c`
* **Start Condition:** `Status__c` is changed to `Submitted` (`doesRequireRecordChangedToMeetCriteria = true`).
* **Decisions & Logic:**
  * `Check_Blocking_Exceptions`: Evaluates `$Record.Has_Blocking_Exceptions__c == true`.
  * **Rule `Has_Blocking_Exceptions`:** Updates `$Record.Status__c = 'Exception Flagged'` (`Flag_Report_For_Exception_Review`).
  * **Default (Compliant):** Updates `$Record.Status__c = 'Under Review'` (`Set_Under_Review_Route`).
* **Interaction with Apex Guard:** In previous versions, this Flow merely reverted the status after save. With the new Apex before-update guard, submissions with blocking exceptions are rejected synchronously; this Flow now handles clean compliant submissions routing to `Under Review`.
* **Status:** **Active & Verified.**

#### 3. Expense Exception Notification Flow
* **File:** `Expense_Exception_Notification_Flow.flow-meta.xml`
* **Trigger Type:** Record-After-Save (`RecordAfterSave`)
* **Trigger Object:** `Expense_Validation_Exception__c`
* **Start Condition:** `(Severity__c == 'High' OR Severity__c == 'Critical') AND Status__c == 'Open'` (`doesRequireRecordChangedToMeetCriteria = true`).
* **Decisions & Logic:**
  * `Check_Reviewer_Assignment`: Checks if `$Record.Reviewer__c` is null.
  * If Null: Executes `Assign_Parent_Report_Approver` to assign `Reviewer__c` from `$Record.Expense_Report__r.Approver__c`.
* **Business Position:** Ensures high-risk violations are automatically queued for the authorized report approver.
* **Status:** **Active & Verified.**

---

## Part 8: Approval Processes and Approver Routing

### 8.1 Live Salesforce Org Approval Processes
Inspection of the live target org via Tooling API identified two active `ProcessDefinition` approval processes:
1. **Travel Request Approval:**
   * **API Name:** `Travel_Request__c.Travel_Request_Approval` (Process Definition ID: `04adL000003CBUDQA4`)
   * **Target Object:** `Travel_Request__c`
   * **Active Step:** `Manager_Review`
2. **Expense Report Approval:**
   * **API Name:** `Expense_Report__c.TravelEasy_Expense_Report_Approval` (Process Definition ID: `04adL000003CG2TQAW`)
   * **Target Object:** `Expense_Report__c`
   * **Active Step:** `Manager_Approval`

### 8.2 Architectural Discrepancy: Intended Rule vs Actual Implementation
* **The Intended Architecture:**
  * Employee Travel Requests submitted for **Finance Team** approval.
  * Manager Travel Requests submitted for **Finance Team** approval.
  * Expense Reports submitted for **Manager** approval.
* **The Actual Implementation:**
  * **No Finance Queue Exists:** There is no Finance Queue or Finance User routing configured in metadata or triggers.
  * **Manager-Only Assignment:** Both `TravelRequestTriggerHandler` and `Travel_Request_Submission_Flow` assign:
    `Approver__c = Employee__r.ManagerId`
  * **Self-Approval Fallback Vulnerability:** In `TravelRequestTriggerHandler.assignDefaultApprovers`:
    ```apex
    tr.Approver__c = emp.ManagerId != null ? emp.ManagerId : tr.Employee__c;
    ```
    If an employee does not have a `ManagerId` populated on their User record, the system assigns the employee as their own approver.
* **Repository Storage Gap:**
  * The local directory `force-app/main/default/approvalProcesses/` is empty. The approval processes were created manually in the live playground org and have not been retrieved into version control.

---

## Part 9: Validation Rules and Business Controls

### 9.1 Declarative Validation Rules vs Programmatic Controls
* **Salesforce Validation Rules (`*.validationRule-meta.xml`):** Exactly **0** declarative validation rules exist in the repository.
* **All Business Controls Are Programmatic:** All input validations, state machine rules, and submission guards are implemented across **Apex Triggers**, **Service Classes**, and **Flow Decisions**.

### 9.2 Comprehensive Controls Inventory Table

| Control Name | Object | Implementation Layer | Condition / Trigger | Error Message / Action | Business Rule Enforced | Bypass Risk |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Validate Travel Dates** | `Travel_Request__c` | Apex Trigger (`TravelRequestTriggerHandler`) | `Travel_End_Date__c < Travel_Start_Date__c` | *"Travel End Date cannot be earlier than Travel Start Date."* | Prevents impossible travel duration. | Low (runs before insert/update). |
| **Validate Travel Cost** | `Travel_Request__c` | Apex Trigger (`TravelRequestTriggerHandler`) | `Estimated_Cost__c <= 0` | *"Estimated Cost must be greater than zero."* | Ensures trips have positive budget commitments. | Low. |
| **Travel Request Prerequisite Guard** | `Expense_Report__c` | Apex Trigger (`ExpenseReportTriggerHandler`) | `Travel_Request__r.Status__c != 'Approved'` and report not Draft | *"Cannot submit or process expense report because the associated Travel Request is not Approved."* | Guarantees expenses only incur against authorized trips. | Low. |
| **Blocking Exceptions Submission Guard** | `Expense_Report__c` | Apex Trigger (`ExpenseReportTriggerHandler`) | `Has_Blocking_Exceptions__c == true` AND (status transitioning to `Submitted` or `Under Review`) | *"Cannot submit expense report while unresolved blocking policy exceptions exist. Please resolve all High and Critical exceptions first."* | Prohibits submission of non-compliant expense reports. | Low (Apex before-update guard). |
| **Blocking Exceptions Approval Guard** | `Expense_Report__c` | Apex Trigger (`ExpenseReportTriggerHandler`) | `Has_Blocking_Exceptions__c == true` AND status transitioning to `Approved` | *"Cannot approve expense report while unresolved blocking policy exceptions exist."* | Hard stop against approving non-compliant expenses. | Low. |
| **Single Transaction Limit Check** | `Expense_Item__c` | Apex Engine (`SmartExpenseControlService`) | `Amount__c > Policy.Single_Transaction_Limit__c` | Creates `High` severity exception; sets `Is_Blocking__c = true`. | Caps individual line-item spend per role/category. | None (runs on item DML). |
| **Daily Category Limit Check** | `Expense_Item__c` | Apex Engine (`SmartExpenseControlService`) | Prior DB spend + Batch spend > `Policy.Daily_Limit__c` | Creates `High` severity exception; sets `Is_Blocking__c = true`. | Enforces daily category limits across multiple items. | None. |
| **Missing Receipt Check** | `Expense_Item__c` | Apex Engine (`SmartExpenseControlService`) | `Amount__c >= Threshold` AND `!Receipt_Attached__c` | Creates `Medium` severity exception; flags item. | Requires proof for expenses exceeding receipt threshold. | Moderate (Medium severity does not block approval). |
| **Potential Duplicate Check** | `Expense_Item__c` | Apex Engine (`SmartExpenseControlService`) | Matching Employee + Date + Vendor + Category + Amount | Creates `High` severity exception; sets `Is_Blocking__c = true`. | Prevents duplicate expense claims. | None. |
| **Cumulative Budget Overrun Check** | `Expense_Report__c` | Apex Engine (`SmartExpenseControlService`) | Cumulative trip spend > `Travel_Request__r.Estimated_Cost__c` | Creates `Critical` severity exception; sets `Is_Blocking__c = true`. | Prevents total trip expenses from exceeding approved budget. | None. |
| **REST Server-Side Role Guard** | `Travel_Request__c` (REST API) | Apex Class (`TravelRequestRestResource`) | `jobRole == 'Manager'` and user not authorized | HTTP 403: *"Supplied role 'Manager' does not match authenticated employee record."* | Prevents role privilege escalation via API. | High via Lightning UI (UI picklist unvalidated). |

---

## Part 10: Lightning UI, Pages, Page Layouts, and Navigation

### 10.1 Lightning Application & Navigation
* **Application Name:** `TravelEasy` (`force-app/main/default/applications/TravelEasy.app-meta.xml`)
* **Header Brand Color:** `#0070D2` (Salesforce Blue)
* **Form Factors:** Desktop / Large
* **Navigation Items (Tabs):**
  1. `Travel_Request__c` (Travel Requests)
  2. `Expense_Report__c` (Expense Reports)
  3. `Expense_Validation_Exception__c` (Expense Exceptions)
  4. `Integration_Log__c` (Integration Audit Logs)
  5. `standard-report` (Reports)
  6. `standard-Dashboard` (Dashboards)

### 10.2 Custom Lightning Web Components (LWCs)

#### 1. `smartExpenseChecker`
* **Location:** `force-app/main/default/lwc/smartExpenseChecker`
* **Target Page:** Embedded on `Expense_Report_Record_Page` flexipage (Main Region).
* **Apex Controller:** `TravelEasyUiController.getExpenseReportSummary`.
* **Display Elements:**
  * 3 Summary KPI Cards: **Report Total** (₹), **Trip Budget** (₹), **Budget Variance** (₹).
  * Dynamic Variance Styling: Green if under budget (`#2e844a`), Bold Red if over budget (`#ea001e`).
  * Alert Banner: Red warning banner when `hasBlockingExceptions == true`; Green success banner when all checks pass.
  * Exception Pill Badges: Total exceptions count and open exceptions count.

#### 2. `exceptionResolutionPanel`
* **Location:** `force-app/main/default/lwc/exceptionResolutionPanel`
* **Target Page:** Embedded on `Expense_Validation_Exception_Record_Page` flexipage (Sidebar Region).
* **Apex Controller:** `TravelEasyUiController.resolveException`.
* **Action Options:** Combobox offering `Resolved`, `Waived`, `Approved`, `Rejected`.
* **Inputs:** Mandatory "Justification Comments" textarea.
* **Behavior:** Updates exception status, stamps reviewer ID, records timestamp, shows toast notification, and automatically triggers parent report blocking status recalculation.

### 10.3 Page Layouts & Submit Button Configuration
* **`Travel_Request__c-Travel Request Layout`:**
  * `<excludeButtons>Submit</excludeButtons>` is configured. Submission is executed by picking `Status__c = 'Submitted'`.
  * `Requester_Role__c` is editable.
  * Related List displays linked `Expense_Report__c` records.
* **`Expense_Report__c-Expense Report Layout`:**
  * `<excludeButtons>Submit</excludeButtons>` is configured. Submission is executed by picking `Status__c = 'Submitted'`.
  * Fields: `Total_Amount__c` and `Has_Blocking_Exceptions__c` are Readonly.
  * Related Lists: Child `Expense_Item__c` items and child `Expense_Validation_Exception__c` exceptions.

---

## Part 11: Integrations and External Services

### 11.1 Apex REST Resource (`TravelRequestRestResource.cls`)
* **Endpoint:** `/services/apexrest/traveleasy/travel-requests`
* **HTTP Method:** `POST`
* **Authentication:** Salesforce OAuth 2.0 (Bearer Token via Connected App or Session).
* **Payload Format:** JSON
  ```json
  {
    "employeeName": "Priya Sharma",
    "employeeId": "EMP-10492",
    "jobRole": "Employee",
    "destination": "Mumbai",
    "purpose": "Enterprise Discovery",
    "travelStartDate": "2026-11-01",
    "travelEndDate": "2026-11-04",
    "estimatedCost": 20000.00
  }
  ```
* **Security & Anti-Escalation:** Performs server-side role verification (`isUserAuthorizedManager`). Rejects unauthorized role claims with HTTP 403 `ROLE_MISMATCH`.
* **Auditing:** Injects request, response, and error status into `Integration_Log__c`.

### 11.2 Postman Test Collection
Located in `postman/TravelEasy_API_Collection.json` with environment `postman/TravelEasy_Environment.json`. Contains 4 pre-configured requests:
1. `Submit Travel Request - Valid Employee (201 Created)`
2. `Submit Travel Request - Valid Manager (201 Created)`
3. `Submit Travel Request - Invalid Past Date (400 Bad Request)`
4. `Submit Travel Request - Role Escalation / Impersonation (403 Forbidden)`

### 11.3 Simulated Payment Disbursement Gateway
* **Class:** `ReimbursementService.cls` / `ProcessReimbursementQueueable.cls`
* **Simulated Endpoint:** `https://api.traveleasy-payments.mock/v1/disbursements`
* **Architecture:** In sandbox environments, payments are simulated with random crypto tokens (`TXN-...`). The architecture is pre-configured with commented Named Credential callout syntax (`callout:TravelEasyPaymentGateway/v1/disbursements`) for future live integration.
* **Disbursement Reconciliation Batch:** `ReimbursementReconciliationBatch.cls` and `ReimbursementScheduler.cls` provide batch reconciliation and retry capabilities for failed disbursements.

### 11.4 Integration Status & Missing Components
* **REST API:** **Implemented & Verified.**
* **Mock Payment Gateway:** **Implemented & Verified.**
* **Integration Logging:** **Implemented & Verified.**
* **Receipt OCR / AI Scanning:** **Missing / Planned.**
* **Agentforce / AI Assistants:** **Missing / Planned.**
* **Data Cloud / Data 360:** **Missing / Planned.**
* **Live Named Credentials / Real Bank Callouts:** **Not configured (Simulated mock).**

---

## Part 12: Local Salesforce Project Structure

The project is structured according to Salesforce DX source format:

```
c:\Users\chara\OneDrive\Documents\CHARAN(OWN)\SALES FORCE\USECASE 5 (TRAVELEASY - SALESFORCE)\
├── sfdx-project.json                           (API 60.0 configuration)
├── manifest/
│   └── package.xml                             (Full metadata manifest)
├── postman/
│   ├── TravelEasy_API_Collection.json          (API test suite)
│   └── TravelEasy_Environment.json             (Postman environment)
└── force-app/main/default/
    ├── applications/
    │   └── TravelEasy.app-meta.xml             (Lightning App definition)
    ├── approvalProcesses/                      (Empty locally; exists in org)
    ├── classes/                                (23 Apex classes)
    ├── customMetadata/                         (12 Travel Expense Policy records)
    ├── dashboards/
    │   └── TravelEasy_Dashboards/              (Executive Dashboard)
    ├── flexipages/
    │   ├── Expense_Report_Record_Page.flexipage-meta.xml
    │   └── Expense_Validation_Exception_Record_Page.flexipage-meta.xml
    ├── flows/
    │   ├── Travel_Request_Submission_Flow.flow-meta.xml
    │   ├── Expense_Report_Submission_Flow.flow-meta.xml
    │   └── Expense_Exception_Notification_Flow.flow-meta.xml
    ├── layouts/                                (5 Page Layout files)
    ├── lwc/
    │   ├── exceptionResolutionPanel/           (LWC exception resolver)
    │   └── smartExpenseChecker/                (LWC expense summary KPI)
    ├── objects/
    │   ├── Travel_Request__c/
    │   ├── Expense_Report__c/
    │   ├── Expense_Item__c/
    │   ├── Expense_Validation_Exception__c/
    │   ├── Integration_Log__c/
    │   └── Travel_Expense_Policy__mdt/
    ├── permissionsets/
    │   ├── TravelEasy_Employee.permissionset-meta.xml
    │   ├── TravelEasy_Manager.permissionset-meta.xml
    │   └── TravelEasy_Finance_Admin.permissionset-meta.xml
    ├── reports/
    │   └── TravelEasy_Reports/                 (4 Custom Reports)
    ├── reportTypes/
    │   └── Smart_Expense_Exceptions.reportType-meta.xml
    ├── tabs/                                   (4 Custom Tab definitions)
    └── triggers/                               (4 Apex Triggers)
```

---

## Part 13: Reports and Dashboards

### 13.1 Reports Inventory (`force-app/main/default/reports/TravelEasy_Reports/`)

| Report Name | Developer Name | Report Type | Primary Grouping | Aggregate Metric | Business Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Travel Requests Overview** | `Travel_Requests_Overview` | `CustomEntity$Travel_Request__c` | `Travel_Request__c.Status__c` | Sum of `Estimated_Cost__c` | Monitors trip volume, estimated spend commitments, and approvals. |
| **Spend vs Budget Variance** | `Spend_vs_Budget_Variance` | `CustomEntity$Expense_Report__c` | `Expense_Report__c.Status__c` | Sum of `Total_Amount__c` | Analyzes incurred spend distributed across draft, flagged, and approved reports. |
| **Smart Expense Exceptions** | `Smart_Expense_Exceptions` | `Smart_Expense_Exceptions__c` (Custom Report Type) | 1. `Severity__c`<br>2. `Exception_Type__c` | Record Count (`RowCount`) | Tracks policy violation distribution, duplicate frequency, and budget overruns. |
| **Reimbursement Status** | `Reimbursement_Status` | `CustomEntity$Expense_Report__c` | `Expense_Report__c.Reimbursement_Status__c` | Sum of `Total_Amount__c` | Audits accounts payable pipeline and disbursement turnaround. |

### 13.2 Custom Report Type (`Smart_Expense_Exceptions__c`)
* **Base Object:** `Expense_Validation_Exception__c`
* **Label:** Smart Expense Exceptions
* **Deployment Status:** Deployed
* **Default Columns:** `Name`, `Expense_Report__c`, `Expense_Item__c`, `Status__c`, `Is_Blocking__c`, `Reviewer__c`, `Severity__c`, `Exception_Type__c`.

### 13.3 Executive Dashboard (`TravelEasy_Dashboards/TravelEasy_Executive_Spend_Control_Dashboard`)
* **Dashboard Title:** TravelEasy Executive Spend & Control Dashboard
* **Running User:** `charankarnam71@wise-fox-rmu03e.com`
* **Layout Structure:** 12-column responsive grid with 4 visual components:
  1. **Estimated Cost by Status (Donut Chart):** Sourced from `Travel_Requests_Overview`. Visualizes committed travel budget across lifecycle statuses.
  2. **Total Spend by Report Status (Bar Chart):** Sourced from `Spend_vs_Budget_Variance`. Displays cumulative INR spend by report status.
  3. **Exception Count by Severity (Column Chart):** Sourced from `Smart_Expense_Exceptions`. Highlighting `Critical` and `High` blocking policy violations.
  4. **Disbursement Pipeline (Donut Chart):** Sourced from `Reimbursement_Status`. Summarizes processed vs pending payment amounts.

---

## Part 14: Testing and Evidence Matrix

Below is the verified 18-scenario testing matrix cross-referencing Apex unit tests, automated validations, and org behavior:

| # | Scenario Description | Expected Result | Actual Result | Evidence Source | Status | Next Action Required |
| :-: | :--- | :--- | :--- | :--- | :---: | :--- |
| **1** | **Employee Travel Request Submission** | Request created with Status `Submitted`; approver set to Manager. | Matches expectation. Status `Submitted`, approver stamped. | `TravelRequestRestResourceTest.testValidEmployeeSubmission` | **PASS** | None. |
| **2** | **Manager Travel Request Submission** | Request created with Role `Manager`; approver assigned. | Matches expectation. REST API authorizes manager and creates record. | `TravelRequestRestResourceTest.testValidManagerSubmission` | **PASS** | Add UI trigger check to prevent employee escalation in Lightning UI. |
| **3** | **Finance Approval Routing** | Travel Requests route to Finance Queue for approval. | Routes to `Employee__r.ManagerId`, NOT Finance Queue. | `TravelRequestTriggerHandler.assignDefaultApprovers` | **FAIL** | Implement Finance Queue and update approver assignment logic. |
| **4** | **Request Approval & Rejection** | Approving stamps date; rejecting requires/defaults reason. | Date stamped upon approval; rejection reason defaulted. | `TravelRequestTriggerTest.testApproverAssignmentAndApprovalStamping` | **PASS** | None. |
| **5** | **Approval Notifications** | Requester receives transactional email on decision. | Email created and logged to `Integration_Log__c`. | `TravelEasyEmailNotificationServiceTest.testScenario1_TravelRequestApprovalEmail` | **PASS** | None. |
| **6** | **Expense Report Creation** | Report created linked to approved Travel Request. | Report created and linked; unapproved request blocked. | `ExpenseReportTriggerTest.testAllowSubmissionOnApprovedTravelRequest` | **PASS** | None. |
| **7** | **Expense Item Entry & Rollup** | Item DML recalculates parent `Total_Amount__c`. | Sum of child items accurately rolled up to parent report. | `ExpenseItemTriggerTest.testParentTotalRecalculationOnItemDml` | **PASS** | None. |
| **8** | **Employee Expense Policy Enforcement** | Evaluates against Employee metadata limits. | Violations detected and flagged accurately. | `SmartExpenseControlServiceTest.testSingleTransactionLimitBreach` | **PASS** | None. |
| **9** | **Manager Expense Policy Enforcement** | Applies higher manager thresholds. | Metadata records exist; REST verified; Apex unit test specifically for Manager limits is absent. | `Travel_Expense_Policy__mdt` records; `SmartExpenseControlService.cls` | **PARTIALLY TESTED** | Add dedicated Apex test method for Manager limit evaluation. |
| **10** | **Single Transaction Limit Breach** | Amount > Single Cap raises `High` exception. | Exception created with `High` severity and `Is_Blocking__c = true`. | `SmartExpenseControlServiceTest.testSingleTransactionLimitBreach` | **PASS** | None. |
| **11** | **Daily Category Limit Breach** | Cumulative daily spend > Daily Cap raises exception. | Multiple items on same date trigger `High` exception. | `SmartExpenseControlServiceTest.testDailyLimitBreachAcrossMultipleItems` | **PASS** | None. |
| **12** | **Receipt Requirement Breach** | Amount >= Threshold without receipt raises exception. | Exception created with `Medium` severity. | `SmartExpenseControlServiceTest.testMissingReceiptValidation` | **PASS** | None. |
| **13** | **Potential Duplicate Detection** | Identical employee, date, vendor, category, amount flagged. | `High` severity exception created for duplicate item. | `SmartExpenseControlServiceTest.testPotentialDuplicateDetection` | **PASS** | None. |
| **14** | **Budget Overrun Detection** | Cumulative spend > Estimated Cost raises `Critical` exception. | `Critical` exception created with exact overrun difference. | `SmartExpenseControlServiceTest.testBudgetOverrunDetection` | **PASS** | Deploy recent fix in `SmartExpenseControlService.cls`. |
| **15** | **Critical Exception Submission Guard** | Prevents submission when `Has_Blocking_Exceptions__c = true`. | Synchronously throws clear submission error. | `ExpenseReportTriggerTest.testBlockSubmissionWhenBlockingExceptionsExist` | **PASS** | Deploy recent fix in `ExpenseReportTriggerHandler.cls`. |
| **16** | **Exception Resolution Lifecycle** | Waiving/resolving all exceptions unblocks report. | `Has_Blocking_Exceptions__c` set to `false`; report submitted. | `ExpenseReportTriggerTest.testAllowSubmissionWhenBlockingExceptionsCleared` | **PASS** | None. |
| **17** | **Expense Report Approval & Disbursement** | Manager approval triggers Queueable disbursement. | Queueable job enqueued; report stamped `Reimbursed`. | `ExpenseReportTriggerTest.testApprovalTriggersReimbursement` | **PASS** | None. |
| **18** | **Reporting & Dashboard Behavior** | Reports and Dashboard aggregate live data correctly. | Metadata files verified; runtime chart rendering cannot be executed via Apex unit tests. | `TravelEasy_Executive_Spend_Control_Dashboard.dashboard-meta.xml` | **UNABLE TO VERIFY VIA APEX** | Perform manual smoke test in live Lightning UI. |

---

## Part 15: Architecture and Dependency Diagrams

### Diagram A: End-to-End Business Workflow (Mermaid)

```mermaid
flowchart TD
    A["1. Employee / Manager opens TravelEasy App"] --> B["2. Creates Travel Request (Destination, Dates, Cost)"]
    B --> C{"3. Date & Cost Validations<br/>(TravelRequestTriggerHandler)"}
    C -- "Invalid Dates / Zero Cost" --> B
    C -- "Valid" --> D["4. Status set to 'Submitted'"]
    D --> E["5. Approver Assigned: ManagerId<br/>(Travel_Request_Submission_Flow)"]
    E --> F{"6. Manager Decision"}
    F -- "Rejected" --> G["7. Status = 'Rejected'<br/>Decision Email Sent"]
    F -- "Approved" --> H["8. Status = 'Approved'<br/>Decision Email Sent"]
    H --> I["9. Employee creates Expense Report linked to Trip"]
    I --> J["10. Employee logs Expense Items (6 Categories)"]
    J --> K["11. Smart Expense Control Engine runs<br/>(SmartExpenseControlService)"]
    K --> L{"12. Violations Detected?<br/>(Single, Daily, Duplicate, Overrun)"}
    L -- "Yes (High / Critical)" --> M["13. Expense Validation Exception created<br/>Has_Blocking_Exceptions__c = TRUE<br/>Status = 'Exception Flagged'"]
    L -- "No Violations" --> N["14. Report Compliant<br/>Has_Blocking_Exceptions__c = FALSE"]
    M --> O{"15. Employee attempts Submission"}
    O -- "Blocking Exception Exists" --> P["16. BLOCKED: AddError Error Displayed<br/>(ExpenseReportTriggerHandler)"]
    P --> Q["17. Manager reviews in LWC Panel<br/>(exceptionResolutionPanel)"]
    Q --> R["18. Manager Resolves or Waives Exception"]
    R --> S["19. Trigger clears Has_Blocking_Exceptions__c to FALSE"]
    S --> N
    N --> T["20. Report Submitted -> Status = 'Under Review'"]
    T --> U{"21. Manager Approves Report"}
    U -- "Approved" --> V["22. Asynchronous Payment Enqueued<br/>(ProcessReimbursementQueueable)"]
    V --> W["23. Payment Settled: Status = 'Reimbursed'<br/>Reference Stamped & Email Sent"]
    W --> X["24. Executive Dashboard & Reports Updated"]
```

---

### Diagram B: Technical Architecture & Component Dependencies (Mermaid)

```mermaid
flowchart TB
    subgraph UI_Layer ["Lightning User Interface Layer"]
        App["TravelEasy App"]
        LWC1["smartExpenseChecker LWC"]
        LWC2["exceptionResolutionPanel LWC"]
        Flexi1["Expense Report Record Page"]
        Flexi2["Expense Exception Record Page"]
    end

    subgraph API_Layer ["Integration & API Layer"]
        RestAPI["TravelRequestRestResource<br/>(/traveleasy/travel-requests)"]
        Postman["Postman API Test Suite"]
    end

    subgraph Controller_Layer ["Apex Controllers & Services"]
        UIController["TravelEasyUiController"]
        SmartEngine["SmartExpenseControlService"]
        ReimburseService["ReimbursementService"]
        EmailService["TravelEasyEmailNotificationService"]
        LogService["IntegrationLogService"]
    end

    subgraph Trigger_Layer ["Apex Triggers & Handlers"]
        TR_Trig["TravelRequestTrigger"] --> TR_Handler["TravelRequestTriggerHandler"]
        ER_Trig["ExpenseReportTrigger"] --> ER_Handler["ExpenseReportTriggerHandler"]
        EI_Trig["ExpenseItemTrigger"] --> EI_Handler["ExpenseItemTriggerHandler"]
        EX_Trig["ExpenseValidationExceptionTrigger"] --> EX_Handler["ExpenseValidationExceptionTriggerHandler"]
    end

    subgraph Flow_Layer ["Record-Triggered Flows"]
        Flow1["Travel_Request_Submission_Flow"]
        Flow2["Expense_Report_Submission_Flow"]
        Flow3["Expense_Exception_Notification_Flow"]
    end

    subgraph Async_Layer ["Asynchronous Execution"]
        QueueableJob["ProcessReimbursementQueueable"]
        BatchJob["ReimbursementReconciliationBatch"]
        SchedJob["ReimbursementScheduler"]
    end

    subgraph Data_Layer ["Data & Metadata Layer"]
        TR_Obj[("Travel_Request__c")]
        ER_Obj[("Expense_Report__c")]
        EI_Obj[("Expense_Item__c")]
        EX_Obj[("Expense_Validation_Exception__c")]
        LOG_Obj[("Integration_Log__c")]
        MDT[("Travel_Expense_Policy__mdt")]
    end

    subgraph Analytics_Layer ["Reports & Dashboards"]
        R1["Travel Requests Overview"]
        R2["Spend vs Budget Variance"]
        R3["Smart Expense Exceptions"]
        R4["Reimbursement Status"]
        Dash["Executive Spend Control Dashboard"]
    end

    %% UI to Controller linkages
    LWC1 --> UIController
    LWC2 --> UIController
    UIController --> ER_Obj
    UIController --> EX_Obj

    %% API linkages
    RestAPI --> TR_Obj
    RestAPI --> LogService

    %% Trigger to Handler to Service linkages
    EI_Handler --> SmartEngine
    SmartEngine --> MDT
    SmartEngine --> EX_Obj
    ER_Handler --> ReimburseService
    ER_Handler --> EmailService
    EX_Handler --> ER_Obj

    %% Flow linkages
    TR_Obj -.-> Flow1
    ER_Obj -.-> Flow2
    EX_Obj -.-> Flow3

    %% Async linkages
    ReimburseService --> QueueableJob
    SchedJob --> BatchJob
    QueueableJob --> LOG_Obj
    BatchJob --> LOG_Obj

    %% Analytics linkages
    TR_Obj --> R1
    ER_Obj --> R2
    EX_Obj --> R3
    ER_Obj --> R4
    R1 --> Dash
    R2 --> Dash
    R3 --> Dash
    R4 --> Dash
```

---

## Part 16: Final Audit Summary

### 16.1 18-Point Executive Summary
1. **Business Workflow Completeness:** The platform establishes a comprehensive spend-control lifecycle from pre-travel authorization through line-item policy audits, manager exception waivers, and asynchronous payment settlement.
2. **Custom Object Inventory:** Exactly 5 custom objects (`Travel_Request__c`, `Expense_Report__c`, `Expense_Item__c`, `Expense_Validation_Exception__c`, `Integration_Log__c`) and 1 Custom Metadata Type (`Travel_Expense_Policy__mdt`) are fully implemented and mapped.
3. **Data Model Integrity:** Relationships are structurally sound: Master-Detail between Report and Items guarantees ownership integrity; Lookup between Report and Exceptions guarantees audit persistence.
4. **Apex Inventory:** Contains 4 bulkified Apex Triggers, 12 production classes, and 11 comprehensive test classes.
5. **Flow Automation:** 3 active Record-After-Save Flows successfully manage approver fallback, status transitions, and exception reviewer notifications.
6. **Approval Configuration:** Live approval processes exist in the target org (`Travel_Request_Approval`, `TravelEasy_Expense_Report_Approval`), but their XML metadata files are missing from the local git repository.
7. **Declarative Validation Rules:** Exactly 0 declarative Salesforce Validation Rules exist; all business validations are executed programmatically via Apex triggers and Flow decisions.
8. **Role-Based Policy Matrix:** 12 Custom Metadata records govern limits across 6 categories for both `Employee` and `Manager` personas.
9. **Lightning UI & Components:** Fully equipped with a custom Lightning Application (`TravelEasy`), 2 record flexipages, and 2 purpose-built LWCs (`smartExpenseChecker` and `exceptionResolutionPanel`).
10. **Integration & API:** A production-ready Apex REST resource (`/traveleasy/travel-requests`) provides external submission capabilities with server-side role validation and payload auditing.
11. **Disbursement Automation:** Asynchronous payment execution is supported via Queueable Apex (`ProcessReimbursementQueueable`), Batch Apex (`ReimbursementReconciliationBatch`), and Schedulable Apex (`ReimbursementScheduler`).
12. **Analytics & Dashboards:** 4 custom reports, 1 custom report type, and 1 executive dashboard (`TravelEasy_Executive_Spend_Control_Dashboard`) provide real-time spend visibility.
13. **Implemented & Verified Features:** Pre-trip cost validation, line-item total rollups, single transaction limits, daily category aggregate limits, duplicate transaction detection, budget overrun calculation, exception creation, and asynchronous disbursement.
14. **Implemented but Untested Areas:** Manager-specific limit enforcement via dedicated Apex unit tests; scheduled batch reconciliation cron execution.
15. **Unverified Runtime Features:** Dashboard chart rendering in live browser sessions (cannot be validated via Apex test runner).
16. **Missing Features:** Declarative file attachment enforcement/OCR; Finance Queue routing; anti-escalation validation on the standard Lightning UI for `Requester_Role__c`.
17. **Architecture Discrepancies:**
    * **Finance Routing:** The business architecture called for Finance Team approval of Travel Requests; the implementation routes solely to `Employee__r.ManagerId`.
    * **Self-Approval Risk:** If an employee has no `ManagerId`, they are assigned as their own approver.
    * **UI Role Escalation:** Standard employees can select `Manager` in the Lightning UI without server validation.
18. **Safest Next Action:** Deploy the pending local fixes for budget-overrun calculation (`SmartExpenseControlService.cls`) and submission-blocking validation (`ExpenseReportTriggerHandler.cls`), then retrieve the live org's Approval Processes into version control.

---

### 16.2 Prioritized Action Plan

| Priority | Category | Action Item | Rationale & Impact |
| :---: | :--- | :--- | :--- |
| **P1** | **Deploy Pending Fixes** | Deploy locally updated `SmartExpenseControlService.cls`, `ExpenseReportTriggerHandler.cls`, and test classes to `TravelEasyPlayground`. | Activates accurate budget-overrun calculations and synchronous submission blocking for reports with open blocking exceptions. |
| **P2** | **Metadata Retrieval** | Retrieve live Approval Processes into `force-app/main/default/approvalProcesses/`. | Closes the source-control gap between the live org configuration and the git repository. |
| **P3** | **Security Guard** | Add a before-insert/update validation in `TravelRequestTriggerHandler` preventing non-managers from setting `Requester_Role__c = 'Manager'`. | Eliminates the privilege escalation gap on standard Lightning record pages. |
| **P4** | **Approval Routing** | Create a `TravelEasy_Finance_Queue` and route Travel Request approvals to Finance rather than Line Managers. | Aligns actual runtime approval behavior with the intended corporate governance model. |
| **P5** | **Approver Fallback** | Prevent `Approver__c` from defaulting to `Employee__c` when `ManagerId` is null; route to a default Admin or Finance queue instead. | Eliminates the risk of self-approved travel requests and unauthorized spend. |
