/**
 * @description Queueable Apex job for asynchronous payment disbursement processing.
 */
public inherited sharing class ProcessReimbursementQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> reportIds;

    public ProcessReimbursementQueueable(List<Id> reportIds) {
        this.reportIds = reportIds;
    }

    public void execute(System.QueueableContext qc) {
        if (reportIds == null || reportIds.isEmpty()) return;

        List<Expense_Report__c> reportsToProcess = [
            SELECT Id, Report_Name__c, Total_Amount__c, Employee__c, Status__c, 
                   Reimbursement_Status__c, Reimbursement_Reference__c
            FROM Expense_Report__c
            WHERE Id IN :reportIds
              AND Status__c = 'Approved'
              AND Reimbursement_Status__c != 'Completed'
        ];

        List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();

        for (Expense_Report__c report : reportsToProcess) {
            Boolean ok = ReimbursementService.processSingleReportReimbursement(report);
            reportsToUpdate.add(report);
        }

        if (!reportsToUpdate.isEmpty()) {
            Database.update(reportsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }
}
