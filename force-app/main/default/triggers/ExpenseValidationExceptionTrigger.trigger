/**
 * @description Single trigger for Expense_Validation_Exception__c delegating to ExpenseValidationExceptionTriggerHandler.
 */
trigger ExpenseValidationExceptionTrigger on Expense_Validation_Exception__c (before insert, before update, after insert, after update, after delete, after undelete) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ExpenseValidationExceptionTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseValidationExceptionTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ExpenseValidationExceptionTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseValidationExceptionTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            ExpenseValidationExceptionTriggerHandler.handleAfterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            ExpenseValidationExceptionTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}
