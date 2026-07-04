# MWD26 — Salesforce-to-Salesforce Integration (project context)

> Sanitized overview for public sharing. No real org usernames, My Domain values,
> org IDs, tokens, or secrets appear here — use the placeholders below.

## Goal
A Midwest Dreamin' 2026 demo integrating two Salesforce orgs against the **same**
Target REST API via a **Developer path** (LWC + Apex + Queueable + logging) and an
**Admin path** (Screen Flow + native HTTP Callout), plus a small **Platform Event
(pub/sub)** example.

## The two orgs
| Role | Alias | Username | My Domain |
|---|---|---|---|
| **SOURCE** (Front Office — sends) | `MWD26_Source` | `source-demo-user@example.com` | `source-demo.my.salesforce.com` |
| **TARGET** (Back Office — receives) | `MWD26_Target` | `target-demo-user@example.com` | `target-demo.my.salesforce.com` |

## Architecture (one endpoint, two callers)
```
SOURCE ORG                                         TARGET ORG
Integration_Request__c                             External_Request__c
Integration_Log__c                                 BackOfficeRequestResource (Apex REST)
Sync_Notification__e (platform event)               @ POST /services/apexrest/mwd26/requests

 Developer path:  LWC -> IntegrationRequestController -> IntegrationRequestSyncQueueable ─┐
 Admin path:      Screen Flow -> Back_Office_Callout subflow -> HTTP Callout ─────────────┤
                                          callout:Target_Org_NC/services/apexrest/mwd26/requests
                                                                                          v
                                          BackOfficeRequestResource creates External_Request__c
                                          returns { success, externalRecordId, message }
```

## 1. Custom objects
**Source:** `Integration_Request__c` (Request_Name__c, Customer_Email__c,
Request_Details__c, Status__c [Draft/Sending/Success/Failed], External_Record_Id__c,
Response_Message__c, Last_Synced_Date__c); `Integration_Log__c`
(Integration_Request__c lookup, Direction__c, Integration_Name__c, Endpoint__c,
HTTP_Method__c, Status__c [Queued/Success/Failed], Status_Code__c, Request_Payload__c,
Response_Body__c, Error_Message__c, External_Record_Id__c, Queueable_Job_Id__c,
Correlation_Id__c, Started_At__c, Completed_At__c).
**Target:** `External_Request__c` (Request_Name__c, Customer_Email__c,
Request_Details__c, Source_Record_Id__c, Source_Org__c, Processing_Status__c
[New/In Progress/Completed/Failed], Response_Message__c).

## 2. OAuth / authentication chain
Named Credential **`Target_Org_NC`** — no URLs/secrets in code. Setup:
1. **External Client App** in **TARGET** (Spring '26 restricts classic Connected
   Apps). Enable OAuth; scopes `api` + `refresh_token, offline_access`; enable
   **Authorization Code and Credentials Flow**; **Require secret for Web Server
   Flow** ON, **PKCE OFF**; Policies -> *All users may self-authorize*. Copy
   Consumer Key + Secret.
2. **Auth Provider** in **SOURCE** (`TargetOrgAuth`): Key/Secret; authorize/token
   endpoints = `https://target-demo.my.salesforce.com/services/oauth2/authorize`
   and `/token`; Default Scopes `api refresh_token` (not `full`). Copy the
   generated Callback URL.
3. Put that Callback URL back into the **ECA (Target)**.
4. **External Credential** in **SOURCE** (`Target_Org_EC`): OAuth 2.0, **Browser
   Flow**, Auth Provider `TargetOrgAuth`, scope `api refresh_token`; add a **Named
   Principal** -> **Authenticate**.
5. **Named Credential** in **SOURCE** (`Target_Org_NC`): URL = target My Domain;
   references `Target_Org_EC`; Generate Authorization Header ON.
6. **Principal Access** — `MWD26 Source Access` permission set grants External
   Credential Principal Access `Target_Org_EC-TargetPrincipal` (**required even for
   admins**).

Gotchas: `"external credential isn't fully configured"` = principal not
authenticated / missing principal access; `redirect_uri_mismatch` = ECA callback
does not match the Auth Provider callback.

## 3. Developer path (Apex, async)
`IntegrationRequestController.sendToBackOffice(Id)` (validate, block duplicates,
Status=Sending, enqueue) -> `IntegrationRequestSyncQueueable`
(`Database.AllowsCallouts`; callout-first; writes result + `Integration_Log__c` via
fail-safe `IntegrationLogger`); DTOs in `IntegrationRequestDTO`; LWC
`sendToBackOffice` (record-page button, toast, `getRecordNotifyChange`). Queueable =
responsive UI + callout isolation + governor headroom.

## 4. Target REST
`BackOfficeRequestResource` — `@RestResource(urlMapping='/mwd26/requests/*')`,
`@HttpPost`; validates (missing field -> **400**), creates `External_Request__c`,
returns `{success, externalRecordId, message}`, HTTP **201** on success.

## 5. Admin path (no-code)
`Admin_Assisted_Back_Office_Sync` (Screen Flow on the record page): Get -> Confirm
-> call subflow -> decision -> update + `Integration_Log__c` -> result screen
(callout-first, no DML-before-callout issue). `Back_Office_Callout` (subflow): Build
Request Body (Apex-defined `requestBody`) -> **HTTP Callout** (Named Credential
`Target_Org_NC`, POST, `/services/apexrest/mwd26/requests`) -> Set Success (normal)
/ Set Failure (Fault). `BackOfficeService` = External Service.

Gotchas: duplicate External Service name -> "Failure encountered while saving";
request body is one Apex-defined resource; wire both normal->Success &
Fault->Failure; an embedded Flow component does not auto-refresh the record page ->
use a **Quick Action**. "No code?" — the admin path is 100% declarative; it calls a
developer-built Apex REST API (the foundation). That split is the story.

## 6. Pub/Sub (Platform Events) — Source, standalone
`Sync_Notification__e` (6 text fields) -> `SyncNotificationPublisher.publish(...)`
(`EventBus.publish`) -> `Sync_Notification_Subscriber` trigger writes an
`Integration_Log__c` (Direction=Inbound). `PublishAfterCommit`; subscriber runs
async as the Automated Process user. **Not wired into anything; not in any app.**

## 7. Testing (all pass, no `SeeAllData`)
`IntegrationRequestControllerTest`, `IntegrationRequestSyncQueueableTest`
(HttpCalloutMock), `BackOfficeRequestResourceTest`, `SyncNotificationTest`. Verified
live end-to-end: happy path, 400 -> Failed, duplicate prevention, pub/sub.

## 8. Supporting metadata
Permission sets (MWD26 Source/Target Access); apps (MWD26 Demo / MWD26 Back Office,
visible to admin profile); "All" list views on all three custom objects; 10 Draft
test records (8 valid + 2 missing-email).

## 9. Security posture
No org URLs, tokens, secrets, usernames, or passwords in the repo (verified across
full git history). Apex/Flow reference only `callout:Target_Org_NC`. Manual auth
setup documented with placeholders; `.gitignore` excludes secret notes.
