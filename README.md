# SmartShed Greenhouse Control Terminal

English | [简体中文](README_zh.md)


A smart-greenhouse IoT terminal developed with **HarmonyOS NEXT**, using **MQTT** to monitor environmental conditions and control actuators remotely.

## Overview

SmartShed runs on HarmonyOS tablets and phones. It offers **manual** and **automatic** control modes and exchanges MQTT messages with two IoT boards (RGB and SOI) to connect environmental sensing with actuator control.

- **RGB board**: measures light intensity, temperature and humidity, and controls a full-spectrum plant-growth light
- **SOI board**: measures soil moisture and controls a fan for cooling/dehumidification and a miniature submersible irrigation pump

## Repository Structure

```
SmartShed-HarmonyOS/
├── AppScope/                          # App-level resource configuration
│   ├── app.json5                      # App configuration (bundleName, version, etc.)
│   └── resources/                     # App resources (icons, strings, etc.)
│
├── entry/                             # Main Entry module
│   ├── src/
│   │   ├── main/
│   │   │   ├── ets/                   # ArkTS source
│   │   │   │   ├── entryability/
│   │   │   │   │   └── EntryAbility.ts        # Ability lifecycle entry point
│   │   │   │   ├── pages/
│   │   │   │   │   ├── Index.ets              # Main page: navigation, MQTT initialization, and data flow
│   │   │   │   │   └── console.ets            # Debug log panel (sidebar/full screen)
│   │   │   │   ├── service/
│   │   │   │   │   ├── MqttReceiverClient.ts  # MQTT client with direct TCP Socket connection
│   │   │   │   │   └── vibration.ets          # Haptic feedback wrapper
│   │   │   │   ├── view/
│   │   │   │   │   ├── ManualPage.ets         # Manual-mode tab
│   │   │   │   │   └── AutoPage.ets           # Smart-mode tab
│   │   │   │   └── viewmodel/
│   │   │   │       ├── SmartShedBean.ts        # Data models (SensorData, ZoneData)
│   │   │   │       └── ConsoleBean.ts          # Log type definitions
│   │   │   ├── module.json5            # Module configuration (permissions, Ability declarations)
│   │   │   └── resources/              # Module resources (colors, strings, images, routes, etc.)
│   │   ├── ohosTest/                   # Automated tests
│   │   ├── test/                       # Local unit tests
│   │   └── mock/                       # Mock configuration
│   │
│   ├── build-profile.json5             # Module build configuration
│   ├── hvigorfile.ts                   # Module Hvigor build script
│   └── oh-package.json5                # Module package dependencies
│
├── build-profile.json5                 # Project build configuration (signing, SDK version, etc.)
├── hvigorfile.ts                       # Project Hvigor build script
├── oh-package.json5                    # Project package management
├── hvigor/                             # Hvigor build tool configuration
├── local.properties                    # Local environment configuration
├── code-linter.json5                   # Lint rules
└── .gitignore
```

## Core Features

### 🔧 Manual Mode (ManualPage)
Sliders control three actuators in real time:
- **Growth light**: brightness from 0–100%
- **Fan**: speed levels 0–3
- **Submersible pump**: flow levels 0–3

### 🤖 Automatic Mode (AutoPage)
The system acts on sensor readings using configurable thresholds:
- Excess temperature/humidity → automatically adjust fan speed
- Insufficient light → automatically adjust growth-light brightness
- Insufficient soil moisture → automatically start irrigation

Configurable thresholds include maximum temperature, maximum humidity, minimum light and lower/upper soil-moisture limits.

### 📡 MQTT Communication
- Native MQTT 3.1.1 implementation over TCP sockets, without a third-party MQTT library
- Connects to the public broker `broker.emqx.io:1883`
- Heartbeats, automatic reconnection and board-offline detection with a 5-second timeout
- All communication logs are streamed to the **Console panel**

### 📋 Live Logs (Console Panel)
- Separate SENT, RECV, INFO and ERR categories
- Automatic scrolling and a cache of up to 100 entries
- Split-pane presentation on wide screens

### Board Communication Protocol

| Topic | Direction | Description |
|-------|------|------|
| `Rayawa/rgb/light_intensity` | RGB → App | Light intensity (Lx) |
| `Rayawa/rgb/temp_and_hum` | RGB → App | Temperature and humidity (℃ / %) |
| `Rayawa/soi/soil_moisture` | SOI → App | Soil moisture (%) |
| `Rayawa/rgb/led` | App → RGB | Growth-light brightness (0–100) |
| `Rayawa/soi/fan` | App → SOI | Fan level (0–3) |
| `Rayawa/soi/water_pump` | App → SOI | Pump level (0–3) |

## Technology

- **Language**: ArkTS (HarmonyOS NEXT)
- **UI framework**: ArkUI + HDS (Harmony Design System)
- **Communication**: native MQTT 3.1.1 over TCP sockets
- **Build tool**: Hvigor
- **Target SDK**: HarmonyOS 6.1.0 API 23
- **Device types**: Phone / Tablet

## Development Environment

- DevEco Studio (the latest version is recommended)
- HarmonyOS SDK 6.1.0 (API 23)
- An OpenHarmony or HarmonyOS NEXT physical device/emulator

## Quick Start

1. Open the project root in DevEco Studio.
2. Wait for Gradle synchronization to complete.
3. Connect a HarmonyOS NEXT physical device or emulator.
4. Click Run to build and install.

> No additional MQTT broker configuration is required. The app connects to the public EMQX server at `broker.emqx.io:1883` by default.

## License

This project is a personal learning and practice project.
