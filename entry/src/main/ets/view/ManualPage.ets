// src/main/ets/view/ManualPage.ets
import { ZoneData } from '../viewmodel/SmartShedBean';
import { LogType, MqttReceiverClient, TOPIC_FAN, TOPIC_LED, TOPIC_WATER_PUMP } from '../service/MqttReceiverClient';
import { curves, promptAction } from '@kit.ArkUI';
import { GlobalLogBus } from '../pages/Index';

@Component
export struct ManualPage {
  @StorageLink("vibrationON") vibrationON: boolean = true;

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

  @State animStep1: boolean = false;
  @State animStep2: boolean = false;
  @State animStep3: boolean = false;

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
    const duration = 500;
    const interval = duration * 0.25;
    const curve = curves.springMotion(0.35, 0.75);
    this.autoEnabled = false;
    this.printLog(LogType.INFO, "已切换到自定义模式");

    setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep1 = true }) }, 100);
    setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep2 = true }) }, interval + 100);
    setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep3 = true }) }, interval * 2 + 100);
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

  private handleManualPageVisibility(isVisible: boolean): void {
    if (!isVisible) {
      this.autoEnabled = false;
      this.stopAutoLogic();
    }
  }

  build() {
    Column({ space: 16 }) {
      Blank().height(80)
      Row() {
        Circle({ width: 8, height: 8 })
          .fill(this.isBoardConnected ? '#41BA41' : '#FF3B30')
          .margin({ right: 6 })
        Text(this.isBoardConnected ? '已连接至Rayawa/Hi3861' : '与开发板连接已断开，请检查网络')
          .fontSize(14)
          .fontColor(this.isBoardConnected ? '#1E661E' : '#A52A2A')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.isBoardConnected ? '#E8F5E9' : '#FFEBEE')
      .borderRadius(8)

      if(this.isBoardConnected){
        Grid() {
          GridItem() {
            Column() {
              Row() { Circle({ width: 6, height: 6 }).fill('#FF7D00'); Text('空气温度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 }) }.width('100%')
              Blank()
              Text(`${this.temp} ℃`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }.width('100%').height('100%').padding(14).backgroundColor($r("sys.color.ohos_id_color_button_normal")).borderRadius(12).shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
          }
          GridItem() {
            Column() {
              Row() { Circle({ width: 6, height: 6 }).fill('#007DFF'); Text('空气湿度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 }) }.width('100%')
              Blank()
              Text(`${this.hum} %`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }.width('100%').height('100%').padding(14).backgroundColor($r("sys.color.ohos_id_color_button_normal")).borderRadius(12).shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
          }
          GridItem() {
            Column() {
              Row() { Circle({ width: 6, height: 6 }).fill('#FFBF00'); Text('光照强度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 }) }.width('100%')
              Blank()
              Text(`${this.intensity} Lx`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }.width('100%').height('100%').padding(14).backgroundColor($r("sys.color.ohos_id_color_button_normal")).borderRadius(12).shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
          }
          GridItem() {
            Column() {
              Row() { Circle({ width: 6, height: 6 }).fill('#34C759'); Text('土壤湿度').fontSize(12).fontColor($r("sys.color.font_secondary")).margin({ left: 6 }) }.width('100%')
              Blank()
              Text(`${this.moisture} %`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r("sys.color.font_primary")).width('100%').textAlign(TextAlign.Start)
            }.width('100%').height('100%').padding(14).backgroundColor($r("sys.color.ohos_id_color_button_normal")).borderRadius(12).shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
          }
        }
        .opacity(this.animStep1 ? 1 : 0)
        .translate({ y: this.animStep1 ? 0 : 20 })
        .columnsTemplate('1fr 1fr')
        .rowsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
        .height(160)

        Column({ space: 14 }) {
          Text('手动控制')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .fontColor($r("sys.color.font_primary"))
            .margin({ bottom: 4 })

          Column() {
            Row() {
              Text('风扇主轴转速').fontSize(13).fontColor($r("sys.color.font_primary"))
              Blank()
              Text(this.fanValue === 0 ? '关闭' : `${this.fanValue} 档`)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r("sys.color.font_secondary"))
            }.width('100%')
            Row(){
              Image($r('app.media.wind1')).height(20).width(20)
              Slider({ value: this.fanValue, min: 0, max: 3, step: 1, style: SliderStyle.InSet })
                .height(28).layoutWeight(1)
                .onChange((val: number, mode: SliderChangeMode) => {
                  let targetVal = Math.floor(val);
                  this.fanValue = targetVal;
                  if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                    this.printLog(LogType.INFO, `通过滑块调节风扇档位 -> 设定为: ${targetVal} 档`);
                    this.safePublish(TOPIC_FAN, targetVal.toString());
                  }
                })
              Image($r('app.media.wind2')).height(20).width(20)
            }.alignItems(VerticalAlign.Center)
          }.width("100%").margin({ bottom: 4 })

          Column() {
            Row() {
              Text('微型潜水泵').fontSize(13).fontColor($r("sys.color.font_primary"))
              Blank()
              Text(this.waterPumpValue === 0 ? '关闭' : `${this.waterPumpValue} 档`)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r("sys.color.font_secondary"))
            }.width('100%')
            Row(){
              Image($r('app.media.water1')).height(20).width(20)
              Slider({ value: this.waterPumpValue, min: 0, max: 3, step: 1, style: SliderStyle.InSet })
                .height(28).layoutWeight(1)
                .onChange((val: number, mode: SliderChangeMode) => {
                  let targetVal = Math.floor(val);
                  this.waterPumpValue = targetVal;
                  if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                    this.printLog(LogType.INFO, `通过滑块调节潜水泵档位 -> 设定为: ${targetVal} 档`);
                    this.safePublish(TOPIC_WATER_PUMP, targetVal.toString());
                  }
                })
              Image($r('app.media.water2')).height(20).width(20)
            }.alignItems(VerticalAlign.Center)
          }.width("100%").margin({ bottom: 4 })

          Column() {
            Row() {
              Text('全光谱植物补光灯').fontSize(13).fontColor($r("sys.color.font_primary"))
              Blank()
              Text(this.ledValue === 0 ? '关闭' : `${this.ledValue} %`)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r("sys.color.font_secondary"))
            }.width('100%')
            Row(){
              Image($r('app.media.light1')).height(20).width(20)
              Slider({ value: this.ledValue, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
                .height(28).layoutWeight(1)
                .onChange((val: number, mode: SliderChangeMode) => {
                  let targetVal = Math.floor(val);
                  this.ledValue = targetVal;
                  if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                    this.printLog(LogType.INFO, `通过滑块调节植物灯亮度 -> 设定为: ${targetVal} %`);
                    this.safePublish(TOPIC_LED, targetVal.toString());
                  }
                })
              Image($r('app.media.light2')).height(20).width(20)
            }.alignItems(VerticalAlign.Center)
          }.width("100%").margin({ bottom: 4 })

        }
        .opacity(this.animStep2 ? 1 : 0)
        .translate({ y: this.animStep2 ? 0 : 20 })
        .width('100%')
        .padding(16)
        .backgroundColor($r("app.color.background"))
        .borderRadius(16)
      } else {
        Column({ space: 12 }) {
          LoadingProgress().width(80).height(80).color(Color.Black)
          Text('等待建立通信...').fontSize(18).fontColor(Color.Black).fontWeight(FontWeight.Bold).margin({ top: 20 })
        }
        .opacity(this.animStep1 ? 1 : 0)
        .translate({ y: this.animStep1 ? 0 : 20 })
        .margin({top: 50})
        .justifyContent(FlexAlign.Center)
      }
    }
    .backgroundColor($r("app.color.backcolor"))
    .ignoreLayoutSafeArea()
    .height("100%")
    .padding({ left: 16, right: 16, top: 75, bottom: 32 })
    .onVisibleAreaChange([0.0], (isVisible: boolean, currentRatio: number) => {
      this.handleManualPageVisibility(isVisible && currentRatio > 0);
    })
  }
}