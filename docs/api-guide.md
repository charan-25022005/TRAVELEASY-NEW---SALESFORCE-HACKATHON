# TravelEasy — REST API Integration Guide

## Endpoint Information
- **URI Mapping:** `/services/apexrest/traveleasy/travel-requests`
- **Method:** `POST`
- **Authentication:** OAuth 2.0 Bearer Token (Salesforce Connected App or Session Header)
- **Content-Type:** `application/json`

---

## 1. Request Payload Schema

```json
{
  "employeeName": "Charan K",
  "employeeId": "EMP101",
  "jobRole": "Employee",
  "destination": "Bengaluru",
  "purpose": "Client Architecture Workshop",
  "travelStartDate": "2027-02-15",
  "travelEndDate": "2027-02-18",
  "estimatedCost": 15000.00
}
```

### Field Definitions & Validations
| Field Name | Type | Required | Constraints |
|---|---|---|---|
| `employeeName` | String | Yes | Non-blank string |
| `employeeId` | String | Yes | Non-blank string |
| `jobRole` | String | Yes | Must be `Employee` or `Manager`. Validated server-side against authenticated user's credentials. |
| `destination` | String | Yes | Max 255 characters |
| `purpose` | String | Yes | Max 255 characters |
| `travelStartDate` | Date (YYYY-MM-DD) | Yes | Cannot be in the past |
| `travelEndDate` | Date (YYYY-MM-DD) | Yes | Must be equal to or after `travelStartDate` |
| `estimatedCost` | Decimal | Yes | Must be greater than 0 |

---

## 2. Success Response

**HTTP Status:** `201 Created`

```json
{
  "success": true,
  "travelRequestId": "a00hg00000abcdeAAA",
  "status": "Submitted",
  "assignedApproverId": "005hg00000xyz123AA",
  "message": "Travel request submitted successfully and routed for manager review."
}
```

---

## 3. Error Responses

### 3.1 Validation Failure (Invalid Date / Missing Fields)
**HTTP Status:** `400 Bad Request`

```json
{
  "success": false,
  "errorCode": "INVALID_INPUT",
  "message": "Travel start date cannot be in the past. Travel end date must be after travel start date."
}
```

### 3.2 Role Escalation / Impersonation Attempt
**HTTP Status:** `403 Forbidden`

```json
{
  "success": false,
  "errorCode": "ROLE_MISMATCH",
  "message": "Supplied role 'Manager' does not match authenticated employee record."
}
```
