/**
 * @description Unit tests for ReimbursementReconciliationBatch and ReimbursementScheduler.
 */
@IsTest
private class ReimbursementBatchTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Batch',
            LastName = 'Tester',
            Email = 'batch.tester@traveleasy.test',
            Username = 'batch.tester.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'btester',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Goa',
            Purpose__c = 'Symposium',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 30000,
            Status__c = 'Approved'
        );
        insert tr;

        List<Expense_Report__c> reports = new List<Expense_Report__c>();
        for (Integer i = 0; i < 5; i++) {
            reports.add(new Expense_Report__c(
                Report_Name__c = 'Batch Reconciliation Report ' + i,
                Travel_Request__c = tr.Id,
                Employee__c = emp.Id,
                Status__c = 'Approved',
                Total_Amount__c = 1500,
                Reimbursement_Status__c = (Math.mod(i, 2) == 0) ? 'Pending' : 'Failed'
            ));
        }
        insert reports;
    }

    @IsTest
    static void testReconciliationBatchExecution() {
        Test.startTest();
        ReimbursementReconciliationBatch batch = new ReimbursementReconciliationBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<Expense_Report__c> reconciled = [
            SELECT Id, Status__c, Reimbursement_Status__c 
            FROM Expense_Report__c 
            WHERE Reimbursement_Status__c = 'Completed'
        ];
        System.assertEquals(5, reconciled.size(), 'All 5 reports should be reconciled to Completed');
    }

    @IsTest
    static void testReimbursementSchedulerExecution() {
        Test.startTest();
        String cronExpr = '0 0 0 1 1 ? 2030';
        String jobId = System.schedule('TestReimbursementScheduler', cronExpr, new ReimbursementScheduler());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should be returned from schedule execution.');
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExpr, ct.CronExpression, 'Cron expression must match');
    }
}
