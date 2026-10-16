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

    @IsTest
    static void testBlockSubmissionWhenBlockingExceptionsExist() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Exception Flagged Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Exception Flagged',
            Has_Blocking_Exceptions__c = true
        );
        insert rep;

        // Attempt transition to Submitted while Has_Blocking_Exceptions__c is true
        rep.Status__c = 'Submitted';
        Boolean threwException = false;
        try {
            update rep;
        } catch (DmlException e) {
            threwException = true;
            System.assert(
                e.getMessage().contains('Cannot submit expense report while unresolved blocking policy exceptions exist'),
                'Expected blocking submission error message, got: ' + e.getMessage()
            );
        }
        System.assert(threwException, 'Should prevent transitioning to Submitted while blocking exceptions exist');
    }

    @IsTest
    static void testBlockTransitionToUnderReviewWhenBlockingExceptionsExist() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Exception Flagged Report 2',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Exception Flagged',
            Has_Blocking_Exceptions__c = true
        );
        insert rep;

        // Attempt transition to Under Review while Has_Blocking_Exceptions__c is true
        rep.Status__c = 'Under Review';
        Boolean threwException = false;
        try {
            update rep;
        } catch (DmlException e) {
            threwException = true;
            System.assert(
                e.getMessage().contains('Cannot submit expense report while unresolved blocking policy exceptions exist'),
                'Expected blocking submission error message, got: ' + e.getMessage()
            );
        }
        System.assert(threwException, 'Should prevent transitioning to Under Review while blocking exceptions exist');
    }

    @IsTest
    static void testAllowSubmissionWhenBlockingExceptionsCleared() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        // Create an Expense Report with Exception Flagged and blocking exceptions cleared (false)
        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Cleared Exceptions Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Exception Flagged',
            Has_Blocking_Exceptions__c = false
        );
        insert rep;

        Test.startTest();
        // Update status to Submitted
        rep.Status__c = 'Submitted';
        update rep;
        Test.stopTest();

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(false, rep.Has_Blocking_Exceptions__c, 'Blocking exceptions flag should remain false');
        System.assertEquals('Under Review', rep.Status__c, 'Submission Flow should route report to Under Review when blocking exceptions are cleared');
    }

    @IsTest
    static void testAutomaticTransitionFromDraftToUnderReviewOnSubmission() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        // 1. Create Draft Expense Report linked to Approved Travel Request
        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Draft to Under Review Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Draft',
            Has_Blocking_Exceptions__c = false
        );
        insert rep;

        rep = [SELECT Id, Status__c, Submission_Date__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals('Draft', rep.Status__c, 'Report should initially be in Draft status');
        System.assertEquals(null, rep.Submission_Date__c, 'Submission Date should initially be null');

        // 2. Perform submission transition (Status = Submitted)
        Test.startTest();
        rep.Status__c = 'Submitted';
        update rep;
        Test.stopTest();

        // 3. Verify automatic transition to Under Review and stamped submission date
        rep = [SELECT Id, Status__c, Submission_Date__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals('Under Review', rep.Status__c, 'Report should automatically transition to Under Review upon submission');
        System.assertEquals(Date.today(), rep.Submission_Date__c, 'Submission Date should be stamped upon submission');
        System.assertEquals(false, rep.Has_Blocking_Exceptions__c, 'Blocking exceptions flag should remain false');
    }

    @IsTest
    static void testBlockSubmissionFromDraftWhenUnapprovedTravelRequest() {
        Travel_Request__c draftTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Draft' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Draft Unapproved TR Report',
            Travel_Request__c = draftTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Draft',
            Has_Blocking_Exceptions__c = false
        );
        insert rep;

        rep.Status__c = 'Submitted';
        Boolean threwException = false;
        try {
            update rep;
        } catch (DmlException e) {
            threwException = true;
            System.assert(e.getMessage().contains('associated Travel Request is not Approved'));
        }
        System.assert(threwException, 'Should block submission from Draft when linked Travel Request is not Approved');
    }

    @IsTest
    static void testBlockSubmissionFromDraftWhenBlockingExceptionsExist() {
        Travel_Request__c appTr = [SELECT Id FROM Travel_Request__c WHERE Status__c = 'Approved' LIMIT 1];
        User emp = [SELECT Id FROM User WHERE Email = 'exp.emp@traveleasy.test' LIMIT 1];

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Draft Blocking Exceptions Report',
            Travel_Request__c = appTr.Id,
            Employee__c = emp.Id,
            Status__c = 'Draft',
            Has_Blocking_Exceptions__c = true
        );
        insert rep;

        rep.Status__c = 'Submitted';
        Boolean threwException = false;
        try {
            update rep;
        } catch (DmlException e) {
            threwException = true;
            System.assert(e.getMessage().contains('Cannot submit expense report while unresolved blocking policy exceptions exist'));
        }
        System.assert(threwException, 'Should block submission from Draft when blocking exceptions exist');
    }
}
