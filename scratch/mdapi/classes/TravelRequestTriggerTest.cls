/**
 * @description Unit and bulk tests for TravelRequestTrigger and TravelRequestTriggerHandler.
 */
@IsTest
private class TravelRequestTriggerTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User mgr = new User(
            FirstName = 'Lead',
            LastName = 'Approver',
            Email = 'lead.approver@traveleasy.test',
            Username = 'lead.approver.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'leadap',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert mgr;

        User emp = new User(
            FirstName = 'Travel',
            LastName = 'Employee',
            Email = 'travel.emp@traveleasy.test',
            Username = 'travel.emp.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'travemp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ManagerId = mgr.Id
        );
        insert emp;
    }

    @IsTest
    static void testApproverAssignmentAndApprovalStamping() {
        User emp = [SELECT Id FROM User WHERE Email = 'travel.emp@traveleasy.test' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE Email = 'lead.approver@traveleasy.test' LIMIT 1];

        Test.startTest();
        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Singapore',
            Purpose__c = 'Partner Conference',
            Travel_Start_Date__c = Date.today().addDays(10),
            Travel_End_Date__c = Date.today().addDays(14),
            Estimated_Cost__c = 45000,
            Status__c = 'Submitted'
        );
        insert tr;
        Test.stopTest();

        tr = [SELECT Id, Approver__c, Status__c, Approval_Date__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertEquals(mgr.Id, tr.Approver__c, 'Approver should automatically match user manager.');

        // Test approval
        tr.Status__c = 'Approved';
        update tr;

        tr = [SELECT Id, Approval_Date__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertNotEquals(null, tr.Approval_Date__c, 'Approval date must be populated upon approval.');
    }

    @IsTest
    static void testRejectionReasonDefault() {
        Travel_Request__c tr = new Travel_Request__c(
            Destination__c = 'Dubai',
            Purpose__c = 'Expo',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 25000,
            Status__c = 'Submitted'
        );
        insert tr;

        tr.Status__c = 'Rejected';
        update tr;

        tr = [SELECT Id, Rejection_Reason__c FROM Travel_Request__c WHERE Id = :tr.Id];
        System.assertNotEquals(null, tr.Rejection_Reason__c, 'Default rejection reason should be populated.');
    }

    @IsTest
    static void testInvalidDatesValidation() {
        Travel_Request__c tr = new Travel_Request__c(
            Destination__c = 'Sydney',
            Purpose__c = 'Client Visit',
            Travel_Start_Date__c = Date.today().addDays(10),
            Travel_End_Date__c = Date.today().addDays(5), // End before Start!
            Estimated_Cost__c = 30000,
            Status__c = 'Draft'
        );

        Boolean threwError = false;
        try {
            insert tr;
        } catch (DmlException e) {
            threwError = true;
            System.assert(e.getMessage().contains('Travel End Date cannot be earlier than Travel Start Date'));
        }
        System.assert(threwError, 'Expected DML exception on invalid date range');
    }

    @IsTest
    static void testInvalidCostValidation() {
        Travel_Request__c tr = new Travel_Request__c(
            Destination__c = 'Sydney',
            Purpose__c = 'Client Visit',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(10),
            Estimated_Cost__c = -100, // Negative!
            Status__c = 'Draft'
        );

        Boolean threwError = false;
        try {
            insert tr;
        } catch (DmlException e) {
            threwError = true;
            System.assert(e.getMessage().contains('Estimated Cost must be greater than zero'));
        }
        System.assert(threwError, 'Expected DML exception on negative cost');
    }

    @IsTest
    static void testBulkTravelRequests() {
        List<Travel_Request__c> listReqs = new List<Travel_Request__c>();
        for (Integer i = 0; i < 200; i++) {
            listReqs.add(new Travel_Request__c(
                Destination__c = 'City ' + i,
                Purpose__c = 'Bulk Mission ' + i,
                Travel_Start_Date__c = Date.today().addDays(10),
                Travel_End_Date__c = Date.today().addDays(15),
                Estimated_Cost__c = 1000 + i,
                Status__c = 'Submitted'
            ));
        }

        Test.startTest();
        insert listReqs;
        Test.stopTest();

        System.assertEquals(200, [SELECT count() FROM Travel_Request__c], 'All 200 bulk requests should be inserted successfully.');
    }
}
