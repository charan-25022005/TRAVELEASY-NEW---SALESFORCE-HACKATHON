/**
 * @description Schedulable class to run ReimbursementReconciliationBatch on a recurring schedule.
 */
public inherited sharing class ReimbursementScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        ReimbursementReconciliationBatch batch = new ReimbursementReconciliationBatch();
        Database.executeBatch(batch, 50);
    }
}
