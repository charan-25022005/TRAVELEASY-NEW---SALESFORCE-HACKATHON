/**
 * @description Secure Apex REST endpoint for Travel Request submissions.
 *              Enforces server-side identity verification, date/cost validations,
 *              role verification, and approver assignment.
 *              URI: /services/apexrest/traveleasy/travel-requests
 */
@RestResource(urlMapping='/traveleasy/travel-requests/*')
global with sharing class TravelRequestRestResource {

    global class TravelRequestPayload {
        public String employeeName;
        public String employeeId;
        public String jobRole;
        public String destination;
        public String purpose;
        public String travelStartDate;
        public String travelEndDate;
        public Decimal estimatedCost;
    }

    global class ApiResponse {
        public Boolean success;
        public String errorCode;
        public String message;
        public Id travelRequestId;
        public String status;
        public Id assignedApproverId;

        public ApiResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        public ApiResponse(Boolean success, String errorCode, String message) {
            this.success = success;
            this.errorCode = errorCode;
            this.message = message;
        }
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        Long startTime = System.currentTimeMillis();
        String requestBody = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';

        try {
            if (String.isBlank(requestBody)) {
                sendError(res, 400, 'INVALID_BODY', 'Request body cannot be empty.', startTime, requestBody);
                return;
            }

            TravelRequestPayload payload;
            try {
                payload = (TravelRequestPayload) JSON.deserialize(requestBody, TravelRequestPayload.class);
            } catch (Exception parseEx) {
                sendError(res, 400, 'MALFORMED_JSON', 'Malformed JSON payload: ' + parseEx.getMessage(), startTime, requestBody);
                return;
            }

            // 1. Validate required fields
            String missingFields = validateRequiredFields(payload);
            if (String.isNotBlank(missingFields)) {
                sendError(res, 400, 'MISSING_FIELDS', 'Missing required fields: ' + missingFields, startTime, requestBody);
                return;
            }

            // 2. Validate dates
            Date startDate;
            Date endDate;
            try {
                startDate = Date.valueOf(payload.travelStartDate);
                endDate = Date.valueOf(payload.travelEndDate);
            } catch (Exception dateEx) {
                sendError(res, 400, 'INVALID_DATE_FORMAT', 'Dates must be formatted as YYYY-MM-DD.', startTime, requestBody);
                return;
            }

            if (startDate < Date.today()) {
                sendError(res, 400, 'INVALID_DATE', 'Travel start date cannot be in the past.', startTime, requestBody);
                return;
            }

            if (endDate < startDate) {
                sendError(res, 400, 'INVALID_DATE_RANGE', 'Travel end date must be on or after travel start date.', startTime, requestBody);
                return;
            }

            // 3. Validate estimated cost
            if (payload.estimatedCost == null || payload.estimatedCost <= 0) {
                sendError(res, 400, 'INVALID_COST', 'Estimated cost must be greater than zero.', startTime, requestBody);
                return;
            }

            // 4. Server-Side Identity & Role Verification
            Id currentUserId = UserInfo.getUserId();
            User currentUser = [
                SELECT Id, Name, Title, Department, ManagerId, UserRole.Name 
                FROM User 
                WHERE Id = :currentUserId 
                LIMIT 1
            ];

            String effectiveRole = 'Employee';
            Boolean isManagerInSystem = isUserAuthorizedManager(currentUser);

            if (String.isNotBlank(payload.jobRole) && payload.jobRole.equalsIgnoreCase('Manager')) {
                if (!isManagerInSystem) {
                    sendError(res, 403, 'ROLE_MISMATCH', 'Supplied role \'Manager\' does not match authenticated employee record.', startTime, requestBody);
                    return;
                }
                effectiveRole = 'Manager';
            }

            // 5. Approver assignment
            Id assignedApprover = currentUser.ManagerId != null ? currentUser.ManagerId : currentUserId;

            // 6. Create Travel_Request__c record
            Travel_Request__c travelReq = new Travel_Request__c();
            travelReq.Employee__c = currentUserId;
            travelReq.Employee_ID__c = payload.employeeId;
            travelReq.Requester_Role__c = effectiveRole;
            travelReq.Destination__c = payload.destination;
            travelReq.Purpose__c = payload.purpose;
            travelReq.Travel_Start_Date__c = startDate;
            travelReq.Travel_End_Date__c = endDate;
            travelReq.Estimated_Cost__c = payload.estimatedCost;
            travelReq.Status__c = 'Submitted';
            travelReq.Approver__c = assignedApprover;

            Database.SaveResult sr = Database.insert(travelReq, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                String dmlError = sr.getErrors()[0].getMessage();
                sendError(res, 400, 'SAVE_FAILED', dmlError, startTime, requestBody);
                return;
            }

            // 7. Successful Response
            ApiResponse successResp = new ApiResponse(true, 'Travel request submitted successfully and routed for manager review.');
            successResp.travelRequestId = travelReq.Id;
            successResp.status = 'Submitted';
            successResp.assignedApproverId = assignedApprover;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(successResp));

            Long durationMs = System.currentTimeMillis() - startTime;
            IntegrationLogService.log(
                'Travel_Request_REST_API',
                '/services/apexrest/traveleasy/travel-requests',
                travelReq.Id,
                travelReq.Id,
                'Success',
                requestBody,
                JSON.serialize(successResp),
                null,
                durationMs
            );

        } catch (Exception ex) {
            sendError(res, 500, 'INTERNAL_SERVER_ERROR', ex.getMessage(), startTime, requestBody);
        }
    }

    /**
     * @description Validates whether user is authorized as a Manager based on Salesforce User data.
     */
    public static Boolean isUserAuthorizedManager(User u) {
        if (u == null) return false;
        String title = u.Title != null ? u.Title.toLowerCase() : '';
        String roleName = (u.UserRole != null && u.UserRole.Name != null) ? u.UserRole.Name.toLowerCase() : '';

        if (title.contains('manager') || title.contains('director') || title.contains('vp') || title.contains('head') || title.contains('lead') ||
            roleName.contains('manager') || roleName.contains('director') || roleName.contains('vp') || roleName.contains('head')) {
            return true;
        }

        // Also check if any other user reports to this user as Manager
        Integer directReports = [SELECT count() FROM User WHERE ManagerId = :u.Id AND IsActive = true];
        return directReports > 0;
    }

    private static String validateRequiredFields(TravelRequestPayload p) {
        List<String> missing = new List<String>();
        if (String.isBlank(p.employeeName)) missing.add('employeeName');
        if (String.isBlank(p.employeeId)) missing.add('employeeId');
        if (String.isBlank(p.jobRole)) missing.add('jobRole');
        if (String.isBlank(p.destination)) missing.add('destination');
        if (String.isBlank(p.purpose)) missing.add('purpose');
        if (String.isBlank(p.travelStartDate)) missing.add('travelStartDate');
        if (String.isBlank(p.travelEndDate)) missing.add('travelEndDate');
        if (p.estimatedCost == null) missing.add('estimatedCost');
        return String.join(missing, ', ');
    }

    private static void sendError(RestResponse res, Integer statusCode, String errorCode, String message, Long startTime, String requestBody) {
        res.statusCode = statusCode;
        ApiResponse err = new ApiResponse(false, errorCode, message);
        String respJson = JSON.serialize(err);
        res.responseBody = Blob.valueOf(respJson);

        Long durationMs = System.currentTimeMillis() - startTime;
        IntegrationLogService.log(
            'Travel_Request_REST_API',
            '/services/apexrest/traveleasy/travel-requests',
            'ERROR-' + System.currentTimeMillis(),
            null,
            'Failed',
            requestBody,
            respJson,
            message,
            durationMs
        );
    }
}
