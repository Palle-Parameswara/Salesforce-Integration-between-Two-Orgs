@IsTest
private class IntegrationRequestControllerTest {

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"success":true,"externalRecordId":"a00CTRL000001","message":"External Request created successfully."}');
            return res;
        }
    }

    private static Integration_Request__c makeRequest(String status, String extId) {
        Integration_Request__c ir = new Integration_Request__c(
            Request_Name__c    = 'Controller Test',
            Customer_Email__c  = 'ctest@example.com',
            Request_Details__c = 'Controller details',
            Status__c          = status,
            External_Record_Id__c = extId
        );
        insert ir;
        return ir;
    }

    @IsTest
    static void sendToBackOffice_enqueuesAndSyncs() {
        Integration_Request__c ir = makeRequest('Draft', null);
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        IntegrationRequestController.SyncStartResult result =
            IntegrationRequestController.sendToBackOffice(ir.Id);

        // Immediately after the controller returns, the record is "Sending".
        System.assertEquals(true, result.started, 'Sync should start');
        System.assertNotEquals(null, result.jobId, 'A job id should be returned');
        Integration_Request__c mid = [SELECT Status__c FROM Integration_Request__c WHERE Id = :ir.Id];
        System.assertEquals('Sending', mid.Status__c, 'Status should be Sending before the job runs');

        Test.stopTest(); // runs the queueable

        Integration_Request__c done = [
            SELECT Status__c, External_Record_Id__c FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Success', done.Status__c);
        System.assertEquals('a00CTRL000001', done.External_Record_Id__c);
        System.assertEquals(1, [SELECT COUNT() FROM Integration_Log__c WHERE Integration_Request__c = :ir.Id]);
    }

    @IsTest
    static void sendToBackOffice_duplicatePrevention() {
        // Already synced successfully.
        Integration_Request__c ir = makeRequest('Success', 'a00EXISTING001');

        Test.startTest();
        IntegrationRequestController.SyncStartResult result =
            IntegrationRequestController.sendToBackOffice(ir.Id);
        Test.stopTest();

        System.assertEquals(false, result.started, 'Should not start a duplicate sync');
        System.assert(result.message.contains('already synced'), 'Should explain it is already synced');

        Integration_Request__c after = [SELECT Status__c FROM Integration_Request__c WHERE Id = :ir.Id];
        System.assertEquals('Success', after.Status__c, 'Status must be unchanged');
        System.assertEquals(0, [SELECT COUNT() FROM Integration_Log__c], 'No log for a skipped duplicate');
    }

    @IsTest
    static void sendToBackOffice_nullId_throws() {
        Test.startTest();
        try {
            IntegrationRequestController.sendToBackOffice(null);
            System.assert(false, 'Expected an AuraHandledException');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }
}
