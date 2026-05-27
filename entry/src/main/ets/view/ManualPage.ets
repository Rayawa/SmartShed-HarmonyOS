// src/main/ets/view/ManualPage.ets
import { ZoneData } from '../viewmodel/SmartShedBean';
import {
  LogType,
  MqttReceiverClient,
  TOPIC_RGB_LED,
  TOPIC_SOI_FAN,
  TOPIC_SOI_WATER_PUMP
} from '../service/MqttReceiverClient';
import { curves, display, LengthMetrics, promptAction } from '@kit.ArkUI';
import { GlobalLogBus } from '../pages/Index';
import { hdsEffect } from '@kit.UIDesignKit';

@Component
export struct ManualPage {
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @StorageLink("isWideScreen") isWideScreen: boolean = true;
  @StorageLink('isBoardRgbConnected') isBoardRgbConnected: boolean = false;
  @StorageLink('isBoardSoiConnected') isBoardSoiConnected: boolean = false;
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

  @StorageLink("lightColor") lightColor: ResourceColor = Color.White;
  @StorageLink("lightIntensity") lightIntensity: number = 10;
  @State button_gradient_state: hdsEffect.PressShadowType = hdsEffect.PressShadowType.NONE;
  @State isPressedConnect: boolean = false;
  @State isPressedRGBConnect: boolean = false;
  @State isPressedSOIConnect: boolean = false;
  @State isPressedA: boolean = false;
  @State isPressedB: boolean = false;
  @State isPressedC: boolean = false;
  @State isPressedD: boolean = false;
  @State isPressedControl: boolean = false;
  @State isPressed1: boolean = false;
  @State isPressed2: boolean = false;
  @State isPressed3: boolean = false;
  @State lightSourceTypeConnect: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeRGBConnect: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeSOIConnect: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeA: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeB: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeC: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeD: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceTypeControl: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceType1: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceType2: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State lightSourceType3: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State animStep1: number = 0;
  @State animStep2: number = 0;
  @State animStep3: number = 0;
  private timer1: number = -1;
  private timer2: number = -1;
  private timer3: number = -1;
  private effect: TransitionEffect = TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: 10 }))
    .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
    .animation({ curve: curves.springMotion(0.4, 0.65) });
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
    animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
      this.animStep1 = 0;
      this.animStep2 = 0;
      this.animStep3 = 0;
    })
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
    this.isWideScreen = px2vp(display.getDefaultDisplaySync().width)>600? true: false;
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
      if (this.isBoardRgbConnected || this.isBoardSoiConnected) {
        this.printLog(LogType.INFO, "已进入手动模式，开始强制同步 App 档位至板子...");
        this.safePublish(TOPIC_SOI_FAN, this.fanValue.toString());
        this.safePublish(TOPIC_SOI_WATER_PUMP, this.waterPumpValue.toString());
        this.safePublish(TOPIC_RGB_LED, this.ledValue.toString());
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
    Column({ space: 16 }) {
      Blank().height(80)
      Row({ space: 5 }) {
        Row(){
          Circle({ width: 8, height: 8 })
            .fill(this.isBoardRgbConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
            .margin({ right: 6 })
          Text(this.isBoardRgbConnected ? 'Rayawa/rgb 已连接' : 'Rayawa/rgb 未连接')
            .fontSize(14)
            .fontColor(this.isBoardRgbConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
        }
        .shadow({
          radius: 8,
          color: "#1a000000",
          offsetX: 0,
          offsetY: 2,
        })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pressShadow(this.button_gradient_state)
          .pointLight({
            sourceType: this.lightSourceTypeRGBConnect,
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
            options: {
              color: this.lightColor,
              intensity: this.lightIntensity,
              height: 150
            }
          })
          .pressShadow(this.button_gradient_state)
          .buildEffect())
        .scale({ x: this.isPressedRGBConnect ? 0.97 : 1, y: this.isPressedRGBConnect ? 0.97 : 1 })
        .animation({ curve: Curve.EaseOut, duration: 150 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.lightSourceTypeRGBConnect = hdsEffect.PointLightSourceType.BRIGHT;
            this.isPressedRGBConnect = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.lightSourceTypeRGBConnect = hdsEffect.PointLightSourceType.NONE;
            this.isPressedRGBConnect = false;
          }
        })
        .padding(10)
        .backgroundColor(this.isBoardRgbConnected ? $r("app.color.green_light") : $r("app.color.red_light"))
        .borderRadius(16)
        .borderWidth(1)
        .borderColor(this.isBoardRgbConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))

        Row(){
          Circle({ width: 8, height: 8 })
            .fill(this.isBoardSoiConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
            .margin({ right: 6 })
          Text(this.isBoardSoiConnected ? 'Rayawa/soi 已连接' : 'Rayawa/soi 未连接')
            .fontSize(14)
            .fontColor(this.isBoardSoiConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
        }
        .shadow({
          radius: 8,
          color: "#1a000000",
          offsetX: 0,
          offsetY: 2,
        })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pressShadow(this.button_gradient_state)
          .pointLight({
            sourceType: this.lightSourceTypeSOIConnect,
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
            options: {
              color: this.lightColor,
              intensity: this.lightIntensity,
              height: 150
            }
          })
          .pressShadow(this.button_gradient_state)
          .buildEffect())
        .scale({ x: this.isPressedSOIConnect ? 0.97 : 1, y: this.isPressedSOIConnect ? 0.97 : 1 })
        .animation({ curve: Curve.EaseOut, duration: 150 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.lightSourceTypeSOIConnect = hdsEffect.PointLightSourceType.BRIGHT;
            this.isPressedSOIConnect = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.lightSourceTypeSOIConnect = hdsEffect.PointLightSourceType.NONE;
            this.isPressedSOIConnect = false;
          }
        })
        .padding(10)
        .backgroundColor(this.isBoardSoiConnected ? $r("app.color.green_light") : $r("app.color.red_light"))
        .borderRadius(16)
        .borderWidth(1)
        .borderColor(this.isBoardSoiConnected ? $r("app.color.green_dark") : $r("app.color.red_dark"))
      }
      .shadow({
        radius: 8,
        color: "#1a000000",
        offsetX: 0,
        offsetY: 2,
      })
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pressShadow(this.button_gradient_state)
        .pointLight({
          sourceType: this.lightSourceTypeConnect,
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
          options: {
            color: this.lightColor,
            intensity: this.lightIntensity,
            height: 150
          }
        })
        .pressShadow(this.button_gradient_state)
        .buildEffect())
      .animation({ curve: Curve.EaseOut, duration: 150 })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.lightSourceTypeConnect = hdsEffect.PointLightSourceType.BRIGHT;
          this.isPressedConnect = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.lightSourceTypeConnect = hdsEffect.PointLightSourceType.NONE;
          this.isPressedConnect = false;
        }
      })
      .justifyContent(FlexAlign.SpaceBetween)
      .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
      .padding(10)
      .borderWidth(1).borderColor($r("app.color.border"))
      .backgroundColor($r("app.color.background"))
      .borderRadius(16)
      .opacity(this.animStep1 ? 1 : 0)
      .translate({ y: this.animStep1 ? 0 : 20 })


      Flex({
        direction: this.isWideScreen ? FlexDirection.Row : FlexDirection.Column,
        space: { main: LengthMetrics.vp(16), cross: LengthMetrics.vp(16) }
      }) {
        Column({ space: 12 }){
          Row({ space: 12 }) {
            Column() {
              Row() {
                Circle({ width: 6, height: 6 }).fill('#FF7D00')
                Text('空气温度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 })
              }.width('100%')
              Blank()
              Text(this.isBoardRgbConnected ? `${this.temp} ℃` : "N/A").fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pressShadow(this.button_gradient_state)
              .pointLight({
                sourceType: this.lightSourceTypeA,
                illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
                options: {
                  color: this.lightColor,
                  intensity: this.lightIntensity,
                  height: 150
                }
              })
              .pressShadow(this.button_gradient_state)
              .buildEffect())
            .scale({ x: this.isPressedA ? 0.97 : 1, y: this.isPressedA ? 0.97 : 1 })
            .animation({ curve: Curve.EaseOut, duration: 150 })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.lightSourceTypeA = hdsEffect.PointLightSourceType.BRIGHT;
                this.isPressedA = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.lightSourceTypeA = hdsEffect.PointLightSourceType.NONE;
                this.isPressedA = false;
              }
            })
            .borderWidth(1).borderColor($r("app.color.border"))
            .layoutWeight(1)
            .height('100%')
            .padding(14)
            .backgroundColor($r("app.color.background"))
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: "#1a000000",
              offsetX: 0,
              offsetY: 2,
            })

            Column() {
              Row() {
                Circle({ width: 6, height: 6 }).fill('#007DFF')
                Text('空气湿度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 })
              }.width('100%')
              Blank()
              Text(this.isBoardRgbConnected ? `${this.hum} %` : "N/A").fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pressShadow(this.button_gradient_state)
              .pointLight({
                sourceType: this.lightSourceTypeB,
                illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
                options: {
                  color: this.lightColor,
                  intensity: this.lightIntensity,
                  height: 150
                }
              })
              .pressShadow(this.button_gradient_state)
              .buildEffect())
            .scale({ x: this.isPressedB ? 0.97 : 1, y: this.isPressedB ? 0.97 : 1 })
            .animation({ curve: Curve.EaseOut, duration: 150 })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.lightSourceTypeB = hdsEffect.PointLightSourceType.BRIGHT;
                this.isPressedB = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.lightSourceTypeB = hdsEffect.PointLightSourceType.NONE;
                this.isPressedB = false;
              }
            })
            .borderWidth(1).borderColor($r("app.color.border"))
            .layoutWeight(1)
            .height('100%')
            .padding(14)
            .backgroundColor($r("app.color.background"))
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: "#1a000000",
              offsetX: 0,
              offsetY: 2,
            })
          }
          .layoutWeight(1)
          .width('100%')

          Row({ space: 12 }) {
            Column() {
              Row() {
                Circle({ width: 6, height: 6 }).fill('#FFBF00')
                Text('光照强度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 })
              }.width('100%')
              Blank()
              Text(this.isBoardRgbConnected ? `${this.intensity} Lx` : "N/A").fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pressShadow(this.button_gradient_state)
              .pointLight({
                sourceType: this.lightSourceTypeC,
                illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
                options: {
                  color: this.lightColor,
                  intensity: this.lightIntensity,
                  height: 150
                }
              })
              .pressShadow(this.button_gradient_state)
              .buildEffect())
            .scale({ x: this.isPressedC ? 0.97 : 1, y: this.isPressedC ? 0.97 : 1 })
            .animation({ curve: Curve.EaseOut, duration: 150 })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.lightSourceTypeC = hdsEffect.PointLightSourceType.BRIGHT;
                this.isPressedC = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.lightSourceTypeC = hdsEffect.PointLightSourceType.NONE;
                this.isPressedC = false;
              }
            })
            .borderWidth(1).borderColor($r("app.color.border"))
            .layoutWeight(1)
            .height('100%')
            .padding(14)
            .backgroundColor($r("app.color.background"))
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: "#1a000000",
              offsetX: 0,
              offsetY: 2,
            })

            Column() {
              Row() {
                Circle({ width: 6, height: 6 }).fill('#34C759')
                Text('土壤湿度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 })
              }.width('100%')
              Blank()
              Text(this.isBoardSoiConnected ? `${this.moisture} %` : "N/A").fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pressShadow(this.button_gradient_state)
              .pointLight({
                sourceType: this.lightSourceTypeD,
                illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
                options: {
                  color: this.lightColor,
                  intensity: this.lightIntensity,
                  height: 150
                }
              })
              .pressShadow(this.button_gradient_state)
              .buildEffect())
            .scale({ x: this.isPressedD ? 0.97 : 1, y: this.isPressedD ? 0.97 : 1 })
            .animation({ curve: Curve.EaseOut, duration: 150 })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.lightSourceTypeD = hdsEffect.PointLightSourceType.BRIGHT;
                this.isPressedD = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.lightSourceTypeD = hdsEffect.PointLightSourceType.NONE;
                this.isPressedD = false;
              }
            })
            .borderWidth(1).borderColor($r("app.color.border"))
            .layoutWeight(1)
            .height('100%')
            .padding(14)
            .backgroundColor($r("app.color.background"))
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: "#1a000000",
              offsetX: 0,
              offsetY: 2,
            })
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
        .height(160)
        .opacity(this.animStep2 ? 1 : 0)
        .translate({ y: this.animStep2 ? 0 : 20 })

        Column() {
          Text('手动控制')
            .padding(5)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .fontColor($r("sys.color.font_primary"))
            .margin({ bottom: 12 })
            if(!this.isBoardRgbConnected && !this.isBoardSoiConnected){
              Text("N/A")
                .padding(5)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .fontColor($r("sys.color.font_primary"))
                .transition(this.effect)
            }
            else {
              Column(){
                if (this.isBoardRgbConnected) {
                  Column() {
                    Row() {
                      Text('全光谱植物补光灯').fontSize(13).fontColor($r("sys.color.font_primary"))
                      Blank()
                      Text(this.isBoardRgbConnected ? (this.ledValue === 0 ? '关闭' : `${this.ledValue} %`) : "N/A")
                        .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r("sys.color.font_secondary"))
                    }.width('100%')
                    Row(){
                      Image($r('app.media.light1')).height(20).width(20)
                      Slider({ value: this.ledValue, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
                        .height(28).layoutWeight(1)
                        .enabled(this.isBoardRgbConnected)
                        .onChange((val: number, mode: SliderChangeMode) => {
                          let targetVal = Math.floor(val);
                          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                            this.ledValue = targetVal;
                            this.printLog(LogType.INFO, `通过滑块调节植物灯亮度 -> 设定为: ${targetVal} %`);
                            this.safePublish(TOPIC_RGB_LED, targetVal.toString());
                          }
                        })
                      Image($r('app.media.light2')).height(20).width(20)
                    }.alignItems(VerticalAlign.Center)
                  }.borderRadius(16).borderWidth(1).borderColor($r("app.color.border")).padding(10).width("100%")
                  .transition(this.effect)
                  .visualEffect(new hdsEffect.HdsEffectBuilder()
                    .pressShadow(this.button_gradient_state)
                    .pointLight({
                      sourceType: this.lightSourceType3,
                      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
                      options: {
                        color: this.lightColor,
                        intensity: this.lightIntensity,
                        height: 150
                      }
                    })
                    .pressShadow(this.button_gradient_state)
                    .buildEffect())
                  .scale({ x: this.isPressed3 ? 0.97 : 1, y: this.isPressed3 ? 0.97 : 1 })
                  .animation({ curve: Curve.EaseOut, duration: 150 })
                  .onTouch((event: TouchEvent) => {
                    if (event.type === TouchType.Down) {
                      this.lightSourceType3 = hdsEffect.PointLightSourceType.BRIGHT;
                      this.isPressed3 = true;
                    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                      this.lightSourceType3 = hdsEffect.PointLightSourceType.NONE;
                      this.isPressed3 = false;
                    }
                  })
                  .margin({ bottom: 12 })
                }
                if (this.isBoardSoiConnected) {
                  Column() {
                    Row() {
                      Text('风扇主轴转速').fontSize(13).fontColor($r("sys.color.font_primary"))
                      Blank()
                      Text(this.isBoardSoiConnected ? (this.fanValue === 0 ? '关闭' : `${this.fanValue} 档`) : "N/A")
                        .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r("sys.color.font_secondary"))
                    }.width('100%')
                    Row(){
                      Image($r('app.media.wind1')).height(20).width(20)
                      Slider({ value: this.fanValue, min: 0, max: 3, step: 1, style: SliderStyle.InSet })
                        .height(28).layoutWeight(1)
                        .enabled(this.isBoardSoiConnected)
                        .onChange((val: number, mode: SliderChangeMode) => {
                          let targetVal = Math.floor(val);
                          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                            this.fanValue = targetVal;
                            this.printLog(LogType.INFO, `通过滑块调节风扇档位 -> 设定为: ${targetVal} 档`);
                            this.safePublish(TOPIC_SOI_FAN, targetVal.toString());
                          }
                        })
                      Image($r('app.media.wind2')).height(20).width(20)
                    }.alignItems(VerticalAlign.Center)
                  }.borderRadius(16).borderWidth(1).borderColor($r("app.color.border")).padding(10).width("100%")
                  .transition(this.effect)
                  .visualEffect(new hdsEffect.HdsEffectBuilder()
                    .pressShadow(this.button_gradient_state)
                    .pointLight({
                      sourceType: this.lightSourceType1,
                      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
                      options: {
                        color: this.lightColor,
                        intensity: this.lightIntensity,
                        height: 150
                      }
                    })
                    .pressShadow(this.button_gradient_state)
                    .buildEffect())
                  .scale({ x: this.isPressed1 ? 0.97 : 1, y: this.isPressed1 ? 0.97 : 1 })
                  .animation({ curve: Curve.EaseOut, duration: 150 })
                  .onTouch((event: TouchEvent) => {
                    if (event.type === TouchType.Down) {
                      this.lightSourceType1 = hdsEffect.PointLightSourceType.BRIGHT;
                      this.isPressed1 = true;
                    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                      this.lightSourceType1 = hdsEffect.PointLightSourceType.NONE;
                      this.isPressed1 = false;
                    }
                  })
                  .margin({ bottom: 12 })
                }
                if (this.isBoardSoiConnected) {
                  Column() {
                    Row() {
                      Text('微型潜水泵').fontSize(13).fontColor($r("sys.color.font_primary"))
                      Blank()
                      Text(this.isBoardSoiConnected ? (this.waterPumpValue === 0 ? '关闭' : `${this.waterPumpValue} 档`) : "N/A")
                        .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r("sys.color.font_secondary"))
                    }.width('100%')
                    Row(){
                      Image($r('app.media.water1')).height(20).width(20)
                      Slider({ value: this.waterPumpValue, min: 0, max: 3, step: 1, style: SliderStyle.InSet })
                        .height(28).layoutWeight(1)
                        .enabled(this.isBoardSoiConnected)
                        .onChange((val: number, mode: SliderChangeMode) => {
                          let targetVal = Math.floor(val);
                          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                            this.waterPumpValue = targetVal;
                            this.printLog(LogType.INFO, `通过滑块调节潜水泵档位 -> 设定为: ${targetVal} 档`);
                            this.safePublish(TOPIC_SOI_WATER_PUMP, targetVal.toString());
                          }
                        })
                      Image($r('app.media.water2')).height(20).width(20)
                    }.alignItems(VerticalAlign.Center)
                  }.borderRadius(16).borderWidth(1).borderColor($r("app.color.border")).padding(10).width("100%")
                  .transition(this.effect)
                  .visualEffect(new hdsEffect.HdsEffectBuilder()
                    .pressShadow(this.button_gradient_state)
                    .pointLight({
                      sourceType: this.lightSourceType2,
                      illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
                      options: {
                        color: this.lightColor,
                        intensity: this.lightIntensity,
                        height: 150
                      }
                    })
                    .pressShadow(this.button_gradient_state)
                    .buildEffect())
                  .scale({ x: this.isPressed2 ? 0.97 : 1, y: this.isPressed2 ? 0.97 : 1 })
                  .animation({ curve: Curve.EaseOut, duration: 150 })
                  .onTouch((event: TouchEvent) => {
                    if (event.type === TouchType.Down) {
                      this.lightSourceType2 = hdsEffect.PointLightSourceType.BRIGHT;
                      this.isPressed2 = true;
                    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                      this.lightSourceType2 = hdsEffect.PointLightSourceType.NONE;
                      this.isPressed2 = false;
                    }
                  })
                  .margin({ bottom: 12 })
                }
              }
            }
        }
        .animation({ curve: curves.springMotion(0.5, 0.8) })
        .shadow({
          radius: 8,
          color: "#1a000000",
          offsetX: 0,
          offsetY: 2,
        })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pressShadow(this.button_gradient_state)
          .pointLight({
            sourceType: this.lightSourceTypeControl,
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
            options: {
              color: this.lightColor,
              intensity: this.lightIntensity,
              height: 150
            }
          })
          .pressShadow(this.button_gradient_state)
          .buildEffect())
        .animation({ curve: Curve.EaseOut, duration: 150 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.lightSourceTypeControl = hdsEffect.PointLightSourceType.BRIGHT;
            this.isPressedControl = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.lightSourceTypeControl = hdsEffect.PointLightSourceType.NONE;
            this.isPressedControl = false;
          }
        })
        .width(this.isWideScreen ? 'calc(50% - 8vp)' : '100%')
        .padding(10)
        .borderWidth(1).borderColor($r("app.color.border"))
        .backgroundColor($r("app.color.background"))
        .borderRadius(16)
        .opacity(this.animStep3 ? 1 : 0)
        .translate({ y: this.animStep3 ? 0 : 20 })
      }
      .animation({ curve: Curve.EaseOut, duration: 150 })

    }
    .height("100%")
    .padding({ left: 16, right: 16, top: 75, bottom: 32 })
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
      this.handleManualPageVisibility(isVisible && currentRatio > 0);
    })
    .backgroundColor($r("app.color.backcolor"))
    .ignoreLayoutSafeArea()
  }
}