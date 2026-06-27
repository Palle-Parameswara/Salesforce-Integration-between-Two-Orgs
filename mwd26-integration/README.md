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
| **Object** | `Integration_Request__c` | `External_Request__c` |
| **Apex** | `IntegrationRequestService` (callout) | `BackOfficeRequestResource` (Apex REST) |
| **UI** | LWC `sendToBackOffice` on the record page | List view / tab of received requests |
| **Auth** | Named Credential `Target_Org_NC` | Connected App + OAuth |

A user clicks **Send to Back Office** on an Integration Request. The Source Org
POSTs the data to the Target Org, which creates an `External_Request__c` and
returns `{ success, externalRecordId, message }`. The Source Org then stamps the
request with **Status**, **External Record Id**, **Response Message**, and
**Last Synced Date**.

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
        IntegrationRequestService.sendRequest(recordId)            │
                  │                                                 │
                  │  POST callout:Target_Org_NC                     │
                  │       /services/apexrest/mwd26/requests         │
                  └───────────  HTTPS + OAuth 2.0  ─────────────────┘
                         (Named Credential: Target_Org_NC)
        Response: { success, externalRecordId, message }  ──▶ write back to Source record
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
4. **Source Org** → Named Credential **`Target_Org_NC`** (Named Principal, OAuth 2.0) → authenticate.

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

## 8. Demo Script (≈3 minutes)

1. **Show the Source record.** Open an Integration Request (Status = **Draft**).
2. **Send it.** Click **Send to Back Office** → success toast appears.
3. **Show the round-trip in the Source.** The record now shows
   Status = **Success**, an **External Record Id**, a **Response Message**, and
   a **Last Synced Date**.
4. **Switch to the Target Org.** Open the **MWD26 Back Office** app →
   **External Requests** tab → the new `External_Request__c` (EXT-####) is there
   with Processing Status = **Completed** and the originating **Source Record Id**.
5. **Failure scenario.** Create a new Integration Request **without a Customer
   Email**, then click **Send to Back Office**:
   - The Target returns HTTP **400** with `Missing required field(s): customerEmail`.
   - The Source record flips to Status = **Failed** and the **Response Message**
     captures the reason. *(Great place to mention validation + error handling.)*

---

## 9. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `Unauthorized` / `401` on send | Named Credential not authenticated, or its name isn't exactly **`Target_Org_NC`**. Re-run the auth flow (§6). |
| `404 Not Found` on callout | Apex REST not deployed to Target, or wrong path. Endpoint must be `/services/apexrest/mwd26/requests`. |
| `You have uncommitted work pending` | A DML ran before the callout. The service is written callout-first on purpose — keep it that way. |
| Status stays **Draft** | The LWC/Apex couldn't run — check the user has **MWD26 Source Access** and the component is on the page. |
| Target record not created | Authenticated Target user lacks access — assign **MWD26 Target Access** to that user (§4, §6 Step 5). |
| `INVALID_FIELD` on deploy | Field API names must match exactly (`__c` suffixes); redeploy the `objects` directory first. |
| External Client App not working yet | A newly created ECA can take up to ~30 minutes to activate. Also confirm **Policies → Permitted Users** allows self-authorization, and that **Require PKCE** is OFF. |

---

## Project Structure

```
mwd26-integration/
├─ sfdx-project.json
├─ README.md
├─ .gitignore
├─ manual-setup/
│  └─ NAMED_CREDENTIAL_SETUP.md      # Connected App / Auth Provider / Named Credential (placeholders)
├─ scripts/apex/
│  └─ create_sample_request.apex     # sample test data
├─ source-app/main/default/          # → deploy to MWD26_Source
│  ├─ objects/Integration_Request__c/
│  ├─ classes/  IntegrationRequestService(.cls + Test)
│  ├─ lwc/sendToBackOffice/
│  ├─ tabs/ applications/ permissionsets/
└─ target-app/main/default/          # → deploy to MWD26_Target
   ├─ objects/External_Request__c/
   ├─ classes/  BackOfficeRequestResource(.cls + Test)
   ├─ tabs/ applications/ permissionsets/
```
