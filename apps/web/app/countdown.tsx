"use client";

import { useEffect, useState } from "react";

const FULL = 60;
const R = 54;
const C = 2 * Math.PI * R;

// A working copy of the app's End early window: the count only runs while you stay on it.
export function Countdown() {
  const [running, setRunning] = useState(false);
  const [inside, setInside] = useState(true);
  const [left, setLeft] = useState(FULL);
  const [note, setNote] = useState("");

  useEffect(() => {
    if (!running || !inside || left === 0) return;
    const id = setTimeout(() => setLeft((n) => n - 1), 1000);
    return () => clearTimeout(id);
  }, [running, inside, left]);

  useEffect(() => {
    const leave = () => away();
    window.addEventListener("blur", leave);
    return () => window.removeEventListener("blur", leave);
  });

  function away() {
    if (!running || left === 0) return;
    setInside(false);
    if (left < FULL) setNote("You left. The countdown is back to 60.");
    setLeft(FULL);
  }

  function toggle() {
    setNote("");
    setLeft(FULL);
    setInside(true);
    setRunning(!running || left === 0);
  }

  const done = left === 0;
  // The arc aims at the next second while counting, so it lands together with the digit.
  const ticking = running && inside && !done;
  return (
    <div
      className="early"
      onPointerEnter={() => setInside(true)}
      onPointerLeave={(e) => e.pointerType === "mouse" && away()}
      onFocus={() => setInside(true)}
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
      <button type="button" className="m-button" onClick={toggle}>
        {done ? "Try it again" : running ? "Keep going" : "End early…"}
      </button>
      <p className="early-note" aria-live="polite">
        {note}
      </p>
    </div>
  );
}
