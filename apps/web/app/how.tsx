"use client";

import { useEffect, useRef, useState } from "react";

const STEPS = [
  ["Write the goal", "The one line you’ll see every time something is blocked. It is the reason, in your own words."],
  ["Pick what to block", "Choose apps from your Applications folder. Type a domain to block a site, or add a path to block part of one."],
  ["Set the hours, or start now", "Repeat it weekly and it runs without you. Or start it by hand from the menu bar for as long as you need."],
];
const GOAL = "Finish the report";
// [name, seconds into the screen when the cursor picks it]
const KINDS: [string, number?][] = [["Social", 1.2], ["Video", 2], ["News"], ["Games"], ["Shopping"], ["Chat", 2.8]];
const PICKED = [["reddit.com", 1.2], ["youtube.com", 2], ["Discord", 2.8]] as const;
const WHEN = [
  ["Work hours", "Monday to Friday, 9 am to 5 pm"],
  ["Evenings", "Every day, 8 pm to 11 pm"],
  ["Only when I start it", "From the menu bar, for as long as I pick"],
];
// One colour per step, from the tile marks. The first keeps the app's own tint.
const TINTS = [undefined, "#e8498f", "#f08a24"];
const REDUCED = "(prefers-reduced-motion: reduce)";

const at = (s: number) => ({ "--at": `${s}s` }) as React.CSSProperties;

function Cursor() {
  return (
    <svg className="cursor" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M5 3l14 8-6 2-3 6z" />
    </svg>
  );
}

// The app's own setup, played through: each step on the left drives the matching screen on the right.
export function HowDemo() {
  const mock = useRef<HTMLDivElement>(null);
  const [step, setStep] = useState(0);
  const [auto, setAuto] = useState(true);
  const [inView, setInView] = useState(false);
  const [typed, setTyped] = useState(0);

  useEffect(() => {
    const io = new IntersectionObserver(([e]) => setInView(e.isIntersecting), { threshold: 0.4 });
    io.observe(mock.current!);
    return () => io.disconnect();
  }, []);

  // Plays on its own until a step is chosen by hand, and only while it can be seen.
  useEffect(() => {
    if (!auto || !inView || matchMedia(REDUCED).matches) return;
    const id = setTimeout(() => setStep((s) => (s + 1) % STEPS.length), 5000);
    return () => clearTimeout(id);
  }, [auto, inView, step]);

  useEffect(() => {
    if (step !== 0 || !inView) return;
    if (matchMedia(REDUCED).matches) return setTyped(GOAL.length);
    let n = -6; // about 0.4s of nothing while the screen arrives
    setTyped(0);
    const id = setInterval(() => {
      setTyped(Math.max(0, ++n));
      if (n >= GOAL.length) clearInterval(id);
    }, 70);
    return () => clearInterval(id);
  }, [step, inView]);

  const screen = (i: number) => (i === step ? "screen on" : "screen");
  return (
    <div className="stage split">
      <ol className="steps">
        {STEPS.map(([title, text], i) => (
          <li key={title} className={i === step ? "on" : undefined} style={{ "--mark": TINTS[i] } as React.CSSProperties}>
            <h3>
              <button
                type="button"
                aria-current={i === step ? "step" : undefined}
                onClick={() => {
                  setAuto(false);
                  setStep(i);
                }}
              >
                {title}
              </button>
            </h3>
            <p>{text}</p>
          </li>
        ))}
      </ol>
      <div className="mock block setup" aria-hidden="true" ref={mock} style={{ "--m-tint": TINTS[step] } as React.CSSProperties}>
        <div className={screen(0)}>
          <p className="q">What do you want to get done?</p>
          <p className="q-detail">Locked shows you this whenever it blocks something.</p>
          <p className="field">
            {typed ? GOAL.slice(0, typed) : <span>Your goal</span>}
            <i />
          </p>
        </div>
        <div className={screen(1)}>
          <p className="q">What pulls you away?</p>
          <p className="q-detail">Pick all that apply.</p>
          <div className="cards">
            {KINDS.map(([name, t]) => (
              <span key={name} className={t ? "pick" : undefined} style={t ? at(t) : undefined}>
                {name}
              </span>
            ))}
            <Cursor />
          </div>
          <p className="tags mono">
            {PICKED.map(([name, t]) => (
              <span key={name} className="late" style={at(t)}>
                {name}
              </span>
            ))}
          </p>
        </div>
        <div className={screen(2)}>
          <p className="q">When should it lock?</p>
          <p className="q-detail">You can change the hours later.</p>
          <div className="cards opts">
            {WHEN.map(([title, detail], i) => (
              <span key={title} className={i ? undefined : "pick"} style={i ? undefined : at(1.4)}>
                <b>{title}</b>
                {detail}
              </span>
            ))}
            <Cursor />
          </div>
        </div>
      </div>
    </div>
  );
}
