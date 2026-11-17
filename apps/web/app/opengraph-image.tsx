import { ImageResponse } from "next/og";

export const alt = "Locked: block distracting apps and sites on your Mac";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: 96,
          color: "#fff",
          background: "radial-gradient(circle at 50% 0%, #5b3fd0 0%, #0d0f14 62%)",
        }}
      >
        <div style={{ fontSize: 30, letterSpacing: 6, color: "rgba(255,255,255,0.6)" }}>LOCKED</div>
        <div style={{ marginTop: 28, fontSize: 92, fontWeight: 700, lineHeight: 1, letterSpacing: -4, maxWidth: 920 }}>
          Block distracting apps and sites on your Mac.
        </div>
        <div style={{ marginTop: 40, fontSize: 32, color: "rgba(255,255,255,0.6)" }}>
          Free for now. No account. Nothing leaves your Mac.
        </div>
      </div>
    ),
    size,
  );
}
