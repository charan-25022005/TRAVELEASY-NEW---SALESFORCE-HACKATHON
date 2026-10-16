/**
 * @description Unit tests for TravelEasyUiController.
 */
@IsTest
private class TravelEasyUiControllerTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Ui',
            LastName = 'Tester',
            Email = 'ui.tester@traveleasy.test',
            Username = 'ui.tester.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'uites',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Shimla',
            Purpose__c = 'Offsite',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 25000,
            Status__c = 'Approved'
        );
        insert tr;

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'UI Test Expense Report',
            Travel_Request__c = tr.Id,
            Employee__c = emp.Id,
            Total_Amount__c = 12000,
            Status__c = 'Under Review'
        );
        insert rep;

        Expense_Validation_Exception__c exc = new Expense_Validation_Exception__c(
            Expense_Report__c = rep.Id,
            Exception_Type__c = 'Missing Receipt',
            Severity__c = 'Medium',
            Details__c = 'Missing invoice',
            Status__c = 'Open'
        );
        insert exc;
    }

    @IsTest
    static void testGetExpenseReportSummary() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        Test.startTest();
        TravelEasyUiController.ReportSummary summary = TravelEasyUiController.getExpenseReportSummary(rep.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertEquals(12000, summary.totalAmount);
        System.assertEquals(25000, summary.estimatedCost);
        System.assertEquals(13000, summary.variance);
        System.assertEquals(1, summary.totalExceptions);
        System.assertEquals(1, summary.openExceptions);
    }

    @IsTest
    static void testResolveException() {
        Expense_Validation_Exception__c exc = [SELECT Id, Status__c FROM Expense_Validation_Exception__c LIMIT 1];

        Test.startTest();
        String result = TravelEasyUiController.resolveException(exc.Id, 'Resolved', 'Receipt verified on file.');
        Test.stopTest();

        System.assert(result.contains('Resolved'));
        exc = [SELECT Id, Status__c, Resolution_Comments__c, Reviewer__c, Resolved_Date__c FROM Expense_Validation_Exception__c WHERE Id = :exc.Id];
        System.assertEquals('Resolved', exc.Status__c);
        System.assertEquals('Receipt verified on file.', exc.Resolution_Comments__c);
        System.assertNotEquals(null, exc.Resolved_Date__c);
    }
}
