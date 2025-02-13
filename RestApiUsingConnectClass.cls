@RestResource(urlMapping='/Account/*')
global with sharing class RestApiUsingConnectClass {
    public class AccountResponse {
        public String Name { get; set; }
        public String Type { get; set; }
        public Decimal AnnualRevenue { get; set; }
        public String Phone { get; set; }
        public String Website { get; set; }
        public String Rating { get; set; }
    }
    
    @HttpGet
    global static List<Account> getAccounts(){
        System.debug('GET Method has been called');
        return [Select Id,Name,Type,AnnualRevenue,Phone,Website,Rating  from Account];    }
    
    @HttpPost
    global static String createAccount(String Name,String Type,Decimal AnnualRevenue,String Phone,String Website,String Rating){
        System.debug('POST Method has been called');
        System.debug(Name+' '+Type+' '+AnnualRevenue+' '+Phone+' '+Website+' '+Rating);
        RestRequest req = RestContext.request;
        List<Account> accList = [SELECT Id, Name, Type, AnnualRevenue, Phone, Website, Rating 
                                 FROM Account 
                                 WHERE Name = :Name LIMIT 1];
        
        Account acc2;
        if (!accList.isEmpty()) {
            acc2 = accList[0];  // Assign only if the list has records
        } else {
            acc2 = null;  
        }
        if(acc2!=null){
            acc2.Name = Name;
            acc2.Type = Type;
            acc2.AnnualRevenue = AnnualRevenue;
            acc2.Phone = Phone;
            acc2.Website = Website;
            acc2.Rating = Rating;  
            update acc2;
            return 'Account updated successfully';
        }
        else{
            Account acc = new Account();
            acc.Name = Name;
            acc.Type = Type;
            acc.AnnualRevenue = AnnualRevenue;
            acc.Phone = Phone;
            acc.Website = Website;
            acc.Rating = Rating;
            System.debug('Post Method has been called');
            insert acc;
            return 'Account created successfully';            
        }
    }
}
