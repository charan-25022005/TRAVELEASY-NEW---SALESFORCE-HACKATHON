/**
 * @description Bulkified trigger handler for Expense_Item__c.
 *              Maintains parent report Total_Amount__c and triggers SmartExpenseControlService evaluation.
 */
public inherited sharing class ExpenseItemTriggerHandler {

    public static Boolean bypass = false;

    public static void handleBeforeInsert(List<Expense_Item__c> newItems) {
        if (bypass) return;
        // Pre-insert checks
    }

    public static void handleBeforeUpdate(List<Expense_Item__c> newItems, Map<Id, Expense_Item__c> oldMap) {
        if (bypass) return;
        // Pre-update checks
    }

    public static void handleAfterInsert(List<Expense_Item__c> newItems) {
        if (bypass) return;
        recalculateParentTotals(newItems);
        runPolicyEvaluation(newItems);
    }

    public static void handleAfterUpdate(List<Expense_Item__c> newItems, Map<Id, Expense_Item__c> oldMap) {
        if (bypass) return;
        recalculateParentTotals(newItems);
        runPolicyEvaluation(newItems);
    }

    public static void handleAfterDelete(List<Expense_Item__c> oldItems) {
        if (bypass) return;
        recalculateParentTotals(oldItems);
    }

    public static void handleAfterUndelete(List<Expense_Item__c> newItems) {
        if (bypass) return;
        recalculateParentTotals(newItems);
        runPolicyEvaluation(newItems);
    }

    private static void recalculateParentTotals(List<Expense_Item__c> items) {
        Set<Id> reportIds = new Set<Id>();
        for (Expense_Item__c item : items) {
            if (item.Expense_Report__c != null) {
                reportIds.add(item.Expense_Report__c);
            }
        }

        if (reportIds.isEmpty()) return;

        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (Id rId : reportIds) {
            totals.put(rId, 0);
        }

        for (AggregateResult ar : [
            SELECT Expense_Report__c repId, SUM(Amount__c) sumAmt
            FROM Expense_Item__c
            WHERE Expense_Report__c IN :reportIds
            GROUP BY Expense_Report__c
        ]) {
            totals.put((Id)ar.get('repId'), (Decimal)ar.get('sumAmt'));
        }

        List<Expense_Report__c> reportsToUpdate = new List<Expense_Report__c>();
        for (Id rId : reportIds) {
            reportsToUpdate.add(new Expense_Report__c(
                Id = rId,
                Total_Amount__c = totals.get(rId)
            ));
        }

        if (!reportsToUpdate.isEmpty()) {
            Database.update(reportsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void runPolicyEvaluation(List<Expense_Item__c> items) {
        SmartExpenseControlService.EvaluationResult evalResult = SmartExpenseControlService.evaluateExpenseItems(items);

        if (!evalResult.exceptions.isEmpty()) {
            Database.insert(evalResult.exceptions, false, AccessLevel.SYSTEM_MODE);
        }

        if (!evalResult.flaggedItems.isEmpty()) {
            // Update items with flag details if needed
        }

        if (evalResult.hasBlockingExceptions) {
            Set<Id> reportIdsToFlag = new Set<Id>();
            for (Expense_Validation_Exception__c exc : evalResult.exceptions) {
                if (exc.Is_Blocking__c && exc.Expense_Report__c != null) {
                    reportIdsToFlag.add(exc.Expense_Report__c);
                }
            }

            if (!reportIdsToFlag.isEmpty()) {
                List<Expense_Report__c> reportsToFlag = new List<Expense_Report__c>();
                for (Id repId : reportIdsToFlag) {
                    reportsToFlag.add(new Expense_Report__c(
                        Id = repId,
                        Has_Blocking_Exceptions__c = true,
                        Status__c = 'Exception Flagged'
                    ));
                }
                Database.update(reportsToFlag, false, AccessLevel.SYSTEM_MODE);
            }
        }
    }
}
