# Admin-Assisted Back Office Sync — Screen Flow + HTTP Callout (no-code)

This is the **admin path** companion to the developer (LWC + Queueable) demo. It
sends data to the same Target Org REST endpoint using a **Screen Flow** and the
native **HTTP Callout in Flow** — no Apex, no LWC. It reuses the existing Named
Credential and the `Integration_Request__c` / `Integration_Log__c` objects.

> Built interactively in Flow Builder (the HTTP Callout action generates an
> External Service, so it isn't shipped as repo metadata). Follow these steps in
> the **Source Org (MWD26_Source)**.

- **Flow name (API):** `Admin_Assisted_Back_Office_Sync`
- **Flow label:** Admin Assisted Back Office Sync
- **Endpoint path:** `/services/apexrest/mwd26/requests` (POST)
- **Named Credential:** `Target_Org_NC` (already configured)

---

## Prerequisites
- `Target_Org_NC` + External Credential `Target_Org_EC` are **authenticated**
  (see `NAMED_CREDENTIAL_SETUP.md`).
- The user running the flow has the **MWD26 Source Access** permission set
  (grants `Integration_Request__c` + `Integration_Log__c` access **and** the
  External Credential Principal Access the callout needs).

---

## Part 1 — Create the HTTP Callout action

You can start this from **Setup → External Services → New** *or* directly inside
Flow Builder (Part 2) via **Add Action → Create HTTP Callout**. Either way:

1. **External Service name:** `BackOfficeService`
2. **Named Credential:** select **`Target_Org_NC`**  *(this is what keeps the URL
   and OAuth tokens out of the flow)*.
3. Add an **invocable action**:
   - **Label:** `Send Back Office Request`
   - **URL Path:** `/services/apexrest/mwd26/requests`  *(relative to the Named Credential)*
   - **Method:** `POST`
4. **Provide a sample request body** (Flow generates the input structure from this):
   ```json
   {
     "requestName": "Sample request name",
     "customerEmail": "sample@example.com",
     "requestDetails": "Sample request details",
     "sourceRecordId": "a00000000000000",
     "sourceOrg": "Source"
   }
   ```
5. **Provide a sample response body** (Flow generates the output structure):
   ```json
   {
     "success": true,
     "externalRecordId": "a00000000000000",
     "message": "External Request created successfully."
   }
   ```
6. **Save**. Flow now has a `Send Back Office Request` action with typed inputs
   (`requestName`, `customerEmail`, `requestDetails`, `sourceRecordId`,
   `sourceOrg`) and a typed **2XX** response (`success`, `externalRecordId`,
   `message`).

> **Important:** a non-2xx response (e.g. the validation **400**) makes the action
> **fault**. We handle that with a Fault path in Part 2 — that's how the failure
> demo works.

---

## Part 2 — Build the Screen Flow

New **Screen Flow** named `Admin_Assisted_Back_Office_Sync`. Add these elements in
order.

### Resources to create first
- **Variable** `varRequestId` — Text *(holds the new record Id)*
- **Variable** `varStartedAt` — Date/Time
- **Text Template** `tplRequestPayload` (View as **Plain Text**):
  ```
  {
    "requestName": "{!Collect_Request.Request_Name}",
    "customerEmail": "{!Collect_Request.Customer_Email}",
    "requestDetails": "{!Collect_Request.Request_Details}",
    "sourceRecordId": "{!varRequestId}",
    "sourceOrg": "Source"
  }
  ```
- Correlation Id uses the built-in **`{!$Flow.InterviewGuid}`** (unique per run).

### 1. Screen — `Collect_Request`
Three components, all **Required = true** (this is the validation):
- Text — API name `Request_Name` — label "Request Name"
- Email — API name `Customer_Email` — label "Customer Email"
- Long Text Area — API name `Request_Details` — label "Request Details"

### 2. Assignment — `Set_Start_Time`
- `varStartedAt` = `{!$Flow.CurrentDateTime}`

### 3. Create Records — `Create_Integration_Request`
- Object: **Integration_Request__c**
- Field values:
  - `Request_Name__c` = `{!Collect_Request.Request_Name}`
  - `Customer_Email__c` = `{!Collect_Request.Customer_Email}`
  - `Request_Details__c` = `{!Collect_Request.Request_Details}`
  - `Status__c` = `Sending`
- Store the new Id → set **`varRequestId`** to the created record Id
  (use "Manually assign variables" → Record Id → `varRequestId`).

### 4. Screen — `Review_And_Send`  *(this screen boundary commits the DML so the callout is legal)*
- Display Text: "You're about to send **{!Collect_Request.Request_Name}** to the
  Back Office. Click **Next** to send."
- (Optional) Display the new Integration Request via `{!varRequestId}`.

### 5. Action — `Send_Back_Office_Request` (the HTTP Callout from Part 1)
Map inputs:
- `requestName` = `{!Collect_Request.Request_Name}`
- `customerEmail` = `{!Collect_Request.Customer_Email}`
- `requestDetails` = `{!Collect_Request.Request_Details}`
- `sourceRecordId` = `{!varRequestId}`
- `sourceOrg` = `Source`

Connect **two** outgoing paths from this element:
- normal (success) → step 6
- **Fault** → step 8

### 6. Update Records — `Update_Request_Success`
- Record: filter `Id Equals {!varRequestId}`
- `Status__c` = `Success`
- `External_Record_Id__c` = `{!Send_Back_Office_Request.2XX.externalRecordId}`
- `Response_Message__c` = `{!Send_Back_Office_Request.2XX.message}`
- `Last_Synced_Date__c` = `{!$Flow.CurrentDateTime}`

### 7. Create Records — `Log_Success` → then go to **Final success screen (9)**
- Object: **Integration_Log__c**
  - `Integration_Request__c` = `{!varRequestId}`
  - `Direction__c` = `Outbound`
  - `Integration_Name__c` = `Admin Assisted Back Office Sync`
  - `Endpoint__c` = `/services/apexrest/mwd26/requests`
  - `HTTP_Method__c` = `POST`
  - `Status__c` = `Success`
  - `Status_Code__c` = `201`  *(or map the action's status-code output if shown)*
  - `Request_Payload__c` = `{!tplRequestPayload}`
  - `Response_Body__c` = (Text Template of the 2XX fields, e.g. success/externalRecordId/message)
  - `External_Record_Id__c` = `{!Send_Back_Office_Request.2XX.externalRecordId}`
  - `Correlation_Id__c` = `{!$Flow.InterviewGuid}`
  - `Started_At__c` = `{!varStartedAt}`
  - `Completed_At__c` = `{!$Flow.CurrentDateTime}`

### 8. Fault branch — `Update_Request_Failed` → `Log_Failed` → **Final failure screen (10)**
- **Update Records** `Update_Request_Failed`:
  - filter `Id Equals {!varRequestId}`
  - `Status__c` = `Failed`
  - `Response_Message__c` = `{!$Flow.FaultMessage}`
  - `Last_Synced_Date__c` = `{!$Flow.CurrentDateTime}`
- **Create Records** `Log_Failed` (Integration_Log__c):
  - same as step 7 but `Status__c` = `Failed`,
    `Error_Message__c` = `{!$Flow.FaultMessage}`, omit External Record Id,
    `Status_Code__c` = leave blank (or the code if available).

### 9. Screen — `Success_Screen`
Display Text:
> ✅ **Back Office Sync completed successfully.**
> - Source Integration Request: see `{!varRequestId}`
> - Target External Record Id: `{!Send_Back_Office_Request.2XX.externalRecordId}`
> - Response: `{!Send_Back_Office_Request.2XX.message}`

### 10. Screen — `Failure_Screen`
Display Text:
> ❌ **Back Office Sync failed.**
> - Source Integration Request: `{!varRequestId}`
> - Error: `{!$Flow.FaultMessage}`

**Save** (label *Admin Assisted Back Office Sync*, API `Admin_Assisted_Back_Office_Sync`)
and **Activate**.

---

## Part 3 — Add it as a tab in the MWD26 Demo app
Flows aren't tabs directly, so surface it via a Lightning page:
1. Setup → **Lightning App Builder** → **New** → **App Page** → one-region →
   name it `Admin Sync`.
2. Drag the **Flow** component on → Flow = **Admin Assisted Back Office Sync** →
   pass no input → **Save** → **Activate** → make it available in the
   **MWD26 Demo** app.
3. The page now appears as an item in the MWD26 Demo app navigation.

*(Quick alternative for rehearsal: run it from Setup → Flows → open → **Run**, or
the URL `/flow/Admin_Assisted_Back_Office_Sync`.)*

---

## Sample request / response JSON
**Request (Source → Target):**
```json
{
  "requestName": "Admin entered request name",
  "customerEmail": "admin@example.com",
  "requestDetails": "Admin entered details",
  "sourceRecordId": "a00XXXXXXXXXXXXXXX",
  "sourceOrg": "Source"
}
```
**Response (Target → Source):**
```json
{
  "success": true,
  "externalRecordId": "a00YYYYYYYYYYYYYYY",
  "message": "Request received and processed by Back Office."
}
```

---

## Troubleshooting
| Symptom | Fix |
|---|---|
| `You have uncommitted work pending` at the callout | Make sure the **Review & Send** screen sits *between* Create Records and the HTTP Callout — its boundary commits the DML. |
| Callout returns 401 / "external credential isn't fully configured" | The running user needs **MWD26 Source Access** (External Credential Principal Access) and `Target_Org_EC` must be authenticated. |
| Validation 400 doesn't reach the failure screen | Connect the **Fault** path of the HTTP Callout action to the failure branch. |
| Can't pick `Target_Org_NC` in the HTTP Callout | Confirm the Named Credential exists and is **Enabled for Callouts** in MWD26_Source. |
