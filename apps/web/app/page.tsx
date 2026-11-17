import { Countdown } from "./countdown";
import { HowDemo } from "./how";
import icon from "./icon.svg";
import { Download } from "./download";
import { DESCRIPTION, FAQ, REPO, SITE_URL } from "./site";

const LOCK =
  "M12 1.5a5.5 5.5 0 0 0-5.5 5.5v3H6a2.5 2.5 0 0 0-2.5 2.5v7A2.5 2.5 0 0 0 6 22h12a2.5 2.5 0 0 0 2.5-2.5v-7A2.5 2.5 0 0 0 18 10h-.5V7A5.5 5.5 0 0 0 12 1.5Zm-3 8.5V7a3 3 0 0 1 6 0v3H9Z";

function Lock() {
  return (
    <svg className="lock" viewBox="0 0 24 24" aria-hidden="true">
      <path d={LOCK} />
    </svg>
  );
}

const MATCHES = [
  ["youtube.com/shorts/x7Kd", true, "Under the path"],
  ["www.youtube.com/watch?v=dQw4", false, "Different path"],
  ["m.youtube.com/shorts", true, "Subdomains count"],
  ["youtube.com/shortsighted", false, "Not a whole segment"],
  ["old.reddit.com/r/all", true, "Subdomains count"],
  ["notreddit.com", false, "Lookalike domain"],
] as const;

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
// [day index, start hour, end hour, kind, label]. Wind down starts Sun to Thu at 22:30 and ends at 07:00 the next day.
const BARS: [number, number, number, "work" | "night", string?][] = [
  ...[0, 1, 2, 3, 4].map((d): [number, number, number, "work", string?] => [d, 9, 13, "work", d === 0 ? "Deep work" : undefined]),
  ...[6, 0, 1, 2, 3].map((d): [number, number, number, "night", string?] => [d, 22.5, 24, "night"]),
  ...[0, 1, 2, 3, 4].map((d): [number, number, number, "night", string?] => [d, 0, 7, "night", d === 0 ? "Wind down" : undefined]),
];

const SPECS = [
  ["Requires", "macOS 15 or later"],
  ["Price", "Free for now. Get it before that changes"],
  ["Account", "None"],
  ["Network", "No requests, ever"],
  ["Permission", "Accessibility, to read the front tab’s address"],
  ["Stores", "Your sessions, locally on your Mac"],
  ["Built with", "Swift and SwiftUI, no third-party code"],
  ["Install", "Download, drag to Applications, open"],
];

const jsonLd = [
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Locked",
    description: DESCRIPTION,
    url: SITE_URL,
    applicationCategory: "ProductivityApplication",
    operatingSystem: "macOS 15 or later",
    offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: FAQ.map(({ q, a }) => ({
      "@type": "Question",
      name: q,
      acceptedAnswer: { "@type": "Answer", text: a },
    })),
  },
];

export default function Home() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <a className="skip" href="#main">
        Skip to content
      </a>

      <header className="nav">
        <a className="brand" href="#top" aria-label="Locked home">
          <img src={icon.src} alt="" width={26} height={26} />
          Locked
        </a>
        <nav aria-label="Primary">
          <a href="#how">How it works</a>
          <a href="#sites">Sites</a>
          <a href="#schedule">Schedule</a>
          <a href="#faq">Questions</a>
        </nav>
        <Download className="btn btn-primary btn-sm">
          Get it free
        </Download>
      </header>

      <main id="main">
        <section className="hero wrap" id="top" aria-labelledby="hero-title">
          <p className="chip">
            <span>Free for now</span> macOS 15 or later, no account
          </p>
          <h1 id="hero-title">Block distracting apps and sites on your Mac.</h1>
          <p className="lede">
            Locked sits in your menu bar. Pick the hours, pick what to block, and write down why. While a session runs,
            blocked apps hide behind your goal and blocked sites are turned away in any browser.
          </p>
          <div className="actions">
            <Download className="btn btn-primary">
              Get it while it’s free
            </Download>
            <a className="btn" href="#how">
              See how it works
            </a>
          </div>
          <div
            className="desk"
            role="img"
            aria-label="A Mac desktop during a Locked session. A browser tab on youtube.com/shorts is replaced by a block page showing the goal: Finish the report."
          >
            <div className="menubar">
              <span>Safari</span>
              <span className="menubar-right">
                <Lock />
                Tue 10:42
              </span>
            </div>
            <div className="browser">
              <div className="toolbar">
                <i />
                <i />
                <i />
                <div className="url swap">
                  <span className="before">youtube.com/shorts</span>
                  <span className="after">Locked</span>
                </div>
              </div>
              <div className="viewport swap">
                <div className="before feed">
                  {Array.from({ length: 5 }, (_, i) => (
                    <b key={i} />
                  ))}
                </div>
                <div className="after block">
                  <Lock />
                  <p className="m-label">This site is locked</p>
                  <p className="goal">Finish the report</p>
                  <p className="m-foot">It opens again when your session ends.</p>
                </div>
              </div>
            </div>
            <div className="panel">
              <p className="m-label">Active</p>
              <p className="panel-name">Deep work</p>
              <p className="panel-time">2h 18m left</p>
              <ul>
                <li>youtube.com/shorts</li>
                <li>reddit.com</li>
                <li>Discord</li>
              </ul>
              <span className="m-button">End early…</span>
            </div>
          </div>
          <ul className="trust">
            <li>Nothing leaves your Mac</li>
            <li>Never quits your apps</li>
            <li>One permission</li>
            <li>No account</li>
            <li>Native Swift, no third-party code</li>
          </ul>
        </section>

        <section className="wrap" id="how" aria-labelledby="how-title">
          <div className="head">
            <h2 id="how-title">A session is a goal, a list and some hours.</h2>
            <p>
              That is the whole model. Make one for work and one for winding down, and each keeps its own rules. Setup
              takes about a minute on first launch.
            </p>
          </div>
          <HowDemo />
        </section>

        <section className="wrap" id="apps" aria-labelledby="apps-title">
          <div className="head">
            <h2 id="apps-title">Blocked apps hide. They never quit.</h2>
            <p>
              Switch to a blocked app and it is hidden the same moment, covered by a full screen showing your goal. Your
              unsaved work stays exactly where it was.
            </p>
          </div>
          <div className="stage">
            <div className="mock block tall" aria-hidden="true">
              <Lock />
              <p className="m-label">Locked</p>
              <p className="goal">Finish the report</p>
              <span className="m-button">Back to work</span>
              <p className="m-foot">Click anywhere or press Return</p>
            </div>
          </div>
          <div className="notes">
            <div className="tile">
              <h3>Already open still counts</h3>
              <p className="tile-panel">An app left open when the session started is blocked the next time you bring it forward.</p>
            </div>
            <div className="tile">
              <h3>Sessions stack</h3>
              <p className="tile-panel">Two active sessions block everything on both lists. Starting one never weakens another.</p>
            </div>
            <div className="tile">
              <h3>Out of your way</h3>
              <p className="tile-panel">No Dock icon and no notifications. The menu bar icon changes while a session is active.</p>
            </div>
          </div>
        </section>

        <section className="wrap" id="sites" aria-labelledby="sites-title">
          <div className="head">
            <h2 id="sites-title">Block a whole site, or only the part that eats your day.</h2>
            <p>
              A rule is a domain with an optional path. Keep YouTube for the tutorial and lose the Shorts feed. Typed,
              clicked or sitting in an old tab, a blocked address is caught either way.
            </p>
          </div>
          <div className="stage">
            <div className="mock rules">
              <p className="m-label">Rules</p>
              <p className="tags mono">
                <span>youtube.com/shorts</span>
                <span>reddit.com</span>
              </p>
              <table>
                <caption className="sr">How example addresses match those rules</caption>
                <thead className="sr">
                  <tr>
                    <th scope="col">Address</th>
                    <th scope="col">Result</th>
                    <th scope="col">Why</th>
                  </tr>
                </thead>
                <tbody>
                  {MATCHES.map(([url, blocked, why]) => (
                    <tr key={url}>
                      <td className="mono">{url}</td>
                      <td>
                        <span className={blocked ? "verdict hot" : "verdict"}>{blocked ? "Blocked" : "Allowed"}</span>
                      </td>
                      <td>{why}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          <div className="notes">
            <div className="tile">
              <h3>Any browser you use</h3>
              <p className="tile-panel">Safari, Chrome, Arc, Brave, Edge, Vivaldi and Firefox-family browsers. Switching browser is not a loophole.</p>
            </div>
            <div className="tile">
              <h3>One permission</h3>
              <p className="tile-panel">Locked reads the front tab’s address through Accessibility. There is nothing to approve per browser and no extension to install.</p>
            </div>
            <div className="tile">
              <h3>Everything else is left alone</h3>
              <p className="tile-panel">Only addresses that match a rule are touched. Sites that aren’t on your list never notice Locked is there.</p>
            </div>
          </div>
        </section>

        <section className="wrap" id="schedule" aria-labelledby="schedule-title">
          <div className="head">
            <h2 id="schedule-title">Set the week once.</h2>
            <p>
              Give a session its days and times and it starts and stops on its own. Locked opens at login, so the
              schedule holds without you remembering to run anything.
            </p>
          </div>
          <div className="stage">
            <div
              className="mock week"
              role="img"
              aria-label="A week of sessions. Deep work runs Monday to Friday, 09:00 to 13:00. Wind down runs Sunday to Thursday from 22:30 until 07:00 the next morning."
            >
              <div className="hours" aria-hidden="true">
                {["00", "06", "12", "18"].map((h) => (
                  <span key={h}>{h}</span>
                ))}
              </div>
              {DAYS.map((day, d) => (
                <div className="day" key={day}>
                  <p>{day}</p>
                  <div className="track">
                    {BARS.filter(([bd]) => bd === d).map(([, from, to, kind, label]) => (
                      <span
                        key={from}
                        className={`bar ${kind}`}
                        style={{ top: `${(from / 24) * 100}%`, height: `${((to - from) / 24) * 100}%` }}
                      >
                        {label}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div className="notes">
            <div className="tile">
              <h3>Past midnight</h3>
              <p className="tile-panel">End earlier than you start, like 22:30 to 07:00, and the session runs into the next morning.</p>
            </div>
            <div className="tile">
              <h3>Sleep is not a loophole</h3>
              <p className="tile-panel">After a restart, a relaunch or a wake mid-session, the session is still active and the blocks are still up.</p>
            </div>
            <div className="tile">
              <h3>Or just start one</h3>
              <p className="tile-panel">A session without a schedule waits for you. Start it from the menu bar and choose how long it lasts.</p>
            </div>
          </div>
        </section>

        <section className="wrap" id="friction" aria-labelledby="friction-title">
          <div className="head">
            <h2 id="friction-title">Ending early costs sixty seconds.</h2>
            <p>
              You can always stop a session. A real need shouldn’t be blocked by your own tool. It takes a minute of
              looking at the countdown, and that is usually enough. Try it.
            </p>
          </div>
          <div className="stage">
            <Countdown />
          </div>
          <div className="notes">
            <div className="tile">
              <h3>No Quit while active</h3>
              <p className="tile-panel">The Quit command is gone until the session ends, so quitting is not the easy way out.</p>
            </div>
            <div className="tile">
              <h3>The list is locked too</h3>
              <p className="tile-panel">An active session’s apps, sites, goal and schedule can’t be edited. You can’t quietly remove the one you’re craving.</p>
            </div>
            <div className="tile">
              <h3>Your work stays safe</h3>
              <p className="tile-panel">A blocked app is hidden behind your goal, never force-quit. Nothing unsaved is lost.</p>
            </div>
          </div>
        </section>

        <section className="wrap" id="scope" aria-labelledby="scope-title">
          <div className="head">
            <h2 id="scope-title">A small tool, on purpose.</h2>
            <p>Locked does one job. Most of what other blockers add is deliberately missing.</p>
          </div>
          <div className="scope">
            <div className="tile">
              <h3>What it does</h3>
              <ul className="tile-panel">
                <li>Named sessions, each with its own goal</li>
                <li>App blocking and site blocking</li>
                <li>Path rules for part of a site</li>
                <li>Weekly schedules, including overnight</li>
                <li>Start now, for a chosen duration</li>
                <li>A 60-second wait to end early</li>
              </ul>
            </div>
            <div className="tile out">
              <h3>What it leaves out</h3>
              <ul className="tile-panel">
                <li>Accounts and sign-in</li>
                <li>Streaks, scores and insights</li>
                <li>Notifications</li>
                <li>Soundscapes</li>
                <li>Telemetry of any kind</li>
              </ul>
            </div>
          </div>
          <dl className="specs">
            {SPECS.map(([k, v]) => (
              <div key={k}>
                <dt>{k}</dt>
                <dd>{v}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="wrap" id="faq" aria-labelledby="faq-title">
          <div className="head">
            <h2 id="faq-title">Questions, answered.</h2>
          </div>
          <div className="faq">
            {FAQ.map(({ q, a }) => (
              <details key={q} className="tile">
                <summary>{q}</summary>
                <p className="tile-panel">{a}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="wrap" id="get" aria-labelledby="get-title">
          <div className="get">
            <img src={icon.src} alt="" width={72} height={72} />
            <h2 id="get-title">Get Locked while it’s free.</h2>
            <p>Free today, not forever. Install it once and it opens at login from then on.</p>
            <Download className="btn btn-primary">
              Download Locked
            </Download>
          </div>
        </section>
      </main>

      <footer className="wrap foot">
        <p>Locked. A website and app blocker for macOS.</p>
        <nav aria-label="Footer">
          <a href={REPO}>GitHub</a>
          <a href={`${REPO}/issues`}>Issues</a>
          <a href="#faq">Questions</a>
        </nav>
      </footer>
    </>
  );
}
