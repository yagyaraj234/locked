// Set NEXT_PUBLIC_SITE_URL to the deployed origin; canonical, sitemap and OG URLs are built from it.
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
export const REPO = "https://github.com/yagyaraj234/locked";
// Always the newest release; the asset must be named Locked.dmg.
export const DOWNLOAD = `${REPO}/releases/latest/download/Locked.dmg`;

export const TITLE = "Locked: block distracting apps and sites on your Mac";
export const DESCRIPTION =
  "A macOS menu bar app that blocks distracting apps and websites during the hours you choose. Works in Safari, Chrome, Arc, Brave, Edge and Firefox. No account, nothing leaves your Mac. Free for now.";

export const FAQ = [
  {
    q: "Is Locked free?",
    a: "Right now, yes. No price, no licence key, no account.",
  },
  {
    q: "Will Locked always be free?",
    a: "No. Locked is free while it is early. Later versions will need a paid licence, so this is the time to get it.",
  },
  {
    q: "If I get it now, will it keep working?",
    a: "Yes. The version you install today has no licence check and makes no network requests, so nothing can switch it off later.",
  },
  {
    q: "Is Locked open source?",
    a: "No. Locked is free to download today, but it is not open source.",
  },
  {
    q: "How do I install it?",
    a: "Download Locked.dmg, drag Locked to Applications and open it. If macOS blocks it the first time, go to System Settings, Privacy & Security, and click Open Anyway. Then allow Accessibility when Locked asks.",
  },
  {
    q: "Which browsers does site blocking work in?",
    a: "Safari, Chromium browsers such as Chrome, Arc, Brave, Edge, Vivaldi and Helium, and Firefox-family browsers such as Firefox, Zen, LibreWolf and Floorp.",
  },
  {
    q: "Does Locked quit my apps?",
    a: "No. A blocked app is hidden and covered by a full-screen block screen. It is never force-quit, so unsaved work is not lost.",
  },
  {
    q: "Can I block one part of a site and keep the rest?",
    a: "Yes. Add a rule with a path, such as youtube.com/shorts. Only addresses under that path are blocked; the rest of the site stays open.",
  },
  {
    q: "Can a session run past midnight?",
    a: "Yes. Set an end time earlier than the start time, such as 22:30 to 07:00, and the session runs into the next morning.",
  },
  {
    q: "What stops me from just turning it off?",
    a: "Ending a session early takes a 60-second countdown in a window that has to stay in front. While a session is active there is no Quit command and its block list cannot be edited.",
  },
  {
    q: "What permission does it need?",
    a: "One: Accessibility, which lets Locked read the address of the front browser tab. It needs nothing per browser.",
  },
  {
    q: "Does anything leave my Mac?",
    a: "No. Locked makes no network requests. Sessions are stored locally on your Mac.",
  },
  {
    q: "Is there an iPhone or Android version?",
    a: "Both are planned. Today Locked runs on Mac, on macOS 15 or later.",
  },
];
