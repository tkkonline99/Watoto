/**
 * Firebase initialization for the Watoto app.
 *
 * One place to configure Firebase. Auth state is persisted so a signed-in
 * parent (or an anonymous child session) survives app restarts and works
 * offline — which matches the curriculum's "offline play" universal rule.
 *
 * STACK NOTE: written for React Native / Expo (the assumed stack). If you are
 * on web, swap the persistence block as marked below. If you are on Flutter,
 * this file is replaced by FlutterFire init in Dart — ask and I'll re-emit.
 */
import { initializeApp, getApps, getApp, type FirebaseApp } from "firebase/app";
import {
  initializeAuth,
  getAuth,
  getReactNativePersistence,
  type Auth,
} from "firebase/auth";
import { getFirestore, type Firestore } from "firebase/firestore";
import AsyncStorage from "@react-native-async-storage/async-storage";

// --- config -----------------------------------------------------------------
// These are NOT secrets (client config is public by design); real security
// comes from Firebase Security Rules + your backend verifying ID tokens.
// Values are injected from your Firebase project via env (.env.example).
const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID,
};

function assertConfig() {
  const missing = Object.entries(firebaseConfig)
    .filter(([, v]) => !v)
    .map(([k]) => k);
  if (missing.length) {
    throw new Error(
      `Firebase config missing: ${missing.join(", ")}. ` +
        `Copy auth/.env.example to .env and fill in your Firebase project values.`,
    );
  }
}

// --- singletons --------------------------------------------------------------
export const app: FirebaseApp = getApps().length
  ? getApp()
  : (assertConfig(), initializeApp(firebaseConfig));

// React Native: persist auth in AsyncStorage so sessions survive restarts.
// WEB SWAP: replace the two lines below with:
//   import { browserLocalPersistence } from "firebase/auth";
//   export const auth = getAuth(app); setPersistence(auth, browserLocalPersistence);
export const auth: Auth = getApps().length
  ? getAuth(app)
  : initializeAuth(app, { persistence: getReactNativePersistence(AsyncStorage) });

export const db: Firestore = getFirestore(app);
