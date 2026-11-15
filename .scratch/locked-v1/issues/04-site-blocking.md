# 04: Site blocking

**What to build:** In Settings I can add sites to a session as a domain with an optional path. While the session is active, a matching tab in Safari, Chrome, Arc, Brave or Edge is redirected to a block page showing my goal, whether I typed the address, followed a link or switched to an existing tab. Sites not on the list are untouched.

This ticket settles the open risk in `spec.md`: try redirecting to a bundled local page first; if browsers refuse it, redirect to `about:blank` and show the native block screen. Record which one was used in the README.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Settings can add and remove site rules on a session
- [ ] A rule with only a domain blocks that domain and its subdomains
- [ ] A rule with a path blocks only URLs under that path
- [ ] A matching tab is redirected within about a second in each of Safari, Chrome, Arc, Brave and Edge
- [ ] The user sees their goal after the redirect
- [ ] Non-matching sites and browsers with no active site rules are left alone
- [ ] The app declares its Apple Events usage so macOS shows the Automation prompt
- [ ] The panel lists blocked sites alongside blocked apps
- [ ] Policy tests cover: exact domain, subdomain, a lookalike domain that must not match, path prefix, `www.` and host case
