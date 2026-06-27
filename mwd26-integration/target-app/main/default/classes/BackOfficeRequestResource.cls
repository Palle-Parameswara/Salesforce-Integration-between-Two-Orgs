/**
 * MWD26 demo — Back Office (Target Org) REST endpoint.
 *
 * Receives integration requests from the Source Org and creates an
 * External_Request__c record.
 *
 * Endpoint:  POST /services/apexrest/mwd26/requests
 */
@RestResource(urlMapping='/mwd26/requests/*')
global with sharing class BackOfficeRequestResource {

    /** Inbound JSON payload sent by the Source Org. */
    global class InboundRequest {
        public String requestName;
        public String customerEmail;
        public String requestDetails;
        public String sourceRecordId;
        public String sourceOrg;
    }

    /** JSON response returned to the Source Org. */
    global class ApiResponse {
        public Boolean success;
        public String externalRecordId;
        public String message;
        public ApiResponse(Boolean success, String externalRecordId, String message) {
            this.success = success;
            this.externalRecordId = externalRecordId;
            this.message = message;
        }
    }

    @HttpPost
    global static ApiResponse handlePost() {
        RestResponse res = RestContext.response;
        if (res != null) {
            res.addHeader('Content-Type', 'application/json');
        }

        try {
            RestRequest req = RestContext.request;
            String body = (req != null && req.requestBody != null)
                ? req.requestBody.toString()
                : '';

            if (String.isBlank(body)) {
                return badRequest(res, 'Request body is empty.');
            }

            InboundRequest payload =
                (InboundRequest) JSON.deserialize(body, InboundRequest.class);

            // Validate required fields.
            List<String> missing = new List<String>();
            if (String.isBlank(payload.requestName))   missing.add('requestName');
            if (String.isBlank(payload.customerEmail)) missing.add('customerEmail');
            if (!missing.isEmpty()) {
                return badRequest(res, 'Missing required field(s): ' + String.join(missing, ', '));
            }

            External_Request__c rec = new External_Request__c(
                Request_Name__c      = payload.requestName,
                Customer_Email__c    = payload.customerEmail,
                Request_Details__c   = payload.requestDetails,
                Source_Record_Id__c  = payload.sourceRecordId,
                Source_Org__c        = payload.sourceOrg,
                Processing_Status__c = 'Completed',
                Response_Message__c  = 'Request received and processed by Back Office.'
            );
            insert rec;

            if (res != null) {
                res.statusCode = 201;
            }
            return new ApiResponse(true, rec.Id, 'External Request created successfully.');

        } catch (Exception e) {
            if (res != null) {
                res.statusCode = 500;
            }
            return new ApiResponse(false, null, 'Error processing request: ' + e.getMessage());
        }
    }

    private static ApiResponse badRequest(RestResponse res, String message) {
        if (res != null) {
            res.statusCode = 400;
        }
        return new ApiResponse(false, null, message);
    }
}
