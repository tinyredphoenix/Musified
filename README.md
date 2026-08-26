# Musified (v5.0)

<div align="center">

**A lightweight, native-feeling music streaming application crafted for iOS & LiveContainer.**  
*Seamless dual-source streaming (320kbps Lossless JioSaavn + YouTube Music), YouTube cloud sync, real-time karaoke lyrics, and pure Apple Music aesthetic.*

[![Version](https://img.shields.io/badge/version-5.0.0-blue.svg?style=flat-square)](https://github.com/tinyredphoenix/Musified/releases)
[![License](https://img.shields.io/badge/license-GPLv3-green.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20LiveContainer-black.svg?style=flat-square)](https://github.com/tinyredphoenix/Musified)

</div>

---

## ✨ Features

### 🎵 Dual-Source Audio Engine
- **JioSaavn 320kbps Lossless AAC**: Primary high-fidelity audio stream with CD-quality clarity.
- **YouTube Music Automatic Fallback**: Seamless $< 1$s parallel resolution fallback whenever tracks are exclusive to YouTube.
- **100% Stream Reliability**: Filtered AAC-LC (`mp4a.40.2`) streams prevent iOS CoreAudio timescale bugs and duration doubling.
- **Download Quality Transparency**: Download songs in 320kbps AAC or YouTube AAC with full metadata and detailed audio info modals.

### ☁️ YouTube Music Cloud Synchronization
- **Native Cookie Sign-in**: Secure WebView sign-in using official Innertube endpoints.
- **Bi-directional Like Sync**: Liking a track immediately syncs with your official YouTube Music account.
- **Playlists & Mixes**: Automatic background loading of your YouTube Music playlists and personalized carousels (*My Supermix*, *Discover Mix*).
- **Play History Reporting**: Background play history logging directly into YouTube Music.

### 🎤 Real-Time Karaoke Synced Lyrics
- **Live Synced LRC Lyrics**: Timestamp-synced glowing karaoke lines powered by LrcLib.
- **Interactive Seeking**: Tap any line in the lyrics view to instantly jump the audio playback to that exact second.
- **Zero-CPU Idle Architecture**: Lyrics stream listeners are completely suspended when the artwork is visible, conserving 100% CPU.

### 🎨 Apple Music Cupertino Design
- **True OLED Black**: Consistent `#000000` dark theme across every tab, dialog, and player sheet.
- **Minimalist Full-Screen Player**: Apple Music-inspired typography, large circular play controls, fluid swipe-to-dismiss gestures, and clean frosted glass tab bars.
- **Single-Source Crystal-Clear Artwork Engine**: Dynamically upscales album art to pristine 800px / 500px / maxres resolution without duplicate network fetches or RAM bloat.

### ⚡ Built for iOS & LiveContainer
- **Zero Memory Leaks**: Stream subscriptions, controllers, and socket pools are strictly managed and disposed.
- **$O(1)$ Hash Set Operations**: Instant offline checks and liked-song lookups eliminate UI frame drops on 1,000+ song playlists.
- **Automated Cache Pruning**: Strict 2-day cache retention keeps LiveContainer app storage ultra-lean and snappy.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter 3.x (Dart 3.x)
- **Audio Pipeline**: `just_audio` + `audio_service` (iOS AVPlayer integration)
- **State & Storage**: ValueNotifiers, Hive NoSQL Storage (pruned cache & user library)
- **Networking**: `youtube_explode_dart`, `http`, native Innertube REST API
- **Design System**: iOS Cupertino HIG + Custom Apple Music Theme

---

## 📦 Installation & Sideloading

Musified is designed to run natively on iOS devices through sideloading tools.

### 1. Automated GitHub Actions IPA
Every push to `main` automatically compiles and packages a signed IPA via GitHub Actions.
1. Go to the [Actions tab](https://github.com/tinyredphoenix/Musified/actions).
2. Download the latest `Musified.ipa` artifact.

### 2. Install on Device
- **LiveContainer**: Import the `.ipa` directly into LiveContainer without consuming an App ID.
- **TrollStore** *(iOS 14.0 - 17.0)*: Open `.ipa` with TrollStore for permanent signing with JIT.
- **AltStore / Sideloadly**: Sideload standard IPA with your Apple ID.

---

## 📄 License & Disclaimer

```
Musified is free software licensed under GNU General Public License v3.0.
All trademarks, logos, audio streams, and artwork belong to their respective copyright holders.
```
