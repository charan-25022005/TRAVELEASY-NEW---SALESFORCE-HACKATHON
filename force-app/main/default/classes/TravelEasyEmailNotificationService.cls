/**
 * @description Centralized email notification service for TravelEasy platform.
 *              Strictly sends EMAIL notifications only (no in-app alerts).
 *              Handles Travel Request decisions, Expense Report decisions, and
 *              Reimbursement payment outcomes with duplicate prevention and safe error handling.
 */
public inherited sharing class TravelEasyEmailNotificationService {

    // In-memory recursion guards to prevent duplicate emails within the same transaction context
    private static Set<Id> processedTravelRequestEmailIds = new Set<Id>();
    private static Set<Id> processedExpenseReportEmailIds = new Set<Id>();
    private static Set<Id> processedReimbursementEmailIds = new Set<Id>();

    // Test tracking properties to verify email invocation in unit tests
    @TestVisible private static Integer testEmailInvocationsCount = 0;
    @TestVisible private static List<String> testSentEmailSubjects = new List<String>();
    @TestVisible private static List<String> testSentRecipientEmails = new List<String>();

    /**
     * @description Sends email notification when a Travel Request is Approved or Rejected.
     */
    public static void sendTravelRequestDecisionEmail(List<Id> travelRequestIds) {
        if (travelRequestIds == null || travelRequestIds.isEmpty()) return;

        List<Travel_Request__c> requests = [
            SELECT Id, Name, Destination__c, Purpose__c, Estimated_Cost__c, Status__c,
                   Rejection_Reason__c, Travel_Start_Date__c, Travel_End_Date__c,
                   Employee__c, Employee__r.Name, Employee__r.Email,
                   Approver__r.Name
            FROM Travel_Request__c
            WHERE Id IN :travelRequestIds
        ];

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        for (Travel_Request__c tr : requests) {
            if (processedTravelRequestEmailIds.contains(tr.Id)) {
                continue; // Skip duplicate email
            }

            String recipientEmail = tr.Employee__r != null ? tr.Employee__r.Email : null;
            if (String.isBlank(recipientEmail)) {
                IntegrationLogService.log(
                    'Email_Notification_Service',
                    'Messaging.sendEmail',
                    'SKIP-NO-EMAIL-' + tr.Id,
                    tr.Id,
                    'Failed',
                    'Travel Request: ' + tr.Name,
                    null,
                    'Missing verified employee email address. Notification skipped.',
                    0
                );
                continue;
            }

            Boolean isApproved = tr.Status__c == 'Approved';
            String employeeName = tr.Employee__r != null && String.isNotBlank(tr.Employee__r.Name) ? tr.Employee__r.Name : 'Employee';
            String approverName = tr.Approver__r != null ? tr.Approver__r.Name : 'Manager';

            String subject = 'Travel Request ' + (isApproved ? 'Approved' : 'Rejected') + ': ' + tr.Name + ' (' + tr.Destination__c + ')';

            String nextSteps = isApproved
                ? 'Your travel request is approved. You are authorized to travel and incur business expenses in accordance with TravelEasy policy guidelines.'
                : 'Your travel request was rejected. Please review manager feedback, adjust your itinerary or budget, and resubmit if necessary.';

            String comments = String.isNotBlank(tr.Rejection_Reason__c) ? tr.Rejection_Reason__c : (isApproved ? 'Approved by manager.' : 'No additional comments provided.');

            String htmlBody = '<div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
                '<h2 style="color: ' + (isApproved ? '#2e844a' : '#c23934') + ';">Travel Request ' + tr.Status__c + '</h2>' +
                '<p>Dear <strong>' + employeeName + '</strong>,</p>' +
                '<p>Your business travel request has been reviewed with the following decision:</p>' +
                '<table style="border-collapse: collapse; width: 100%; max-width: 600px; margin: 15px 0;">' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Request Number</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + tr.Name + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Destination</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + tr.Destination__c + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Dates</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + tr.Travel_Start_Date__c + ' to ' + tr.Travel_End_Date__c + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Estimated Budget</strong></td><td style="padding: 8px; border: 1px solid #ddd;">₹' + tr.Estimated_Cost__c + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Decision</strong></td><td style="padding: 8px; border: 1px solid #ddd; font-weight: bold; color: ' + (isApproved ? '#2e844a' : '#c23934') + ';">' + tr.Status__c + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Reviewer</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + approverName + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Manager Comments</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + comments + '</td></tr>' +
                '</table>' +
                '<div style="background: #eef4ff; border-left: 4px solid #0176d3; padding: 10px; margin: 15px 0;"><strong>Next Steps:</strong> ' + nextSteps + '</div>' +
                '<p style="color: #666; font-size: 12px; margin-top: 25px;">This is an automated notification from the TravelEasy Platform. Please do not reply directly to this email.</p>' +
                '</div>';

            String plainText = 'Travel Request ' + tr.Status__c + '\n\n' +
                'Dear ' + employeeName + ',\n\n' +
                'Request Number: ' + tr.Name + '\n' +
                'Destination: ' + tr.Destination__c + '\n' +
                'Decision: ' + tr.Status__c + '\n' +
                'Reviewer Comments: ' + comments + '\n\n' +
                'Next Steps: ' + nextSteps + '\n\n' +
                'TravelEasy Platform';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recipientEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(htmlBody);
            mail.setPlainTextBody(plainText);
            mail.setSaveAsActivity(false);

            emailList.add(mail);
            processedTravelRequestEmailIds.add(tr.Id);

            testSentEmailSubjects.add(subject);
            testSentRecipientEmails.add(recipientEmail);
        }

        dispatchEmails(emailList, 'Travel_Request_Decision_Email');
    }

    /**
     * @description Sends email notification when an Expense Report is Approved or Rejected.
     */
    public static void sendExpenseReportDecisionEmail(List<Id> expenseReportIds) {
        if (expenseReportIds == null || expenseReportIds.isEmpty()) return;

        List<Expense_Report__c> reports = [
            SELECT Id, Name, Report_Name__c, Total_Amount__c, Status__c, Rejection_Reason__c,
                   Employee__c, Employee__r.Name, Employee__r.Email,
                   Travel_Request__r.Name, Approver__r.Name
            FROM Expense_Report__c
            WHERE Id IN :expenseReportIds
        ];

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        for (Expense_Report__c rep : reports) {
            if (processedExpenseReportEmailIds.contains(rep.Id)) {
                continue;
            }

            String recipientEmail = rep.Employee__r != null ? rep.Employee__r.Email : null;
            if (String.isBlank(recipientEmail)) {
                IntegrationLogService.log(
                    'Email_Notification_Service',
                    'Messaging.sendEmail',
                    'SKIP-NO-EMAIL-' + rep.Id,
                    rep.Id,
                    'Failed',
                    'Expense Report: ' + rep.Name,
                    null,
                    'Missing verified employee email address. Notification skipped.',
                    0
                );
                continue;
            }

            Boolean isApproved = rep.Status__c == 'Approved';
            String employeeName = rep.Employee__r != null && String.isNotBlank(rep.Employee__r.Name) ? rep.Employee__r.Name : 'Employee';
            String travelReqNumber = rep.Travel_Request__r != null ? rep.Travel_Request__r.Name : 'N/A';
            String comments = String.isNotBlank(rep.Rejection_Reason__c) ? rep.Rejection_Reason__c : (isApproved ? 'Approved by reviewer.' : 'No rejection details provided.');

            String subject = 'Expense Report ' + (isApproved ? 'Approved' : 'Rejected') + ': ' + rep.Name + ' (' + rep.Report_Name__c + ')';

            String nextSteps = isApproved
                ? 'Your expense report is approved and has been submitted to the disbursement pipeline. You will receive a confirmation email once reimbursement payment is completed.'
                : 'Your expense report has been rejected. Please review reviewer comments, resolve any identified policy violations or missing receipts, and resubmit.';

            String htmlBody = '<div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
                '<h2 style="color: ' + (isApproved ? '#2e844a' : '#c23934') + ';">Expense Report ' + rep.Status__c + '</h2>' +
                '<p>Dear <strong>' + employeeName + '</strong>,</p>' +
                '<p>Your expense report decision details:</p>' +
                '<table style="border-collapse: collapse; width: 100%; max-width: 600px; margin: 15px 0;">' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Expense Report</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + rep.Name + ' (' + rep.Report_Name__c + ')</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Travel Request</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + travelReqNumber + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Expense Amount</strong></td><td style="padding: 8px; border: 1px solid #ddd;">₹' + rep.Total_Amount__c + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Decision</strong></td><td style="padding: 8px; border: 1px solid #ddd; font-weight: bold; color: ' + (isApproved ? '#2e844a' : '#c23934') + ';">' + rep.Status__c + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Reviewer Comments</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + comments + '</td></tr>' +
                '</table>' +
                '<div style="background: #eef4ff; border-left: 4px solid #0176d3; padding: 10px; margin: 15px 0;"><strong>Next Steps:</strong> ' + nextSteps + '</div>' +
                '<p style="color: #666; font-size: 12px; margin-top: 25px;">TravelEasy Platform — Intelligent Travel & Spend Control</p>' +
                '</div>';

            String plainText = 'Expense Report ' + rep.Status__c + '\n\n' +
                'Dear ' + employeeName + ',\n\n' +
                'Report Number: ' + rep.Name + '\n' +
                'Travel Request: ' + travelReqNumber + '\n' +
                'Total Amount: ₹' + rep.Total_Amount__c + '\n' +
                'Decision: ' + rep.Status__c + '\n' +
                'Reviewer Comments: ' + comments + '\n\n' +
                'Next Steps: ' + nextSteps + '\n\n' +
                'TravelEasy Platform';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recipientEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(htmlBody);
            mail.setPlainTextBody(plainText);
            mail.setSaveAsActivity(false);

            emailList.add(mail);
            processedExpenseReportEmailIds.add(rep.Id);

            testSentEmailSubjects.add(subject);
            testSentRecipientEmails.add(recipientEmail);
        }

        dispatchEmails(emailList, 'Expense_Report_Decision_Email');
    }

    /**
     * @description Sends email notification when a reimbursement payment is confirmed:
     *              Successful (Completed) or Failed (Rejected / Gateway error).
     *              Clearly indicates simulated transaction nature per requirements.
     */
    public static void sendReimbursementOutcomeEmail(List<Id> expenseReportIds, Boolean isSuccess, String failureReason) {
        if (expenseReportIds == null || expenseReportIds.isEmpty()) return;

        List<Expense_Report__c> reports = [
            SELECT Id, Name, Report_Name__c, Total_Amount__c, Reimbursement_Status__c,
                   Reimbursement_Reference__c, Reimbursement_Date__c,
                   Employee__c, Employee__r.Name, Employee__r.Email
            FROM Expense_Report__c
            WHERE Id IN :expenseReportIds
        ];

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        for (Expense_Report__c rep : reports) {
            if (processedReimbursementEmailIds.contains(rep.Id)) {
                continue;
            }

            String recipientEmail = rep.Employee__r != null ? rep.Employee__r.Email : null;
            if (String.isBlank(recipientEmail)) {
                IntegrationLogService.log(
                    'Email_Notification_Service',
                    'Messaging.sendEmail',
                    'SKIP-NO-EMAIL-' + rep.Id,
                    rep.Id,
                    'Failed',
                    'Reimbursement: ' + rep.Name,
                    null,
                    'Missing verified employee email address. Notification skipped.',
                    0
                );
                continue;
            }

            String employeeName = rep.Employee__r != null && String.isNotBlank(rep.Employee__r.Name) ? rep.Employee__r.Name : 'Employee';
            String refNum = String.isNotBlank(rep.Reimbursement_Reference__c) ? rep.Reimbursement_Reference__c : 'N/A';
            String dateFormatted = rep.Reimbursement_Date__c != null ? rep.Reimbursement_Date__c.format() : String.valueOf(Date.today());
            String reasonText = String.isNotBlank(failureReason) ? failureReason : 'Payment processing exception encountered.';

            String subject = isSuccess
                ? 'Reimbursement Payment Confirmed: ' + rep.Name + ' (' + refNum + ')'
                : 'Reimbursement Payment Failed: ' + rep.Name;

            String nextSteps = isSuccess
                ? 'Your reimbursement has been processed successfully. Funds will reflect per banking cycle times.'
                : 'Finance will reconcile the issue and retry processing or contact you regarding account details.';

            String htmlBody = '<div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
                '<h2 style="color: ' + (isSuccess ? '#2e844a' : '#c23934') + ';">Reimbursement Payment ' + (isSuccess ? 'Successful' : 'Failed') + '</h2>' +
                '<p>Dear <strong>' + employeeName + '</strong>,</p>' +
                '<table style="border-collapse: collapse; width: 100%; max-width: 600px; margin: 15px 0;">' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Expense Report</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + rep.Name + ' (' + rep.Report_Name__c + ')</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Disbursement Amount</strong></td><td style="padding: 8px; border: 1px solid #ddd;">₹' + rep.Total_Amount__c + ' INR</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Payment Status</strong></td><td style="padding: 8px; border: 1px solid #ddd; font-weight: bold; color: ' + (isSuccess ? '#2e844a' : '#c23934') + ';">' + (isSuccess ? 'Completed' : 'Failed') + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Transaction Reference</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + refNum + '</td></tr>' +
                '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Payment Date</strong></td><td style="padding: 8px; border: 1px solid #ddd;">' + dateFormatted + '</td></tr>' +
                (!isSuccess ? '<tr><td style="padding: 8px; border: 1px solid #ddd; background: #f8f9fa;"><strong>Failure Reason</strong></td><td style="padding: 8px; border: 1px solid #ddd; color: #c23934;">' + reasonText + '</td></tr>' : '') +
                '</table>' +
                '<div style="background: #eef4ff; border-left: 4px solid #0176d3; padding: 10px; margin: 15px 0;"><strong>Next Steps:</strong> ' + nextSteps + '</div>' +
                '<div style="background: #fff8e1; border: 1px solid #ffe082; padding: 8px; margin: 15px 0; font-size: 12px; color: #795548;">' +
                '<em>Important Note: This payment transaction was simulated through TravelEasy Sandbox Payment Gateway for demonstration purposes. No real bank funds were transferred.</em>' +
                '</div>' +
                '</div>';

            String plainText = 'Reimbursement Payment ' + (isSuccess ? 'Successful' : 'Failed') + '\n\n' +
                'Dear ' + employeeName + ',\n\n' +
                'Expense Report: ' + rep.Name + '\n' +
                'Amount: ₹' + rep.Total_Amount__c + ' INR\n' +
                'Status: ' + (isSuccess ? 'Completed' : 'Failed') + '\n' +
                'Transaction Reference: ' + refNum + '\n' +
                'Payment Date: ' + dateFormatted + '\n' +
                (!isSuccess ? 'Failure Reason: ' + reasonText + '\n' : '') +
                'Next Steps: ' + nextSteps + '\n\n' +
                '(Simulated transaction in TravelEasy platform)';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recipientEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(htmlBody);
            mail.setPlainTextBody(plainText);
            mail.setSaveAsActivity(false);

            emailList.add(mail);
            processedReimbursementEmailIds.add(rep.Id);

            testSentEmailSubjects.add(subject);
            testSentRecipientEmails.add(recipientEmail);
        }

        dispatchEmails(emailList, 'Reimbursement_Payment_Outcome_Email');
    }

    /**
     * @description Sends list of single email messages with fail-safe error handling and audit logging.
     */
    private static void dispatchEmails(List<Messaging.SingleEmailMessage> emailList, String operationName) {
        if (emailList.isEmpty()) return;

        try {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailList, false);
            testEmailInvocationsCount += emailList.size();

            for (Integer i = 0; i < results.size(); i++) {
                Messaging.SendEmailResult res = results[i];
                if (!res.isSuccess()) {
                    String errMessage = res.getErrors()[0].getMessage();
                    IntegrationLogService.log(
                        'Email_Notification_Service',
                        operationName,
                        'FAIL-SEND-' + System.currentTimeMillis(),
                        null,
                        'Failed',
                        'Recipient: ' + emailList[i].getToAddresses(),
                        null,
                        errMessage,
                        0
                    );
                }
            }
        } catch (Exception ex) {
            // Ensure email issues never roll back the business record transaction
            IntegrationLogService.log(
                'Email_Notification_Service',
                operationName,
                'ERR-DISPATCH-' + System.currentTimeMillis(),
                null,
                'Failed',
                null,
                null,
                ex.getMessage(),
                0
            );
        }
    }
}
