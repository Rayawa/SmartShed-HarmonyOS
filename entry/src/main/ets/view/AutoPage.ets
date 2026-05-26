// src/main/ets/view/AutoPage.ets
import { ZoneData } from '../viewmodel/SmartShedBean';
import { MqttReceiverClient, TOPIC_FAN, TOPIC_LED, TOPIC_WATER_PUMP } from '../service/MqttReceiverClient';
import { curves, display, LengthMetrics, promptAction } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';
import { LogType } from '../viewmodel/ConsoleBean';
import { GlobalLogBus } from '../pages/Index';
import { HdsButton } from '../viewmodel/HdsButton'; // 🌟 引入 HdsButton 进行无缝替换


@Component
export struct AutoPage {
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @StorageLink("isWideScreen") isWideScreen: boolean = true;
  @StorageLink('isBoardConnected') isBoardConnected: boolean = false;
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

  @StorageLink("transparentColor")transparentColor: ResourceColor = $r("sys.color.ohos_toggle_bg_transparent")
  @StorageLink("transparentDiffColor")transparentDiffColor: ResourceColor = $r("sys.color.ohos_id_color_mask_thin_transparent")
  @StorageLink("transparentBorderColor")transparentBorderColor: ResourceColor = $r("sys.color.toast_border_color")

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
    this.isWideScreen = px2vp(display.getDefaultDisplaySync().width)>600? true: false;
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
      this.printLog(LogType.ERROR, `自动控制外发失败崩溃: ${errMsg}`);
      promptAction.showToast({ message: '指令自动下发失败，请检查网络', duration: 2000 });
      this.isBoardConnected = false;
    }
  }

  private startAutoLogic(): void {
    this.stopAutoLogic();
    this.zone1.isExit = false;
    this.printLog(LogType.INFO, "智能模式启动");

    const handler = setInterval(() => {
      if (this.zone1.isExit) {
        clearInterval(handler);
        return;
      }
      if (!this.autoEnabled) {
        return;
      }
      try {
        const tempMax = parseInt(this.zone1.autoTempMax) || 30;
        const humMax = parseInt(this.zone1.autoHumMax) || 80;
        const moistureMin = parseInt(this.zone1.autoMoistureMin) || 40;
        const moistureMax = parseInt(this.zone1.autoMoistureMax) || 75;
        const intensityMin = parseInt(this.zone1.autoIntensityMin) || 200;

        let targetFan = 0;
        if (this.temp > tempMax + 10 || this.hum > humMax + 20 || this.moisture > moistureMax + 20) {
          targetFan = 3;
        } else if (this.temp > tempMax + 5 || this.hum > humMax + 10 || this.moisture > moistureMax + 10) {
          targetFan = 2;
        } else if (this.temp > tempMax || this.hum > humMax || this.moisture > moistureMax) {
          targetFan = 1;
        }

        if (this.fanValue !== targetFan) {
          this.printLog(LogType.INFO, `[策略变更] 触发降温排湿，风扇状态跳转: ${this.fanValue} -> ${targetFan} 档`);
          this.fanValue = targetFan;
          this.safePublish(TOPIC_FAN, targetFan.toString());
        }

        let targetPump = 0;
        if (this.moisture < moistureMin - 20) {
          targetPump = 3;
        } else if (this.moisture < moistureMin - 10) {
          targetPump = 2;
        } else if (this.moisture < moistureMin) {
          targetPump = 1;
        }

        if (this.waterPumpValue !== targetPump) {
          this.printLog(LogType.INFO, `[策略变更] 土壤过分干燥(当前土湿:${this.moisture}%)，水泵自动开启: ${this.waterPumpValue} -> ${targetPump} 档`);
          this.waterPumpValue = targetPump;
          this.safePublish(TOPIC_WATER_PUMP, targetPump.toString());
        }

        let targetLed = 0;
        if (this.intensity < intensityMin) {
          let level = Math.floor((2000 - this.ledValue) / 20);
          targetLed = level > 100 ? 100 : level;
        }

        if (this.ledValue !== targetLed) {
          this.printLog(LogType.INFO, `[策略变更] 自然光不足(当前光照:${this.intensity}Lx)，补光灯自动调节至: ${targetLed}%`);
          this.ledValue = targetLed;
          this.safePublish(TOPIC_LED, targetLed.toString());
        }

      } catch (err) {
        const errMsg = err instanceof Error ? err.message : JSON.stringify(err);
        this.printLog(LogType.ERROR, `智能策略核心算法发生崩溃: ${errMsg}`);
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
      Column()
        .opacity(this.animStep1 ? 1 : 0)
        .height("100%")
        .width("100%")
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: 10000,
              iterations: -1,
              autoPlay: true,
              onFinish: ()=> {
                console.info('Succeeded in finishing');
              }
            },
            controller: this.controller
          })
          .buildEffect())


      Column({ space: 16 }) {
        Blank().height(80)

        // ==================== 1. 连接状态栏 ====================
        Stack() {
          HdsButton({
            barWidth: 336,
            barHeight: 56,
            enableClickScale: true,
            enablePointLight: true,
            enableDrag: true,
            onButtonClick: () => {
              this.printLog(LogType.INFO, "点击了连接状态栏");
            }
          }) {
            Row() {
              Circle({ width: 8, height: 8 })
                .fill(this.isBoardConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
                .margin({ right: 10 })
              Text(this.isBoardConnected ? '已连接至 Rayawa/Hi3861 核心板' : '与开发板连接已断开，请检查网络')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isBoardConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
            }
            .padding({ left: 16, right: 16 })
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .opacity(this.animStep1 ? 1 : 0)
        .translate({ y: this.animStep1 ? 0 : 20 })

        // 🌟 完全保留原有的取反断开逻辑
        if(this.isBoardConnected){
          Flex({
            direction: this.isWideScreen ? FlexDirection.Row : FlexDirection.Column,
            space: { main: LengthMetrics.vp(16), cross: LengthMetrics.vp(16) }
          }) {
            // ==================== 2. 环境监测数据区域（4个独立材质卡片） ====================
            Column({ space: 12 }) {
              // 第一排：空气温度 & 空气湿度
              Row({ space: 12 }) {
                // 空气温度
                Stack() {
                  HdsButton({
                    barWidth: 164,
                    barHeight: 80,
                    enableClickScale: true,
                    enablePointLight: true,
                    enableDrag: true
                  }) {
                    Column() {
                      Row() {
                        Circle({ width: 6, height: 6 }).fill('#FF7D00').margin({ right: 6 })
                        Text('空气温度').fontSize(12).fontColor($r("sys.color.font_secondary"))
                      }.width('100%')
                      Blank()
                      Text(`${this.temp} ℃`).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%')
                    }
                    .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                  }
                }.layoutWeight(1)

                // 空气湿度
                Stack() {
                  HdsButton({
                    barWidth: 164,
                    barHeight: 80,
                    enableClickScale: true,
                    enablePointLight: true,
                    enableDrag: true
                  }) {
                    Column() {
                      Row() {
                        Circle({ width: 6, height: 6 }).fill('#007DFF').margin({ right: 6 })
                        Text('空气湿度').fontSize(12).fontColor($r("sys.color.font_secondary"))
                      }.width('100%')
                      Blank()
                      Text(`${this.hum} %`).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%')
                    }
                    .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                  }
                }.layoutWeight(1)
              }
              .width('100%')

              // 第二排：光照强度 & 土壤湿度
              Row({ space: 12 }) {
                // 光照强度
                Stack() {
                  HdsButton({
                    barWidth: 164,
                    barHeight: 80,
                    enableClickScale: true,
                    enablePointLight: true,
                    enableDrag: true
                  }) {
                    Column() {
                      Row() {
                        Circle({ width: 6, height: 6 }).fill('#FFBF00').margin({ right: 6 })
                        Text('光照强度').fontSize(12).fontColor($r("sys.color.font_secondary"))
                      }.width('100%')
                      Blank()
                      Text(`${this.intensity} Lx`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%')
                    }
                    .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                  }
                }.layoutWeight(1)

                // 土壤湿度
                Stack() {
                  HdsButton({
                    barWidth: 164,
                    barHeight: 80,
                    enableClickScale: true,
                    enablePointLight: true,
                    enableDrag: true
                  }) {
                    Column() {
                      Row() {
                        Circle({ width: 6, height: 6 }).fill('#34C759').margin({ right: 6 })
                        Text('土壤湿度').fontSize(12).fontColor($r("sys.color.font_secondary"))
                      }.width('100%')
                      Blank()
                      Text(`${this.moisture} %`).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%')
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

            // ==================== 2. 智能模式设置面板替换 ====================
            Column({ space: 12 }) {
              Text('智能模式设置')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .fontColor("#444444")
                .margin({ bottom: 4 })

              Stack() {
                HdsButton({
                  barWidth: 336,
                  barHeight: 140, // 严丝合缝包裹内部三组 Row 阈值设定组件
                  enablePointLight: true,
                  enableClickScale: false // 输入框承载卡片，保持静止不进行整包缩放
                }) {
                  Column({ space: 10 }) {
                    Row({ space: 10 }) {
                      this.inputField('温度上限', () => this.zone1.autoTempMax, (v) => { this.zone1.autoTempMax = v })
                      this.inputField('空湿上限', () => this.zone1.autoHumMax, (v) => { this.zone1.autoHumMax = v })
                    }.width('100%')

                    Row({ space: 10 }) {
                      this.inputField('土湿下限', () => this.zone1.autoMoistureMin, (v) => { this.zone1.autoMoistureMin = v })
                      this.inputField('土湿上限', () => this.zone1.autoMoistureMax, (v) => { this.zone1.autoMoistureMax = v })
                    }.width('100%')

                    Row({ space: 10 }) {
                      this.inputField('光照下限', () => this.zone1.autoIntensityMin, (v) => { this.zone1.autoIntensityMin = v })
                      this.inputField('光照上限', () => this.zone1.autoIntensityMax, (v) => { this.zone1.autoIntensityMax = v })
                    }.width('100%')
                  }
                  .padding(10)
                  .width('100%')
                  .height('100%')
                }
              }.width('100%')
            }
            .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
            .opacity(this.animStep3 ? 1 : 0)
            .translate({ y: this.animStep3 ? 0 : 20 })
          }
        } else {
          Column({ space: 12 }) {
            LoadingProgress().width(80).height(80).color("#444444")
            Text('等待建立通信...').fontSize(18).fontWeight(FontWeight.Bold).fontColor("#444444").margin({ top: 20 })
          }
          .opacity(this.animStep1 ? 1 : 0)
          .translate({ y: this.animStep1 ? 0 : 20 })
          .margin({top: 50})
          .justifyContent(FlexAlign.Center)
        }
      }
      .height("100%")
      .padding({ left: 16, right: 16, top: 75, bottom: 32 })
    }
    .onAreaChange((oldValue: Area, newValue: Area) => {
      let currentWidth = newValue.width as number;
      let newWideState = currentWidth >= 600;

      if (this.isWideScreen !== newWideState) {
        animateTo({
          duration: 400,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.isWideScreen = newWideState;
        });
      }
    })
    .onVisibleAreaChange([0.0], (isVisible: boolean, currentRatio: number) => {
      this.handleAutoPageVisibility(isVisible && currentRatio > 0);
    })
    .backgroundColor($r("app.color.backcolor"))
    .ignoreLayoutSafeArea()
  }

  // 🌟 完全原汁原味的原版输入组件逻辑与样式
  @Builder
  inputField(label: string, getter: () => string, setter: (val: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .width(60)
        .fontColor("#444444")
        .margin({ right: 5 })
      TextInput({ text: getter() })
        .fontSize(11)
        .height(28)
        .width(65)
        .padding({ left: 6, right: 6 })
        .fontColor("#DDDDDD")
        .backgroundColor(this.autoEnabled ? this.transparentDiffColor : $r("app.color.diff_background"))
        .borderRadius(6)
        .type(InputType.Number)
        .onChange((val: string) => {
          setter(val);
          this.printLog(LogType.INFO, `用户修改自动阈值 [${label}] 为: ${val}`);
        })
    }
    .layoutWeight(1)
  }
}