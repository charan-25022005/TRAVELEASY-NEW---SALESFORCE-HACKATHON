/**
 * @description Comprehensive unit and integration tests for TravelRequestRestResource REST API.
 */
@IsTest
private class TravelRequestRestResourceTest {

    @TestSetup
    static void setupTestData() {
        // Setup manager user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User mgr = new User(
            FirstName = 'Manager',
            LastName = 'TestUser',
            Email = 'mgr.testuser@traveleasy.test',
            Username = 'mgr.testuser.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'mgru',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            Title = 'Engineering Manager'
        );
        insert mgr;

        // Setup standard employee user with manager link
        User emp = new User(
            FirstName = 'Employee',
            LastName = 'TestUser',
            Email = 'emp.testuser@traveleasy.test',
            Username = 'emp.testuser.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'empu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            Title = 'Software Engineer',
            ManagerId = mgr.Id
        );
        insert emp;
    }

    @IsTest
    static void testValidEmployeeSubmission() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp.testuser@traveleasy.test' LIMIT 1];
        System.runAs(emp) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/traveleasy/travel-requests';
            req.httpMethod = 'POST';

            TravelRequestRestResource.TravelRequestPayload payload = new TravelRequestRestResource.TravelRequestPayload();
            payload.employeeName = 'Employee TestUser';
            payload.employeeId = 'EMP101';
            payload.jobRole = 'Employee';
            payload.destination = 'Bengaluru';
            payload.purpose = 'Architecture Summit';
            payload.travelStartDate = String.valueOf(Date.today().addDays(5));
            payload.travelEndDate = String.valueOf(Date.today().addDays(10));
            payload.estimatedCost = 15000;

            req.requestBody = Blob.valueOf(JSON.serialize(payload));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            TravelRequestRestResource.doPost();
            Test.stopTest();

            System.assertEquals(201, res.statusCode, 'Expected 201 Created');
            TravelRequestRestResource.ApiResponse respObj = (TravelRequestRestResource.ApiResponse) 
                JSON.deserialize(res.responseBody.toString(), TravelRequestRestResource.ApiResponse.class);
            System.assert(respObj.success, 'Expected success to be true');
            System.assertNotEquals(null, respObj.travelRequestId, 'Travel Request ID should be returned');

            Travel_Request__c createdReq = [SELECT Id, Status__c, Requester_Role__c FROM Travel_Request__c WHERE Id = :respObj.travelRequestId];
            System.assertEquals('Submitted', createdReq.Status__c, 'Status must be Submitted');
            System.assertEquals('Employee', createdReq.Requester_Role__c, 'Role must be Employee');
        }
    }

    @IsTest
    static void testValidManagerSubmission() {
        User mgr = [SELECT Id FROM User WHERE Email = 'mgr.testuser@traveleasy.test' LIMIT 1];
        System.runAs(mgr) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/traveleasy/travel-requests';
            req.httpMethod = 'POST';

            TravelRequestRestResource.TravelRequestPayload payload = new TravelRequestRestResource.TravelRequestPayload();
            payload.employeeName = 'Manager TestUser';
            payload.employeeId = 'MGR201';
            payload.jobRole = 'Manager';
            payload.destination = 'London';
            payload.purpose = 'Executive Leadership Meeting';
            payload.travelStartDate = String.valueOf(Date.today().addDays(10));
            payload.travelEndDate = String.valueOf(Date.today().addDays(15));
            payload.estimatedCost = 80000;

            req.requestBody = Blob.valueOf(JSON.serialize(payload));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            TravelRequestRestResource.doPost();
            Test.stopTest();

            System.assertEquals(201, res.statusCode, 'Expected 201 Created for authorized manager');
        }
    }

    @IsTest
    static void testRoleEscalationForbidden() {
        // Employee attempting to claim Manager privileges
        User emp = [SELECT Id FROM User WHERE Email = 'emp.testuser@traveleasy.test' LIMIT 1];
        System.runAs(emp) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/traveleasy/travel-requests';
            req.httpMethod = 'POST';

            TravelRequestRestResource.TravelRequestPayload payload = new TravelRequestRestResource.TravelRequestPayload();
            payload.employeeName = 'Employee TestUser';
            payload.employeeId = 'EMP101';
            payload.jobRole = 'Manager'; // Unauthorized escalation attempt!
            payload.destination = 'Tokyo';
            payload.purpose = 'Fraudulent Escalation Attempt';
            payload.travelStartDate = String.valueOf(Date.today().addDays(5));
            payload.travelEndDate = String.valueOf(Date.today().addDays(8));
            payload.estimatedCost = 50000;

            req.requestBody = Blob.valueOf(JSON.serialize(payload));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            TravelRequestRestResource.doPost();
            Test.stopTest();

            System.assertEquals(403, res.statusCode, 'Expected 403 Forbidden on role mismatch');
            System.assert(res.responseBody.toString().contains('ROLE_MISMATCH'), 'Should return ROLE_MISMATCH code');
        }
    }

    @IsTest
    static void testInvalidPastDate() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp.testuser@traveleasy.test' LIMIT 1];
        System.runAs(emp) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/traveleasy/travel-requests';
            req.httpMethod = 'POST';

            TravelRequestRestResource.TravelRequestPayload payload = new TravelRequestRestResource.TravelRequestPayload();
            payload.employeeName = 'Employee TestUser';
            payload.employeeId = 'EMP101';
            payload.jobRole = 'Employee';
            payload.destination = 'Bengaluru';
            payload.purpose = 'Past Date Check';
            payload.travelStartDate = String.valueOf(Date.today().addDays(-5)); // Past date
            payload.travelEndDate = String.valueOf(Date.today().addDays(2));
            payload.estimatedCost = 10000;

            req.requestBody = Blob.valueOf(JSON.serialize(payload));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            TravelRequestRestResource.doPost();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Expected 400 Bad Request for past date');
        }
    }

    @IsTest
    static void testInvalidDateRange() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp.testuser@traveleasy.test' LIMIT 1];
        System.runAs(emp) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/traveleasy/travel-requests';
            req.httpMethod = 'POST';

            TravelRequestRestResource.TravelRequestPayload payload = new TravelRequestRestResource.TravelRequestPayload();
            payload.employeeName = 'Employee TestUser';
            payload.employeeId = 'EMP101';
            payload.jobRole = 'Employee';
            payload.destination = 'Bengaluru';
            payload.purpose = 'Invalid Range Check';
            payload.travelStartDate = String.valueOf(Date.today().addDays(10));
            payload.travelEndDate = String.valueOf(Date.today().addDays(5)); // End before start
            payload.estimatedCost = 10000;

            req.requestBody = Blob.valueOf(JSON.serialize(payload));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            TravelRequestRestResource.doPost();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Expected 400 Bad Request for invalid date range');
        }
    }

    @IsTest
    static void testInvalidCostAndMissingFields() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/traveleasy/travel-requests';
        req.httpMethod = 'POST';

        TravelRequestRestResource.TravelRequestPayload payload = new TravelRequestRestResource.TravelRequestPayload();
        payload.employeeName = 'Employee TestUser';
        // missing employeeId, dates, etc.
        payload.estimatedCost = -500;

        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TravelRequestRestResource.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected 400 Bad Request for missing fields');
    }

    @IsTest
    static void testEmptyAndMalformedBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/traveleasy/travel-requests';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        RestContext.request = req;
        RestContext.response = res;

        TravelRequestRestResource.doPost();
        System.assertEquals(400, res.statusCode, 'Expected 400 for empty body');

        req.requestBody = Blob.valueOf('{malformed json}');
        TravelRequestRestResource.doPost();
        System.assertEquals(400, res.statusCode, 'Expected 400 for malformed json');
    }
}
