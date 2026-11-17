"use client";

import { useEffect, useReducer } from "react";

const FULL = 60;
const R = 54;
const C = 2 * Math.PI * R;

// idle → counting ⇄ away (the count waits at 60) → done. A click from counting or away goes back to idle.
type Phase = "idle" | "counting" | "away" | "done";
type State = { phase: Phase; left: number; note: string };
type Event = "click" | "tick" | "leave" | "enter";

const IDLE: State = { phase: "idle", left: FULL, note: "" };

function reduce(s: State, e: Event): State {
  switch (e) {
    case "click":
      return s.phase === "idle" || s.phase === "done" ? { phase: "counting", left: FULL, note: "" } : IDLE;
    case "tick":
      if (s.phase !== "counting") return s;
      return { ...s, phase: s.left === 1 ? "done" : "counting", left: s.left - 1 };
    case "leave":
      if (s.phase !== "counting" && s.phase !== "away") return s;
      return { phase: "away", left: FULL, note: s.left < FULL ? "You left. The countdown is back to 60." : s.note };
    case "enter":
      return s.phase === "away" ? { ...s, phase: "counting" } : s;
  }
}

// A working copy of the app's End early window: the count only runs while you stay on it.
export function Countdown() {
  const [{ phase, left, note }, dispatch] = useReducer(reduce, IDLE);

  useEffect(() => {
    if (phase !== "counting") return;
    const id = setTimeout(() => dispatch("tick"), 1000);
    return () => clearTimeout(id);
  }, [phase, left]);

  useEffect(() => {
    const leave = () => dispatch("leave");
    window.addEventListener("blur", leave);
    return () => window.removeEventListener("blur", leave);
  }, []);

  const done = phase === "done";
  // The arc aims at the next second while counting, so it lands together with the digit.
  const ticking = phase === "counting";
  return (
    <div
      className="early"
      onPointerEnter={() => dispatch("enter")}
      onPointerLeave={(e) => e.pointerType === "mouse" && dispatch("leave")}
      onFocus={() => dispatch("enter")}
    >
      <p className="m-label">{done ? "Session ended" : "Ending “Deep work”"}</p>
      <div className="dial" role="timer" aria-label={`${left} seconds left`}>
        <svg viewBox="0 0 120 120" aria-hidden="true">
          <circle cx="60" cy="60" r={R} />
          <circle cx="60" cy="60" r={R} className={ticking ? "dial-arc ticking" : "dial-arc"} strokeDasharray={C} strokeDashoffset={C * (1 - (ticking ? left - 1 : left) / FULL)} />
        </svg>
        <span>{left}</span>
      </div>
      <p className="early-hint">
        {done
          ? "That took a full minute. Most urges don’t last that long."
          : "Keep this window in front. Leaving it restarts the countdown."}
      </p>
      <button type="button" className="m-button" onClick={() => dispatch("click")}>
        {done ? "Try it again" : phase === "idle" ? "End early…" : "Keep going"}
      </button>
      <p className="early-note" aria-live="polite">
        {note}
      </p>
    </div>
  );
}
