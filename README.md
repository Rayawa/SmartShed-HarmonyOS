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
├── AppScope/                          # 应用级资源配置
│   ├── app.json5                      # 应用配置（bundleName、版本等）
│   └── resources/                     # 应用级资源（图标、字符串等）
│
├── entry/                             # 主 Entry 模块
│   ├── src/
│   │   ├── main/
│   │   │   ├── ets/                   # ArkTS 源代码
│   │   │   │   ├── entryability/
│   │   │   │   │   └── EntryAbility.ts        # Ability 生命周期入口
│   │   │   │   ├── pages/
│   │   │   │   │   ├── Index.ets              # 主页面：导航框架 + MQTT 初始化 + 数据流
│   │   │   │   │   └── console.ets            # 调试日志面板（侧边/全屏）
│   │   │   │   ├── service/
│   │   │   │   │   ├── MqttReceiverClient.ts  # MQTT 客户端（TCP Socket 直连）
│   │   │   │   │   └── vibration.ets          # 触觉反馈封装
│   │   │   │   ├── view/
│   │   │   │   │   ├── ManualPage.ets         # 手动模式 Tab 页面
│   │   │   │   │   └── AutoPage.ets           # 智能模式 Tab 页面
│   │   │   │   └── viewmodel/
│   │   │   │       ├── SmartShedBean.ts        # 数据模型（SensorData、ZoneData）
│   │   │   │       └── ConsoleBean.ts          # 日志类型定义
│   │   │   ├── module.json5            # 模块配置（权限、Ability 声明）
│   │   │   └── resources/              # 模块级资源（颜色、字符串、图片、路由等）
│   │   ├── ohosTest/                   # 自动化测试
│   │   ├── test/                       # 本地单元测试
│   │   └── mock/                       # Mock 配置
│   │
│   ├── build-profile.json5             # 模块构建配置
│   ├── hvigorfile.ts                   # 模块 Hvigor 构建脚本
│   └── oh-package.json5                # 模块包依赖声明
│
├── build-profile.json5                 # 项目级构建配置（签名、SDK 版本等）
├── hvigorfile.ts                       # 项目级 Hvigor 构建脚本
├── oh-package.json5                    # 项目级包管理
├── hvigor/                             # Hvigor 构建工具配置
├── local.properties                    # 本地环境配置
├── code-linter.json5                   # 代码检查规则
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
