/**
 * @description Centralized logging service for TravelEasy API and asynchronous payment events.
 *              Guarantees sensitive data sanitization and resilient error handling.
 */
public inherited sharing class IntegrationLogService {

    /**
     * @description Creates and inserts an Integration_Log__c record.
     */
    public static void log(String operation, String endpoint, String referenceId, Id relatedRecordId, String status, String requestPayload, String responsePayload, String errorMessage, Long executionTimeMs) {
        try {
            Integration_Log__c logRecord = new Integration_Log__c();
            logRecord.Operation__c = operation;
            logRecord.Endpoint__c = endpoint;
            logRecord.Reference_Id__c = referenceId;
            logRecord.Related_Record_Id__c = relatedRecordId != null ? String.valueOf(relatedRecordId) : null;
            logRecord.Status__c = status;
            logRecord.Request_Payload__c = sanitize(requestPayload);
            logRecord.Response_Payload__c = sanitize(responsePayload);
            logRecord.Error_Message__c = errorMessage;
            logRecord.Execution_Time_Ms__c = executionTimeMs;

            Database.insert(logRecord, false, AccessLevel.USER_MODE);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IntegrationLogService error: ' + ex.getMessage());
        }
    }

    /**
     * @description Sanitizes sensitive data such as tokens and passwords from logged payloads.
     */
    private static String sanitize(String payload) {
        if (String.isBlank(payload)) {
            return payload;
        }
        // Mask common secret tokens if present
        String sanitized = payload.replaceAll('(?i)"(password|token|secret|access_token)"\\s*:\\s*"[^"]+"', '"$1":"***MASKED***"');
        if (sanitized.length() > 32000) {
            sanitized = sanitized.substring(0, 32000) + '... [TRUNCATED]';
        }
        return sanitized;
    }
}
