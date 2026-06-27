@IsTest
private class IntegrationRequestServiceTest {

    /** Mock that mimics a successful Target Org response (HTTP 201). */
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod(), 'Callout should be POST');
            System.assert(req.getEndpoint().startsWith('callout:Target_Org_NC'),
                'Callout must use the Named Credential');
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"success":true,"externalRecordId":"a0XAB0000001234","message":"External Request created successfully."}');
            return res;
        }
    }

    /** Mock that mimics a validation failure from the Target Org (HTTP 400). */
    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"success":false,"externalRecordId":null,"message":"Missing required field(s): customerEmail"}');
            return res;
        }
    }

    /** Mock that throws, to exercise the catch/exception path. */
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated connection failure');
        }
    }

    private static Integration_Request__c makeRequest() {
        Integration_Request__c ir = new Integration_Request__c(
            Request_Name__c    = 'Test Request',
            Customer_Email__c  = 'test@example.com',
            Request_Details__c = 'Some request details',
            Status__c          = 'Draft'
        );
        insert ir;
        return ir;
    }

    @IsTest
    static void sendRequest_success() {
        Integration_Request__c ir = makeRequest();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        IntegrationRequestService.SyncResult result = IntegrationRequestService.sendRequest(ir.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success');
        System.assertEquals('a0XAB0000001234', result.externalRecordId);

        Integration_Request__c updated = [
            SELECT Status__c, External_Record_Id__c, Response_Message__c, Last_Synced_Date__c
            FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Success', updated.Status__c);
        System.assertEquals('a0XAB0000001234', updated.External_Record_Id__c);
        System.assertNotEquals(null, updated.Last_Synced_Date__c, 'Sync date should be set');
    }

    @IsTest
    static void sendRequest_targetValidationFailure() {
        Integration_Request__c ir = makeRequest();
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Test.startTest();
        IntegrationRequestService.SyncResult result = IntegrationRequestService.sendRequest(ir.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure');

        Integration_Request__c updated = [
            SELECT Status__c, Response_Message__c, Last_Synced_Date__c
            FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Failed', updated.Status__c);
        System.assert(updated.Response_Message__c.contains('customerEmail'),
            'Should capture the validation message');
        System.assertNotEquals(null, updated.Last_Synced_Date__c);
    }

    @IsTest
    static void sendRequest_calloutException() {
        Integration_Request__c ir = makeRequest();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        IntegrationRequestService.SyncResult result = IntegrationRequestService.sendRequest(ir.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure on exception');

        Integration_Request__c updated = [
            SELECT Status__c, Response_Message__c FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Failed', updated.Status__c);
        System.assert(updated.Response_Message__c.startsWith('Callout error:'),
            'Should record the callout error');
    }

    @IsTest
    static void sendRequest_nullId_throws() {
        Test.startTest();
        try {
            IntegrationRequestService.sendRequest(null);
            System.assert(false, 'Expected an AuraHandledException');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }
}
