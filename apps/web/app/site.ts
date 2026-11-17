// Set NEXT_PUBLIC_SITE_URL to the deployed origin; canonical, sitemap and OG URLs are built from it.
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
export const REPO = "https://github.com/yagyaraj234/locked";

export const TITLE = "Locked: block distracting apps and sites on your Mac";
export const DESCRIPTION =
  "A free macOS menu bar app that blocks distracting apps and websites during the hours you choose. Works in Safari, Chrome, Arc, Brave, Edge and Firefox. No account, nothing leaves your Mac.";

export const FAQ = [
  {
    q: "Is Locked free?",
    a: "Yes. There is no price, no subscription, no licence key and no account. The source is on GitHub.",
  },
  {
    q: "How do I install it?",
    a: "For now you build it yourself: clone the repository, run xcodegen in apps/macos, and run the Locked scheme from Xcode. There is no signed, notarized download yet.",
  },
  {
    q: "Which browsers does site blocking work in?",
    a: "Safari, and Chromium browsers such as Chrome, Arc, Brave, Edge, Vivaldi and Helium. Firefox-family browsers (Firefox, Zen, LibreWolf, Floorp) are recognised too, but that path has not been tested yet.",
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
    a: "Ending a session early takes a 60-second countdown in a window that has to stay in front. While a session is active there is no Quit command and its block list cannot be edited. You can still kill the process from Activity Monitor; the friction is deliberate, but light.",
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
    a: "Not yet. Both are planned; today Locked is macOS only and needs macOS 15 or later.",
  },
];
