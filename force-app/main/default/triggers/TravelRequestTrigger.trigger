/**
 * @description Single trigger for Travel_Request__c object delegating to TravelRequestTriggerHandler.
 */
trigger TravelRequestTrigger on Travel_Request__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            TravelRequestTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TravelRequestTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TravelRequestTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TravelRequestTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
