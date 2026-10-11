# TravelEasy — Security & Access Architecture

## 1. Profiles & Permission Sets
Following Salesforce best practices, baseline access is granted via Permission Sets aligned with least privilege:

1. **`TravelEasy_Employee`**:
   - Access to create/read own `Travel_Request__c` records.
   - Access to create/edit `Expense_Report__c` and `Expense_Item__c` in Draft/Submitted states.
   - Read access to own `Expense_Validation_Exception__c` records.
   - Read-only access to Reimbursement details.

2. **`TravelEasy_Manager`**:
   - All Employee permissions.
   - Edit/Approve access to assigned `Travel_Request__c` and `Expense_Report__c`.
   - Access to review, waive, or approve assigned `Expense_Validation_Exception__c`.
   - Access to manager reporting and spend dashboards.

3. **`TravelEasy_Finance_Admin`**:
   - Full read/edit/delete access on all TravelEasy objects.
   - Permissions to trigger/re-run Reimbursement jobs (`ProcessReimbursementQueueable`, `ReimbursementReconciliationBatch`).
   - Access to manage `Travel_Expense_Policy__mdt` records.
   - Access to `Integration_Log__c` records and executive analytics.

## 2. Server-Side Identity & Role Verification (Anti-Impersonation)
In the Travel Request REST API endpoint (`TravelRequestRestResource`), requester identification follows strict zero-trust rules:
1. The authenticated user context (`UserInfo.getUserId()`) is inspected.
2. The user-supplied `employeeId` and `jobRole` in the JSON body are cross-referenced with the user record's trusted profile, title, or configured employee directory.
3. If an employee enters `jobRole: "Manager"` while their trusted profile/title is non-manager, the system rejects the request with HTTP 403 Forbidden.
4. The assigned approver is determined strictly by the requester's `ManagerId` on the Salesforce `User` object, preventing requesters from choosing their own approver.

## 3. Data Protection & Secrets
- No hardcoded credentials or API tokens in Apex classes or Git commits.
- Named Credentials and External Credentials are used for external web service callouts.
- Integration logs sanitize all authorization headers and credentials.
