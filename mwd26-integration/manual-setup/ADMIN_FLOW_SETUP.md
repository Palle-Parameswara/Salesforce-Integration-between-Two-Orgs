# Admin-Assisted Back Office Sync — Screen Flow + HTTP Callout (no-code)

The **admin path** companion to the developer (LWC + Queueable) demo. It runs on
an **Integration Request record page** and sends the record to the same Target Org
REST endpoint using a native **HTTP Callout in Flow** — no Apex, no LWC. It reuses
the existing Named Credential and the `Integration_Request__c` /
`Integration_Log__c` objects.

## ✅ What's in the repo (deploys directly)
The **working** version is committed — you don't have to rebuild it:

| Component | Type |
|---|---|
| `Admin_Assisted_Back_Office_Sync` | Screen Flow (runs on the record page) |
| `Back_Office_Callout` | Autolaunched subflow (does the HTTP Callout) |
| `BackOfficeService` | External Service registration (the HTTP Callout schema) |

Deploying these to a fresh org recreates the HTTP Callout (the External Service
regenerates its request/response types). The contract between the two flows:
- **Inputs:** `in_requestName`, `in_customerEmail`, `in_requestDetails`, `in_sourceRecordId`, `in_sourceOrg`
- **Outputs:** `out_success` (Bool), `out_externalRecordId`, `out_message`, `out_statusCode` (Number), `out_errorMessage`

The steps below document **how it was built** — use them to rebuild by hand in a
new org, or to understand the moving parts.

---

## Prerequisites
- `Target_Org_NC` + External Credential `Target_Org_EC` are **authenticated**
  (see `NAMED_CREDENTIAL_SETUP.md`).
- The user running the flow has the **MWD26 Source Access** permission set
  (object access + the External Credential Principal Access the callout needs).

---

## Part 1 — The HTTP Callout inside `Back_Office_Callout`

In Flow Builder (Back Office Callout → Edit):

1. Add an **Action → Create HTTP Callout**:
   - **External Service:** `BackOfficeService`  *(must be unique — see gotcha below)*
   - **Named Credential:** **`Target_Org_NC`**  *(keeps URL + OAuth out of the flow)*
   - **Invocable action label:** `Send Back Office Request`
   - **URL Path:** `/services/apexrest/mwd26/requests` · **Method:** `POST`
   - **Sample request body** → Review:
     ```json
     { "requestName": "Sample request name", "customerEmail": "sample@example.com",
       "requestDetails": "Sample request details", "sourceRecordId": "a00000000000000",
       "sourceOrg": "Source" }
     ```
   - **Sample response body** → Review → **Save**:
     ```json
     { "success": true, "externalRecordId": "a00000000000000",
       "message": "External Request created successfully." }
     ```

2. **Request body is ONE composite resource** (not five separate inputs). In the
   action's **Set Request Body → Value**: click → **+ New Resource** → it pre-fills
   Data Type = *Apex-Defined* with the generated request class → name it
   **`requestBody`** → select it.

3. Add an **Assignment** `Build Request Body` *before* the action to populate it:
   - `requestBody.requestName`   = `{!in_requestName}`
   - `requestBody.customerEmail` = `{!in_customerEmail}`
   - `requestBody.requestDetails`= `{!in_requestDetails}`
   - `requestBody.sourceRecordId`= `{!in_sourceRecordId}`
   - `requestBody.sourceOrg`     = `{!in_sourceOrg}`

4. **Success outputs** — Assignment `Set Success Outputs` on the action's normal path:
   - `out_success`          = `{!$GlobalConstant.True}`
   - `out_externalRecordId` = `{!BackOfficeService.2XX.externalRecordId}`
   - `out_message`          = `{!BackOfficeService.2XX.message}`
   - `out_statusCode`       = `201`

5. **Failure outputs** — drag the action's **Fault** connector to an Assignment
   `Set Failure Outputs`:
   - `out_success`      = `{!$GlobalConstant.False}`
   - `out_errorMessage` = `{!$Flow.FaultMessage}`

6. Wire it: **Start → Build Request Body → BackOfficeService action**, then the
   action's **normal → Set Success Outputs** and **Fault → Set Failure Outputs**.
   **Save → Activate.**

```
Start → Build Request Body → BackOfficeService (HTTP Callout)
                                  ├─(normal)→ Set Success Outputs
                                  └─(Fault) → Set Failure Outputs
```

> **A non-2xx response (e.g. the validation 400) triggers the Fault path** — that's
> how the failure scenario flows to "Failed".

---

## Part 2 — Run it from the record (with auto-refresh)

⚠️ An **embedded Flow component** on a record page updates the record in the
database but **does not auto-refresh the page** — you'd have to refresh manually
to see the new Status/External Id. To get an automatic refresh, surface the flow
as a **Quick Action** instead:

1. **Object Manager → Integration Request → Buttons, Links, and Actions → New Action**
   - Action Type: **Flow** · Flow: **Admin Assisted Back Office Sync**
   - Label: `Send to Back Office (Admin)` → **Save**
2. **Object Manager → Integration Request → Page Layouts** → drag the action into
   **Mobile & Lightning Actions** → **Save**.
3. The admin clicks the action → flow runs in a modal → on **Finish** the record
   page **refreshes automatically** and shows Status = Success, External Record Id, etc.

*(An embedded Flow component or the `/flow/Admin_Assisted_Back_Office_Sync?recordId=<id>`
URL also work — they just need a manual refresh afterward.)*

---

## Gotchas we hit (and fixes)
| Symptom | Fix |
|---|---|
| **"Failure encountered while saving"** when creating the HTTP Callout | An External Service named `BackOfficeService` already exists from a prior attempt. Delete it (Setup → External Services, or `sf project delete source -m ExternalServiceRegistration:BackOfficeService`) and recreate, or use a new name. |
| **"Enter a value"** on Set Request Body | The body is a single Apex-defined resource — create `requestBody` (Part 1, step 2) and populate it with the `Build Request Body` assignment. |
| `Set_Failure_Outputs`/`Set_Success_Outputs` **"isn't connected"** warning | Both action paths must be wired: **normal → Success**, **Fault → Failure**. Draw the missing connector. |
| Record page **doesn't update** after the flow | Expected for an embedded Flow component — use the **Quick Action** (Part 2) for auto-refresh. |
| Callout 401 / "external credential isn't fully configured" | Running user needs **MWD26 Source Access** and `Target_Org_EC` must be authenticated. |

---

## Sample request / response JSON
**Request (Source → Target):**
```json
{ "requestName": "Admin entered request name", "customerEmail": "admin@example.com",
  "requestDetails": "Admin entered details", "sourceRecordId": "a00XXXXXXXXXXXXXXX",
  "sourceOrg": "Source" }
```
**Response (Target → Source):**
```json
{ "success": true, "externalRecordId": "a00YYYYYYYYYYYYYYY",
  "message": "Request received and processed by Back Office." }
```

---

## How the screen flow works (already built)
`Get Request` (by recordId) → **Confirm** screen → set start time → **call
`Back_Office_Callout`** → Decision on `out_success`:
- **Success** → update request (Success + External Id + message + sync date) →
  create `Integration_Log__c` (Success, 201, payload, response) → **Success** screen.
- **Failure / Fault** → update request (Failed + error) → create
  `Integration_Log__c` (Failed, error message) → **Failure** screen.

No record is created in the flow (it runs on an existing record), so the callout is
the first, DML-free operation — no "uncommitted work pending" issue.
