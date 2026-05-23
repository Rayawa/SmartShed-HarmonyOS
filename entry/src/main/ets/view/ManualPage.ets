// components/ManualPage.ets
import { ZoneData } from '../viewmodel/SmartShedBean';
import {
  MqttReceiverClient, TOPIC_FAN, TOPIC_LED, TOPIC_WATER_PUMP
} from '../service/MqttReceiverClient';
import { curves, promptAction } from '@kit.ArkUI';

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

  aboutToAppear(): void {
    const duration = 500;
    const interval = duration * 0.25;
    const curve = curves.springMotion(0.35, 0.75);

    setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep1 = true }) }, 100);
    setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep2 = true }) }, interval + 100);
    setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep3 = true }) }, interval * 2 + 100);
  }

  private safePublish(topic: string, value: string) {
    try {
      if (this.mqttClient) {
        this.mqttClient.publish(topic, value);
        console.info(`[App] 指令成功下发 -> Topic: ${topic}, Val: ${value}`);
      } else {
        throw new Error("MQTT未初始化");
      }
    } catch (error) {
      console.error(`[App] 下发失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '指令下发失败，请检查网络', duration: 2000 });
      this.isBoardConnected = false;
    }
  }

  private stopAutoLogic(): void {
    this.zone1.isExit = true;
    if (this.zone1.autoManagerThread !== null) {
      clearInterval(this.zone1.autoManagerThread);
      this.zone1.autoManagerThread = null;
    }
  }

  private handleManualPageVisibility(isVisible: boolean): void {
    if (!isVisible) {
      return;
    }
    this.autoEnabled = false;
    this.stopAutoLogic();
  }

  build() {
    Column({ space: 16 }) {
      Blank().height(80)

      // 连接状态横幅
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

        // 传感器状态数据卡片区
        Grid() {
          GridItem() { this.sensorCard('空气温度', `${this.temp} ℃`, '#FF7D00', 'sys.media.ohos_ic_public_brightness') }
          GridItem() { this.sensorCard('空气湿度', `${this.hum} %`, '#007DFF', 'sys.media.ohos_ic_public_weather') }
          GridItem() { this.sensorCard('光照强度', `${this.intensity} Lx`, '#FFBF00', 'sys.media.ohos_ic_public_sun') }
          GridItem() { this.sensorCard('土壤湿度', `${this.moisture} %`, '#34C759', 'sys.media.ohos_ic_public_add_filled') }
        }
        .opacity(this.animStep1 ? 1 : 0)
        .translate({ y: this.animStep1 ? 0 : 20 })
        .columnsTemplate('1fr 1fr')
        .rowsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
        .height(160)

        // 硬件控制器面板
        Column({ space: 14 }) {
          Text('手动控制')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .fontColor($r("sys.color.font_primary"))
            .margin({ bottom: 4 })

          // 联动风扇滑块
          this.customSlider('风扇主轴转速', this.fanValue, 0, 3, $r('app.media.wind1'), $r("app.media.wind2"),
            (val) => {
              this.fanValue = val;
            },
            (val) => {
              this.fanValue = val;
              this.safePublish(TOPIC_FAN, val.toString());
            })

          // 联动潜水泵滑块
          this.customSlider('微型潜水泵', this.waterPumpValue, 0, 3, $r('app.media.water1'), $r("app.media.water2"),
            (val) => {
              this.waterPumpValue = val;
            },
            (val) => {
              this.waterPumpValue = val;
              this.safePublish(TOPIC_WATER_PUMP, val.toString());
            })

          // 联动补光灯滑块
          this.customSlider('全光谱植物补光灯', this.ledValue, 0, 100, $r('app.media.light1'), $r("app.media.light2"),
            (val) => {
              this.ledValue = val;
            },
            (val) => {
              this.ledValue = val;
              this.safePublish(TOPIC_LED, val.toString());
            })
        }
        .opacity(this.animStep2 ? 1 : 0)
        .translate({ y: this.animStep2 ? 0 : 20 })
        .width('100%')
        .padding(16)
        .backgroundColor($r("app.color.background"))
        .borderRadius(16)
      } else {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(80)
            .height(80)
            .color(Color.Black)

          Text('等待建立通信...')
            .fontSize(18)
            .fontColor(Color.Black)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 20 })
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

  @Builder
  sensorCard(label: string, value: string, color: string, icon: string) {
    Column() {
      Row() {
        Circle({ width: 6, height: 6 }).fill(color)
        Text(label)
          .fontSize(12)
          .fontColor($r("sys.color.font_secondary"))
          .margin({ left: 6 })
      }.width('100%')

      Blank()

      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r("sys.color.font_primary"))
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor($r("app.color.background"))
    .borderRadius(12)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
  }

  @Builder
  customSlider(label: string, value: number, min: number, max: number, icon1: Resource, icon2: Resource,
    onPreview: (v: number) => void, onCommit: (v: number) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor($r("sys.color.font_primary"))
        Blank()
        Text(value === 0 ? '关闭' : `${value} 档`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r("sys.color.font_secondary"))
      }.width('100%')
      Row(){
        Image(icon1).height(20).width(20)
        Slider({ value: value, min: min, max: max, step: 1, style: SliderStyle.InSet })
          .height(28)
          .layoutWeight(1)
          .onChange((val: number, mode: SliderChangeMode) => {
            let targetVal = Math.floor(val);
            onPreview(targetVal);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              onCommit(targetVal);
            }
          })
        Image(icon2).height(20).width(20)
      }.alignItems(VerticalAlign.Center)


    }
    .width("100%")
    .margin({ bottom: 4 })
  }
}
