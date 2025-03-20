

# **Salesforce to Salesforce Integration using OAuth 2.0**  

This guide provides a step-by-step approach to integrating two Salesforce orgs using **OAuth 2.0**, enabling data retrieval and updates across the orgs.

---

## **Prerequisites**  
- Two Salesforce orgs (Source & Target)  
- Admin access to both orgs  
- Enabled API access  

---

## **Steps to Implement Integration**  

### **STEP 1: Create a Connected App in Target ORG**  
1. Navigate to **Setup** → **App Manager**.  
2. Click **New Connected App**.  
3. Provide **Basic Information**:  
   - Name: `SalesforceOrgIntegration`  
   - API Name: `SalesforceOrgIntegration`  
   - Contact Email: `your-email@example.com`  
4. Under **API (Enable OAuth Settings)**:  
   - ✅ **Enable OAuth Settings**  
   - Callback URL: `https://login.salesforce.com/services/oauth2/callback`  (dummy URL for timebeing)
   - Select OAuth Scopes:  
     - **Full access (full)**
     - **Perform requests on your behalf at any time (refresh_token, offline_access)**  
5. Click **Save & Continue**.  
6. Copy the **Consumer Key** and **Consumer Secret** (needed for Source org authentication).  
![image](https://github.com/user-attachments/assets/0b5cfd4e-330c-4a70-a271-a8443edbf0d2)
![image](https://github.com/user-attachments/assets/0ed6cd2b-3ca5-48be-98f2-a886606bbc81)


---

### **STEP 2: Create an Auth Provider in Source ORG**  
1. Navigate to **Setup** → Search **Auth Provider** → Click **New**.  
2. Select **Salesforce** as the provider type.  
3. Provide the details:  
   - **Name**: `TargetOrgAuth`  
   - **URL Suffix**: `targetorgauth`  
   - **Consumer Key**: (from Step 1)  
   - **Consumer Secret**: (from Step 1)  
   - **Authorize Endpoint URL**: `https://login.salesforce.com/services/oauth2/authorize`  
   - **Token Endpoint URL**: `https://login.salesforce.com/services/oauth2/token`  
4. Click **Save** and copy the **Callback URL** generated.  
5. Go back to **Connected App in Target ORG**, edit it, and add this **Callback URL**.
   ![image](https://github.com/user-attachments/assets/a08ae83c-0a6c-4739-8dc5-608bbb930406)
 

---

### **STEP 3: Create a Named Credential in Source ORG**  
1. Navigate to **Setup** → Search **Named Credentials** → Click **New**.  
2. Provide the details:  
   - **Label**: `TargetOrg_NC`  
   - **Name**: `TargetOrg_NC`  
   - **URL**: `https://your-target-org.my.salesforce.com`  (copy the current my domain URL from the my domain of target Org)
   - **Identity Type**: Named Principal  
   - **Authentication Protocol**: OAuth 2.0  
   - **Auth Provider**: Select the Auth Provider created in Step 2  
3. Click **Save**.
4. After this a login page occurs where you have to login to target org.
   ![image](https://github.com/user-attachments/assets/9177826b-2b35-43b2-9251-171fde78e9bb)


---

### **STEP 4: Create an HTTP Callout Class in Source ORG**  
Create an Apex class in the **Source Org** to make API requests to the **Target Org**.  

#### **Apex Class: AccountHelper.cls**  

Create LWC component for display 
#### **LWC Component: getAccountdetailsifrequiredsaveaccountdetailstoo**


---

### **STEP 5: Create a REST Apex Class in Target ORG**  
Create a REST API to handle account operations in the **Target Org**.  
#### **Apex Class: RestApiUsingConnectClass.cls**  



## **Testing the Integration**  

1. **Retrieve Accounts from Target Org**  
   - Execute `AccountHelper.getAccountList()` in the **Source Org** Developer Console.  
   - The response should contain account details from the **Target Org**.  

2. **Create or Update an Account in Target Org**  
   - Execute `AccountHelper.createOrUpdateAccount()` with account details.  
   - Verify the new account in the **Target Org** under **Accounts**.  

---

## **Troubleshooting & Debugging**  
- If you receive an `Unauthorized` error, ensure:  
  - The **Connected App** in **Target Org** is **approved** for access.  
  - The **Auth Provider & Named Credential** are correctly configured.  
- If API calls fail:  
  - Check **Debug Logs** for errors.  
  - Verify the correct **endpoint URL** in Named Credentials.  
  - Ensure the **OAuth Scopes** include `full` and `refresh_token`.  

---

## **References**  
- [Salesforce Named Credentials](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_named_credentials.htm)  
- [Salesforce REST API Guide](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/)  
- [OAuth 2.0 Authorization in Salesforce](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_web_server_flow.htm&type=5)
- https://www.youtube.com/watch?v=xWvnUc-w-4o 

---



