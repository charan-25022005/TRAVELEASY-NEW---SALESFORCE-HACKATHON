/**
 * @description Bulkified trigger handler for Expense_Report__c.
 *              Enforces travel request approval prerequisites, blocking exception guards,
 *              approval stamping, and triggers asynchronous reimbursement upon approval.
 */
public inherited sharing class ExpenseReportTriggerHandler {

    public static void handleBeforeInsert(List<Expense_Report__c> newReports) {
        validateTravelRequestApproval(newReports);
    }

    public static void handleBeforeUpdate(List<Expense_Report__c> newReports, Map<Id, Expense_Report__c> oldMap) {
        validateTravelRequestApproval(newReports);
        validateApprovalRequirements(newReports, oldMap);
    }

    public static void handleAfterInsert(List<Expense_Report__c> newReports) {
        // Post-insert hooks
    }

    public static void handleAfterUpdate(List<Expense_Report__c> newReports, Map<Id, Expense_Report__c> oldMap) {
        List<Id> approvedReportIds = new List<Id>();

        for (Expense_Report__c rep : newReports) {
            Expense_Report__c oldRep = oldMap.get(rep.Id);
            if (rep.Status__c == 'Approved' && oldRep.Status__c != 'Approved') {
                approvedReportIds.add(rep.Id);
            }
        }

        if (!approvedReportIds.isEmpty() && !System.isQueueable() && !System.isBatch()) {
            ReimbursementService.initiateReimbursement(approvedReportIds);
        }
    }

    private static void validateTravelRequestApproval(List<Expense_Report__c> reports) {
        Set<Id> trIds = new Set<Id>();
        for (Expense_Report__c rep : reports) {
            if (rep.Travel_Request__c != null && rep.Status__c != 'Draft') {
                trIds.add(rep.Travel_Request__c);
            }
        }

        if (trIds.isEmpty()) return;

        Map<Id, Travel_Request__c> trMap = new Map<Id, Travel_Request__c>([
            SELECT Id, Status__c, Estimated_Cost__c 
            FROM Travel_Request__c 
            WHERE Id IN :trIds
        ]);

        for (Expense_Report__c rep : reports) {
            if (rep.Travel_Request__c != null && rep.Status__c != 'Draft') {
                Travel_Request__c tr = trMap.get(rep.Travel_Request__c);
                if (tr != null && tr.Status__c != 'Approved') {
                    rep.addError('Cannot submit or process expense report because the associated Travel Request is not Approved (Current status: ' + tr.Status__c + ').');
                }
            }
        }
    }

    private static void validateApprovalRequirements(List<Expense_Report__c> reports, Map<Id, Expense_Report__c> oldMap) {
        for (Expense_Report__c rep : reports) {
            Expense_Report__c oldRep = oldMap.get(rep.Id);

            if (rep.Status__c == 'Approved' && oldRep.Status__c != 'Approved') {
                if (rep.Has_Blocking_Exceptions__c) {
                    rep.addError('Cannot approve expense report while unresolved blocking policy exceptions exist.');
                } else {
                    rep.Approval_Date__c = System.now();
                }
            }

            if (rep.Status__c == 'Rejected' && oldRep.Status__c != 'Rejected') {
                if (String.isBlank(rep.Rejection_Reason__c)) {
                    rep.Rejection_Reason__c = 'Rejected during manager review.';
                }
            }
        }
    }
}
