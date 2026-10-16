/**
 * @description Smart Expense Control Engine.
 *              Evaluates expense items against role-based Custom Metadata policies,
 *              detects single-transaction breaches, daily aggregate limits, missing receipts,
 *              potential duplicates, and travel budget overruns.
 */
public inherited sharing class SmartExpenseControlService {

    public class EvaluationResult {
        public List<Expense_Validation_Exception__c> exceptions;
        public Map<Id, Expense_Item__c> flaggedItems;
        public Boolean hasBlockingExceptions;

        public EvaluationResult() {
            this.exceptions = new List<Expense_Validation_Exception__c>();
            this.flaggedItems = new Map<Id, Expense_Item__c>();
            this.hasBlockingExceptions = false;
        }
    }

    /**
     * @description Evaluates a list of expense items and returns exceptions and updates.
     */
    public static EvaluationResult evaluateExpenseItems(List<Expense_Item__c> items) {
        EvaluationResult result = new EvaluationResult();
        if (items == null || items.isEmpty()) {
            return result;
        }

        // 1. Gather parent report and travel request data
        Set<Id> reportIds = new Set<Id>();
        Set<Id> itemIds = new Set<Id>();
        for (Expense_Item__c item : items) {
            if (item.Expense_Report__c != null) {
                reportIds.add(item.Expense_Report__c);
            }
            if (item.Id != null) {
                itemIds.add(item.Id);
            }
        }

        Map<Id, Expense_Report__c> reportMap = new Map<Id, Expense_Report__c>([
            SELECT Id, Employee__c, Status__c, Total_Amount__c, Travel_Request__c,
                   Travel_Request__r.Estimated_Cost__c, Travel_Request__r.Requester_Role__c,
                   Travel_Request__r.Approver__c
            FROM Expense_Report__c
            WHERE Id IN :reportIds
        ]);

        // 2. Load Active Custom Metadata Policies into memory cache
        Map<String, Travel_Expense_Policy__mdt> policyCache = getPolicyCache();

        // 3. Prepare parameters for daily aggregate query
        Set<Id> employeeIds = new Set<Id>();
        Set<Date> transactionDates = new Set<Date>();
        Set<String> categories = new Set<String>();

        for (Expense_Item__c item : items) {
            Expense_Report__c parentReport = reportMap.get(item.Expense_Report__c);
            if (parentReport != null && parentReport.Employee__c != null) {
                employeeIds.add(parentReport.Employee__c);
            }
            if (item.Transaction_Date__c != null) {
                transactionDates.add(item.Transaction_Date__c);
            }
            if (String.isNotBlank(item.Category__c)) {
                categories.add(item.Category__c);
            }
        }

        // Query existing items in DB on same dates for same employees to calculate accurate daily totals
        Map<String, Decimal> existingDailyTotals = getExistingDailyTotals(employeeIds, transactionDates, categories, itemIds);

        // Keep track of within-batch daily accumulations and duplicates
        Map<String, Decimal> batchDailyAccumulator = new Map<String, Decimal>();
        Set<String> seenTransactionsInBatch = new Set<String>();

        // Query existing potential duplicates in database
        Map<String, Expense_Item__c> existingDuplicateMatches = getExistingDuplicates(employeeIds, transactionDates, categories, itemIds);

        // Map to track budget totals per travel request
        Map<Id, Decimal> travelRequestCurrentTotals = getTravelRequestTotals(reportMap.values(), items);

        // 4. Evaluate Each Item
        for (Expense_Item__c item : items) {
            Expense_Report__c parentReport = reportMap.get(item.Expense_Report__c);
            if (parentReport == null) continue;

            Id employeeId = parentReport.Employee__c;
            String userRole = (parentReport.Travel_Request__r != null && String.isNotBlank(parentReport.Travel_Request__r.Requester_Role__c)) 
                              ? parentReport.Travel_Request__r.Requester_Role__c : 'Employee';

            String policyKey = makeKey(userRole, item.Category__c);
            Travel_Expense_Policy__mdt policy = policyCache.get(policyKey);

            // Fallback to Employee role policy if specific role policy record is not found
            if (policy == null) {
                policy = policyCache.get(makeKey('Employee', item.Category__c));
            }

            Boolean isItemFlagged = false;
            String flagReason = '';

            if (policy != null) {
                // A. Single-Transaction Limit Check
                if (item.Amount__c != null && item.Amount__c > policy.Single_Transaction_Limit__c) {
                    Expense_Validation_Exception__c exc = createException(
                        item.Expense_Report__c,
                        item.Id,
                        'Policy Violation',
                        'High',
                        'Transaction amount of ' + item.Amount__c + ' exceeds configured single-transaction limit of ' + policy.Single_Transaction_Limit__c + ' for category ' + item.Category__c + ' (' + userRole + ' policy).',
                        parentReport.Travel_Request__r != null ? parentReport.Travel_Request__r.Approver__c : null
                    );
                    result.exceptions.add(exc);
                    result.hasBlockingExceptions = true;
                    isItemFlagged = true;
                    flagReason = 'Exceeds single-transaction limit of ' + policy.Single_Transaction_Limit__c;
                }

                // B. Daily Limit Check (Aggregate multi-item rollup)
                String dailyKey = String.valueOf(employeeId) + '_' + String.valueOf(item.Transaction_Date__c) + '_' + item.Category__c;
                Decimal priorDaily = existingDailyTotals.containsKey(dailyKey) ? existingDailyTotals.get(dailyKey) : 0;
                Decimal inBatchDaily = batchDailyAccumulator.containsKey(dailyKey) ? batchDailyAccumulator.get(dailyKey) : 0;
                Decimal currentDayTotal = priorDaily + inBatchDaily + (item.Amount__c != null ? item.Amount__c : 0);

                if (currentDayTotal > policy.Daily_Limit__c) {
                    Expense_Validation_Exception__c exc = createException(
                        item.Expense_Report__c,
                        item.Id,
                        'Policy Violation',
                        'High',
                        'Cumulative daily total for ' + item.Category__c + ' on ' + item.Transaction_Date__c + ' (' + currentDayTotal + ') exceeds configured daily limit of ' + policy.Daily_Limit__c + '.',
                        parentReport.Travel_Request__r != null ? parentReport.Travel_Request__r.Approver__c : null
                    );
                    result.exceptions.add(exc);
                    result.hasBlockingExceptions = true;
                    isItemFlagged = true;
                    if (String.isBlank(flagReason)) flagReason = 'Exceeds daily category limit of ' + policy.Daily_Limit__c;
                }
                batchDailyAccumulator.put(dailyKey, inBatchDaily + (item.Amount__c != null ? item.Amount__c : 0));

                // C. Receipt Requirement Check
                if (item.Amount__c != null && item.Amount__c >= policy.Receipt_Required_Threshold__c && !item.Receipt_Attached__c) {
                    Expense_Validation_Exception__c exc = createException(
                        item.Expense_Report__c,
                        item.Id,
                        'Missing Receipt',
                        'Medium',
                        'Receipt is mandatory for ' + item.Category__c + ' expenses of ' + policy.Receipt_Required_Threshold__c + ' or greater. No receipt proof attached.',
                        parentReport.Travel_Request__r != null ? parentReport.Travel_Request__r.Approver__c : null
                    );
                    result.exceptions.add(exc);
                    result.hasBlockingExceptions = true;
                    isItemFlagged = true;
                    if (String.isBlank(flagReason)) flagReason = 'Missing mandatory receipt for amount >= ' + policy.Receipt_Required_Threshold__c;
                }
            }

            // D. Duplicate Detection
            String dupKey = String.valueOf(employeeId) + '_' + String.valueOf(item.Transaction_Date__c) + '_' + 
                            (item.Vendor__c != null ? item.Vendor__c.trim().toLowerCase() : '') + '_' + 
                            item.Category__c + '_' + String.valueOf(item.Amount__c);

            Boolean isDuplicate = seenTransactionsInBatch.contains(dupKey) || existingDuplicateMatches.containsKey(dupKey);
            if (isDuplicate) {
                Expense_Validation_Exception__c exc = createException(
                    item.Expense_Report__c,
                    item.Id,
                    'Potential Duplicate',
                    'High',
                    'Potential duplicate expense detected matching identical employee, date (' + item.Transaction_Date__c + '), vendor (' + item.Vendor__c + '), category, and amount (' + item.Amount__c + ').',
                    parentReport.Travel_Request__r != null ? parentReport.Travel_Request__r.Approver__c : null
                );
                result.exceptions.add(exc);
                result.hasBlockingExceptions = true;
                isItemFlagged = true;
                if (String.isBlank(flagReason)) flagReason = 'Potential duplicate transaction';
            }
            seenTransactionsInBatch.add(dupKey);

            if (isItemFlagged) {
                Expense_Item__c flaggedItem = new Expense_Item__c(
                    Id = item.Id,
                    Is_Flagged_For_Review__c = true,
                    Flag_Reason__c = flagReason
                );
                result.flaggedItems.put(item.Id, flaggedItem);
            }
        }

        // E. Travel Budget Overrun Detection (per Report / Travel Request)
        Set<Id> evaluatedRequests = new Set<Id>();
        for (Expense_Report__c rep : reportMap.values()) {
            if (rep.Travel_Request__c != null && !evaluatedRequests.contains(rep.Travel_Request__c)) {
                evaluatedRequests.add(rep.Travel_Request__c);
                Decimal estimatedCost = rep.Travel_Request__r.Estimated_Cost__c != null ? rep.Travel_Request__r.Estimated_Cost__c : 0;
                Decimal totalSpend = travelRequestCurrentTotals.containsKey(rep.Travel_Request__c) ? travelRequestCurrentTotals.get(rep.Travel_Request__c) : 0;

                if (estimatedCost > 0 && totalSpend > estimatedCost) {
                    Decimal overrun = totalSpend - estimatedCost;
                    Expense_Validation_Exception__c exc = createException(
                        rep.Id,
                        null,
                        'Budget Overrun',
                        'Critical',
                        'Cumulative trip expenses (' + totalSpend + ') exceed approved travel budget (' + estimatedCost + ') by ' + overrun + '.',
                        rep.Travel_Request__r.Approver__c
                    );
                    result.exceptions.add(exc);
                    result.hasBlockingExceptions = true;
                }
            }
        }

        return result;
    }

    /**
     * @description Loads active metadata policies into map.
     */
    private static Map<String, Travel_Expense_Policy__mdt> getPolicyCache() {
        Map<String, Travel_Expense_Policy__mdt> cache = new Map<String, Travel_Expense_Policy__mdt>();
        for (Travel_Expense_Policy__mdt p : [
            SELECT Role__c, Category__c, Single_Transaction_Limit__c, Daily_Limit__c,
                   Receipt_Required_Threshold__c, Allowed_Payment_Methods__c, Requires_Manager_Review__c, Is_Active__c
            FROM Travel_Expense_Policy__mdt
            WHERE Is_Active__c = true
        ]) {
            cache.put(makeKey(p.Role__c, p.Category__c), p);
        }
        return cache;
    }

    private static String makeKey(String role, String category) {
        String r = role != null ? role.trim().toLowerCase() : '';
        String c = category != null ? category.trim().toLowerCase() : '';
        return r + '_' + c;
    }

    private static Expense_Validation_Exception__c createException(Id reportId, Id itemId, String excType, String severity, String details, Id reviewerId) {
        Expense_Validation_Exception__c exc = new Expense_Validation_Exception__c();
        exc.Expense_Report__c = reportId;
        exc.Expense_Item__c = itemId;
        exc.Exception_Type__c = excType;
        exc.Severity__c = severity;
        exc.Details__c = details;
        exc.Status__c = 'Open';
        exc.Is_Blocking__c = (severity == 'High' || severity == 'Critical');
        exc.Reviewer__c = reviewerId;
        return exc;
    }

    private static Map<String, Decimal> getExistingDailyTotals(Set<Id> employeeIds, Set<Date> dates, Set<String> categories, Set<Id> excludeItemIds) {
        Map<String, Decimal> totals = new Map<String, Decimal>();
        if (employeeIds.isEmpty() || dates.isEmpty() || categories.isEmpty()) return totals;

        for (Expense_Item__c itm : [
            SELECT Expense_Report__r.Employee__c, Transaction_Date__c, Category__c, Amount__c
            FROM Expense_Item__c
            WHERE Expense_Report__r.Employee__c IN :employeeIds
              AND Transaction_Date__c IN :dates
              AND Category__c IN :categories
              AND Id NOT IN :excludeItemIds
        ]) {
            String k = String.valueOf(itm.Expense_Report__r.Employee__c) + '_' + String.valueOf(itm.Transaction_Date__c) + '_' + itm.Category__c;
            Decimal existing = totals.containsKey(k) ? totals.get(k) : 0;
            totals.put(k, existing + (itm.Amount__c != null ? itm.Amount__c : 0));
        }
        return totals;
    }

    private static Map<String, Expense_Item__c> getExistingDuplicates(Set<Id> employeeIds, Set<Date> dates, Set<String> categories, Set<Id> excludeItemIds) {
        Map<String, Expense_Item__c> dupes = new Map<String, Expense_Item__c>();
        if (employeeIds.isEmpty() || dates.isEmpty() || categories.isEmpty()) return dupes;

        for (Expense_Item__c itm : [
            SELECT Expense_Report__r.Employee__c, Transaction_Date__c, Vendor__c, Category__c, Amount__c
            FROM Expense_Item__c
            WHERE Expense_Report__r.Employee__c IN :employeeIds
              AND Transaction_Date__c IN :dates
              AND Category__c IN :categories
              AND Id NOT IN :excludeItemIds
        ]) {
            String k = String.valueOf(itm.Expense_Report__r.Employee__c) + '_' + String.valueOf(itm.Transaction_Date__c) + '_' + 
                       (itm.Vendor__c != null ? itm.Vendor__c.trim().toLowerCase() : '') + '_' + 
                       itm.Category__c + '_' + String.valueOf(itm.Amount__c);
            dupes.put(k, itm);
        }
        return dupes;
    }

    private static Map<Id, Decimal> getTravelRequestTotals(List<Expense_Report__c> reports, List<Expense_Item__c> currentBatchItems) {
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        Set<Id> trIds = new Set<Id>();

        for (Expense_Report__c rep : reports) {
            if (rep.Travel_Request__c != null) {
                trIds.add(rep.Travel_Request__c);
            }
        }
        if (trIds.isEmpty()) return totals;

        Set<Id> currentItemIds = new Set<Id>();
        for (Expense_Item__c itm : currentBatchItems) {
            if (itm.Id != null) {
                currentItemIds.add(itm.Id);
            }
        }

        // Sum existing items for these travel requests in DB (excluding items in current transaction)
        for (Expense_Item__c itm : [
            SELECT Amount__c, Expense_Report__r.Travel_Request__c
            FROM Expense_Item__c
            WHERE Expense_Report__r.Travel_Request__c IN :trIds
              AND Id NOT IN :currentItemIds
        ]) {
            Id trId = itm.Expense_Report__r.Travel_Request__c;
            Decimal existing = totals.containsKey(trId) ? totals.get(trId) : 0;
            totals.put(trId, existing + (itm.Amount__c != null ? itm.Amount__c : 0));
        }

        // Add items from current batch
        Map<Id, Id> repToTrMap = new Map<Id, Id>();
        for (Expense_Report__c rep : reports) {
            repToTrMap.put(rep.Id, rep.Travel_Request__c);
        }

        for (Expense_Item__c itm : currentBatchItems) {
            Id trId = repToTrMap.get(itm.Expense_Report__c);
            if (trId != null) {
                Decimal existing = totals.containsKey(trId) ? totals.get(trId) : 0;
                totals.put(trId, existing + (itm.Amount__c != null ? itm.Amount__c : 0));
            }
        }

        return totals;
    }
}
