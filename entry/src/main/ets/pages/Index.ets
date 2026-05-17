// index.ets
import { SensorData, ZoneData } from '../viewmodel/SmartShedBean';
import { MqttReceiverClient } from '../service/MqttReceiverClient';
import { HdsNavigation, HdsTabs, ScrollEffectType } from '@hms.hds.hdsBaseComponent';
import { curves, LengthMetrics, promptAction } from '@kit.ArkUI';
import { BlurStrategy, hdsMaterial, HdsNavigationTitleMode, HdsTabsController } from '@kit.UIDesignKit';
import { ManualPage } from '../view/ManualPage';
import { AutoPage } from '../view/AutoPage';

@Entry
@Component
struct Index {
  private TabBarController: HdsTabsController = new HdsTabsController();

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
  @State animStep1: boolean = false;
  @State animStep2: boolean = false;
  @State animStep3: boolean = false;


  private mqttClient!: MqttReceiverClient;

  aboutToAppear(): void {
    AppStorage.setOrCreate('isBoardConnected', false);
    AppStorage.setOrCreate('autoEnabled', false);
    AppStorage.setOrCreate('temp', 28);
    AppStorage.setOrCreate('hum', 50);
    AppStorage.setOrCreate('intensity', 134);
    AppStorage.setOrCreate('moisture', 50);
    AppStorage.setOrCreate('fanValue', 0);
    AppStorage.setOrCreate('waterPumpValue', 0);
    AppStorage.setOrCreate('ledValue', 0);
    AppStorage.setOrCreate('zone1', new ZoneData());
    try {
      this.mqttClient = new MqttReceiverClient((topic: string, payload: string) => {
        this.onMqttMessage(topic, payload);
      });
      this.isBoardConnected = true;

      this.mqttClient.onStart();
    } catch (error) {
      console.error(`[App] 初始化失败: ${JSON.stringify(error)}`);
      this.isBoardConnected = true;
      promptAction.showToast({ message: '板端通讯组件初始化失败', duration: 3000 });
    }
  }

  aboutToDisappear(): void {
    this.zone1.isExit = true;
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
    if (!this.isBoardConnected) {
      this.isBoardConnected = true;
    }
    try {
      const data: SensorData = JSON.parse(payload);
      this.isBoardConnected = true;

      if (topic === 'Rayawa/light_intensity_1' && data.intensity !== undefined) {
        this.intensity = data.intensity;
        this.zone1.bean.intensity = data.intensity;
      } else if (topic === 'Rayawa/soil_moisture_1' && data.moisture !== undefined) {
        this.moisture = data.moisture;
        this.zone1.bean.moisture = data.moisture;
      } else if (topic === 'Rayawa/temp_and_hum_1') {
        if (data.temp !== undefined) {
          this.temp = data.temp;
          this.zone1.bean.temp = data.temp;
        }
        if (data.hum !== undefined) {
          this.hum = data.hum;
          this.zone1.bean.hum = data.hum;
        }
      }
    } catch (e) {
      console.error(`[App] JSON解析失败: ${JSON.stringify(e)}`);
    }
  }

  build() {
    HdsNavigation() {
      HdsTabs({ controller: this.TabBarController }) {
        TabContent() {
          ManualPage({ mqttClient: this.mqttClient })
        }
        .tabBar(new BottomTabBarStyle($r('sys.media.wifi_router_fill'), "自定义模式"))

        TabContent() {
          AutoPage({ mqttClient: this.mqttClient })
        }
        .tabBar(new BottomTabBarStyle($r('sys.media.wifi_router_fill'), "智能模式"))
      }
      .scrollable(false)
      .blurStrategy(BlurStrategy.ENABLE)
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .barFloatingStyle({
        barBottomMargin: 30,
        lightColor: $r('app.color.light_color'),
        gradientMask: { maskColor: $r('app.color.light_color'), maskHeight: 92 },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      })
    }
    .ignoreLayoutSafeArea()
    .height("100%")
    .titleMode(HdsNavigationTitleMode.FULL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r("sys.color.ohos_id_color_background") },
          contentStyle: {
            titleStyle: { mainTitleColor: $r("sys.color.font_primary") },
          },
        },
      },
      content: { title: { mainTitle: "智慧大棚控制终端" } },
    });
  }
}