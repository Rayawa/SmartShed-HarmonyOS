# SmartShed-HarmonyOS

English | [简体中文](README_zh.md)

A HarmonyOS greenhouse dashboard for MQTT sensor monitoring and actuator control.

Archived project retained for reference.

## Overview

The application connects to environment/RGB and soil/actuator boards. Manual controls adjust lighting, fan and pump levels; an automatic mode evaluates configurable environmental thresholds. A console displays communication events.

## Technology and Dependencies

ArkTS, ArkUI, HarmonyOS 6.1.0 (API 23), OHPM and Hvigor. MQTT 3.1.1 is implemented over TCP sockets in the application. Tests use Hypium 1.0.25 and Hamock 1.0.0. Hardware operation requires compatible firmware and matching broker/topics.

## Repository Structure

- `entry/src/main/ets/` — ArkTS application code
- `entry/src/main/resources/` — module resources and routes
- `AppScope/` — application metadata and resources
- `build-profile.example.json5` — portable build configuration template
- `oh-package.json5` — package and test dependencies
- `hvigor/` — build configuration
- `entry/src/main/ets/service/` — MQTT client and device services
- `entry/src/main/ets/view/` — manual and automatic control pages
- `entry/src/main/ets/viewmodel/` — sensor and console data models

## Quick Start

1. Install DevEco Studio and a HarmonyOS SDK compatible with `build-profile.example.json5`.
2. Copy `build-profile.example.json5` to `build-profile.json5` and configure the local SDK and signing in DevEco Studio.
3. Open the repository root, restore dependencies with OHPM through the IDE, and select the `entry` module.
4. Select a compatible device or emulator and run the application. Keep signing material and machine-specific paths local.

Review the broker configuration in the MQTT service and match the board firmware topics before testing. The source defaults to `broker.emqx.io:1883`. Use the console to confirm sensor messages before enabling actuator controls.
