# Watoto Authentication

Real authentication for the app, replacing the dev tokens. Built on **Firebase
Auth + Firestore**, with the privacy-protective pattern a children's app needs.

The only thing this code can't do for you is create your Firebase project and
paste in its config — that's the "Your Firebase project" the gate refers to.
Everything else (the working auth) is here.

## What's in `auth/`

| File | Role |
|------|------|
| `firebase.ts` | Initializes Firebase; persists sessions (offline-friendly). |
| `auth.ts` | Parent sign-up/in/out, email verify, password reset, anonymous session, **`getIdToken()`** (replaces dev tokens). |
| `childProfiles.ts` | Child profiles under the parent — minimal, non-identifying data. |
| `parentGate.ts` | Adult-only gate shown before account/data/purchase screens. |
| `index.ts` | Public API. |
| `.env.example` | Firebase client config keys. |

## The design (and why)

For a kids' app under COPPA / GDPR-K, the safe architecture is:

- **Children never create credentialed accounts.** A **parent** signs in with
  email + password and owns everything.
- **Anonymous first.** On launch the app starts an anonymous session, so a
  child can play **offline with no sign-up wall**. When the parent later makes
  an account, that session is **upgraded in place** (progress is preserved).
- **Parent gate.** `makeParentGate()` / `checkParentGate()` stand in front of
  any account, settings, or purchase screen — an action a young child won't
  complete. It's a gate, not identity proof; Firebase Auth is the real identity.
- **Data minimization.** A child profile stores only a nickname, an age band,
  and an avatar id — no email, birthdate, or contact info. Parental consent is
  recorded at sign-up (timestamp + policy version) for your compliance record.

## Setup (about 10 minutes)

1. Create a project at the Firebase console. Add an app and copy its config.
2. In **Authentication -> Sign-in method**, enable **Email/Password** and
   **Anonymous**.
3. Create a **Firestore** database.
4. `cp auth/.env.example .env` and fill in the values.
5. Install dependencies:

   ```bash
   npm install firebase @react-native-async-storage/async-storage
   ```

## Using it

```ts
import {
  ensureAnonymousSession, makeParentGate, checkParentGate,
  signUpParent, signInParent, addChild, listChildren, getIdToken, observeAuth,
} from "@/auth";

// 1) app launch — child can play immediately, offline
await ensureAnonymousSession();

// 2) drive navigation from auth state
const unsub = observeAuth((user) => setUser(user));

// 3) parent taps "Parent area" -> show the gate
const challenge = makeParentGate();        // show challenge.prompt
const ok = checkParentGate(typedInput, challenge);

// 4) behind the gate (consent collected on the sign-up screen)
await signUpParent(email, password, { displayName: "Tony", consent: true });
// or: await signInParent(email, password);

// 5) add a child profile
await addChild({ displayName: "Amara", ageBand: "2-3", avatarId: "fox" });
```

## Replacing the dev tokens (the AWS backend call)

Anywhere you currently attach a dev token, use the Firebase ID token:

```ts
const token = await getIdToken();
await fetch(`${API_BASE}/progress`, {
  headers: { Authorization: `Bearer ${token}` },
});
```

Your AWS backend then **verifies** that token before trusting the request.
Two standard options:

- **Firebase Admin SDK** (simplest): `await admin.auth().verifyIdToken(token)`
  returns the decoded claims (incl. `uid`). Reject on throw.
- **Verify the JWT yourself**: validate the signature against Google's public
  keys at `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`,
  and check `iss` = `https://securetoken.google.com/<projectId>`, `aud` =
  `<projectId>`, and expiry. Use this if your AWS runtime can't pull the Admin SDK.

The decoded `uid` is the parent account; scope all backend data to it.

## Lock down Firestore

Minimum rules so a parent can only touch their own data:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /accounts/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
      match /children/{childId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

## If your stack isn't Expo / React Native

The auth logic in `auth.ts`, `childProfiles.ts`, and `parentGate.ts` is plain
TypeScript on the Firebase JS SDK and is identical on web — only the
persistence block in `firebase.ts` changes (commented inline). If you're on
Flutter/Dart or native, say so and I'll re-emit this module for that SDK.
