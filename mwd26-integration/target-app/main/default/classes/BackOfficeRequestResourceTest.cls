@IsTest
private class BackOfficeRequestResourceTest {

    /** Builds a REST context with the given JSON body and returns the RestResponse. */
    private static RestResponse setupContext(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/mwd26/requests';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return RestContext.response;
    }

    @IsTest
    static void post_success_createsRecord() {
        String body = JSON.serialize(new Map<String, Object>{
            'requestName'    => 'MWD Demo',
            'customerEmail'  => 'demo@example.com',
            'requestDetails' => 'Please process this request',
            'sourceRecordId' => 'a0X000000000ABC',
            'sourceOrg'      => 'Source Org'
        });
        RestResponse res = setupContext(body);

        Test.startTest();
        BackOfficeRequestResource.ApiResponse resp = BackOfficeRequestResource.handlePost();
        Test.stopTest();

        System.assertEquals(true, resp.success, 'Expected success');
        System.assertEquals(201, res.statusCode, 'Expected HTTP 201');

        List<External_Request__c> recs = [
            SELECT Id, Request_Name__c, Customer_Email__c, Processing_Status__c, Source_Record_Id__c
            FROM External_Request__c
        ];
        System.assertEquals(1, recs.size(), 'One record should be created');
        System.assertEquals('MWD Demo', recs[0].Request_Name__c);
        System.assertEquals('Completed', recs[0].Processing_Status__c);
        System.assertEquals('a0X000000000ABC', recs[0].Source_Record_Id__c);
        System.assertEquals(resp.externalRecordId, recs[0].Id, 'Response Id should match record');
    }

    @IsTest
    static void post_missingRequiredFields_returns400() {
        String body = JSON.serialize(new Map<String, Object>{
            'requestDetails' => 'No name or email supplied'
        });
        RestResponse res = setupContext(body);

        Test.startTest();
        BackOfficeRequestResource.ApiResponse resp = BackOfficeRequestResource.handlePost();
        Test.stopTest();

        System.assertEquals(false, resp.success, 'Expected failure');
        System.assertEquals(400, res.statusCode, 'Expected HTTP 400');
        System.assert(resp.message.contains('requestName'), 'Message should name missing fields');
        System.assertEquals(0, [SELECT COUNT() FROM External_Request__c], 'No record should be created');
    }

    @IsTest
    static void post_emptyBody_returns400() {
        RestResponse res = setupContext('');

        Test.startTest();
        BackOfficeRequestResource.ApiResponse resp = BackOfficeRequestResource.handlePost();
        Test.stopTest();

        System.assertEquals(false, resp.success, 'Expected failure on empty body');
        System.assertEquals(400, res.statusCode, 'Expected HTTP 400');
    }
}
