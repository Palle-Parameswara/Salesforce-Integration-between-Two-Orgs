// MWD26 demo — create a sample Integration_Request__c in the SOURCE org.
// Run with:  sf apex run -f scripts/apex/create_sample_request.apex -o MWD26_Source
Integration_Request__c ir = new Integration_Request__c(
    Request_Name__c    = 'New customer onboarding',
    Customer_Email__c  = 'jane.customer@example.com',
    Request_Details__c = 'Please onboard Jane Customer into the back-office system.',
    Status__c          = 'Draft'
);
insert ir;
System.debug('Created Integration_Request__c: ' + ir.Id);
