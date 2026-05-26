// src/main/ets/view/ManualPage.ets
import { ZoneData } from '../viewmodel/SmartShedBean';
import { LogType, MqttReceiverClient, TOPIC_FAN, TOPIC_LED, TOPIC_WATER_PUMP } from '../service/MqttReceiverClient';
import { curves, display, LengthMetrics, promptAction, router } from '@kit.ArkUI';
import { GlobalLogBus } from '../pages/Index';
import { HdsButton } from '../viewmodel/HdsButton';
import { vibration } from '../service/vibration';

@Component
export struct ManualPage {
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

  @State animStep1: number = 0;
  @State animStep2: number = 0;
  @State animStep3: number = 0;
  private timer1: number = -1;
  private timer2: number = -1;
  private timer3: number = -1;

  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  onVisibleChange(){
    this.handleManualPageVisibility(this.isVisible);
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
    GlobalLogBus.emit(type, `Manual: ${message}`);
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
    this.autoEnabled = false;
    this.printLog(LogType.INFO, "已切换到自定义模式");

    if (this.isVisible) {
      this.handleManualPageVisibility(true);
    }
  }

  aboutToDisappear(): void {
    this.handleManualPageVisibility(false);
  }

  private handleManualPageVisibility(visible: boolean): void {
    if (visible) {
      this.autoEnabled = false;
      if (this.isBoardConnected) {
        this.printLog(LogType.INFO, "已进入手动模式，开始强制同步 App 档位至板子...");
        this.safePublish(TOPIC_FAN, this.fanValue.toString());
        this.safePublish(TOPIC_WATER_PUMP, this.waterPumpValue.toString());
        this.safePublish(TOPIC_LED, this.ledValue.toString());
        this.printLog(LogType.INFO, `同步完成 -> 风扇:${this.fanValue}档, 水泵:${this.waterPumpValue}档, 补光灯:${this.ledValue}%`);
      }
      this.stopAutoLogic();
      this.startEnterAnimation();
    } else {
      this.stopEnterAnimation();
    }
  }

  private safePublish(topic: string, value: string) {
    try {
      if (this.mqttClient) {
        this.mqttClient.publish(topic, value);
        this.printLog(LogType.INFO, `指令成功外发 -> 目标Topic: ${topic}, 设定值: ${value}`);
      } else {
        throw new Error("MQTT未初始化");
      }
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : JSON.stringify(error);
      this.printLog(LogType.ERROR, `控制包外发失败: ${errMsg}`);
      promptAction.showToast({ message: '指令下发失败，请检查网络', duration: 2000 });
    }
  }

  private stopAutoLogic(): void {
    this.zone1.isExit = true;
    if (this.zone1.autoManagerThread !== null) {
      this.printLog(LogType.INFO, `正清理并销毁后台运行的自动化常驻线程锁`);
      clearInterval(this.zone1.autoManagerThread);
      this.zone1.autoManagerThread = null;
    }
  }

  build() {
    Stack(){
      Image($r("app.media.back")).width("100%").height("100%")
      Column({ space: 20 }) {
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
        }.justifyContent(FlexAlign.SpaceBetween).width("100%")

        Stack() {
          HdsButton({
            barWidth: 336,
            barHeight: 56,
            enableClickScale: true,
            enablePointLight: true,
            enableDrag: true
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

        if (this.isBoardConnected) {
          Flex({
            direction: this.isWideScreen ? FlexDirection.Row : FlexDirection.Column,
            space: { main: LengthMetrics.vp(16), cross: LengthMetrics.vp(16) }
          }) {

            Column({ space: 12 }) {
              Row({ space: 12 }) {
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
                        Text('空气温度').fontSize(12).fontColor(Color.White)
                      }.width('100%')
                      Blank()
                      Text(`${this.temp} ℃`).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                    }
                    .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                  }
                }.layoutWeight(1)

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
                        Text('空气湿度').fontSize(12).fontColor(Color.White)
                      }.width('100%')
                      Blank()
                      Text(`${this.hum} %`).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                    }
                    .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                  }
                }.layoutWeight(1)
              }
              .width('100%')

              Row({ space: 12 }) {
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
                        Text('光照强度').fontSize(12).fontColor(Color.White)
                      }.width('100%')
                      Blank()
                      Text(`${this.intensity} Lx`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
                    }
                    .padding({ left: 25, top: 10, bottom: 8 }).width('100%').height('100%')
                  }
                }.layoutWeight(1)

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
                        Text('土壤湿度').fontSize(12).fontColor(Color.White)
                      }.width('100%')
                      Blank()
                      Text(`${this.moisture} %`).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
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

            Column({ space: 12 }) {
              Text('手动控制')
                .padding({ left: 4, top: 4 })
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .fontColor(Color.White)

              Stack() {
                HdsButton({
                  barWidth: 336,
                  barHeight: 80,
                  enablePointLight: true,
                  enableClickScale: true
                }) {
                  Row() {
                    Column({ space: 4 }) {
                      Row() {
                        Text('风扇主轴转速').fontSize(13).fontColor(Color.White)
                        Blank()
                        Text(this.fanValue === 0 ? '关闭' : `${this.fanValue} 档`)
                          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
                      }.width('100%')

                      Row() {
                        Image($r('app.media.wind1')).height(20).width(20)
                        Slider({ value: this.fanValue, min: 0, max: 3, step: 1, style: SliderStyle.InSet })
                          .height(28).layoutWeight(1)
                          .onChange((val: number, mode: SliderChangeMode) => {
                            let targetVal = Math.floor(val);
                            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                              this.fanValue = targetVal;
                              this.printLog(LogType.INFO, `通过滑块调节风扇档位 -> 设定为: ${targetVal} 档`);
                              this.safePublish(TOPIC_FAN, targetVal.toString());
                            }
                          })
                        Image($r('app.media.wind2')).height(20).width(20)
                      }.alignItems(VerticalAlign.Center).width('100%')
                    }.width('100%')
                  }
                  .padding({ left: 17, right: 17, top: 10, bottom: 5 }).width('100%').height('100%')
                }
              }.width('100%')

              Stack() {
                HdsButton({
                  barWidth: 336,
                  barHeight: 80,
                  enablePointLight: true,
                  enableClickScale: true
                }) {
                  Row() {
                    Column({ space: 4 }) {
                      Row() {
                        Text('微型潜水泵').fontSize(13).fontColor(Color.White)
                        Blank()
                        Text(this.waterPumpValue === 0 ? '关闭' : `${this.waterPumpValue} 档`)
                          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
                      }.width('100%')

                      Row() {
                        Image($r('app.media.water1')).height(20).width(20)
                        Slider({ value: this.waterPumpValue, min: 0, max: 3, step: 1, style: SliderStyle.InSet })
                          .height(28).layoutWeight(1)
                          .onChange((val: number, mode: SliderChangeMode) => {
                            let targetVal = Math.floor(val);
                            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                              this.waterPumpValue = targetVal;
                              this.printLog(LogType.INFO, `通过滑块调节潜水泵档位 -> 设定为: ${targetVal} 档`);
                              this.safePublish(TOPIC_WATER_PUMP, targetVal.toString());
                            }
                          })
                        Image($r('app.media.water2')).height(20).width(20)
                      }.alignItems(VerticalAlign.Center).width('100%')
                    }.width('100%')
                  }
                  .padding({ left: 17, right: 17, top: 10, bottom: 5 }).width('100%').height('100%')
                }
              }.width('100%')

              Stack() {
                HdsButton({
                  barWidth: 336,
                  barHeight: 80,
                  enablePointLight: true,
                  enableClickScale: true
                }) {
                  Row() {
                    Column({ space: 4 }) {
                      Row() {
                        Text('全光谱植物补光灯').fontSize(13).fontColor(Color.White)
                        Blank()
                        Text(this.ledValue === 0 ? '关闭' : `${this.ledValue} %`)
                          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
                      }.width('100%')

                      Row() {
                        Image($r('app.media.light1')).height(20).width(20)
                        Slider({ value: this.ledValue, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
                          .height(28).layoutWeight(1)
                          .onChange((val: number, mode: SliderChangeMode) => {
                            let targetVal = Math.floor(val);
                            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                              this.ledValue = targetVal;
                              this.printLog(LogType.INFO, `通过滑块调节植物灯亮度 -> 设定为: ${targetVal} %`);
                              this.safePublish(TOPIC_LED, targetVal.toString());
                            }
                          })
                        Image($r('app.media.light2')).height(20).width(20)
                      }.alignItems(VerticalAlign.Center).width('100%')
                    }.width('100%')
                  }
                  .padding({ left: 17, right: 17, top: 10, bottom: 5 }).width('100%').height('100%')
                }
              }.width('100%')
            }
            .opacity(this.animStep3 ? 1 : 0)
            .translate({ y: this.animStep3 ? 0 : 20 })
            .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
          }
        } else {
          Column({ space: 12 }) {
            LoadingProgress().width(80).height(80) .color(Color.White)
            Text('等待建立通信...').fontSize(18).fontWeight(FontWeight.Bold) .fontColor(Color.White).margin({ top: 20 })
          }
          .opacity(this.animStep1 ? 1 : 0)
          .translate({ y: this.animStep1 ? 0 : 20 })
          .margin({top: 50})
          .justifyContent(FlexAlign.Center)
        }
      }
      .width("100%")
      .height("100%")
      .padding({ left: 16, right: 16, top: 75, bottom: 32 })
    }
    .onVisibleAreaChange([0.0], (isVisible: boolean, currentRatio: number) => {
      this.handleManualPageVisibility(isVisible && currentRatio > 0);
    })
    .width("100%")
    .height("100%")
    .ignoreLayoutSafeArea()
  }
}