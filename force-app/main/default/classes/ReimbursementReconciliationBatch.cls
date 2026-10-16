/**
 * @description Batch Apex job for reconciling pending or failed expense reimbursements.
 */
public inherited sharing class ReimbursementReconciliationBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    public Integer totalProcessed = 0;
    public Integer totalSuccess = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Report_Name__c, Total_Amount__c, Employee__c, Status__c, 
                   Reimbursement_Status__c, Reimbursement_Reference__c
            FROM Expense_Report__c
            WHERE Status__c = 'Approved'
              AND (Reimbursement_Status__c = 'Pending' OR Reimbursement_Status__c = 'Failed')
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Expense_Report__c> scope) {
        List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();

        for (Expense_Report__c rep : scope) {
            totalProcessed++;
            Boolean success = ReimbursementService.processSingleReportReimbursement(rep);
            if (success) {
                totalSuccess++;
            }
            reportsToUpdate.add(rep);
        }

        if (!reportsToUpdate.isEmpty()) {
            Database.update(reportsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    public void finish(Database.BatchableContext bc) {
        IntegrationLogService.log(
            'Batch_Reconciliation_Job',
            'Apex:ReimbursementReconciliationBatch',
            'BATCH-' + bc.getJobId(),
            null,
            'Success',
            'Total processed: ' + totalProcessed,
            'Total successful: ' + totalSuccess,
            null,
            0
        );
    }
}
