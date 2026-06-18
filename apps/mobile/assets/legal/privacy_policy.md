# Watoto — Privacy Policy & Data-Retention Schedule (DRAFT)

> **This is a working draft, not legal advice.** It is written to give a licensed attorney a substantive starting point rather than a blank page. Every value in [brackets] must be set by [Company]. A qualified privacy lawyer must review and localize this before publication, because children's-privacy obligations vary by jurisdiction and change over time. It is intended to be read alongside `COMPLIANCE_SIGNOFF.md` and is grounded in the same frameworks: the amended COPPA Rule (in force April 2026), the FTC's guidance for child-directed services, and the EU/UK GDPR (notably Article 8 on children's consent and the UK Age-Appropriate Design Code).

Effective date: [DATE]  ·  Last updated: [DATE]  ·  Applies to: the Watoto app on iOS and Android and any related services operated by [Company / legal entity], [address].

---

## 1. Plain-language summary (for parents)

Watoto is built for children, so we collect as little as possible and we never sell your or your child's data, never show third-party ads, and never use your child's information to target advertising. A parent or guardian sets up and controls the account; children do not enter personal contact details, and the app works offline. You can review, export, or delete your child's information at any time from the in-app parent area or by emailing [privacy@company]. The sections below give the full detail.

## 2. Our stance on children's privacy (privacy by design)

- No behavioral or third-party advertising, and no advertising SDKs or ad identifiers in the child experience.
- No sale or "sharing" of personal information (as those terms are defined under applicable law), and no data brokers.
- Data minimization: we collect only what a feature needs, and prefer on-device storage. Progress is kept on the device and only synced to the cloud if the parent enables an account.
- A verifiable parental consent gate stands in front of any personal-data collection from a child.
- Least-privilege access internally, encryption in transit and at rest, and a documented breach-response process.

## 3. What we collect — and what we deliberately do not

We separate the **child profile** (minimal, parent-created) from the **account holder** (the adult).

| Category | Examples | Source | Why |
|---|---|---|---|
| Child profile | Display name or nickname *chosen by the parent*, avatar, age band, learning progress and preferences | Parent sets it up; app records progress | Run the curriculum, save progress, personalize difficulty |
| Account holder (adult) | Email address, hashed authentication credential, parental-consent record, subscription/entitlement status | Parent at sign-up | Authenticate the owner, sync across devices, manage purchases, prove consent |
| Technical & diagnostic | App version, device model/OS, coarse region, crash reports, privacy-preserving usage counts | Automatic, where enabled | Keep the app stable and secure; understand which lessons are used (in aggregate) |
| Support | Messages you send us, and what they contain | You, when you contact support | Answer your question |

We do **not** collect from children: real full name, postal or email address, phone number, precise geolocation, photos or audio of the child, contacts, or any persistent advertising identifier. We do not ask a child for personal information to unlock features, and we do not enable child-to-child or child-to-stranger messaging.

Analytics and crash reporting are configured in a privacy-preserving way (no advertising identifiers, coarse region only) and are [optional / on by default with an opt-out — confirm with counsel and reflect the real build].

## 4. How we use information

To provide and sync the service and save progress; to operate parental controls and the consent gate; to keep the app secure and debug crashes; to process subscriptions; to respond to support and parental-rights requests; and to comply with law. We do not use children's personal information for any commercial purpose unrelated to the activity, and we do not profile children for advertising.

## 5. Legal bases (GDPR/UK GDPR)

Where GDPR applies, our bases are: **performance of a contract** (operating the account and features the parent requested); **consent** (the parent's verifiable consent for processing a child's personal data under Article 8, and any optional analytics); and **legitimate interests** for security and core diagnostics, balanced against the heightened protection children are owed. Parental consent can be withdrawn at any time (Section 9). Under Article 8, the digital-consent age is 16 unless a member state has set it lower (as low as 13); [Company] applies the correct threshold per region and obtains verifiable parental consent below it.

## 6. Verifiable parental consent (COPPA) and the parent gate

Before any personal information is collected from a child under 13 (US) or under the applicable GDPR-K age, the app presents a parent gate and obtains verifiable parental consent using [chosen method(s) — e.g., government-ID check, charge-and-refund, signed consent form, knowledge-based authentication; the method must match the risk of the data use]. We keep a record of the consent (who, when, method, scope). A parent may review what has been collected, refuse further collection, and direct deletion at any time. The "direct notice" to parents and the operator-contact details required by COPPA are provided at the consent step and in this policy.

## 7. Who we share with (processors only)

We do not sell or share personal information for advertising. We disclose limited data to vetted service providers ("processors") strictly to run Watoto, each under a written data-protection agreement that bars them from using the data for their own purposes:

- Cloud hosting and database: [provider] — stores account and synced progress data.
- Payment processing: [Stripe / Apple / Google] — handles subscription transactions; [Company] does not store full card numbers.
- Crash and diagnostics: [provider, if used] — receives crash logs configured without ad identifiers.

We may also disclose information if required by law, to protect safety, or in a corporate transaction — in which case children's data continues under privacy commitments at least as protective as this policy, and a material change is notified per Section 14.

## 8. Where data is processed and international transfers

Data may be processed in [regions]. Where data leaves the EU/UK, transfers rely on an approved mechanism such as Standard Contractual Clauses, the UK Addendum, or an adequacy decision, with supplementary measures as needed. [Confirm hosting regions and mechanisms with counsel.]

## 9. Parental rights and controls

A parent/guardian may, at any time: review the child's personal information; correct it; export it in a portable format; delete the child's profile and associated data; refuse further collection or use; and withdraw consent. EU/UK residents also have the rights to restrict or object to certain processing and to lodge a complaint with their supervisory authority; California and other US-state residents have the rights afforded by their state laws. Exercise any of these from the in-app parent area or by emailing [privacy@company]. We respond without undue delay — within [30] days for GDPR requests — and we will not condition a child's participation on disclosing more information than is reasonably necessary.

## 10. Data-retention schedule

We keep personal information only as long as it serves the purpose collected, then delete or irreversibly anonymize it. "Deletion trigger" is the event that starts the clock.

| Data | Retention | Deletion trigger |
|---|---|---|
| Child profile & learning progress | Kept while the account is active and the profile exists | Parent deletes the profile, or account closed → purged within [30] days |
| Account holder record (email, hashed credential, consent record) | Life of the account | Account closure → purged within [30] days (consent record may be retained longer only as evidence of compliance, then deleted) |
| On-device data (offline progress, cached content) | Until the app is uninstalled or local data cleared | User action on device |
| Cloud backups | Rolling [35]-day window | Ages out automatically; deletions propagate to backups within the window |
| Crash & diagnostic logs | [90] days | Auto-expiry |
| Privacy-preserving usage analytics | [14] months, in aggregate/de-identified form | Auto-expiry |
| Support correspondence | [24] months | Auto-expiry after ticket closure |
| Payment & tax records | As required by tax/accounting law in [jurisdiction] (commonly up to [7] years) | Statutory period ends; data minimized to what the law requires |

When a parent deletes a child's profile, we remove it from production systems promptly and from backups within the backup window above. [Confirm each interval with counsel and align to the real infrastructure once the backend is built.]

## 11. Security

We protect data with encryption in transit (TLS) and at rest, role-based and least-privilege access, secret management, audit logging, and regular review. Children never hold their own login credentials — the parent owns the account, and child profiles are accessed through it. No system is perfectly secure, but in the event of a personal-data breach we will notify affected parents and the relevant authorities as required (for GDPR, generally within 72 hours of becoming aware), following our incident-response plan.

## 12. Changes to this policy

If we make a material change — especially one affecting children's data or that would require new parental consent — we will notify the account holder (e.g., by email and in-app) and, where the law requires, obtain fresh consent before the change takes effect for existing data. The "Last updated" date always reflects the current version.

## 13. Contact

Privacy questions and rights requests: [privacy@company]. Postal: [address]. Our [Data Protection Officer / privacy contact] is [name/role]. EU/UK users may also contact their local data-protection supervisory authority; if we have an EU/UK representative, they are [name/contact].

---

## Appendix A — Internal data-retention & deletion runbook (not part of the published policy)

For the engineering and operations team; keep it consistent with Section 10.

- **Deletion request SLA:** acknowledge within [72h]; complete production deletion within [30] days; confirm backup expiry to the requester.
- **Propagation:** deletion job removes records from primary DB, search indexes, caches, and queued sync; flags backups so restores re-apply pending deletions.
- **Account closure flow:** soft-delete (grace period [14] days for accidental closure) → hard-delete → backup expiry → log the completion with timestamp and scope.
- **Consent ledger:** store consent events (subject, timestamp, method, scope, policy version) separately from profile data; retain only as compliance evidence and purge on the schedule above.
- **Data inventory & DPA register:** maintain a living list of every data store and every processor with its DPA, transfer mechanism, and retention setting; review at least [annually] and before adding any new processor.
- **Minimization checks:** before any new field is collected or any new SDK is added, run a data-protection impact assessment (DPIA) given the child audience, and update this policy and the inventory.

## Appendix B — Open items to resolve with counsel before publishing

1. Confirm the verifiable-parental-consent method(s) and that they match the data uses.
2. Set every [bracketed] retention interval and jurisdiction-specific statutory period.
3. Confirm hosting regions, transfer mechanisms, and the final processor list.
4. Decide analytics/crash reporting default (opt-in vs opt-out) and reflect the real build.
5. Localize the policy and the in-app notices for each launch market and language (EN/FR/SW at minimum), including the correct GDPR-K consent age per country.
6. Confirm state-law disclosures (e.g., California) and whether an EU/UK representative or DPO is required.
