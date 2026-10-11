/**
 * @description Single trigger for Expense_Item__c delegating to ExpenseItemTriggerHandler.
 */
trigger ExpenseItemTrigger on Expense_Item__c (before insert, before update, after insert, after update, after delete, after undelete) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ExpenseItemTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseItemTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ExpenseItemTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseItemTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            ExpenseItemTriggerHandler.handleAfterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            ExpenseItemTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}
