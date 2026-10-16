/**
 * @description Comprehensive test suite for SmartExpenseControlService covering:
 *              All 6 categories, single transaction limits, daily limits,
 *              receipt verification, duplicate detection, and budget overruns.
 */
@IsTest
private class SmartExpenseControlServiceTest {

    @TestSetup
    static void setupTestData() {
        // Setup User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Policy',
            LastName = 'Tester',
            Email = 'policy.tester@traveleasy.test',
            Username = 'policy.tester.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'ptest',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        // Setup Approved Travel Request with Budget 15000
        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Requester_Role__c = 'Employee',
            Destination__c = 'Chennai',
            Purpose__c = 'Client Workshop',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 15000,
            Status__c = 'Approved'
        );
        insert tr;

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Chennai Workshop Expenses',
            Travel_Request__c = tr.Id,
            Employee__c = emp.Id,
            Status__c = 'Draft'
        );
        insert rep;
    }

    @IsTest
    static void testSingleTransactionLimitBreach() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // Airfare single limit for Employee is 10000. Submit 12000.
        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Airfare',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'Air India',
            Amount__c = 12000,
            Payment_Method__c = 'Corporate Card',
            Receipt_Attached__c = true
        );

        Test.startTest();
        SmartExpenseControlService.EvaluationResult res = SmartExpenseControlService.evaluateExpenseItems(new List<Expense_Item__c>{ item });
        Test.stopTest();

        System.assert(res.hasBlockingExceptions, 'Single limit breach must generate blocking exceptions');
        Boolean foundPolicyViolation = false;
        for (Expense_Validation_Exception__c exc : res.exceptions) {
            if (exc.Exception_Type__c == 'Policy Violation' && exc.Severity__c == 'High') {
                foundPolicyViolation = true;
            }
        }
        System.assert(foundPolicyViolation, 'Expected Policy Violation of High severity for Airfare');
    }

    @IsTest
    static void testDailyLimitBreachAcrossMultipleItems() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // Ground Transportation daily limit for Employee is 3000.
        // Submit two items on the same date totaling 3500.
        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Ground Transportation',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'City Cab',
            Amount__c = 1800,
            Receipt_Attached__c = true
        );
        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Ground Transportation',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'Metro Transit',
            Amount__c = 1700,
            Receipt_Attached__c = true
        );

        Test.startTest();
        SmartExpenseControlService.EvaluationResult res = SmartExpenseControlService.evaluateExpenseItems(new List<Expense_Item__c>{ item1, item2 });
        Test.stopTest();

        System.assert(res.hasBlockingExceptions, 'Cumulative daily limit breach should trigger exception');
        Boolean foundDailyBreach = false;
        for (Expense_Validation_Exception__c exc : res.exceptions) {
            if (exc.Exception_Type__c == 'Policy Violation' && exc.Details__c.contains('daily limit')) {
                foundDailyBreach = true;
            }
        }
        System.assert(foundDailyBreach, 'Expected daily limit violation exception');
    }

    @IsTest
    static void testMissingReceiptValidation() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // Meals & Food receipt threshold for Employee is 300.
        // Submit 650 with Receipt_Attached__c = false.
        Expense_Item__c item = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Meals & Food',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'Taj Restaurant',
            Amount__c = 650,
            Receipt_Attached__c = false
        );

        Test.startTest();
        SmartExpenseControlService.EvaluationResult res = SmartExpenseControlService.evaluateExpenseItems(new List<Expense_Item__c>{ item });
        Test.stopTest();

        Boolean foundMissingReceipt = false;
        for (Expense_Validation_Exception__c exc : res.exceptions) {
            if (exc.Exception_Type__c == 'Missing Receipt') {
                foundMissingReceipt = true;
            }
        }
        System.assert(foundMissingReceipt, 'Expected Missing Receipt exception');
    }

    @IsTest
    static void testPotentialDuplicateDetection() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // Submit two identical items within the same batch
        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Incidentals & Miscellaneous',
            Transaction_Date__c = Date.today().addDays(6),
            Vendor__c = 'Office Stationery Mart',
            Amount__c = 450,
            Receipt_Attached__c = true
        );
        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Incidentals & Miscellaneous',
            Transaction_Date__c = Date.today().addDays(6),
            Vendor__c = 'Office Stationery Mart',
            Amount__c = 450,
            Receipt_Attached__c = true
        );

        Test.startTest();
        SmartExpenseControlService.EvaluationResult res = SmartExpenseControlService.evaluateExpenseItems(new List<Expense_Item__c>{ item1, item2 });
        Test.stopTest();

        Boolean foundDuplicate = false;
        for (Expense_Validation_Exception__c exc : res.exceptions) {
            if (exc.Exception_Type__c == 'Potential Duplicate') {
                foundDuplicate = true;
            }
        }
        System.assert(foundDuplicate, 'Expected Potential Duplicate exception to be raised');
    }

    @IsTest
    static void testBudgetOverrunDetection() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // Budget is 15000. Submit items totaling 18000.
        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Hotel & Lodging',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'Marriott Hotel',
            Amount__c = 5000,
            Receipt_Attached__c = true
        );
        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Airfare',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'IndiGo Airlines',
            Amount__c = 10000,
            Receipt_Attached__c = true
        );
        Expense_Item__c item3 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Client Entertainment',
            Transaction_Date__c = Date.today().addDays(6),
            Vendor__c = 'Client Dinner',
            Amount__c = 3000,
            Receipt_Attached__c = true
        );

        Test.startTest();
        SmartExpenseControlService.EvaluationResult res = SmartExpenseControlService.evaluateExpenseItems(new List<Expense_Item__c>{ item1, item2, item3 });
        Test.stopTest();

        Boolean foundBudgetOverrun = false;
        for (Expense_Validation_Exception__c exc : res.exceptions) {
            if (exc.Exception_Type__c == 'Budget Overrun' && exc.Severity__c == 'Critical') {
                foundBudgetOverrun = true;
            }
        }
        System.assert(foundBudgetOverrun, 'Expected Critical Budget Overrun exception when expenses exceed 15000');
    }

    @IsTest
    static void testAllSixCategoriesCompliant() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // All 6 categories within limits and with receipts
        List<Expense_Item__c> compliantItems = new List<Expense_Item__c>{
            new Expense_Item__c(Expense_Report__c = rep.Id, Category__c = 'Airfare', Transaction_Date__c = Date.today().addDays(5), Vendor__c = 'Air India', Amount__c = 4000, Receipt_Attached__c = true),
            new Expense_Item__c(Expense_Report__c = rep.Id, Category__c = 'Hotel & Lodging', Transaction_Date__c = Date.today().addDays(5), Vendor__c = 'ITC Hotel', Amount__c = 3000, Receipt_Attached__c = true),
            new Expense_Item__c(Expense_Report__c = rep.Id, Category__c = 'Ground Transportation', Transaction_Date__c = Date.today().addDays(5), Vendor__c = 'Uber', Amount__c = 800, Receipt_Attached__c = true),
            new Expense_Item__c(Expense_Report__c = rep.Id, Category__c = 'Meals & Food', Transaction_Date__c = Date.today().addDays(5), Vendor__c = 'Bistro', Amount__c = 500, Receipt_Attached__c = true),
            new Expense_Item__c(Expense_Report__c = rep.Id, Category__c = 'Client Entertainment', Transaction_Date__c = Date.today().addDays(6), Vendor__c = 'Cafe', Amount__c = 1500, Receipt_Attached__c = true),
            new Expense_Item__c(Expense_Report__c = rep.Id, Category__c = 'Incidentals & Miscellaneous', Transaction_Date__c = Date.today().addDays(6), Vendor__c = 'Stationery', Amount__c = 200, Receipt_Attached__c = true)
        };

        Test.startTest();
        SmartExpenseControlService.EvaluationResult res = SmartExpenseControlService.evaluateExpenseItems(compliantItems);
        Test.stopTest();

        System.assert(!res.hasBlockingExceptions, 'Compliant items must not generate blocking exceptions');
    }
}
