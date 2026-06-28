/**
 * MWD26 demo — LWC entry point for the Back Office sync.
 *
 * Keeps the user-facing request fast: it validates, guards against duplicates,
 * marks the record as Sending, and hands the actual callout off to a Queueable.
 */
public with sharing class IntegrationRequestController {

    /** Lightweight response for the LWC. */
    public class SyncStartResult {
        @AuraEnabled public Boolean started;
        @AuraEnabled public String message;
        @AuraEnabled public String jobId;
        @AuraEnabled public String correlationId;

        public SyncStartResult(Boolean started, String message) {
            this.started = started;
            this.message = message;
        }
    }

    @AuraEnabled
    public static SyncStartResult sendToBackOffice(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('No record Id was provided.');
        }

        Integration_Request__c ir = [
            SELECT Id, Status__c, External_Record_Id__c
            FROM Integration_Request__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Duplicate guard — already synced successfully, so don't send again.
        if (ir.Status__c == 'Success' && String.isNotBlank(ir.External_Record_Id__c)) {
            return new SyncStartResult(false, 'This request is already synced to Back Office.');
        }

        // Mark as Sending (synchronous DML is fine — the callout runs async).
        ir.Status__c = 'Sending';
        update ir;

        String correlationId = String.valueOf(recordId) + '-' + String.valueOf(Datetime.now().getTime());
        Id jobId = System.enqueueJob(new IntegrationRequestSyncQueueable(recordId, correlationId));

        SyncStartResult result = new SyncStartResult(
            true,
            'Sync started. Refresh the record in a few seconds to see the result.'
        );
        result.jobId = jobId;
        result.correlationId = correlationId;
        return result;
    }
}
