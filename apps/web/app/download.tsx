"use client";

import { useId, useRef, useState, type ReactNode } from "react";
import icon from "./icon.svg";
import { DOWNLOAD } from "./site";

const UNBLOCK = "xattr -cr /Applications/Locked.app";

// A download button that first explains the one command an unsigned app needs.
export function Download({ className, children }: { className: string; children: ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const title = useId();
  const [copied, setCopied] = useState(false);

  async function copy() {
    await navigator.clipboard.writeText(UNBLOCK);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <>
      <button type="button" className={className} onClick={() => dialog.current?.showModal()}>
        {children}
      </button>
      {/* The dialog has no padding of its own, so a click that lands on it directly is a click on the backdrop. */}
      <dialog
        ref={dialog}
        className="dl"
        aria-labelledby={title}
        onClick={(e) => e.target === e.currentTarget && e.currentTarget.close()}
      >
        <div className="dl-body">
          <form method="dialog">
            <button className="dl-close" aria-label="Close">
              ×
            </button>
          </form>
          <img src={icon.src} alt="" width={56} height={56} />
          <h2 id={title}>One command, then you’re in.</h2>
          <p>Locked isn’t signed with Apple yet, so macOS warns you the first time. Here’s how to get past it:</p>
          <ol>
            <li>Open the downloaded Locked.dmg and drag Locked into Applications.</li>
            <li>Open Terminal and run this command once:</li>
          </ol>
          <div className="dl-cmd">
            <code>{UNBLOCK}</code>
            <button type="button" onClick={copy} aria-live="polite">
              {copied ? "Copied" : "Copy"}
            </button>
          </div>
          <p>Then open Locked and allow Accessibility when it asks. It opens normally from then on.</p>
          <a className="btn btn-primary" href={DOWNLOAD} onClick={() => dialog.current?.close()}>
            Got it, download Locked
          </a>
        </div>
      </dialog>
    </>
  );
}
