public with sharing class AccountHelper {
    public class AccountResponse {
        public String Id { get; set; }
        public String Name { get; set; }
        public String Type { get; set; }
        public Decimal AnnualRevenue { get; set; }
        public String Phone { get; set; }
        public String Website { get; set; }
        public String Rating { get; set; }
    }
    public class AccountRequest {
        public String Name { get; set; }
        public String Type { get; set; }
        public Decimal AnnualRevenue { get; set; }
        public String Phone { get; set; }
        public String Website { get; set; }
        public String Rating { get; set; }
    }
    

    @AuraEnabled(cacheable=true)

    public static List<Account> getAccountList() {        
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:testConnection/services/apexrest/Account/');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setMethod('GET');
               Http http = new Http();
            HttpResponse res = http.send(req);
            List<Account> accList = new List<Account>();
            System.debug('Response code: ' + res.getStatusCode());
            System.debug('Response body: ' + res.getBody());
            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('Response body: ' + responseBody);
                
                // Call the method to parse and get the list of accounts
                List<AccountResponse> accounts1 = (List<AccountResponse>) JSON.deserialize(responseBody, List<AccountResponse>.class);
                
                List<Account> accounts = new List<Account>();
        for (AccountResponse ar : accounts1) {
            Account acc = new Account();
            acc.Id = ar.Id;
            acc.Name = ar.Name;
            acc.Type = ar.Type;
            acc.AnnualRevenue = ar.AnnualRevenue;
            acc.Phone = ar.Phone;
            acc.Website = ar.Website;
            acc.Rating = ar.Rating;
            accounts.add(acc);
        }
        return accounts;
            } else {
                System.debug('Error: ' + res.getStatus() + ' ' + res.getStatusCode());
            }
            return null;

    }

    @AuraEnabled
    public static void sendAccountDetails(String acc) {
        System.debug('Request body: ' + acc);
        AccountRequest ar=(AccountRequest) JSON.deserialize(acc, AccountRequest.class);
        HttpRequest req = new HttpRequest();
        Account acc1=new Account(Name=ar.Name,Type=ar.Type,AnnualRevenue=ar.AnnualRevenue,Phone=ar.Phone,Website=ar.Website,Rating=ar.Rating);
        String accountJson = JSON.serialize(new Map<String, Object>{
            'Name' => acc1.Name,
            'Type' => acc1.Type,
            'AnnualRevenue' => acc1.AnnualRevenue,
            'Phone' => acc1.Phone,
            'Website' => acc1.Website,
            'Rating' => acc1.Rating
        });

        req.setEndpoint('callout:testConnection/services/apexrest/Account/');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setMethod('POST');
        System.debug('Request body: ' + req);
        req.setBody(accountJson);
        System.debug('Request body: ' + req.getBody());
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Response body: ' + res.getStatus());
        System.debug('Response body: ' + res.getBody() + ' ' + res.getStatusCode());
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to send account details: ' + res.getStatus() + ' ' + res.getStatusCode());
        }
    }

}
