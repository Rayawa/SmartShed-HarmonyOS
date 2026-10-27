# SmartShed-HarmonyOS

[English](README.md) | 简体中文

通过 MQTT 监测传感器并控制执行器的 HarmonyOS 大棚管理终端。

归档项目，保留用于参考。

## 项目概述

应用连接环境/RGB 板和土壤/执行器板。手动模式调节补光、风扇和水泵，自动模式按可配置环境阈值进行控制，控制台显示通信事件。

## 技术栈与依赖

ArkTS、ArkUI、HarmonyOS 6.1.0（API 23）、OHPM、Hvigor。应用通过 TCP Socket 实现 MQTT 3.1.1。测试使用 Hypium 1.0.25 和 Hamock 1.0.0；硬件联动需要兼容固件及一致的代理和主题。

## 文件结构

- `entry/src/main/ets/` — ArkTS 应用代码
- `entry/src/main/resources/` — 模块资源与路由
- `AppScope/` — 应用配置与资源
- `build-profile.example.json5` — 可移植构建配置模板
- `oh-package.json5` — 包与测试依赖
- `hvigor/` — 构建配置
- `entry/src/main/ets/service/` — MQTT 客户端与设备服务
- `entry/src/main/ets/view/` — 手动与自动控制页面
- `entry/src/main/ets/viewmodel/` — 传感器及控制台模型

## 快速上手

1. 安装 DevEco Studio 及与 `build-profile.example.json5` 匹配的 HarmonyOS SDK。
2. 将 `build-profile.example.json5` 复制为 `build-profile.json5`，在 IDE 中配置本地 SDK 与签名。
3. 打开仓库根目录，通过 IDE 的 OHPM 恢复依赖并选择 `entry` 模块。
4. 选择兼容设备或模拟器后运行；签名材料与机器路径仅在本地配置。

测试前检查 MQTT 服务中的代理配置，并与板端固件主题保持一致。源码默认使用 `broker.emqx.io:1883`。先在控制台确认传感器消息，再测试执行器控制。
