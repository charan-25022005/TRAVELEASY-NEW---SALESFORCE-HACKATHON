/**
 * @description Unit tests for ReimbursementService and ProcessReimbursementQueueable.
 */
@IsTest
private class ReimbursementServiceTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Reimb',
            LastName = 'Tester',
            Email = 'reimb.tester@traveleasy.test',
            Username = 'reimb.tester.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'rtester',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Ahmedabad',
            Purpose__c = 'Review',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 12000,
            Status__c = 'Approved'
        );
        insert tr;

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Reimbursement Approved Report',
            Travel_Request__c = tr.Id,
            Employee__c = emp.Id,
            Status__c = 'Approved',
            Total_Amount__c = 8500,
            Reimbursement_Status__c = 'Pending'
        );
        insert rep;
    }

    @IsTest
    static void testQueueableReimbursementProcessing() {
        Expense_Report__c rep = [SELECT Id, Status__c, Reimbursement_Status__c FROM Expense_Report__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new ProcessReimbursementQueueable(new List<Id>{ rep.Id }));
        Test.stopTest();

        rep = [SELECT Id, Status__c, Reimbursement_Status__c, Reimbursement_Reference__c, Reimbursement_Date__c 
               FROM Expense_Report__c 
               WHERE Id = :rep.Id];

        System.assertEquals('Completed', rep.Reimbursement_Status__c, 'Reimbursement status should be Completed');
        System.assertEquals('Reimbursed', rep.Status__c, 'Report status should be Reimbursed');
        System.assertNotEquals(null, rep.Reimbursement_Reference__c, 'Reference transaction ID must be stamped');
        System.assertNotEquals(null, rep.Reimbursement_Date__c, 'Reimbursement Date must be recorded');

        // Verify Integration Log
        List<Integration_Log__c> logs = [SELECT Id, Operation__c, Status__c, Reference_Id__c FROM Integration_Log__c];
        System.assert(!logs.isEmpty(), 'Integration Log audit record must be generated');
        System.assertEquals('Success', logs[0].Status__c, 'Log status should be Success');
    }
}
