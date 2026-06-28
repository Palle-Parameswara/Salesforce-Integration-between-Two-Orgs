# MWD26 — Salesforce-to-Salesforce Integration Demo

A clean, presentation-ready demo of **org-to-org integration** built for
**Midwest Dreamin' 2026**. A front-office **Source Org** sends a request to a
back-office **Target Org** over an authenticated Apex callout; the Target Org
receives it via Apex REST, creates a record, and replies; the Source Org records
the outcome.

---

## 1. Demo Overview

| | Source Org (Front Office) | Target Org (Back Office) |
|---|---|---|
| **Role** | Raises & sends requests | Receives & processes requests |
| **Object** | `Integration_Request__c` (+ `Integration_Log__c`) | `External_Request__c` |
| **Apex** | `IntegrationRequestController` → `IntegrationRequestSyncQueueable` → `IntegrationLogger` | `BackOfficeRequestResource` (Apex REST) |
| **UI** | LWC `sendToBackOffice` on the record page | List view / tab of received requests |
| **Auth** | Named Credential `Target_Org_NC` | External Client App + OAuth |

A user clicks **Send to Back Office** on an Integration Request. The controller
validates, blocks duplicates, marks the record **Sending**, and **enqueues a
Queueable** — so the UI returns instantly. The Queueable POSTs to the Target Org
(which creates an `External_Request__c` and returns
`{ success, externalRecordId, message }`), stamps the source record with
**Status / External Record Id / Response Message / Last Synced Date**, and writes
an **`Integration_Log__c`** audit row. See §10 for why.

---

## 2. Architecture (text diagram)

```
  SOURCE ORG (Front Office)                         TARGET ORG (Back Office)
  ┌──────────────────────────────┐                 ┌──────────────────────────────┐
  │ Integration_Request__c        │                 │ External_Request__c           │
  │   • Request_Name__c           │                 │   • Request_Name__c           │
  │   • Customer_Email__c         │                 │   • Customer_Email__c         │
  │   • Request_Details__c        │                 │   • Request_Details__c        │
  │   • Status__c (Draft→...)     │                 │   • Source_Record_Id__c       │
  │   • External_Record_Id__c     │                 │   • Source_Org__c             │
  │   • Response_Message__c       │                 │   • Processing_Status__c      │
  │   • Last_Synced_Date__c       │                 │   • Response_Message__c        │
  └───────────────┬──────────────┘                 └───────────────▲──────────────┘
                  │                                                 │
        LWC: sendToBackOffice                            @RestResource(@HttpPost)
                  │                                       BackOfficeRequestResource
                  ▼                                                 │
        IntegrationRequestController.sendToBackOffice(recordId)     │
            • validate • block duplicates • Status=Sending          │
            • System.enqueueJob(...)  ─┐  (UI returns instantly)    │
                                       ▼                            │
        IntegrationRequestSyncQueueable (Database.AllowsCallouts)   │
                  │  POST callout:Target_Org_NC                     │
                  │       /services/apexrest/mwd26/requests         │
                  ├───────────  HTTPS + OAuth 2.0  ─────────────────┘
                  │            (Named Credential: Target_Org_NC)
                  │  Response: { success, externalRecordId, message }
                  ├─▶ update Integration_Request__c (Success/Failed + details)
                  └─▶ IntegrationLogger → Integration_Log__c (audit row)
```

---

## 3. Source Org Setup

1. Deploy the `source-app` metadata (see §5).
2. Assign the **MWD26 Source Access** permission set.
3. Complete the **Named Credential** (`Target_Org_NC`) — see §6 / `manual-setup/`.
4. Add the `sendToBackOffice` component to the Integration Request record page:
   open a record → ⚙ **Edit Page** → drag **sendToBackOffice** onto the page →
   **Save** → **Activate** (Org Default).

## 4. Target Org Setup

1. Deploy the `target-app` metadata (see §5).
2. Assign the **MWD26 Target Access** permission set to the user that will
   authenticate the Named Credential.
3. Create the **External Client App** — see §6 / `manual-setup/`.
4. (Optional) Pre-load a few `External_Request__c` records to show an empty vs.
   populated state during the talk.

---

## 5. Salesforce CLI Deploy Commands

> Aliases used here: `MWD26_Source` and `MWD26_Target`.

```bash
# --- authorize (one-time) ---
sf org login web --alias MWD26_Source
sf org login web --alias MWD26_Target

# --- TARGET ORG: objects, then Apex REST (+ tests), then tab/app/permset ---
sf project deploy start -d target-app/main/default/objects        -o MWD26_Target
sf project deploy start -d target-app/main/default/classes         -o MWD26_Target \
  -l RunSpecifiedTests -t BackOfficeRequestResourceTest
sf project deploy start -d target-app/main/default/tabs \
  -d target-app/main/default/applications \
  -d target-app/main/default/permissionsets -o MWD26_Target
sf org assign permset -n MWD26_Target_Access -o MWD26_Target

# --- SOURCE ORG: objects, then Apex (+ tests), then LWC/tab/app/permset ---
sf project deploy start -d source-app/main/default/objects        -o MWD26_Source
sf project deploy start -d source-app/main/default/classes         -o MWD26_Source \
  -l RunSpecifiedTests -t IntegrationRequestServiceTest
sf project deploy start -d source-app/main/default/lwc \
  -d source-app/main/default/tabs \
  -d source-app/main/default/applications \
  -d source-app/main/default/permissionsets -o MWD26_Source
sf org assign permset -n MWD26_Source_Access -o MWD26_Source
```

> Tip: you can also deploy a whole package directory at once
> (`sf project deploy start -d source-app -o MWD26_Source`); the granular
> commands above just make the order and test runs explicit for the talk.

---

## 6. Manual Setup — External Client App / Auth Provider / Named Credential

⚠️ **These are NOT in source control** — they generate secrets and need an
interactive login. Follow **[`manual-setup/NAMED_CREDENTIAL_SETUP.md`](manual-setup/NAMED_CREDENTIAL_SETUP.md)**.

> **Note (Spring '26+):** classic Connected App creation is restricted —
> use an **External Client App**. It still yields a Consumer Key/Secret + Callback
> URL, so the Auth Provider / Named Credential steps are unchanged.

Summary of the chain (full values/placeholders in that file):

1. **Target Org** → External Client App → get **Consumer Key/Secret**.
2. **Source Org** → Auth Provider `TargetOrgAuth` (uses the key/secret) → get **Callback URL**.
3. **Target Org** → paste the Callback URL back into the External Client App.
4. **Source Org** → External Credential `Target_Org_EC` (OAuth 2.0, **Browser Flow**, Auth Provider `TargetOrgAuth`) → add a **Named Principal** → **Authenticate**.
5. **Source Org** → Named Credential **`Target_Org_NC`** referencing `Target_Org_EC`.
6. **Source Org** → grant **External Credential Principal Access** (already in the MWD26 Source Access permission set).

🔒 **Security rules honored by this repo**
- No org URLs, tokens, secrets, usernames, or passwords are committed.
- The only endpoint reference in Apex is `callout:Target_Org_NC/...` (the Named Credential).
- External Client App / Auth Provider / Named Credential stay manual; `.gitignore`
  keeps any local secret notes out of Git.

---

## 7. Create Test Data

```bash
# Creates one sample Integration_Request__c in the Source Org
sf apex run -f scripts/apex/create_sample_request.apex -o MWD26_Source
```

Or create one manually: **MWD26 Demo** app → **Integration Requests** tab →
**New** → fill in Request Name, Customer Email, Request Details → **Save**
(Status defaults to *Draft*).

---

## 8. Demo Script (≈4 minutes)

1. **Show the Source record.** Open an Integration Request (Status = **Draft**).
2. **Send it.** Click **Send to Back Office** → toast: *"Sync started. Refresh in a
   few seconds…"* The record immediately shows Status = **Sending** (the callout
   is running in the background Queueable — the UI didn't block).
3. **Refresh.** Status flips to **Success**, with **External Record Id**,
   **Response Message**, and **Last Synced Date** populated.
4. **Switch to the Target Org.** **MWD26 Back Office** app → **External Requests**
   → the new `External_Request__c` (EXT-####) is there, Processing Status =
   **Completed**, with the originating **Source Record Id**.
5. **Show the log.** Back in the Source: open the **Integration Logs** tab (or the
   **Integration Logs** related list on the request) → the **Success** log row
   shows the **request payload**, **response body**, **status code 201**, the
   **Queueable Job Id**, and the **Correlation Id**. *(This is your observability moment.)*
6. **Failure scenario.** Create a request **without a Customer Email** → **Send to
   Back Office**:
   - Target returns HTTP **400** `Missing required field(s): customerEmail`.
   - Source record → Status = **Failed**, readable Response Message.
   - A **Failed** Integration Log row captures the 400 + error message.
7. **Duplicate prevention.** Click **Send to Back Office** again on an
   already-**Success** record → toast: *"This request is already synced to Back
   Office."* No second Target record, no callout.

> **Two paths, one foundation.** Steps 1–7 are the **Developer Path** (LWC +
> Queueable + Apex logging). For the **Admin Path** — the same integration driven
> by a no-code **Screen Flow + HTTP Callout** — see **§11**.

---

## 9. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `The external credential isn't fully configured` | The Named Principal isn't authenticated, **or** the running user lacks **External Credential Principal Access**. Authenticate `Target_Org_EC` and confirm **MWD26 Source Access** is assigned (§6). |
| `Unauthorized` / `401` on send | Named Credential not authenticated, or its name isn't exactly **`Target_Org_NC`**. Re-run the auth flow (§6). |
| Auth fails / `redirect_uri_mismatch` | The ECA Callback URL doesn't match the Auth Provider Callback URL exactly. Copy it from the Auth Provider page into the ECA (§6 step 3). |
| `404 Not Found` on callout | Apex REST not deployed to Target, or wrong path. Endpoint must be `/services/apexrest/mwd26/requests`. |
| `You have uncommitted work pending` | A DML ran before the callout. The service is written callout-first on purpose — keep it that way. |
| Status stuck on **Sending** | The Queueable hasn't finished or failed. Check **Setup → Apex Jobs** for the Queueable, and the latest **Integration Log** row for the error. Just refresh the record once the job completes. |
| Status stays **Draft** | The controller didn't run — check the user has **MWD26 Source Access** and the component is on the page. |
| No **Integration Log** row | Logging is fail-safe (never throws). Check the user has create access to `Integration_Log__c` (in **MWD26 Source Access**) and look at the debug log for `IntegrationLogger:` warnings. |
| "Already synced" when you didn't expect it | Duplicate guard fired — the record already has Status **Success** + an **External Record Id**. Reset those fields to re-send. |
| Target record not created | Authenticated Target user lacks access — assign **MWD26 Target Access** to that user (§4, §6 step 7). |
| `INVALID_FIELD` on deploy | Field API names must match exactly (`__c` suffixes); redeploy the `objects` directory first. |
| External Client App not working yet | A newly created ECA can take up to ~30 minutes to activate. Also confirm **Policies → Permitted Users** allows self-authorization, and that **Require PKCE** is OFF. |

---

## 10. Production-style patterns (Queueable + Integration Log)

**Why Queueable Apex?**
- **Responsive UI** — the LWC gets an instant "sync started" instead of waiting on
  a synchronous HTTP round-trip.
- **Callout isolation** — the callout runs in its own async transaction, so the
  controller can do DML (mark **Sending**) first without the classic
  *"You have uncommitted work pending"* error.
- **Headroom** — async governor limits are higher, and it's the natural place to
  add retries/chaining later (intentionally out of scope for this demo).

**Why `Integration_Log__c`?**
- **Auditability / observability** — every attempt records the request payload,
  response body, HTTP status code, error message, endpoint, method, timestamps,
  the **Queueable Job Id**, and a **Correlation Id** that ties controller →
  queueable → log together.
- **Fail-safe** — `IntegrationLogger` swallows *its own* insert failures only, so a
  logging problem can never roll back or hide the real integration result.
- **Demo gold** — it makes the invisible callout visible on screen.

**Viewing logs in the demo:** the **Integration Logs** tab (MWD26 Demo app), or the
**Integration Logs** related list on each Integration Request (added automatically
via the lookup — drop it on the page layout if it isn't shown).

> **Manual setup reminder:** the callout only works once the Named Credential
> **`Target_Org_NC`** (+ External Credential `Target_Org_EC`) is authenticated —
> see §6 / `manual-setup/`.

---

## 11. Admin-Friendly Flow Demo (the "Admin Path")

> Full build guide: **[`manual-setup/ADMIN_FLOW_SETUP.md`](manual-setup/ADMIN_FLOW_SETUP.md)**

### 1. What this shows
The **same** Target Org REST API and Named Credential, driven by an
**admin-built Screen Flow** with the native **HTTP Callout in Flow** — *no Apex,
no LWC*. It writes to the same `Integration_Request__c` and `Integration_Log__c`
objects, so developers and admins share one integration foundation.

### 2. How admins use Screen Flow + HTTP Callout
A Screen Flow on the **Integration Request record page** calls a small
**`Back_Office_Callout`** subflow that uses the native **HTTP Callout** action
pointed at the existing **`Target_Org_NC`** Named Credential — so no URL or secret
ever lives in the flow. The flow then updates the record and writes an Integration
Log, all point-and-click.

### 3. Setup steps (summary)
**Two flows already ship as metadata** in `source-app/main/default/flows/`:
- `Admin_Assisted_Back_Office_Sync` (Screen Flow) — complete.
- `Back_Office_Callout` (autolaunched subflow) — a **placeholder** with a fixed
  input/output contract.

So the admin's only work is:
1. Confirm **`Target_Org_NC`** exists and is authenticated (§6).
2. Open **`Back_Office_Callout`** in Flow Builder → replace the placeholder with a
   **Create HTTP Callout** action (Named Credential `Target_Org_NC`, **POST**, path
   `/services/apexrest/mwd26/requests`) using the sample JSON below; map the
   `in_*` inputs and set the `out_*` outputs (success + **Fault** paths).
3. Add the **Flow** component (`Admin Assisted Back Office Sync`) to the
   **Integration Request** record page.

Full click-by-click: **[`manual-setup/ADMIN_FLOW_SETUP.md`](manual-setup/ADMIN_FLOW_SETUP.md)**.

**Sample request JSON**
```json
{
  "requestName": "Admin entered request name",
  "customerEmail": "admin@example.com",
  "requestDetails": "Admin entered details",
  "sourceRecordId": "a00XXXXXXXXXXXXXXX",
  "sourceOrg": "Source"
}
```
**Sample response JSON**
```json
{
  "success": true,
  "externalRecordId": "a00YYYYYYYYYYYYYYY",
  "message": "Request received and processed by Back Office."
}
```

> ⚙️ **Why it runs on the record page (not collect-and-create):** the flow operates
> on an existing Integration Request, so the **callout is the first, DML-free
> operation** — no "uncommitted work pending" issue — and the record Id is already
> available for `sourceRecordId`.

### 4. Demo steps
1. Open an existing **Integration Request** record (Status **Draft**).
2. Run **Admin Assisted Back Office Sync** from the record (see the auto-refresh tip below).
3. On the **Confirm** screen, click **Next** to fire the callout.
4. **Success screen** shows the Target External Record Id and response message.
5. The **Source** `Integration_Request__c` → Status **Success**.
6. Show the **Target** `External_Request__c` (EXT-####) created.
7. Show the **`Integration_Log__c`** row (Outbound, Success, payload + response).

> 🔄 **Auto-refresh tip:** an *embedded* Flow component updates the record but
> won't refresh the page on its own (you'd refresh manually). Surface the flow as
> a **Quick Action** (Object Manager → Integration Request → New Action → type
> *Flow*) and add it to the page layout — Quick Action flows **refresh the record
> automatically on finish**. See `manual-setup/ADMIN_FLOW_SETUP.md` Part 2.

### 5. Failure demo
Run the flow with an **invalid/blank Customer Email** so the Target returns
**400**. The HTTP Callout's **Fault path** routes to: Source record → **Failed**,
a **Failed** Integration Log (with the error message), and the failure screen.

### 6. Is it really "no code"?
**The admin path is 100% declarative** — no Apex, no LWC. It's a Screen Flow, an
autolaunched subflow, the native **HTTP Callout** action, and a **Named
Credential**. The admin builds and owns all of it in Flow Builder. It *calls* a
Target Org Apex REST API a **developer** wrote — that's the foundation, not part of
the admin's build. That split **is** the story.

### 7. Speaker talking points
- *"Admins get a guided, point-and-click experience — no code in the flow itself."*
- *"Developers still own the secure API and the reusable integration foundation."*
- *"Named Credentials keep authentication completely out of the flow."*
- *"Integration logs make troubleshooting easy — same audit trail for both paths."*

---

## Project Structure

```
mwd26-integration/
├─ sfdx-project.json
├─ README.md
├─ .gitignore
├─ manual-setup/
│  ├─ NAMED_CREDENTIAL_SETUP.md      # External Client App / Auth Provider / External Credential / Named Credential
│  └─ ADMIN_FLOW_SETUP.md           # Admin Path: Screen Flow + HTTP Callout build guide (no-code)
├─ scripts/apex/
│  └─ create_sample_request.apex     # sample test data
├─ source-app/main/default/          # → deploy to MWD26_Source
│  ├─ objects/  Integration_Request__c/  Integration_Log__c/
│  ├─ classes/  IntegrationRequestController(.cls + Test)
│  │            IntegrationRequestSyncQueueable(.cls + Test)
│  │            IntegrationLogger.cls   IntegrationRequestDTO.cls
│  ├─ lwc/sendToBackOffice/
│  ├─ flows/  Admin_Assisted_Back_Office_Sync  Back_Office_Callout (Admin Path, working)
│  ├─ externalServiceRegistrations/  BackOfficeService (HTTP Callout schema)
│  ├─ tabs/ applications/ permissionsets/
└─ target-app/main/default/          # → deploy to MWD26_Target
   ├─ objects/External_Request__c/
   ├─ classes/  BackOfficeRequestResource(.cls + Test)
   ├─ tabs/ applications/ permissionsets/
```
