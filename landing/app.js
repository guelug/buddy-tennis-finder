"use strict";

const APPLE_STORE_URL = "https://apps.apple.com/app/id6793740051";
const ALLOWED_INVITE_KEYS = new Set(["code", "inviteCode"]);

document.querySelectorAll(".ios-link").forEach((link) => {
  link.href = APPLE_STORE_URL;
});

if (/Android/i.test(navigator.userAgent)) {
  document.querySelectorAll(".android-link").forEach((link) => {
    link.classList.remove("secondary");
  });
}

if (location.pathname === "/private-league") {
  const incoming = new URLSearchParams(location.search);
  const safeParams = new URLSearchParams();

  for (const [key, value] of incoming) {
    const normalized = value.trim();
    if (ALLOWED_INVITE_KEYS.has(key) && /^[A-Za-z0-9_-]{4,64}$/.test(normalized)) {
      safeParams.set(key, normalized);
    }
  }

  if ([...safeParams].length > 0) {
    const deepLink = `matchpoint://private-league?${safeParams.toString()}`;
    window.setTimeout(() => {
      location.assign(deepLink);
    }, 250);
  }
}
