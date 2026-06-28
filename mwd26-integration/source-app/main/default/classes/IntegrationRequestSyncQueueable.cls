/**
 * MWD26 demo — async worker for the Back Office sync.
 *
 * The controller enqueues this so the LWC doesn't block on the callout. The job
 * performs the HTTP callout, writes the result back onto Integration_Request__c,
 * and always records an Integration_Log__c row (success or failure).
 */
public with sharing class IntegrationRequestSyncQueueable
        implements Queueable, Database.AllowsCallouts {

    @TestVisible
    private static final String ENDPOINT =
        'callout:Target_Org_NC/services/apexrest/mwd26/requests';
    private static final String INTEGRATION_NAME = 'Back Office Sync';
    private static final String HTTP_METHOD = 'POST';

    private final Id recordId;
    private final String correlationId;

    public IntegrationRequestSyncQueueable(Id recordId, String correlationId) {
        this.recordId = recordId;
        this.correlationId = correlationId;
    }

    public void execute(QueueableContext ctx) {
        Datetime startedAt = System.now();

        Integration_Request__c ir = [
            SELECT Id, Request_Name__c, Customer_Email__c, Request_Details__c, Status__c
            FROM Integration_Request__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Build the payload.
        IntegrationRequestDTO.OutboundRequest payload = new IntegrationRequestDTO.OutboundRequest();
        payload.requestName    = ir.Request_Name__c;
        payload.customerEmail  = ir.Customer_Email__c;
        payload.requestDetails = ir.Request_Details__c;
        payload.sourceRecordId = ir.Id;
        payload.sourceOrg      = UserInfo.getOrganizationName();
        String requestBody = JSON.serialize(payload);

        // Prepare the log entry up front so every exit path can complete it.
        IntegrationLogger.LogEntry logEntry = IntegrationLogger.newEntry();
        logEntry.integrationRequestId = ir.Id;
        logEntry.integrationName = INTEGRATION_NAME;
        logEntry.endpoint = ENDPOINT;
        logEntry.httpMethod = HTTP_METHOD;
        logEntry.requestPayload = requestBody;
        logEntry.queueableJobId = ctx == null ? null : ctx.getJobId();
        logEntry.correlationId = correlationId;
        logEntry.startedAt = startedAt;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod(HTTP_METHOD);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBody);

            HttpResponse res = new Http().send(req);
            Integer status = res.getStatusCode();
            String body = res.getBody();

            logEntry.statusCode = status;
            logEntry.responseBody = body;

            IntegrationRequestDTO.TargetResponse tr;
            try {
                tr = (IntegrationRequestDTO.TargetResponse)
                    JSON.deserialize(body, IntegrationRequestDTO.TargetResponse.class);
            } catch (Exception parseEx) {
                tr = null;
            }

            if (status >= 200 && status < 300 && tr != null && tr.success == true) {
                ir.Status__c             = 'Success';
                ir.External_Record_Id__c = tr.externalRecordId;
                ir.Response_Message__c   = tr.message;

                logEntry.status = 'Success';
                logEntry.externalRecordId = tr.externalRecordId;
            } else {
                String msg = (tr != null && String.isNotBlank(tr.message))
                    ? tr.message
                    : 'Target Org returned HTTP ' + status;
                ir.Status__c           = 'Failed';
                ir.Response_Message__c = msg;

                logEntry.status = 'Failed';
                logEntry.errorMessage = msg;
            }
        } catch (Exception e) {
            ir.Status__c           = 'Failed';
            ir.Response_Message__c = 'Callout error: ' + e.getMessage();

            logEntry.status = 'Failed';
            logEntry.errorMessage = 'Callout error: ' + e.getMessage();
        }

        // Write the result back. Logging is separate and must not break this.
        ir.Last_Synced_Date__c = System.now();
        update ir;

        logEntry.completedAt = System.now();
        IntegrationLogger.log(logEntry);
    }
}
