# CLAUDE.md — MWD26 Salesforce-to-Salesforce Integration

Project memory for Claude Code. Read `PROJECT_OVERVIEW.md` for the full narrative;
this file is the working reference (commands, conventions, gotchas, status).

## What this is
A Midwest Dreamin' 2026 demo integrating two Salesforce orgs against ONE Target
REST API, two ways:
- **Developer path:** LWC → `IntegrationRequestController` → `IntegrationRequestSyncQueueable` → callout → Target Apex REST → writes `Integration_Log__c`.
- **Admin path (no-code):** Screen Flow `Admin_Assisted_Back_Office_Sync` → subflow `Back_Office_Callout` (native HTTP Callout) → same endpoint → `Integration_Log__c`.
- **Pub/sub:** `Sync_Notification__e` platform event + publisher + subscriber trigger (standalone, not wired in).

## Orgs (CLI aliases)
| Role | Alias(es) | Holds |
|---|---|---|
| SOURCE (front office) | `MWD26_Source` / `sourceOrg` | Integration_Request__c, Integration_Log__c, Sync_Notification__e, LWC, Apex controller/queueable, Admin flow |
| TARGET (back office) | `MWD26_Target` / `targetOrg` | External_Request__c, `BackOfficeRequestResource` (Apex REST) |

> ⚠️ NEVER commit real usernames, My Domain values, org IDs, tokens, or secrets.
> Use placeholders (`source-demo-user@example.com`, `target-demo.my.salesforce.com`).
> Real values live only in the local CLI auth — get them at runtime via `sf org display`.

## Repo layout (SFDX)
- `source-app/` → deploys to MWD26_Source · `target-app/` → deploys to MWD26_Target
- `manual-setup/` → `NAMED_CREDENTIAL_SETUP.md` (OAuth chain), `ADMIN_FLOW_SETUP.md` (flow build)
- `scripts/apex/` → seed/util scripts · API version 61.0

## Git workflow
- Repo: `Palle-Parameswara/Salesforce-Integration-between-Two-Orgs`, working branch **`mwd26-2026-refactor`** (PR #1 open; `main` untouched).
- Push requires the **`Palle-Parameswara`** gh account: `gh auth switch --user Palle-Parameswara` (the other account `paramhighcloudsolutions` is pull-only).
- The GitHub repo has the project under a `mwd26-integration/` subfolder. Work happens in the local project; sync + commit into a clone to push. Commit author: `Palle-Parameswara <palleparameswarareddy2000@gmail.com>`.

## Common commands
```bash
# deploy a dir to an org
sf project deploy start -d source-app/main/default/classes -o MWD26_Source -l RunSpecifiedTests -t <TestClass>
sf project deploy start -d target-app/main/default/classes -o MWD26_Target
# run anonymous apex / seed data
sf apex run -f scripts/apex/create_sample_request.apex -o MWD26_Source
# query
sf data query -q "SELECT ... FROM Integration_Request__c" -o MWD26_Source
# JSON output: pipe stdout only (2>/dev/null) — the CLI update warning corrupts JSON if merged
```

## Key facts
- Callout is ALWAYS `callout:Target_Org_NC/services/apexrest/mwd26/requests` (Named Credential; no raw URLs).
- Auth = External Client App (Target) → Auth Provider `TargetOrgAuth` (Source) → External Credential `Target_Org_EC` (Browser Flow) → Named Credential `Target_Org_NC`. Principal access `Target_Org_EC-TargetPrincipal` is in the `MWD26 Source Access` permission set (required even for admins).
- Target REST returns `{success, externalRecordId, message}`; 201 on create, 400 on missing required field.
- Both apps: `MWD26 Demo` (Source), `MWD26 Back Office` (Target); made visible via Admin profile `applicationVisibilities`.

## Gotchas learned (don't relearn these)
- **Metadata element ordering:** PermissionSet and Flow XML require same-named elements grouped together in schema order, or deploy fails ("Element X is duplicated at this location").
- **Callout-after-DML:** Apex does callout-first then DML. In Flow, a Screen boundary commits DML before a callout; the admin flow runs on an existing record so the callout is first (no create-in-flow).
- **External Credential "isn't fully configured"** = principal not authenticated OR running user lacks External Credential Principal Access.
- **Native Flow HTTP Callout:** request body is ONE Apex-defined resource (build it in an Assignment); response is under `<action>.2XX.*`; non-2xx triggers the Fault path; duplicate External Service name → "Failure encountered while saving" (delete + recreate).
- **Embedded Flow component doesn't refresh the record page** — use a Quick Action for auto-refresh.
- **Custom objects** deploy with only "Recently Viewed" — added `All` list views (filterScope Everything).
- **Spring '26:** classic Connected Apps restricted → use External Client Apps. Don't require PKCE (breaks the Auth Provider flow).
- Scratchpad clone can be wiped between sessions — re-clone if `git` says "not a git repository".

## Status (working, verified live)
- ✅ Developer path, Admin path, and pub/sub all deployed and verified end-to-end.
- ✅ All Apex tests pass (no `SeeAllData`).
- ✅ 10 Draft test records in Source (8 valid + 2 missing-email named `FAILTEST`).
- Open follow-ups (not done): mirror pub/sub to Target; wire `SyncNotificationPublisher.publish()` into the Queueable; add the Admin-flow Quick Action; merge PR #1.
