import { ZoneData } from '../viewmodel/SmartShedBean';
import {
  MqttReceiverClient, TOPIC_FAN, TOPIC_LED, TOPIC_WATER_PUMP
} from '../service/MqttReceiverClient';
import { curves, promptAction } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';

@Component
export struct AutoPage {
  @State ShaderEffectController: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
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


  /**
   * 智能闭环控制策略线程
   */
  private startAutoLogic(): void {
    this.stopAutoLogic();
    this.zone1.isExit = false;

    const handler = setInterval(() => {
      // 如果触发退出标志，及时销毁定时器
      if (this.zone1.isExit) {
        clearInterval(handler);
        return;
      }

      // 如果当前并未处于智能接管状态，直接跳过计算
      if (!this.autoEnabled) {
        return;
      }

      try {
        const tempMax = parseInt(this.zone1.autoTempMax) || 30;
        const humMax = parseInt(this.zone1.autoHumMax) || 80;
        const moistureMin = parseInt(this.zone1.autoMoistureMin) || 40;
        const moistureMax = parseInt(this.zone1.autoMoistureMax) || 75;
        const intensityMin = parseInt(this.zone1.autoIntensityMin) || 200;

        // --- 1. 风扇控制阶梯算法 ---
        let targetFan = 0;
        if (this.temp > tempMax + 10 || this.hum > humMax + 20 || this.moisture > moistureMax + 20) {
          targetFan = 3;
        } else if (this.temp > tempMax + 5 || this.hum > humMax + 10 || this.moisture > moistureMax + 10) {
          targetFan = 2;
        } else if (this.temp > tempMax || this.hum > humMax || this.moisture > moistureMax) {
          targetFan = 1;
        }

        if (this.fanValue !== targetFan) {
          this.fanValue = targetFan;
          this.safePublish(TOPIC_FAN, targetFan.toString());
        }

        // --- 2. 水泵控制阶梯算法 ---
        let targetPump = 0;
        if (this.moisture < moistureMin - 20) {
          targetPump = 3;
        } else if (this.moisture < moistureMin - 10) {
          targetPump = 2;
        } else if (this.moisture < moistureMin) {
          targetPump = 1;
        }

        if (this.waterPumpValue !== targetPump) {
          this.waterPumpValue = targetPump;
          this.safePublish(TOPIC_WATER_PUMP, targetPump.toString());
        }

        // --- 3. 植物补光灯自适应控制算法 ---
        let targetLed = 0;
        if (this.intensity < intensityMin) {
          let level = Math.floor((2000 - this.ledValue) / 20);
          targetLed = level > 100 ? 100 : level;
        }

        if (this.ledValue !== targetLed) {
          this.ledValue = targetLed;
          this.safePublish(TOPIC_LED, targetLed.toString());
        }

      } catch (err) {
        console.error(`[AutoLogic] 策略计算异常: ${JSON.stringify(err)}`);
      }
    }, 2000);

    this.zone1.autoManagerThread = handler;
  }

  private stopAutoLogic(): void {
    this.zone1.isExit = true;
    if (this.zone1.autoManagerThread !== null) {
      clearInterval(this.zone1.autoManagerThread);
      this.zone1.autoManagerThread = null;
    }
  }

  private handleAutoPageVisibility(isVisible: boolean): void {
    if (isVisible) {
      this.autoEnabled = true;
      this.startAutoLogic();
      return;
    }

    this.autoEnabled = false;
    this.stopAutoLogic();
  }

  private safePublish(topic: string, value: string) {
    try {
      if (this.mqttClient) {
        this.mqttClient.publish(topic, value);
        console.info(`[AutoLogic] 自动调控下发成功 -> ${topic} : ${value}`);
      } else {
        throw new Error("MQTT未初始化");
      }
    } catch (error) {
      console.error(`[App] 自动下发失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '指令自动下发失败，请检查网络', duration: 2000 });
      this.isBoardConnected = false;
    }
  }

  build() {
    Column({ space: 16 }) {
      Blank().height(80)

      // 状态横幅
      Row() {
        Circle({ width: 8, height: 8 })
          .fill(this.isBoardConnected ? '#41BA41' : '#FF3B30')
          .margin({ right: 6 })
        Text(this.isBoardConnected ? '已连接至Rayawa/Hi3861' : '与开发板连接已断开，请检查网络')
          .fontSize(14)
          .fontColor(this.isBoardConnected ? '#1E661E' : '#A52A2A')
      }
      .opacity(this.animStep1 ? 1 : 0)
      .translate({ y: this.animStep1 ? 0 : 20 })
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.isBoardConnected ? '#E8F5E9' : '#FFEBEE')
      .borderRadius(8)

      if(this.isBoardConnected){
        // 实时传感器数据卡片区
        Grid() {
          GridItem() { this.sensorCard('空气温度', `${this.temp} ℃`, '#FF7D00', 'sys.media.ohos_ic_public_brightness') }
          GridItem() { this.sensorCard('空气湿度', `${this.hum} %`, '#007DFF', 'sys.media.ohos_ic_public_weather') }
          GridItem() { this.sensorCard('光照强度', `${this.intensity} Lx`, '#FFBF00', 'sys.media.ohos_ic_public_sun') }
          GridItem() { this.sensorCard('土壤湿度', `${this.moisture} %`, '#34C759', 'sys.media.ohos_ic_public_add_filled') }
        }
        .columnsTemplate('1fr 1fr')
        .rowsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
        .height(160)
        .opacity(this.animStep2 ? 1 : 0)
        .translate({ y: this.animStep2 ? 0 : 20 })

        // 自动策略控制面板
        Column({ space: 12 }) {
          Text('智能模式设置')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .fontColor($r("sys.color.font_primary"))
            .margin({ bottom: 4 })

          Column({ space: 10 }) {
            Row({ space: 10 }) {
              this.inputField('温度上限', this.zone1.autoTempMax, (v) => { this.zone1.autoTempMax = v })
              this.inputField('空湿上限', this.zone1.autoHumMax, (v) => { this.zone1.autoHumMax = v })
            }.width('100%')

            Row({ space: 10 }) {
              this.inputField('土湿下限', this.zone1.autoMoistureMin, (v) => { this.zone1.autoMoistureMin = v })
              this.inputField('土湿上限', this.zone1.autoMoistureMax, (v) => { this.zone1.autoMoistureMax = v })
            }.width('100%')

            Row({ space: 10 }) {
              this.inputField('光照下限', this.zone1.autoIntensityMin, (v) => { this.zone1.autoIntensityMin = v })
              this.inputField('光照上限', this.zone1.autoIntensityMax, (v) => { this.zone1.autoIntensityMax = v })
            }.width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r("sys.color.ohos_id_color_button_normal"))
        .borderRadius(16)
        .opacity(this.animStep3 ? 1 : 0)
        .translate({ y: this.animStep3 ? 0 : 20 })

      } else {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(80)
            .height(80)
            .color(Color.Black)

          Text('等待建立通信...')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.Black)
            .margin({ top: 20 })
        }
        .opacity(this.animStep1 ? 1 : 0)
        .translate({ y: this.animStep1 ? 0 : 20 })
        .margin({top: 50})
        .justifyContent(FlexAlign.Center)
      }

    }
    .ignoreLayoutSafeArea()
    .height("100%")
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .shaderEffect({
        effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
        animation: { duration: 2500, iterations: -1, autoPlay: true },
        controller: this.ShaderEffectController,
      })
      .buildEffect())
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT])
    .padding({ left: 16, right: 16, top: 75, bottom: 32 })
    .onVisibleAreaChange([0.0], (isVisible: boolean, currentRatio: number) => {
      this.handleAutoPageVisibility(isVisible && currentRatio > 0);
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
    .backgroundColor($r("sys.color.ohos_id_color_button_normal"))
    .borderRadius(12)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
  }

  @Builder
  inputField(label: string, value: string, onStrChange: (s: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .width(60)
        .fontColor($r("sys.color.font_secondary"))
        .margin({ right: 5})
      TextInput({ text: value })
        .fontSize(10)
        .height(25)
        .width(60)
        .padding({ left: 8, right: 8 })
        .backgroundColor($r("app.color.diff_background"))
        .borderRadius(6)
        .type(InputType.Number)
        .onChange((val: string) => {
          onStrChange(val);
        })
    }
    .layoutWeight(1)
  }
}
