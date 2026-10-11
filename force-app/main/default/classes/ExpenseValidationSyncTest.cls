/**
 * @description Thorough unit tests verifying parent Expense_Report__c status synchronization:
 *              Exception creation, multiple simultaneous exceptions, partial resolution,
 *              full resolution, reopening an exception, deletion, and bulk handling.
 */
@IsTest
private class ExpenseValidationSyncTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Sync',
            LastName = 'Employee',
            Email = 'sync.emp@traveleasy.test',
            Username = 'sync.emp.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'synce',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Kochi',
            Purpose__c = 'Client Review',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 20000,
            Status__c = 'Approved'
        );
        insert tr;

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Kochi Client Review Expenses',
            Travel_Request__c = tr.Id,
            Employee__c = emp.Id,
            Status__c = 'Submitted'
        );
        insert rep;
    }

    @IsTest
    static void testSingleBlockingExceptionLifecycle() {
        Expense_Report__c rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c LIMIT 1];

        // 1. Create a High severity blocking exception
        Expense_Validation_Exception__c exc = new Expense_Validation_Exception__c(
            Expense_Report__c = rep.Id,
            Exception_Type__c = 'Policy Violation',
            Severity__c = 'High',
            Details__c = 'Single limit exceeded',
            Status__c = 'Open'
        );
        insert exc;

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(true, rep.Has_Blocking_Exceptions__c, 'Parent report should have blocking flag set');
        System.assertEquals('Exception Flagged', rep.Status__c, 'Parent report status should become Exception Flagged');

        // 2. Resolve the exception
        exc.Status__c = 'Resolved';
        exc.Resolution_Comments__c = 'Approved by manager';
        update exc;

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(false, rep.Has_Blocking_Exceptions__c, 'Parent report should be unblocked');
        System.assertEquals('Under Review', rep.Status__c, 'Status should transition to Under Review');

        // 3. Reopen the exception
        exc.Status__c = 'Open';
        update exc;

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(true, rep.Has_Blocking_Exceptions__c, 'Reopening exception must re-flag parent report');
        System.assertEquals('Exception Flagged', rep.Status__c, 'Status should return to Exception Flagged');
    }

    @IsTest
    static void testMultipleExceptionsPartialResolution() {
        Expense_Report__c rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c LIMIT 1];

        Expense_Validation_Exception__c exc1 = new Expense_Validation_Exception__c(
            Expense_Report__c = rep.Id,
            Exception_Type__c = 'Policy Violation',
            Severity__c = 'High',
            Details__c = 'Violation 1',
            Status__c = 'Open'
        );
        Expense_Validation_Exception__c exc2 = new Expense_Validation_Exception__c(
            Expense_Report__c = rep.Id,
            Exception_Type__c = 'Budget Overrun',
            Severity__c = 'Critical',
            Details__c = 'Violation 2',
            Status__c = 'Open'
        );
        insert new List<Expense_Validation_Exception__c>{ exc1, exc2 };

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(true, rep.Has_Blocking_Exceptions__c);

        // Resolve ONLY exc1; exc2 is still Open!
        exc1.Status__c = 'Waived';
        update exc1;

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(true, rep.Has_Blocking_Exceptions__c, 'Parent must remain flagged while exc2 is still open');

        // Now resolve exc2
        exc2.Status__c = 'Resolved';
        update exc2;

        rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(false, rep.Has_Blocking_Exceptions__c, 'Parent should clear only when all blocking exceptions are resolved');
        System.assertEquals('Under Review', rep.Status__c);
    }

    @IsTest
    static void testExceptionDeletionSync() {
        Expense_Report__c rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c LIMIT 1];

        Expense_Validation_Exception__c exc = new Expense_Validation_Exception__c(
            Expense_Report__c = rep.Id,
            Exception_Type__c = 'Missing Receipt',
            Severity__c = 'High',
            Details__c = 'Receipt missing',
            Status__c = 'Open'
        );
        insert exc;

        rep = [SELECT Id, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(true, rep.Has_Blocking_Exceptions__c);

        // Delete exception
        delete exc;

        rep = [SELECT Id, Has_Blocking_Exceptions__c, Status__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(false, rep.Has_Blocking_Exceptions__c, 'Deleting the only exception should clear blocking flag');
    }

    @IsTest
    static void testBulkExceptionsSynchronization() {
        Expense_Report__c rep = [SELECT Id, Status__c, Has_Blocking_Exceptions__c FROM Expense_Report__c LIMIT 1];

        List<Expense_Validation_Exception__c> listExc = new List<Expense_Validation_Exception__c>();
        for (Integer i = 0; i < 50; i++) {
            listExc.add(new Expense_Validation_Exception__c(
                Expense_Report__c = rep.Id,
                Exception_Type__c = 'Policy Violation',
                Severity__c = 'High',
                Details__c = 'Bulk violation ' + i,
                Status__c = 'Open'
            ));
        }

        Test.startTest();
        insert listExc;

        rep = [SELECT Id, Has_Blocking_Exceptions__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(true, rep.Has_Blocking_Exceptions__c);

        // Bulk resolve all 50
        for (Expense_Validation_Exception__c e : listExc) {
            e.Status__c = 'Resolved';
        }
        update listExc;
        Test.stopTest();

        rep = [SELECT Id, Has_Blocking_Exceptions__c, Status__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(false, rep.Has_Blocking_Exceptions__c, 'Bulk resolution must clear blocking status');
        System.assertEquals('Under Review', rep.Status__c);
    }
}
