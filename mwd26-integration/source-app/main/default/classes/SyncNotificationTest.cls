@IsTest
private class SyncNotificationTest {

    @IsTest
    static void publish_delivers_and_subscriber_logs() {
        Integration_Request__c ir = new Integration_Request__c(
            Request_Name__c = 'PubSub test',
            Customer_Email__c = 'pubsub@example.com',
            Status__c = 'Success'
        );
        insert ir;

        Test.startTest();
        SyncNotificationPublisher.publish(
            ir.Id, 'IR-TEST', 'Success', 'a00PUBSUB0001', 'Processed by pub/sub', 'corr-pubsub-1'
        );
        Test.stopTest(); // delivers the platform event -> subscriber trigger runs

        List<Integration_Log__c> logs = [
            SELECT Direction__c, Status__c, Integration_Name__c, Response_Body__c, Integration_Request__c
            FROM Integration_Log__c WHERE Correlation_Id__c = 'corr-pubsub-1'
        ];
        System.assertEquals(1, logs.size(), 'Subscriber should have created one log');
        System.assertEquals('Inbound', logs[0].Direction__c);
        System.assertEquals('Success', logs[0].Status__c);
        System.assertEquals('Pub/Sub: Sync Notification', logs[0].Integration_Name__c);
        System.assertEquals(ir.Id, logs[0].Integration_Request__c, 'Should link back to the request');
    }

    @IsTest
    static void failedStatus_maps_toFailed() {
        Test.startTest();
        SyncNotificationPublisher.publish(
            null, 'IR-TEST2', 'Failed', null, 'Something went wrong', 'corr-pubsub-2'
        );
        Test.stopTest();

        Integration_Log__c log = [
            SELECT Status__c, Direction__c FROM Integration_Log__c WHERE Correlation_Id__c = 'corr-pubsub-2' LIMIT 1
        ];
        System.assertEquals('Failed', log.Status__c);
        System.assertEquals('Inbound', log.Direction__c);
    }
}
