/**
 * MWD26 demo — reusable, fail-safe logger for Integration_Log__c.
 *
 * Keeps logging out of the Queueable's core flow. If the log insert itself
 * fails, the failure is swallowed (debug-logged only) so it can never mask or
 * roll back the real integration result.
 */
public with sharing class IntegrationLogger {

    /** Mutable holder describing one log row. */
    public class LogEntry {
        public Id integrationRequestId;
        public String direction = 'Outbound';
        public String integrationName;
        public String endpoint;
        public String httpMethod;
        public String status;
        public Integer statusCode;
        public String requestPayload;
        public String responseBody;
        public String errorMessage;
        public String externalRecordId;
        public String queueableJobId;
        public String correlationId;
        public Datetime startedAt;
        public Datetime completedAt;
    }

    /** Factory for a fresh entry. */
    public static LogEntry newEntry() {
        return new LogEntry();
    }

    /**
     * Inserts the log row. Never throws — a logging failure must not break the
     * integration response that has already been written to Integration_Request__c.
     */
    public static Integration_Log__c log(LogEntry e) {
        Integration_Log__c rec = toRecord(e);
        try {
            insert rec;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'IntegrationLogger: failed to insert Integration_Log__c — ' + ex.getMessage());
        }
        return rec;
    }

    private static Integration_Log__c toRecord(LogEntry e) {
        return new Integration_Log__c(
            Integration_Request__c = e.integrationRequestId,
            Direction__c           = e.direction,
            Integration_Name__c    = e.integrationName,
            Endpoint__c            = e.endpoint,
            HTTP_Method__c         = e.httpMethod,
            Status__c              = e.status,
            Status_Code__c         = e.statusCode,
            Request_Payload__c     = e.requestPayload,
            Response_Body__c       = e.responseBody,
            Error_Message__c       = e.errorMessage,
            External_Record_Id__c  = e.externalRecordId,
            Queueable_Job_Id__c    = e.queueableJobId,
            Correlation_Id__c      = e.correlationId,
            Started_At__c          = e.startedAt,
            Completed_At__c        = e.completedAt
        );
    }
}
