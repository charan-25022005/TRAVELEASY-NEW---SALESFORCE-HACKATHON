/**
 * @description Bulkified trigger handler for Expense_Validation_Exception__c.
 *              Enforces exception resolution audit tracking and performs reliable parent
 *              Expense_Report__c status synchronization across all sibling exceptions.
 */
public inherited sharing class ExpenseValidationExceptionTriggerHandler {

    public static Boolean bypass = false;

    private static final Set<String> RESOLVED_STATUSES = new Set<String>{'Resolved', 'Waived', 'Approved'};

    public static void handleBeforeInsert(List<Expense_Validation_Exception__c> newExceptions) {
        if (bypass) return;
        for (Expense_Validation_Exception__c exc : newExceptions) {
            if (exc.Severity__c == 'High' || exc.Severity__c == 'Critical') {
                exc.Is_Blocking__c = true;
            }
        }
    }

    public static void handleBeforeUpdate(List<Expense_Validation_Exception__c> newExceptions, Map<Id, Expense_Validation_Exception__c> oldMap) {
        if (bypass) return;
        for (Expense_Validation_Exception__c exc : newExceptions) {
            Expense_Validation_Exception__c oldExc = oldMap.get(exc.Id);

            // Recompute Is_Blocking__c
            if (exc.Severity__c == 'High' || exc.Severity__c == 'Critical') {
                exc.Is_Blocking__c = !RESOLVED_STATUSES.contains(exc.Status__c);
            } else {
                exc.Is_Blocking__c = false;
            }

            // Transitioning to a resolved state
            if (RESOLVED_STATUSES.contains(exc.Status__c) && !RESOLVED_STATUSES.contains(oldExc.Status__c)) {
                if (exc.Reviewer__c == null) {
                    exc.Reviewer__c = UserInfo.getUserId();
                }
                exc.Resolved_Date__c = System.now();
                if (String.isBlank(exc.Resolution_Comments__c)) {
                    exc.Resolution_Comments__c = 'Resolution confirmed by reviewer.';
                }
            }

            // Reopening an exception
            if (!RESOLVED_STATUSES.contains(exc.Status__c) && RESOLVED_STATUSES.contains(oldExc.Status__c)) {
                exc.Resolved_Date__c = null;
            }
        }
    }

    public static void handleAfterInsert(List<Expense_Validation_Exception__c> newExceptions) {
        if (bypass) return;
        synchronizeParentReportStatus(getParentReportIds(newExceptions));
    }

    public static void handleAfterUpdate(List<Expense_Validation_Exception__c> newExceptions, Map<Id, Expense_Validation_Exception__c> oldMap) {
        if (bypass) return;
        synchronizeParentReportStatus(getParentReportIds(newExceptions));
    }

    public static void handleAfterDelete(List<Expense_Validation_Exception__c> oldExceptions) {
        if (bypass) return;
        synchronizeParentReportStatus(getParentReportIds(oldExceptions));
    }

    public static void handleAfterUndelete(List<Expense_Validation_Exception__c> newExceptions) {
        if (bypass) return;
        synchronizeParentReportStatus(getParentReportIds(newExceptions));
    }

    private static Set<Id> getParentReportIds(List<Expense_Validation_Exception__c> exceptions) {
        Set<Id> ids = new Set<Id>();
        for (Expense_Validation_Exception__c exc : exceptions) {
            if (exc.Expense_Report__c != null) {
                ids.add(exc.Expense_Report__c);
            }
        }
        return ids;
    }

    /**
     * @description Synchronizes Has_Blocking_Exceptions__c and Status__c on parent reports
     *              based on ALL associated sibling exceptions.
     */
    public static void synchronizeParentReportStatus(Set<Id> parentReportIds) {
        if (parentReportIds == null || parentReportIds.isEmpty()) return;

        // Query all exceptions under the affected reports
        Map<Id, List<Expense_Validation_Exception__c>> reportToExceptions = new Map<Id, List<Expense_Validation_Exception__c>>();
        for (Id rId : parentReportIds) {
            reportToExceptions.put(rId, new List<Expense_Validation_Exception__c>());
        }

        for (Expense_Validation_Exception__c exc : [
            SELECT Id, Expense_Report__c, Severity__c, Status__c, Is_Blocking__c
            FROM Expense_Validation_Exception__c
            WHERE Expense_Report__c IN :parentReportIds
        ]) {
            reportToExceptions.get(exc.Expense_Report__c).add(exc);
        }

        Map<Id, Expense_Report__c> currentReports = new Map<Id, Expense_Report__c>([
            SELECT Id, Status__c, Has_Blocking_Exceptions__c
            FROM Expense_Report__c
            WHERE Id IN :parentReportIds
        ]);

        List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();

        for (Id rId : parentReportIds) {
            Expense_Report__c report = currentReports.get(rId);
            if (report == null) continue;

            List<Expense_Validation_Exception__c> allExceptions = reportToExceptions.get(rId);
            Boolean hasOpenBlocking = false;

            for (Expense_Validation_Exception__c exc : allExceptions) {
                Boolean isBlocking = exc.Is_Blocking__c || (exc.Severity__c == 'High' || exc.Severity__c == 'Critical');
                Boolean isOpen = !RESOLVED_STATUSES.contains(exc.Status__c);
                if (isBlocking && isOpen) {
                    hasOpenBlocking = true;
                    break;
                }
            }

            Boolean needsUpdate = false;
            Expense_Report__c repUpdate = new Expense_Report__c(Id = rId);

            if (hasOpenBlocking) {
                if (!report.Has_Blocking_Exceptions__c) {
                    repUpdate.Has_Blocking_Exceptions__c = true;
                    needsUpdate = true;
                }
                if (report.Status__c != 'Exception Flagged' && report.Status__c != 'Draft' && report.Status__c != 'Rejected') {
                    repUpdate.Status__c = 'Exception Flagged';
                    needsUpdate = true;
                }
            } else {
                if (report.Has_Blocking_Exceptions__c) {
                    repUpdate.Has_Blocking_Exceptions__c = false;
                    needsUpdate = true;
                }
                if (report.Status__c == 'Exception Flagged') {
                    repUpdate.Status__c = 'Under Review';
                    needsUpdate = true;
                }
            }

            if (needsUpdate) {
                reportsToUpdate.add(repUpdate);
            }
        }

        if (!reportsToUpdate.isEmpty()) {
            Database.update(reportsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }
}
