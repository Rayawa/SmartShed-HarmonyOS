// src/main/ets/view/AutoPage.ets
import { ZoneData } from '../viewmodel/SmartShedBean';
import { MqttReceiverClient, TOPIC_FAN, TOPIC_LED, TOPIC_WATER_PUMP } from '../service/MqttReceiverClient';
import { curves, display, promptAction, router } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';
import { LogType } from '../viewmodel/ConsoleBean';
import { GlobalLogBus } from '../pages/Index';
import { HdsButton } from '../viewmodel/HdsButton';
import { vibration } from '../service/vibration';

@Component
export struct AutoPage {
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @StorageLink("isWideScreen") isWideScreen: boolean = true;

  // ==================== 1. 变量名与全局状态一致化 ====================
  @StorageLink('isRgbBoardConnected') isRgbBoardConnected: boolean = false;
  @StorageLink('isSoiBoardConnected') isSoiBoardConnected: boolean = false;
  @StorageLink('autoEnabled') autoEnabled: boolean = false;

  @StorageLink('temp') temp: number = 28;
  @StorageLink('hum') hum: number = 50;
  @StorageLink('intensity') intensity: number = 134;
  @StorageLink('moisture') moisture: number = 50;
  @StorageLink('fanValue') fanValue: number = 0;
  @StorageLink('waterPumpValue') waterPumpValue: number = 0;
  @StorageLink('ledValue') ledValue: number = 0;
  @StorageLink('zone1') zone1: ZoneData = new ZoneData();
  public mqttClient!: MqttReceiverClient;

  @StorageLink("transparentColor") transparentColor: ResourceColor = $r("sys.color.ohos_toggle_bg_transparent")
  @StorageLink("transparentDiffColor") transparentDiffColor: ResourceColor = $r("sys.color.ohos_id_color_mask_thin_transparent")
  @StorageLink("transparentBorderColor") transparentBorderColor: ResourceColor = $r("sys.color.toast_border_color")

  @State controller: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  @State animStep1: number = 0;
  @State animStep2: number = 0;
  @State animStep3: number = 0;
  private timer1: number = -1;
  private timer2: number = -1;
  private timer3: number = -1;

  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  onVisibleChange(){
    this.handleAutoPageVisibility(this.isVisible);
  }

  private startEnterAnimation(): void {
    this.stopEnterAnimation();
    const duration = 500;
    const interval = duration * 0.25;
    const curve = curves.springMotion(0.35, 0.75);
    this.timer1 = setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep1 = 1 }) }, 100);
    this.timer2 = setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep2 = 1 }) }, interval + 100);
    this.timer3 = setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep3 = 1 }) }, interval * 2 + 100);
  }

  private stopEnterAnimation(): void {
    if (this.timer1 !== -1) { clearTimeout(this.timer1); this.timer1 = -1; }
    if (this.timer2 !== -1) { clearTimeout(this.timer2); this.timer2 = -1; }
    if (this.timer3 !== -1) { clearTimeout(this.timer3); this.timer3 = -1; }
    this.animStep1 = 0;
    this.animStep2 = 0;
    this.animStep3 = 0;
  }

  private printLog(type: LogType, message: string): void {
    GlobalLogBus.emit(type, `Auto: ${message}`);
    const now = new Date();
    const timeStr = `${now.toLocaleTimeString()}.${String(now.getMilliseconds()).padStart(3, '0')}`;
    const logHeader = `[${timeStr}] [MQTT_${type}]`;
    if (type === LogType.ERROR) {
      console.error(`${logHeader} ${message}`);
    } else {
      console.info(`${logHeader} ${message}`);
    }
  }

  aboutToAppear(): void {
    this.isWideScreen = px2vp(display.getDefaultDisplaySync().width) > 600;
    this.autoEnabled = true;
    this.printLog(LogType.INFO, "已切换到智能模式");
    if (this.isVisible) {
      this.handleAutoPageVisibility(true);
    }
  }

  private handleAutoPageVisibility(visible: boolean): void {
    if (visible) {
      this.autoEnabled = true;
      this.startAutoLogic();
      this.startEnterAnimation();
    } else {
      this.stopEnterAnimation();
    }
  }

  private safePublish(topic: string, value: string) {
    try {
      if (this.mqttClient) {
        this.mqttClient.publish(topic, value);
        this.printLog(LogType.INFO, `自动控制指令下发 -> 主题: ${topic}, 下发值: ${value}`);
      } else {
        throw new Error("MQTT未初始化");
      }
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : JSON.stringify(error);
      this.printLog(LogType.ERROR, `自动控制外发失败: ${errMsg}`);
      promptAction.showToast({ message: '指令自动下发失败，请检查网络', duration: 2000 });
      // 剔除了直接在这里强制改变硬件在线状态的代码
    }
  }

  private startAutoLogic(): void {
    this.stopAutoLogic();
    this.zone1.isExit = false;
    this.printLog(LogType.INFO, "智能模式启动");

    const handler = setInterval(() => {
      if (this.zone1.isExit || !this.autoEnabled) {
        clearInterval(handler);
        return;
      }
      try {
        const tempMax = parseInt(this.zone1.autoTempMax) || 30;
        const humMax = parseInt(this.zone1.autoHumMax) || 80;
        const moistureMin = parseInt(this.zone1.autoMoistureMin) || 40;
        const moistureMax = parseInt(this.zone1.autoMoistureMax) || 75;
        const intensityMin = parseInt(this.zone1.autoIntensityMin) || 200;

        // --- 策略1：风扇控制 (仅在 SOI 板连接时下发指令) ---
        if (this.isSoiBoardConnected) {
          let targetFan = 0;
          if (this.temp > tempMax + 10 || this.hum > humMax + 20 || this.moisture > moistureMax + 20) {
            targetFan = 3;
          } else if (this.temp > tempMax + 5 || this.hum > humMax + 10 || this.moisture > moistureMax + 10) {
            targetFan = 2;
          } else if (this.temp > tempMax || this.hum > humMax || this.moisture > moistureMax) {
            targetFan = 1;
          }

          if (this.fanValue !== targetFan) {
            this.printLog(LogType.INFO, `[智能策略] 触发风扇策略调节: ${this.fanValue} -> ${targetFan} 档`);
            this.fanValue = targetFan;
            this.safePublish(TOPIC_FAN, targetFan.toString());
          }
        }

        // --- 策略2：水泵控制 (仅在 SOI 板连接时下发指令) ---
        if (this.isSoiBoardConnected) {
          let targetPump = 0;
          if (this.moisture < moistureMin - 20) {
            targetPump = 3;
          } else if (this.moisture < moistureMin - 10) {
            targetPump = 2;
          } else if (this.moisture < moistureMin) {
            targetPump = 1;
          }

          if (this.waterPumpValue !== targetPump) {
            this.printLog(LogType.INFO, `[智能策略] 触发水泵策略调节: ${this.waterPumpValue} -> ${targetPump} 档`);
            this.waterPumpValue = targetPump;
            this.safePublish(TOPIC_WATER_PUMP, targetPump.toString());
          }
        }

        // --- 策略3：补光灯控制 (仅在 RGB 板连接时下发指令) ---
        if (this.isRgbBoardConnected) {
          let targetLed = 0;
          if (this.intensity < intensityMin) {
            let level = Math.floor((2000 - this.intensity) / 20); // 修正：根据环境光照强度进行补光计算
            targetLed = level > 100 ? 100 : (level < 0 ? 0 : level);
          }

          if (this.ledValue !== targetLed) {
            this.printLog(LogType.INFO, `[智能策略] 触发植物灯策略调节: ${this.ledValue}% -> ${targetLed}%`);
            this.ledValue = targetLed;
            this.safePublish(TOPIC_LED, targetLed.toString());
          }
        }

      } catch (err) {
        const errMsg = err instanceof Error ? err.message : JSON.stringify(err);
        this.printLog(LogType.ERROR, `智能策略核心算法发生异常: ${errMsg}`);
      }
    }, 2000);

    this.zone1.autoManagerThread = handler;
  }

  private stopAutoLogic(): void {
    this.zone1.isExit = true;
    if (this.zone1.autoManagerThread !== null) {
      this.printLog(LogType.INFO, "已停止并回收智能自动监测线程锁");
      clearInterval(this.zone1.autoManagerThread);
      this.zone1.autoManagerThread = null;
    }
  }

  build() {
    Stack(){
      Image($r("app.media.back")).width("100%").height("100%")
      Column().width("100%").height("100%")
        .opacity(this.animStep2 ? 1 : 0)
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.DUAL_EDGE_FLOW_LIGHT,
            animation: { duration: 4000, iterations: -1, autoPlay: true },
            controller: this.controller,
            params: {
              firstEdgeFlowLight: { startPos: 0, endPos: 1.0, color: '#1AD0F1' },
              secondEdgeFlowLight: { startPos: 0.5, endPos: 1.5, color: '#FFA4E5' }
            }
          })
          .buildEffect())

      Column({ space: 16 }) {
        Row(){
          Text(" 智慧大棚控制终端").fontColor(Color.White).fontWeight(FontWeight.Bold).fontSize(30)
          HdsButton({
            barWidth: 45,
            barHeight: 57,
            enableClickScale: true,
            enablePointLight: true,
            enableDrag: true,
            iconResource: $r("sys.symbol.code_square"),
            onButtonClick: () => {
              if(this.vibrationON) vibration.dotVibration()
              router.pushUrl({ url: "pages/console"})}
          })
        }.zIndex(99)
        .justifyContent(FlexAlign.SpaceBetween).width("100%")

        Stack() {
          Row() {
            HdsButton({
              barWidth: 168,
              barHeight: 76,
              enableClickScale: this.isRgbBoardConnected,
              enablePointLight: this.isRgbBoardConnected,
              enableDrag: this.isRgbBoardConnected
            }) {
              Row() {
                Circle({ width: 8, height: 8 })
                  .fill(this.isRgbBoardConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
                  .margin({ right: 10 })
                Text(this.isRgbBoardConnected ? 'Rayawa/rgb 已连接' : 'Rayawa/rgb 未连接')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isRgbBoardConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
              }
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }
            Blank().width(10)
            HdsButton({
              barWidth: 168,
              barHeight: 76,
              enableClickScale: this.isSoiBoardConnected,
              enablePointLight: this.isSoiBoardConnected,
              enableDrag: this.isSoiBoardConnected
            }) {
              Row() {
                Circle({ width: 8, height: 8 })
                  .fill(this.isSoiBoardConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
                  .margin({ right: 10 })
                Text(
                  this.isSoiBoardConnected ? 'Rayawa/soi 已连接' : 'Rayawa/soi 未连接')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isSoiBoardConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
              }
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }

          }
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .width('100%')
        .opacity(this.animStep1 ? 1 : 0)
        .translate({ y: this.animStep1 ? 0 : 20 })

        // ==================== 3. 任何一块板在线，均渲染传感器网格与设置区 ====================
        if(this.isRgbBoardConnected || this.isSoiBoardConnected){
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Stack() {
                HdsButton({ barWidth: 164, barHeight: 80 }) {
                  Column() {
                    Row() {
                      Circle({ width: 6, height: 6 }).fill('#FF7D00').margin({ right: 6 })
                      Text('空气温度').fontSize(12).fontColor(Color.White)
                    }.width('100%')
                    Blank()
                    Text(this.isRgbBoardConnected ? `${this.temp} ℃` : "N/A").fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                  }
                  .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                }
              }.layoutWeight(1)

              Stack() {
                HdsButton({ barWidth: 164, barHeight: 80 }) {
                  Column() {
                    Row() {
                      Circle({ width: 6, height: 6 }).fill('#007DFF').margin({ right: 6 })
                      Text('空气湿度').fontSize(12).fontColor(Color.White)
                    }.width('100%')
                    Blank()
                    Text(this.isRgbBoardConnected ? `${this.hum} %` : "N/A").fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                  }
                  .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                }
              }.layoutWeight(1)
            }
            .width('100%')

            Row({ space: 12 }) {
              Stack() {
                HdsButton({ barWidth: 164, barHeight: 80 }) {
                  Column() {
                    Row() {
                      Circle({ width: 6, height: 6 }).fill('#FFBF00').margin({ right: 6 })
                      Text('光照强度').fontSize(12).fontColor(Color.White)
                    }.width('100%')
                    Blank()
                    Text(this.isRgbBoardConnected ? `${this.intensity} Lx` : "N/A").fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                  }
                  .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                }
              }.layoutWeight(1)

              Stack() {
                HdsButton({ barWidth: 164, barHeight: 80 }) {
                  Column() {
                    Row() {
                      Circle({ width: 6, height: 6 }).fill('#34C759').margin({ right: 6 })
                      Text('土壤湿度').fontSize(12).fontColor(Color.White)
                    }.width('100%')
                    Blank()
                    Text(this.isSoiBoardConnected ? `${this.moisture} %` : "N/A").fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                  }
                  .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                }
              }.layoutWeight(1)
            }
            .width('100%')
          }
          .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
          .opacity(this.animStep2 ? 1 : 0)
          .translate({ y: this.animStep2 ? 0 : 20 })

          Column({ space: 5 }) {
            Text('智能模式设置')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .fontColor(Color.White)

            Column({ space: 10 }) {
              Row({ space: 12 }) {
                this.hdsInputField('温度上限', () => this.zone1.autoTempMax, (v) => { this.zone1.autoTempMax = v })
                this.hdsInputField('空湿上限', () => this.zone1.autoHumMax, (v) => { this.zone1.autoHumMax = v })
              }.width('100%')

              Row({ space: 12 }) {
                this.hdsInputField('土湿下限', () => this.zone1.autoMoistureMin, (v) => { this.zone1.autoMoistureMin = v })
                this.hdsInputField('土湿上限', () => this.zone1.autoMoistureMax, (v) => { this.zone1.autoMoistureMax = v })
              }.width('100%')

              Row({ space: 12 }) {
                this.hdsInputField('光照下限', () => this.zone1.autoIntensityMin, (v) => { this.zone1.autoIntensityMin = v })
                this.hdsInputField('补光上限', () => this.zone1.autoIntensityMax, (v) => { this.zone1.autoIntensityMax = v })
              }.width('100%')
            }
            .padding(10)
            .width('100%')

          }
          .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
          .opacity(this.animStep3 ? 1 : 0)
          .translate({ y: this.animStep3 ? 0 : 20 })

        } else {
          Column({ space: 12 }) {
            LoadingProgress().width(80).height(80).color(Color.White)
              .opacity(this.animStep1 ? 1 : 0)
              .translate({ y: this.animStep1 ? 0 : 20 })
            Text('等待连接开发板...').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ top: 20 })
              .opacity(this.animStep2 ? 1 : 0)
              .translate({ y: this.animStep2 ? 0 : 20 })
          }
          .margin({ top: 50 })
          .justifyContent(FlexAlign.Center)
        }
      }
      .width("100%")
      .height("100%")
      .padding({ left: 16, right: 16, top: 75, bottom: 32 })
    }
    .onVisibleAreaChange([0.0], (isVisible: boolean, currentRatio: number) => {
      this.handleAutoPageVisibility(isVisible && currentRatio > 0);
    })
    .width("100%")
    .height("100%")
    .ignoreLayoutSafeArea()
  }

  @Builder
  hdsInputField(label: string, getter: () => string, setter: (val: string) => void) {
    Stack() {
      HdsButton({
        barWidth: 164,
        barHeight: 60,
        enablePointLight: true,
        enableClickScale: true,
        enableDrag: true
      }) {
        Row() {
          Text(label)
            .fontSize(13)
            .width(60)
            .fontColor(Color.White)
            .margin({ right: 2 })
          TextInput({ text: getter() })
            .fontSize(11)
            .height(28)
            .layoutWeight(1)
            .padding({ left: 6, right: 6 })
            .fontColor("#DDDDDD")
            .backgroundColor(this.autoEnabled ? this.transparentDiffColor : $r("app.color.diff_background"))
            .borderRadius(16)
            .type(InputType.Number)
            .onChange((val: string) => {
              setter(val);
              this.printLog(LogType.INFO, `用户修改自动阈值 [${label}] 为: ${val}`);
            })
        }
        .padding({ left: 12, right: 12 })
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .layoutWeight(1)
  }
}