/**
 * @description Bulkified trigger handler for Expense_Report__c.
 *              Enforces travel request approval prerequisites, blocking exception guards,
 *              approval stamping, and triggers asynchronous reimbursement upon approval.
 */
public inherited sharing class ExpenseReportTriggerHandler {

    public static Boolean bypass = false;

    public static void handleBeforeInsert(List<Expense_Report__c> newReports) {
        if (bypass) return;
        validateTravelRequestApproval(newReports);
        handleSubmissionTransitions(newReports, null);
    }

    public static void handleBeforeUpdate(List<Expense_Report__c> newReports, Map<Id, Expense_Report__c> oldMap) {
        if (bypass) return;
        validateTravelRequestApproval(newReports);
        validateSubmissionRequirements(newReports, oldMap);
        validateApprovalRequirements(newReports, oldMap);
        handleSubmissionTransitions(newReports, oldMap);
    }

    public static void handleAfterInsert(List<Expense_Report__c> newReports) {
        if (bypass) return;
        // Post-insert hooks
    }

    public static void handleAfterUpdate(List<Expense_Report__c> newReports, Map<Id, Expense_Report__c> oldMap) {
        if (bypass) return;
        List<Id> approvedReportIds = new List<Id>();
        List<Id> decisionReportIds = new List<Id>();
        List<Id> completedReimbursementIds = new List<Id>();
        List<Id> failedReimbursementIds = new List<Id>();

        for (Expense_Report__c rep : newReports) {
            Expense_Report__c oldRep = oldMap.get(rep.Id);
            if ((rep.Status__c == 'Approved' && oldRep.Status__c != 'Approved') ||
                (rep.Status__c == 'Rejected' && oldRep.Status__c != 'Rejected')) {
                decisionReportIds.add(rep.Id);
            }
            if (rep.Status__c == 'Approved' && oldRep.Status__c != 'Approved') {
                approvedReportIds.add(rep.Id);
            }
            // Reimbursement outcome emails - sent ONLY upon confirmed status transition
            if (rep.Reimbursement_Status__c == 'Completed' && oldRep.Reimbursement_Status__c != 'Completed') {
                completedReimbursementIds.add(rep.Id);
            } else if (rep.Reimbursement_Status__c == 'Failed' && oldRep.Reimbursement_Status__c != 'Failed') {
                failedReimbursementIds.add(rep.Id);
            }
        }

        if (!decisionReportIds.isEmpty()) {
            TravelEasyEmailNotificationService.sendExpenseReportDecisionEmail(decisionReportIds);
        }

        if (!completedReimbursementIds.isEmpty()) {
            TravelEasyEmailNotificationService.sendReimbursementOutcomeEmail(completedReimbursementIds, true, null);
        }

        if (!failedReimbursementIds.isEmpty()) {
            TravelEasyEmailNotificationService.sendReimbursementOutcomeEmail(failedReimbursementIds, false, 'Payment processing failed or rejected during settlement.');
        }

        if (!approvedReportIds.isEmpty() && !System.isQueueable() && !System.isBatch()) {
            ReimbursementService.initiateReimbursement(approvedReportIds);
        }
    }

    private static void validateTravelRequestApproval(List<Expense_Report__c> reports) {
        Set<Id> trIds = new Set<Id>();
        for (Expense_Report__c rep : reports) {
            if (rep.Travel_Request__c != null && rep.Status__c != 'Draft' && rep.Status__c != 'Exception Flagged') {
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
            if (rep.Travel_Request__c != null && rep.Status__c != 'Draft' && rep.Status__c != 'Exception Flagged') {
                Travel_Request__c tr = trMap.get(rep.Travel_Request__c);
                if (tr != null && tr.Status__c != 'Approved') {
                    rep.addError('Cannot submit or process expense report because the associated Travel Request is not Approved (Current status: ' + tr.Status__c + ').');
                }
            }
        }
    }

    private static void validateSubmissionRequirements(List<Expense_Report__c> reports, Map<Id, Expense_Report__c> oldMap) {
        for (Expense_Report__c rep : reports) {
            Expense_Report__c oldRep = oldMap != null ? oldMap.get(rep.Id) : null;

            if (rep.Has_Blocking_Exceptions__c) {
                Boolean isSubmissionAttempt = (rep.Status__c == 'Submitted');
                Boolean isUnderReviewTransition = (rep.Status__c == 'Under Review' && (oldRep == null || oldRep.Status__c != 'Under Review'));

                if (isSubmissionAttempt || isUnderReviewTransition) {
                    rep.addError('Cannot submit expense report while unresolved blocking policy exceptions exist. Please resolve all High and Critical exceptions first.');
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

    private static void handleSubmissionTransitions(List<Expense_Report__c> reports, Map<Id, Expense_Report__c> oldMap) {
        for (Expense_Report__c rep : reports) {
            Expense_Report__c oldRep = oldMap != null ? oldMap.get(rep.Id) : null;

            if (rep.Status__c == 'Submitted' && (oldRep == null || oldRep.Status__c != 'Submitted')) {
                if (rep.Submission_Date__c == null) {
                    rep.Submission_Date__c = Date.today();
                }
                if (!rep.Has_Blocking_Exceptions__c) {
                    rep.Status__c = 'Under Review';
                }
            }
        }
    }
}
