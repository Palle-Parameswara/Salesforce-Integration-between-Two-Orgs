/**
 * MWD26 demo — publisher side of the pub/sub example.
 *
 * Publishes a Sync_Notification__e Platform Event. Standalone: nothing calls this
 * automatically today. To wire it into the real flow later, call publish(...) at
 * the end of IntegrationRequestSyncQueueable.execute().
 */
public with sharing class SyncNotificationPublisher {

    /** Publish a single sync-notification event. Returns the EventBus save result. */
    public static Database.SaveResult publish(
        String integrationRequestId,
        String requestNumber,
        String status,
        String externalRecordId,
        String message,
        String correlationId
    ) {
        Sync_Notification__e evt = new Sync_Notification__e(
            Integration_Request_Id__c = integrationRequestId,
            Request_Number__c         = requestNumber,
            Status__c                 = status,
            External_Record_Id__c     = externalRecordId,
            Message__c                = message,
            Correlation_Id__c         = correlationId
        );
        return EventBus.publish(evt);
    }
}
