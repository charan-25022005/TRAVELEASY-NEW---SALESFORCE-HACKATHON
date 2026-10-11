/**
 * @description Unit tests for ExpenseReportTrigger and ExpenseReportTriggerHandler.
 */
@IsTest
private class ExpenseReportTriggerTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Expense',
            LastName = 'Employee',
            Email = 'exp.emp@traveleasy.test',
            Username = 'exp.emp.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'expe',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        Travel_Request__c draftTr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Kolkata',
            Purpose__c = 'Inspection',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 10000,
            Status__c = 'Draft'
        );
        insert draftTr;

        Travel_Request__c approvedTr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Pune',
            Purpose__c = 'Training',
            Travel_Start_Date__c = Date.today().addDays(10),
            Travel_End_Date__c = Date.today().addDays(12),
            Estimated_Cost__c = 15000,
            Status__c = 'Approved'
        );
        insert approvedTr;
    }

    @IsTest
    static void testBlockSubmissionOnUnapprovedTravelRequest() {
        Travel_Request__c draftTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Draft' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Unapproved Trip Report',
            Travel_Request__c = draftTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Submitted'
        );

        Boolean threwException = false;
        try {
            insert rep;
        } catch (DmlException e) {
            threwException = true;
            System.assert(e.getMessage().contains('associated Travel Request is not Approved'));
        }
        System.assert(threwException, 'Expected submission to fail for unapproved travel request.');
    }

    @IsTest
    static void testAllowSubmissionOnApprovedTravelRequest() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Approved Trip Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Submitted'
        );

        Test.startTest();
        insert rep;
        Test.stopTest();

        System.assertNotEquals(null, rep.Id, 'Expense Report should insert successfully for approved travel request.');
    }

    @IsTest
    static void testBlockApprovalWhenBlockingExceptionsExist() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Blocked Approval Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Under Review',
            Has_Blocking_Exceptions__c = true
        );
        insert rep;

        rep.Status__c = 'Approved';
        Boolean threwException = false;
        try {
            update rep;
        } catch (DmlException e) {
            threwException = true;
            System.assert(e.getMessage().contains('unresolved blocking policy exceptions exist'));
        }
        System.assert(threwException, 'Should prevent approval while blocking exceptions exist');
    }

    @IsTest
    static void testApprovalTriggersReimbursement() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Ready for Approval Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Under Review',
            Has_Blocking_Exceptions__c = false
        );
        insert rep;

        Test.startTest();
        rep.Status__c = 'Approved';
        update rep;
        Test.stopTest();

        rep = [SELECT Id, Status__c, Approval_Date__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertNotEquals(null, rep.Approval_Date__c, 'Approval date should be stamped');
    }

    @IsTest
    static void testRejectionReasonDefault() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Rejection Test Report',
            Travel_Request__c = appTr.Id,
            Status__c = 'Under Review'
        );
        insert rep;

        rep.Status__c = 'Rejected';
        update rep;

        rep = [SELECT Id, Rejection_Reason__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertNotEquals(null, rep.Rejection_Reason__c, 'Rejection reason should default when blank');
    }
}
