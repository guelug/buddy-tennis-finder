import {
  browserLocalPersistence,
  GoogleAuthProvider,
  setPersistence,
  signInWithPopup,
  type Auth,
  type UserCredential
} from "firebase/auth";

export async function runGooglePopup(auth: Auth): Promise<UserCredential> {
  await setPersistence(auth, browserLocalPersistence);
  const provider = new GoogleAuthProvider();
  provider.addScope("email");
  provider.addScope("profile");
  provider.setCustomParameters({ prompt: "select_account" });
  return signInWithPopup(auth, provider);
}
