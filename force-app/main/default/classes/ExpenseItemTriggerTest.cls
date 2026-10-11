/**
 * @description Unit and bulk tests for ExpenseItemTrigger and ExpenseItemTriggerHandler.
 */
@IsTest
private class ExpenseItemTriggerTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName = 'Item',
            LastName = 'Employee',
            Email = 'item.emp@traveleasy.test',
            Username = 'item.emp.' + System.currentTimeMillis() + '@traveleasy.test',
            Alias = 'itemp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert emp;

        Travel_Request__c tr = new Travel_Request__c(
            Employee__c = emp.Id,
            Destination__c = 'Jaipur',
            Purpose__c = 'Tech Meet',
            Travel_Start_Date__c = Date.today().addDays(5),
            Travel_End_Date__c = Date.today().addDays(8),
            Estimated_Cost__c = 50000,
            Status__c = 'Approved'
        );
        insert tr;

        Expense_Report__c rep = new Expense_Report__c(
            Report_Name__c = 'Jaipur Trip Report',
            Travel_Request__c = tr.Id,
            Employee__c = emp.Id,
            Status__c = 'Draft'
        );
        insert rep;
    }

    @IsTest
    static void testParentTotalRecalculationOnItemDml() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        // Insert Item 1
        Expense_Item__c item1 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Hotel & Lodging',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'Hilton',
            Amount__c = 3000,
            Receipt_Attached__c = true
        );
        insert item1;

        rep = [SELECT Id, Total_Amount__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(3000, rep.Total_Amount__c, 'Total amount should match 3000');

        // Insert Item 2
        Expense_Item__c item2 = new Expense_Item__c(
            Expense_Report__c = rep.Id,
            Category__c = 'Meals & Food',
            Transaction_Date__c = Date.today().addDays(5),
            Vendor__c = 'Diner',
            Amount__c = 800,
            Receipt_Attached__c = true
        );
        insert item2;

        rep = [SELECT Id, Total_Amount__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(3800, rep.Total_Amount__c, 'Total amount should now be 3800');

        // Update Item 1
        item1.Amount__c = 4000;
        update item1;

        rep = [SELECT Id, Total_Amount__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(4800, rep.Total_Amount__c, 'Total amount should update to 4800');

        // Delete Item 2
        delete item2;

        rep = [SELECT Id, Total_Amount__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(4000, rep.Total_Amount__c, 'Total amount should be 4000 after deleting item2');
    }

    @IsTest
    static void testBulkItemInsertion() {
        Expense_Report__c rep = [SELECT Id FROM Expense_Report__c LIMIT 1];

        List<Expense_Item__c> bulkItems = new List<Expense_Item__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkItems.add(new Expense_Item__c(
                Expense_Report__c = rep.Id,
                Category__c = 'Incidentals & Miscellaneous',
                Transaction_Date__c = Date.today().addDays(5),
                Vendor__c = 'Vendor ' + i,
                Amount__c = 100,
                Receipt_Attached__c = true
            ));
        }

        Test.startTest();
        insert bulkItems;
        Test.stopTest();

        rep = [SELECT Id, Total_Amount__c FROM Expense_Report__c WHERE Id = :rep.Id];
        System.assertEquals(5000, rep.Total_Amount__c, 'Total should equal 50 * 100 = 5000');
    }
}
