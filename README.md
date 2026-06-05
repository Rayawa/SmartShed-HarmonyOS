# SmartShed 智慧大棚控制终端

基于 **HarmonyOS NEXT** 开发的智慧农业大棚物联网控制终端，通过 **MQTT** 协议远程监控大棚环境并控制执行设备。

## 项目概述

SmartShed 是一款运行在鸿蒙平板/手机上的大棚管理 App，提供 **手动控制** 和 **智能自动控制** 两种模式，通过 MQTT 与两块物联网开发板（RGB 板 + SOI 板）进行双向通信，实现环境感知与设备控制的闭环。

- **RGB 开发板**：采集光照强度、温湿度数据，并控制全光谱植物补光灯
- **SOI 开发板**：采集土壤湿度数据，并控制风扇（降温排湿）和微型潜水泵（灌溉）

## 项目结构

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

## 核心功能

### 🔧 手动模式（ManualPage）
通过滑块实时控制三个执行器：
- **补光灯**：0～100% 亮度
- **风扇**：0～3 档转速
- **潜水泵**：0～3 档流量

### 🤖 智能模式（AutoPage）
系统根据传感器数据自动决策，支持自定义阈值：
- 温度/湿度超过阈值 → 自动调节风扇档位
- 光照不足 → 自动调节补光灯亮度
- 土壤湿度过低 → 自动开启水泵灌溉

可配置参数：温度上限、湿度上限、光照下限、土湿上下限。

### 📡 MQTT 通信
- 基于 TCP Socket 原生实现 MQTT 3.1.1 协议（无需第三方 MQTT 库）
- 连接公共代理 `broker.emqx.io:1883`
- 心跳保活 + 自动重连 + 板端离线检测（5 秒超时）
- 所有通信日志实时推送至 **Console 面板**

### 📋 实时日志（Console Panel）
- 分类型显示：发送（SENT）、接收（RECV）、信息（INFO）、错误（ERR）
- 自动滚动 + 最多 100 条缓存
- 支持宽屏分栏显示

### 板端通信协议

| Topic | 方向 | 说明 |
|-------|------|------|
| `Rayawa/rgb/light_intensity` | RGB → App | 光照强度（Lx） |
| `Rayawa/rgb/temp_and_hum` | RGB → App | 温湿度（℃ / %） |
| `Rayawa/soi/soil_moisture` | SOI → App | 土壤湿度（%） |
| `Rayawa/rgb/led` | App → RGB | 补光灯亮度（0～100） |
| `Rayawa/soi/fan` | App → SOI | 风扇档位（0～3） |
| `Rayawa/soi/water_pump` | App → SOI | 水泵档位（0～3） |

## 技术栈

- **语言**：ArkTS（HarmonyOS NEXT）
- **UI 框架**：ArkUI + HDS（Harmony Design System）
- **通信**：TCP Socket 原生实现 MQTT 3.1.1
- **构建工具**：Hvigor
- **目标 SDK**：HarmonyOS 6.1.0 API 23
- **设备类型**：Phone / Tablet

## 开发环境

- DevEco Studio（推荐最新版本）
- HarmonyOS SDK 6.1.0 (API 23)
- OpenHarmony 或 HarmonyOS NEXT 真机/模拟器

## 快速开始

1. 使用 DevEco Studio 打开项目根目录
2. 等待 Gradle 同步完成
3. 连接 HarmonyOS NEXT 设备（真机或模拟器）
4. 点击 Run 构建并安装

> 无需额外配置 MQTT Broker，App 默认连接公共 EMQX 服务器 `broker.emqx.io:1883`。

## 许可证

本项目为个人学习实践项目。
