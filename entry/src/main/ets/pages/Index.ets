// src/main/ets/pages/Index.ets
import { SensorData, ZoneData } from '../viewmodel/SmartShedBean';
// 【逻辑对齐】：修正导入的主题常量名，与 MqttReceiverClient.ts 完全一致
import { LogType, MqttReceiverClient } from '../service/MqttReceiverClient';
import { HdsTabs } from '@hms.hds.hdsBaseComponent';
import { promptAction } from '@kit.ArkUI';
import { BlurStrategy, hdsMaterial, HdsTabsController } from '@kit.UIDesignKit';
import { ManualPage } from '../view/ManualPage';
import { AutoPage } from '../view/AutoPage';
import { vibration } from '../service/vibration';
import { LogMessage } from '../viewmodel/ConsoleBean';

export class GlobalLogBus {
  private static onLogEmit: ((type: LogType, content: string) => void) | null = null;

  public static register(cb: (type: LogType, content: string) => void) {
    GlobalLogBus.onLogEmit = cb;
  }
  public static unregister() {
    GlobalLogBus.onLogEmit = null;
  }

  public static emit(type: LogType, content: string) {
    if (GlobalLogBus.onLogEmit) {
      GlobalLogBus.onLogEmit(type, content);
    }
  }
}

AppStorage.setOrCreate('isBoardRgbConnected', false);
AppStorage.setOrCreate('isBoardSoiConnected', false);
AppStorage.setOrCreate<LogMessage[]>('logList', []);
AppStorage.setOrCreate('autoEnabled', false);
AppStorage.setOrCreate('temp', 28);
AppStorage.setOrCreate('hum', 50);
AppStorage.setOrCreate('intensity', 134);
AppStorage.setOrCreate('moisture', 50);
AppStorage.setOrCreate('fanValue', 0);
AppStorage.setOrCreate('waterPumpValue', 0);
AppStorage.setOrCreate('ledValue', 0);
AppStorage.setOrCreate('zone1', new ZoneData());

@Entry
@Component
struct Index {
  private TabBarController: HdsTabsController = new HdsTabsController();
  @StorageLink("vibrationON") vibrationON: boolean = true;
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

  @StorageLink("lightIntensity") lightIntensity: number = 10;
  @State animStep1: boolean = false;
  @State animStep2: boolean = false;
  @State animStep3: boolean = false;
  @State logList: LogMessage[] = [];

  private mqttClient!: MqttReceiverClient;

  aboutToAppear(): void {
    GlobalLogBus.register((type: LogType, content: string) => {
      const now = new Date();
      const timeStr = `${now.getHours()}:${now.getMinutes()}:${now.getSeconds()}`;
      this.logList.push({ id: Date.now(), time: timeStr, type, content });
      if (this.logList.length > 100) this.logList.shift();
    });

    try {
      this.mqttClient = new MqttReceiverClient((topic: string, payload: string) => {
        this.onMqttMessage(topic, payload);
      });

      this.mqttClient.setLogCallback((type: LogType, content: string) => {
        GlobalLogBus.emit(type, content);
      });

      this.mqttClient.onStart();
    } catch (error) {
      console.error(`[App] 初始化失败: ${JSON.stringify(error)}`);
      this.isBoardRgbConnected = false;
      this.isBoardSoiConnected = false;
      promptAction.showToast({ message: '板端通讯组件初始化失败', duration: 3000 });
    }
  }

  aboutToDisappear(): void {
    this.zone1.isExit = true;
    GlobalLogBus.unregister();
    if (this.zone1.autoManagerThread !== null) {
      clearInterval(this.zone1.autoManagerThread);
      this.zone1.autoManagerThread = null;
    }
    if (this.mqttClient) {
      this.mqttClient.disconnect();
    }
  }

  private onMqttMessage(topic: string, payload: string): void {
    console.info(`[App] MQTT收到 -> Topic: ${topic}, Payload: ${payload}`);

    try {
      const data: SensorData = JSON.parse(payload);

      if (topic === 'Rayawa/rgb/light_intensity' && data.intensity !== undefined) {
        const val = Number(data.intensity);
        this.intensity = val;
        this.zone1.bean.intensity = val;
      }
      else if (topic === 'Rayawa/rgb/temp_and_hum') {
        if (data.temp !== undefined) {
          const tVal = Number(data.temp);
          this.temp = tVal;
          this.zone1.bean.temp = tVal;
        }
        if (data.hum !== undefined) {
          const hVal = Number(data.hum);
          this.hum = hVal;
          this.zone1.bean.hum = hVal;
        }
      }
      else if (topic === 'Rayawa/soi/soil_moisture' && data.moisture !== undefined) {
        const val = Number(data.moisture);
        this.moisture = val;
        this.zone1.bean.moisture = val;
      }
    } catch (e) {
      console.error(`[App] JSON解析失败: ${JSON.stringify(e)}`);
    }
  }

  @State currentTabIndex: number = 0;

  build() {
    Column(){
      HdsTabs({ controller: this.TabBarController }) {
        TabContent() {
          ManualPage({ mqttClient: this.mqttClient, isVisible: this.currentTabIndex === 0 })
        }
        .tabBar(new BottomTabBarStyle($r('sys.media.ohos_user_auth_icon_fingerprint'), "自定义模式"))

        TabContent() {
          AutoPage({ mqttClient: this.mqttClient, isVisible: this.currentTabIndex === 1 })
        }
        .tabBar(new BottomTabBarStyle($r('sys.media.wifi_router_fill'), "智能模式"))
      }
      .height("100%").width("100%")
      .ignoreLayoutSafeArea()
      .onChange((index: number) => {
        if(this.vibrationON) vibration.dotVibration();
        this.currentTabIndex = index;
      })
      .blurStrategy(BlurStrategy.ENABLE)
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .scrollable(false)
      .barFloatingStyle({
        barBottomMargin: 40,
        lightColor: Color.White,
        gradientMask: { maskColor: $r("app.color.backcolor"), maskHeight: 1 },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      })
    }.width("100%").height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}