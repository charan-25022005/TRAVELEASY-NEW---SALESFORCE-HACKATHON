/**
 * @description Core service handling payment reimbursement orchestration,
 *              simulated external payment integration, and idempotent transaction auditing.
 */
public inherited sharing class ReimbursementService {

    /**
     * @description Enqueues asynchronous Queueable execution for approved expense reports.
     */
    public static void initiateReimbursement(List<Id> reportIds) {
        if (reportIds == null || reportIds.isEmpty()) return;
        System.enqueueJob(new ProcessReimbursementQueueable(reportIds));
    }

    /**
     * @description Simulates payment execution for an approved expense report.
     *              Maintains strict audit trails in Integration_Log__c without exposing secrets.
     */
    public static Boolean processSingleReportReimbursement(Expense_Report__c report) {
        Long startTime = System.currentTimeMillis();
        String referenceTxn = 'TXN-' + String.valueOf(Crypto.getRandomInteger()).replaceAll('-', '') + '-' + System.currentTimeMillis();

        String simulatedEndpoint = 'https://api.traveleasy-payments.mock/v1/disbursements';
        String requestBody = JSON.serialize(new Map<String, Object>{
            'expenseReportId' => report.Id,
            'reportName' => report.Report_Name__c,
            'amount' => report.Total_Amount__c,
            'currency' => 'INR',
            'employeeId' => report.Employee__c,
            'timestamp' => DateTime.now().getTime()
        });

        Boolean isSuccessful = true;
        String responseBody = '';
        String errorMessage = null;

        try {
            // Simulated payment gateway interaction
            // In a live environment with configured Named Credentials:
            // HttpRequest req = new HttpRequest();
            // req.setEndpoint('callout:TravelEasyPaymentGateway/v1/disbursements');
            // req.setMethod('POST');
            // req.setBody(requestBody);
            // HttpResponse res = new Http().send(req);

            responseBody = JSON.serialize(new Map<String, Object>{
                'status' => 'SUCCESS',
                'gatewayReference' => referenceTxn,
                'settlementCode' => 'SETTLE-200-OK',
                'clearedAt' => DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            });

            report.Reimbursement_Status__c = 'Completed';
            report.Reimbursement_Reference__c = referenceTxn;
            report.Reimbursement_Date__c = System.now();
            report.Status__c = 'Reimbursed';

        } catch (Exception ex) {
            isSuccessful = false;
            errorMessage = ex.getMessage();
            report.Reimbursement_Status__c = 'Failed';
            responseBody = JSON.serialize(new Map<String, Object>{
                'status' => 'FAILED',
                'error' => errorMessage
            });
        }

        Long durationMs = System.currentTimeMillis() - startTime;
        IntegrationLogService.log(
            'Reimbursement_Payment_Gateway',
            simulatedEndpoint,
            referenceTxn,
            report.Id,
            isSuccessful ? 'Success' : 'Failed',
            requestBody,
            responseBody,
            errorMessage,
            durationMs
        );

        return isSuccessful;
    }
}
