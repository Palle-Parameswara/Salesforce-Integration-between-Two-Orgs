@IsTest
private class IntegrationRequestSyncQueueableTest {

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().startsWith('callout:Target_Org_NC'),
                'Callout must use the Named Credential');
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"success":true,"externalRecordId":"a00XX0000012345","message":"External Request created successfully."}');
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"success":false,"externalRecordId":null,"message":"Missing required field(s): customerEmail"}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated connection failure');
        }
    }

    private static Integration_Request__c makeRequest() {
        Integration_Request__c ir = new Integration_Request__c(
            Request_Name__c    = 'Queueable Test',
            Customer_Email__c  = 'qtest@example.com',
            Request_Details__c = 'Async details',
            Status__c          = 'Sending'
        );
        insert ir;
        return ir;
    }

    @IsTest
    static void queueable_success() {
        Integration_Request__c ir = makeRequest();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        System.enqueueJob(new IntegrationRequestSyncQueueable(ir.Id, 'corr-success-1'));
        Test.stopTest();

        Integration_Request__c updated = [
            SELECT Status__c, External_Record_Id__c, Response_Message__c, Last_Synced_Date__c
            FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Success', updated.Status__c);
        System.assertEquals('a00XX0000012345', updated.External_Record_Id__c);
        System.assertNotEquals(null, updated.Last_Synced_Date__c);

        Integration_Log__c log = [
            SELECT Status__c, Status_Code__c, Request_Payload__c, Response_Body__c,
                   External_Record_Id__c, Queueable_Job_Id__c, Correlation_Id__c,
                   Started_At__c, Completed_At__c, Endpoint__c, HTTP_Method__c, Direction__c
            FROM Integration_Log__c WHERE Integration_Request__c = :ir.Id
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals('Success', log.Status__c);
        System.assertEquals(201, log.Status_Code__c);
        System.assertEquals('Outbound', log.Direction__c);
        System.assertEquals('POST', log.HTTP_Method__c);
        System.assert(log.Endpoint__c.startsWith('callout:Target_Org_NC'));
        System.assert(String.isNotBlank(log.Request_Payload__c), 'Payload should be captured');
        System.assert(String.isNotBlank(log.Response_Body__c), 'Response should be captured');
        System.assertEquals('a00XX0000012345', log.External_Record_Id__c);
        System.assertEquals('corr-success-1', log.Correlation_Id__c);
        System.assertNotEquals(null, log.Queueable_Job_Id__c, 'Job id should be captured');
        System.assertNotEquals(null, log.Started_At__c);
        System.assertNotEquals(null, log.Completed_At__c);
    }

    @IsTest
    static void queueable_failureResponse() {
        Integration_Request__c ir = makeRequest();
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Test.startTest();
        System.enqueueJob(new IntegrationRequestSyncQueueable(ir.Id, 'corr-fail-1'));
        Test.stopTest();

        Integration_Request__c updated = [
            SELECT Status__c, Response_Message__c FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Failed', updated.Status__c);
        System.assert(updated.Response_Message__c.contains('customerEmail'));

        Integration_Log__c log = [
            SELECT Status__c, Status_Code__c, Error_Message__c
            FROM Integration_Log__c WHERE Integration_Request__c = :ir.Id LIMIT 1
        ];
        System.assertEquals('Failed', log.Status__c);
        System.assertEquals(400, log.Status_Code__c);
        System.assert(log.Error_Message__c.contains('customerEmail'));
    }

    @IsTest
    static void queueable_calloutException() {
        Integration_Request__c ir = makeRequest();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        System.enqueueJob(new IntegrationRequestSyncQueueable(ir.Id, 'corr-ex-1'));
        Test.stopTest();

        Integration_Request__c updated = [
            SELECT Status__c, Response_Message__c FROM Integration_Request__c WHERE Id = :ir.Id
        ];
        System.assertEquals('Failed', updated.Status__c);
        System.assert(updated.Response_Message__c.startsWith('Callout error:'));

        Integration_Log__c log = [
            SELECT Status__c, Status_Code__c, Error_Message__c
            FROM Integration_Log__c WHERE Integration_Request__c = :ir.Id LIMIT 1
        ];
        System.assertEquals('Failed', log.Status__c);
        System.assertEquals(null, log.Status_Code__c, 'No HTTP status on a thrown callout');
        System.assert(log.Error_Message__c.startsWith('Callout error:'));
    }
}
