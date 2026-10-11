/**
 * @description Single trigger for Expense_Report__c delegating to ExpenseReportTriggerHandler.
 */
trigger ExpenseReportTrigger on Expense_Report__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ExpenseReportTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseReportTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ExpenseReportTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseReportTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
