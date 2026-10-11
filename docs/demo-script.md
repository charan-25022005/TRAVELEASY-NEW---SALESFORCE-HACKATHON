# TravelEasy — 2027 NPN Catalyst Hackathon Live Demo Script

**Total Demo Duration:** 20 Minutes (followed by 25 min Q&A and 15 min deliberation)

---

### Step 1: Employee Travel Request Submission (Postman / REST API) [00:00 - 03:00]
- **Story:** Employee submits an upcoming travel request to Bengaluru for an architectural workshop.
- **Action:** Open Postman, show endpoint `/services/apexrest/traveleasy/travel-requests`.
- **Payload:** Send valid JSON body with `jobRole: "Employee"` and estimated cost `₹15,000`.
- **Expected Outcome:** HTTP 201 Created. Show returned `travelRequestId` and assigned manager approver.
- **Bonus Security Demonstration:** Show submitting with `jobRole: "Manager"` under an employee session -> Demonstrates server-side anti-impersonation guard yielding HTTP 403 Forbidden!

### Step 2: Manager Reviews & Approves Travel Request [03:00 - 05:00]
- **Story:** Manager receives automated notification via `Travel_Request_Submission_Flow`.
- **Action:** In Salesforce Lightning UI, switch to Manager view. Open the travel request record.
- **Expected Outcome:** Approve the request. Status transitions from `Submitted` -> `Approved`.

### Step 3: Expense Report & Expense Items Submission [05:00 - 08:00]
- **Story:** Employee returns from the trip and logs expenses under the approved Travel Request.
- **Action:** Create `Expense_Report__c` and enter items across different categories:
  1. *Hotel & Lodging:* ₹8,000 (Compliant, receipt attached)
  2. *Meals & Food:* ₹2,500 (Compliant, receipt attached)
  3. *Client Entertainment:* ₹12,000 without receipt (Exceeds single limit & missing mandatory receipt)
  4. *Airfare:* ₹7,000 (Triggers cumulative travel budget overrun against original ₹15,000 estimate)
- **Expected Outcome:** Submitting the report triggers `SmartExpenseControlService`.

### Step 4: Smart Expense Control Engine in Action [08:00 - 12:00]
- **Story:** System identifies multiple policy violations and flags the report.
- **Action:** Show the parent `Expense_Report__c` record:
  - Status automatically becomes `Exception Flagged`.
  - `Has_Blocking_Exceptions__c` checkbox is checked.
  - Related list shows generated `Expense_Validation_Exception__c` records:
    - *Policy Violation (High Severity)* on Client Entertainment.
    - *Missing Receipt (Medium Severity)* on Client Entertainment.
    - *Budget Overrun (Critical Severity)* because total expenses exceed ₹15,000 budget.
  - Show automated alert dispatched by `Expense_Exception_Notification_Flow`.

### Step 5: Exception Review & Status Synchronization [12:00 - 14:00]
- **Story:** Finance Manager inspects the exceptions in the Lightning UI.
- **Action:**
  - Manager reviews Client Entertainment exception, accepts vendor justification, and marks it `Waived` with comments.
  - Reviewer resolves the Missing Receipt exception upon uploading invoice proof.
  - Manager approves budget overrun exception after adjusting client billable allocation.
- **Expected Outcome:** Real-time trigger handler synchronizes parent status: `Has_Blocking_Exceptions__c` unchecks, and `Expense_Report__c` status updates to `Under Review` / cleared for approval.

### Step 6: Expense Approval & Automated Reimbursement [14:00 - 17:00]
- **Story:** Cleared expense report is approved by Manager.
- **Action:** Manager clicks Approve.
- **Expected Outcome:**
  - Trigger launches `ProcessReimbursementQueueable`.
  - Payment gateway simulation executes.
  - Status updates to `Reimbursed`.
  - `Integration_Log__c` record created with timestamp, reference transaction number, and payload.

### Step 7: Executive Spend & Control Dashboard [17:00 - 20:00]
- **Story:** Executive leadership and Finance review spend metrics.
- **Action:** Navigate to **TravelEasy Executive Spend & Control Dashboard**.
- **Demonstration:**
  - *Spend vs Budget Variance* chart.
  - *Exception Severity Breakdown* (Critical/High/Medium/Low).
  - *Category Spend Distribution* (Airfare, Hotel, Meals, etc.).
  - *Reimbursement Turnaround Cycle Time*.
