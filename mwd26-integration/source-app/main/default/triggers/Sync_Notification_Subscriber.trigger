/**
 * MWD26 demo — subscriber side of the pub/sub example.
 *
 * Fires when a Sync_Notification__e is published and records an Integration_Log__c
 * row (Direction = Inbound) so you can SEE that the event was received. Runs as the
 * Automated Process user, so it swallows errors rather than throwing.
 */
trigger Sync_Notification_Subscriber on Sync_Notification__e (after insert) {
    List<Integration_Log__c> logs = new List<Integration_Log__c>();

    for (Sync_Notification__e evt : Trigger.New) {
        String status = (evt.Status__c == 'Success')
            ? 'Success'
            : (evt.Status__c == 'Failed' ? 'Failed' : 'Queued');

        Integration_Log__c log = new Integration_Log__c(
            Direction__c        = 'Inbound',
            Integration_Name__c = 'Pub/Sub: Sync Notification',
            Status__c           = status,
            Response_Body__c    = evt.Message__c,
            External_Record_Id__c = evt.External_Record_Id__c,
            Correlation_Id__c   = evt.Correlation_Id__c,
            Completed_At__c     = System.now()
        );
        if (String.isNotBlank(evt.Integration_Request_Id__c)) {
            log.Integration_Request__c = evt.Integration_Request_Id__c;
        }
        logs.add(log);
    }

    try {
        if (!logs.isEmpty()) {
            insert logs;
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Sync_Notification_Subscriber failed: ' + e.getMessage());
    }
}
