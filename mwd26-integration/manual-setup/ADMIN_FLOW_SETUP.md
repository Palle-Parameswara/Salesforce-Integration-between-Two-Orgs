# Admin-Assisted Back Office Sync — Screen Flow + HTTP Callout (no-code)

The **admin path** companion to the developer (LWC + Queueable) demo. It runs on
an **Integration Request record page** and sends the record to the same Target Org
REST endpoint using a native **HTTP Callout in Flow** — no Apex, no LWC. It reuses
the existing Named Credential and the `Integration_Request__c` /
`Integration_Log__c` objects.

## What's already deployed (in the repo)
Two flows ship as metadata, so you don't hand-build the orchestration:

| Flow | Type | Status |
|---|---|---|
| **`Back_Office_Callout`** | Autolaunched subflow | A **placeholder** — you add the HTTP Callout action (Part 1) |
| **`Admin_Assisted_Back_Office_Sync`** | Screen Flow | ✅ complete — calls the subflow, updates the record, writes the log |

The screen flow has a fixed contract with the subflow:
- **Inputs:** `in_requestName`, `in_customerEmail`, `in_requestDetails`, `in_sourceRecordId`, `in_sourceOrg`
- **Outputs:** `out_success` (Bool), `out_externalRecordId`, `out_message`, `out_statusCode` (Number), `out_errorMessage`

**Your only build steps are Part 1 (HTTP Callout) and Part 2 (put the flow on the page).**

---

## Prerequisites
- `Target_Org_NC` + External Credential `Target_Org_EC` are **authenticated**
  (see `NAMED_CREDENTIAL_SETUP.md`).
- The user running the flow has the **MWD26 Source Access** permission set
  (object access + the External Credential Principal Access the callout needs).

---

## Part 1 — Add the HTTP Callout inside `Back_Office_Callout`

1. Setup → **Flows** → open **Back Office Callout** → **Edit**.
2. **Delete** the `Placeholder Not Configured` assignment (you'll replace it).
3. Drag an **Action** onto the canvas → in the panel choose **Create HTTP Callout**:
   - **External Service:** `BackOfficeService`
   - **Named Credential:** **`Target_Org_NC`**  *(keeps the URL + OAuth out of the flow)*
   - **Invocable action label:** `Send Back Office Request`
   - **URL Path:** `/services/apexrest/mwd26/requests`
   - **Method:** `POST`
   - **Sample request body** (generates the request structure):
     ```json
     {
       "requestName": "Sample request name",
       "customerEmail": "sample@example.com",
       "requestDetails": "Sample request details",
       "sourceRecordId": "a00000000000000",
       "sourceOrg": "Source"
     }
     ```
   - **Sample response body** (generates the response structure):
     ```json
     {
       "success": true,
       "externalRecordId": "a00000000000000",
       "message": "External Request created successfully."
     }
     ```
   - **Save**.
4. **Map the action inputs** (request body) from the subflow variables:
   - `requestName` = `{!in_requestName}`
   - `customerEmail` = `{!in_customerEmail}`
   - `requestDetails` = `{!in_requestDetails}`
   - `sourceRecordId` = `{!in_sourceRecordId}`
   - `sourceOrg` = `{!in_sourceOrg}`
5. Connect **Start → the HTTP Callout action**.
6. **On success** — add an **Assignment** (`Set_Success_Outputs`) after the action:
   - `out_success` = `{!$GlobalConstant.True}`
   - `out_externalRecordId` = `{!Send_Back_Office_Request.2XX.externalRecordId}`
   - `out_message` = `{!Send_Back_Office_Request.2XX.message}`
   - `out_statusCode` = `201`  *(or the action's status-code output if shown)*
   *(merge-field names follow whatever the action generated — bind to its 2XX response)*
7. **On failure** — from the HTTP Callout action draw the **Fault** connector to a
   second **Assignment** (`Set_Failure_Outputs`):
   - `out_success` = `{!$GlobalConstant.False}`
   - `out_errorMessage` = `{!$Flow.FaultMessage}`
8. **Save** and **Activate**.

> A non-2xx response (e.g. the validation **400**) triggers the action's **Fault**
> path — that's exactly how the failure demo flows to "Failed".

---

## Part 2 — Put the flow on the Integration Request record page

1. Open any **Integration Request** record → ⚙ → **Edit Page** (Lightning App Builder).
2. Drag the **Flow** component onto the page.
3. **Flow** = **Admin Assisted Back Office Sync**.
4. Confirm the **recordId** input passes automatically (the component sets it from
   the record). Leave other inputs default.
5. **Save** → **Activate** (Org Default, or for the MWD26 Demo app).

*(Quick alternative for rehearsal: add it as a record **Action**, or run from
`/flow/Admin_Assisted_Back_Office_Sync?recordId=<id>`.)*

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

## How the flow works (already built)
`Get Request` (by recordId) → **Confirm** screen → set start time → **call
`Back_Office_Callout`** → Decision on `out_success`:
- **Success** → update the request (Success + External Id + message + sync date) →
  create `Integration_Log__c` (Success, 201, payload, response) → **Success** screen.
- **Failure / Fault** → update the request (Failed + error) → create
  `Integration_Log__c` (Failed, error message) → **Failure** screen.

> No record is created in the flow (it runs on an existing record), so the callout
> is the first DML-free operation — no "uncommitted work pending" issue.

---

## Troubleshooting
| Symptom | Fix |
|---|---|
| Flow runs but every request "fails" with *"Back_Office_Callout is a placeholder…"* | You haven't done Part 1 yet — add the HTTP Callout action and the success/fault Assignments inside `Back_Office_Callout`. |
| Callout 401 / "external credential isn't fully configured" | The running user needs **MWD26 Source Access** (External Credential Principal Access) and `Target_Org_EC` must be authenticated. |
| Validation 400 doesn't reach the failure screen | Make sure the HTTP Callout action's **Fault** path sets `out_success = False` and `out_errorMessage`. |
| Can't pick `Target_Org_NC` in the HTTP Callout | Confirm the Named Credential exists and is **Enabled for Callouts** in MWD26_Source. |
| Subflow contract errors after editing | Don't rename the `in_*` / `out_*` variables — the screen flow binds to those exact names. |
