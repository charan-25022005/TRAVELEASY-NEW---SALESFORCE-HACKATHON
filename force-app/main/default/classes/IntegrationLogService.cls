
/**
 * @description Centralized logging service for TravelEasy API and
 *              asynchronous payment events.
 *              Sanitizes sensitive data and logs insertion failures.
 */
public inherited sharing class IntegrationLogService {

    /**
     * @description Creates and inserts an Integration_Log__c record.
     */
    public static void log(
        String operation,
        String endpoint,
        String referenceId,
        Id relatedRecordId,
        String status,
        String requestPayload,
        String responsePayload,
        String errorMessage,
        Long executionTimeMs
    ) {
        try {
            Integration_Log__c logRecord = new Integration_Log__c();

            logRecord.Operation__c = operation;
            logRecord.Endpoint__c = endpoint;
            logRecord.Reference_Id__c = referenceId;
            logRecord.Related_Record_Id__c =
                relatedRecordId != null
                    ? String.valueOf(relatedRecordId)
                    : null;
            logRecord.Status__c = status;
            logRecord.Request_Payload__c = sanitize(requestPayload);
            logRecord.Response_Payload__c = sanitize(responsePayload);
            logRecord.Error_Message__c = errorMessage;
            logRecord.Execution_Time_Ms__c = executionTimeMs;

            Database.SaveResult result =
                Database.insert(
                    logRecord,
                    false,
                    AccessLevel.SYSTEM_MODE
                );

            if (!result.isSuccess()) {
                for (Database.Error err : result.getErrors()) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Integration Log insert failed: '
                            + err.getMessage()
                    );
                }
            } else {
                System.debug(
                    LoggingLevel.INFO,
                    'Integration Log created: ' + result.getId()
                );
            }

        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                'IntegrationLogService error: ' + ex.getMessage()
            );
        }
    }

    /**
     * @description Masks common sensitive values and truncates
     *              payloads that exceed the configured length.
     */
    private static String sanitize(String payload) {
        if (String.isBlank(payload)) {
            return payload;
        }

        String sanitized = payload.replaceAll(
            '(?i)"(password|token|secret|access_token)"\\s*:\\s*"[^"]+"',
            '"$1":"***MASKED***"'
        );

        if (sanitized.length() > 32000) {
            sanitized =
                sanitized.substring(0, 32000) + '... [TRUNCATED]';
        }

        return sanitized;
    }
}
