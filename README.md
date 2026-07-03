# ClickWheel

A minimal, offline, click-wheel-style music player for iPhone, built to be
installed permanently via **TrollStore** (no jailbreak, no Apple Developer
account, no Mac required).

It plays audio files you drop into its own folder over a USB cable, and shows a
classic iPod-style interface: a scroll wheel, a song list, and a now-playing
screen with album art and lock-screen controls.

## How it gets built without a Mac

You don't compile anything locally. When you push this project to GitHub, the
included GitHub Actions workflow (`.github/workflows/build.yml`) builds it on a
cloud macOS machine and produces an unsigned `.ipa`. TrollStore fake-signs the
app when you install it, so it never needs a signing certificate.

### Steps

1. Create a free GitHub account and a new (empty) repository.
2. Push everything in this folder to the repo's `main` branch.
3. Open the **Actions** tab — the build runs automatically (~3–5 min).
4. Get the `.ipa`:
   - **On a computer:** open the finished run and download the `ClickWheel-ipa`
     artifact (a zip containing `ClickWheel.ipa`).
   - **On the phone:** open the repo's **Releases** page (a release tagged
     `latest` is created each build) and download `ClickWheel.ipa` directly in
     Safari.

## Installing on the phone (with TrollStore already installed)

- **First install:** briefly reinsert a SIM for data, open the Releases page in
  Safari, download `ClickWheel.ipa`, then tap it → Share → **TrollStore** →
  Install. Remove the SIM afterwards.
- **Later updates (fully offline):** with ClickWheel already installed, drop a
  newer `ClickWheel.ipa` into the app's folder over USB (via iMazing / 3uTools),
  then in the **Files** app open *On My iPhone → ClickWheel*, tap the `.ipa`,
  and Share → TrollStore → Install.

## Adding music (fully offline, over USB)

The app has iTunes File Sharing enabled, so its **Documents** folder is visible
in iMazing / 3uTools / Finder under the app's name. Drag your `.mp3` / `.m4a`
(and other) files straight in over the cable, then reopen the app — it scans
that folder on launch.

Native playback covers MP3, AAC/M4A, ALAC, WAV and AIFF. (FLAC support via the
audio engine can be hit-or-miss; convert those to M4A if any don't appear.)

## Kiosk / "iPod mode"

Turn on **Settings → Accessibility → Guided Access**, then triple-click the side
button inside the app to lock the phone to ClickWheel only.
