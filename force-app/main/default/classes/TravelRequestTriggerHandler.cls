/**
 * @description Bulkified trigger handler for Travel_Request__c lifecycle and approval state machine.
 */
public inherited sharing class TravelRequestTriggerHandler {

    public static void handleBeforeInsert(List<Travel_Request__c> newRecords) {
        assignDefaultApprovers(newRecords);
        validateDatesAndCost(newRecords);
    }

    public static void handleBeforeUpdate(List<Travel_Request__c> newRecords, Map<Id, Travel_Request__c> oldMap) {
        validateDatesAndCost(newRecords);
        handleApprovalStateTransitions(newRecords, oldMap);
    }

    public static void handleAfterInsert(List<Travel_Request__c> newRecords) {
        // Post-insert orchestration hook if needed
    }

    public static void handleAfterUpdate(List<Travel_Request__c> newRecords, Map<Id, Travel_Request__c> oldMap) {
        List<Id> decisionTrIds = new List<Id>();
        for (Travel_Request__c tr : newRecords) {
            Travel_Request__c oldTr = oldMap.get(tr.Id);
            if ((tr.Status__c == 'Approved' && oldTr.Status__c != 'Approved') ||
                (tr.Status__c == 'Rejected' && oldTr.Status__c != 'Rejected')) {
                decisionTrIds.add(tr.Id);
            }
        }
        if (!decisionTrIds.isEmpty()) {
            TravelEasyEmailNotificationService.sendTravelRequestDecisionEmail(decisionTrIds);
        }
    }

    private static void assignDefaultApprovers(List<Travel_Request__c> records) {
        Set<Id> employeeIds = new Set<Id>();
        for (Travel_Request__c tr : records) {
            if (tr.Employee__c != null && tr.Approver__c == null) {
                employeeIds.add(tr.Employee__c);
            }
        }

        if (employeeIds.isEmpty()) return;

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, ManagerId 
            FROM User 
            WHERE Id IN :employeeIds
        ]);

        for (Travel_Request__c tr : records) {
            if (tr.Approver__c == null && tr.Employee__c != null && userMap.containsKey(tr.Employee__c)) {
                User emp = userMap.get(tr.Employee__c);
                tr.Approver__c = emp.ManagerId != null ? emp.ManagerId : tr.Employee__c;
            }
        }
    }

    private static void validateDatesAndCost(List<Travel_Request__c> records) {
        for (Travel_Request__c tr : records) {
            if (tr.Travel_Start_Date__c != null && tr.Travel_End_Date__c != null) {
                if (tr.Travel_End_Date__c < tr.Travel_Start_Date__c) {
                    tr.Travel_End_Date__c.addError('Travel End Date cannot be earlier than Travel Start Date.');
                }
            }
            if (tr.Estimated_Cost__c != null && tr.Estimated_Cost__c <= 0) {
                tr.Estimated_Cost__c.addError('Estimated Cost must be greater than zero.');
            }
        }
    }

    private static void handleApprovalStateTransitions(List<Travel_Request__c> records, Map<Id, Travel_Request__c> oldMap) {
        for (Travel_Request__c tr : records) {
            Travel_Request__c oldTr = oldMap.get(tr.Id);

            // Stamping approval date on approval
            if (tr.Status__c == 'Approved' && oldTr.Status__c != 'Approved') {
                tr.Approval_Date__c = System.now();
            }

            // If rejected, ensure rejection reason is captured
            if (tr.Status__c == 'Rejected' && oldTr.Status__c != 'Rejected') {
                if (String.isBlank(tr.Rejection_Reason__c)) {
                    tr.Rejection_Reason__c = 'Rejected by reviewer without specific notes.';
                }
            }
        }
    }
}
