# ShadowBroker iOS

<p align="center">
  <img src="https://img.shields.io/badge/iOS-18%2B-000.svg?style=flat&logo=apple&labelColor=111" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138.svg?style=flat&logo=swift&labelColor=111" />
  <img src="https://img.shields.io/badge/MapKit-native-44D62C.svg?style=flat&logo=mapbox&labelColor=111" />
  <img src="https://img.shields.io/badge/license-MIT-7543f9.svg?style=flat&labelColor=111" />
</p>

**Real-time OSINT aircraft intelligence client for iPhone & iPad.** Tracks VIP movements, military aviation, and every ADS-B-equipped aircraft in the sky — powered by your self-hosted [ShadowBroker](https://github.com/BigBodyCobain/Shadowbroker) backend.

---

## Overview

ShadowBroker iOS brings the full geospatial intelligence stack to your pocket. Point it at a ShadowBroker instance and the map populates with color-coded aircraft — from Air Force One and fighter jets to billionaire Gulfstreams and ISR platforms.

All processing happens on-device. Zero telemetry, zero tracking.

---

## Features

### 🗺️ Live Map

- Native MapKit rendering with smooth 60fps animations
- 12-second auto-refresh with live connection state indicator
- Realistic elevation on hybrid map layer
- Aircraft pins segregated into **13 priority-ranked categories**

### 🧬 Category Color System

| Priority | Category | Pin Color | Icon |
|----------|----------|-----------|------|
| P0 | 🥇 Air Force One | `#FFD700` Gold | `star.fill` |
| P1 | 👑 Presidential | `#FF6B6B` Red | `crown.fill` |
| P2 | 👁️ ISR / Recon | `#A855F7` Purple | `airplane` |
| P3 | ⚡ Fighter | `#EF4444` Bright Red | `airplane` |
| P4 | ⛽ Tanker | `#FF8C42` Orange | `airplane` |
| P5 | 💣 Bomber | `#F97316` Dark Orange | `airplane` |
| P6 | 🛸 UAV / Drone | `#06B6D4` Cyan | `antenna.radiowaves.left.and.right` |
| P7 | 📦 Cargo | `#84CC16` Lime | `airplane` |
| P8 | 🔰 General Military | `#4ECDC4` Teal | `airplane` |
| P9 | 💰 Billionaire | `#10B981` Emerald | `dollarsign.circle.fill` |
| P10 | 🏛️ Government | `#3B82F6` Blue | `building.columns.fill` |
| P11 | 🛩️ Commercial | `#6B7280` Gray | `airplane.circle` |
| P12 | ❓ Other | `#9CA3AF` Light Gray | `questionmark.circle` |

### 🔎 Search & Filter

- Full-text search across callsign, registration, and tracked name
- Filter chips for high-priority categories (Tracked, AF1, Fighters, Tankers, ISR, UAV, Billionaire, Government)
- Dropdown filter sheet with every category toggleable
- "Show Only Tracked" mode strips civilian clutter
- Debounced input — no frame drops while typing

### 📍 Aircraft Detail

- Tap any pin for instant slide-up card
- Altitude, speed, heading, vertical rate, squawk
- Origin/destination, operator, aircraft type
- Registration, flag, military force designation
- Wiki link for military airframes

### 🔌 Backend Integration

- Connects to ShadowBroker's `/api/live-data/fast` endpoint
- Falls back to OpenSky public API when backend is unreachable
- Settings sheet to configure backend URL on the fly
- Enriches data with `tracked_names.json` highlight logic
- Military classification mirrors `services/fetchers/military.py` from the backend

---

## Quick Start

### Prerequisites

- Xcode 16+
- iOS 18+ device or simulator
- (Recommended) A running [ShadowBroker](https://github.com/BigBodyCobain/Shadowbroker) instance

### Run

```bash
git clone https://github.com/ShadowBrokerIOS/ShadowBrokerIOS.git
cd ShadowBrokerIOS
open ShadowBrokerIOS.xcodeproj
```

Select your target → **Run** (⌘R). The map loads with OpenSky data immediately.

To connect your own backend:
1. Tap the **gear** icon
2. Enter your ShadowBroker instance URL:
   ```
   http://192.168.1.XX:8000
   ```
3. The app switches to your backend's enriched data stream

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│  ShadowBrokerIOSApp                              │
│  ┌────────────────────────────────────────────┐  │
│  │  ContentView (NavigationStack + Sheets)     │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │  AircraftMapView                     │  │  │
│  │  │  (MKMapView + delegate + overlays)   │  │  │
│  │  └──────────────────────────────────────┘  │  │
│  │  │  Header + FilterChips + Search             │  │
│  │  │  Settings Sheet │ Filter Sheet              │  │
│  └────────────────────────────────────────────┘  │
│                                                     │
│  AircraftViewModel (ObservableObject)               │
│  ┌────────────────────────────────────────────┐  │
│  │  State: aircraft[] │ filters │ searchText   │  │
│  │  Timer: 12s refresh loop                    │  │
│  │  Methods: refresh() │ toggleFilter() │ ...  │  │
│  └────────────────────────────────────────────┘  │
│                                                     │
│  ShadowBrokerAPIService                              │
│  ┌────────────────────────────────────────────┐  │
│  │  fetchFromBackend()  → /api/live-data/fast  │  │
│  │  fetchFromOpenSky()  → opensky-network.org  │  │
│  └────────────────────────────────────────────┘  │
│                                                     │
│  Models: Aircraft │ TrackedEntity │ ConnectionState  │
└──────────────────────────────────────────────────┘
```

- **SwiftUI** — declarative UI with navigation and sheets
- **MapKit** — native map rendering, no third-party SDKs
- **Async/await** — structured concurrency for networking
- **MVVM** — `@StateObject` ViewModel with reactive filtering
- **Zero dependencies** — pure Apple SDKs, zero CocoaPods/SPM

---

## Roadmap

- [ ] **Aircraft trails** — `/api/trail/flight/{icao24}` real-time flight paths
- [ ] **Widget + Live Activity** — AF1 departure alerts on your Lock Screen
- [ ] **SAR overlay** — search-and-rescue ground operations toggle
- [ ] **InfoNet integration** — messaging via the ShadowBroker mesh
- [ ] **Deep links** — export to Flightradar24 / ADS-B Exchange
- [ ] **TestFlight beta** — App Store readiness pass
- [ ] **App Icon + Store screenshots** — final polish

---

## Credits

Built to run alongside the original [ShadowBroker](https://github.com/BigBodyCobain/Shadowbroker) stack. Deploy the Docker compose on a VPS or home server, point the iOS app at it.

---

<p align="center">
  <sub><em>Stay frosty.</em></sub>
</p>
