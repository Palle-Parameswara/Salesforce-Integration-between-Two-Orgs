/**
 * MWD26 demo — Front Office (Source Org) integration service.
 *
 * Takes an Integration_Request__c record Id, sends the data to the Target Org
 * via a Named Credential callout, then writes the result back onto the record.
 *
 * The endpoint is referenced ONLY through the Named Credential `Target_Org_NC`.
 * No org URLs, tokens, or secrets are hardcoded.
 */
public with sharing class IntegrationRequestService {

    @TestVisible
    private static final String ENDPOINT =
        'callout:Target_Org_NC/services/apexrest/mwd26/requests';

    /** Payload sent to the Target Org. */
    public class OutboundRequest {
        public String requestName;
        public String customerEmail;
        public String requestDetails;
        public String sourceRecordId;
        public String sourceOrg;
    }

    /** Response shape returned by the Target Org. */
    public class TargetResponse {
        public Boolean success;
        public String externalRecordId;
        public String message;
    }

    /** Result surfaced to the LWC. */
    public class SyncResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String externalRecordId;
    }

    @AuraEnabled
    public static SyncResult sendRequest(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('No record Id was provided.');
        }

        Integration_Request__c ir = [
            SELECT Id, Request_Name__c, Customer_Email__c, Request_Details__c, Status__c
            FROM Integration_Request__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Build the payload BEFORE any DML — a callout cannot follow uncommitted DML.
        OutboundRequest payload = new OutboundRequest();
        payload.requestName    = ir.Request_Name__c;
        payload.customerEmail  = ir.Customer_Email__c;
        payload.requestDetails = ir.Request_Details__c;
        payload.sourceRecordId = ir.Id;
        payload.sourceOrg      = UserInfo.getOrganizationName();

        SyncResult result = new SyncResult();

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(payload));

            HttpResponse res = new Http().send(req);
            Integer status = res.getStatusCode();

            TargetResponse tr;
            try {
                tr = (TargetResponse) JSON.deserialize(res.getBody(), TargetResponse.class);
            } catch (Exception parseEx) {
                tr = null;
            }

            if (status >= 200 && status < 300 && tr != null && tr.success == true) {
                ir.Status__c             = 'Success';
                ir.External_Record_Id__c = tr.externalRecordId;
                ir.Response_Message__c   = tr.message;

                result.success          = true;
                result.message          = String.isNotBlank(tr.message)
                                            ? tr.message
                                            : 'Request sent successfully.';
                result.externalRecordId = tr.externalRecordId;
            } else {
                String msg = (tr != null && String.isNotBlank(tr.message))
                    ? tr.message
                    : 'Target Org returned HTTP ' + status;
                ir.Status__c           = 'Failed';
                ir.Response_Message__c = msg;

                result.success = false;
                result.message = msg;
            }
        } catch (Exception e) {
            ir.Status__c           = 'Failed';
            ir.Response_Message__c = 'Callout error: ' + e.getMessage();

            result.success = false;
            result.message = ir.Response_Message__c;
        }

        ir.Last_Synced_Date__c = System.now();
        update ir;

        return result;
    }
}
