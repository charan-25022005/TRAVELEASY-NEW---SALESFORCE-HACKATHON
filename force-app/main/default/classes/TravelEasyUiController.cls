/**
 * @description Controller supporting TravelEasy Lightning Web Components.
 */
public with sharing class TravelEasyUiController {

    public class ReportSummary {
        @AuraEnabled public Id reportId;
        @AuraEnabled public String reportName;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal estimatedCost;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public Boolean isOverBudget;
        @AuraEnabled public Boolean hasBlockingExceptions;
        @AuraEnabled public Integer totalExceptions;
        @AuraEnabled public Integer openExceptions;
    }

    @AuraEnabled(cacheable=true)
    public static ReportSummary getExpenseReportSummary(Id reportId) {
        if (reportId == null) return null;

        Expense_Report__c rep = [
            SELECT Id, Report_Name__c, Status__c, Total_Amount__c, Has_Blocking_Exceptions__c,
                   Travel_Request__r.Estimated_Cost__c
            FROM Expense_Report__c
            WHERE Id = :reportId
            LIMIT 1
        ];

        ReportSummary summary = new ReportSummary();
        summary.reportId = rep.Id;
        summary.reportName = rep.Report_Name__c;
        summary.status = rep.Status__c;
        summary.totalAmount = rep.Total_Amount__c != null ? rep.Total_Amount__c : 0;
        summary.estimatedCost = (rep.Travel_Request__r != null && rep.Travel_Request__r.Estimated_Cost__c != null) 
                                ? rep.Travel_Request__r.Estimated_Cost__c : 0;
        summary.variance = summary.estimatedCost - summary.totalAmount;
        summary.isOverBudget = summary.totalAmount > summary.estimatedCost && summary.estimatedCost > 0;
        summary.hasBlockingExceptions = rep.Has_Blocking_Exceptions__c;

        List<Expense_Validation_Exception__c> excs = [
            SELECT Id, Status__c 
            FROM Expense_Validation_Exception__c 
            WHERE Expense_Report__c = :reportId
        ];
        summary.totalExceptions = excs.size();
        Integer openCount = 0;
        for (Expense_Validation_Exception__c e : excs) {
            if (e.Status__c == 'Open' || e.Status__c == 'Under Review') {
                openCount++;
            }
        }
        summary.openExceptions = openCount;

        return summary;
    }

    @AuraEnabled
    public static String resolveException(Id exceptionId, String action, String comments) {
        if (exceptionId == null) throw new AuraHandledException('Exception ID is required.');
        if (String.isBlank(action)) throw new AuraHandledException('Resolution action is required.');

        Expense_Validation_Exception__c exc = [
            SELECT Id, Status__c, Reviewer__c, Resolution_Comments__c, Resolved_Date__c
            FROM Expense_Validation_Exception__c
            WHERE Id = :exceptionId
            LIMIT 1
        ];

        exc.Status__c = action; // 'Resolved', 'Waived', 'Approved', 'Rejected'
        exc.Reviewer__c = UserInfo.getUserId();
        exc.Resolution_Comments__c = comments;
        exc.Resolved_Date__c = System.now();

        Database.update(exc, AccessLevel.USER_MODE);
        return 'Exception status successfully updated to ' + action;
    }
}
