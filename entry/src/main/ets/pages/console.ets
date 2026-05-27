// src/main/ets/pages/console.ets
import { hdsEffect } from '@kit.UIDesignKit';
import { vibration } from '../service/vibration';
import { LogMessage, LogType } from '../viewmodel/ConsoleBean';
import { HdsButton } from '../viewmodel/HdsButton';
import { GlobalLogBus } from './Index';

class LogDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private list: LogMessage[] = [];

  constructor(list: LogMessage[]) {
    this.list = list;
  }

  public reload(newList: LogMessage[]): void {
    this.list = newList;
    this.notifyDataReload();
  }

  totalCount(): number {
    return this.list.length;
  }

  getData(index: number): LogMessage {
    return this.list[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }
}

@Entry
@Component
struct consolePage {
  private scroller: Scroller = new Scroller();
  @StorageLink("transparentColor") transparentColor: ResourceColor = $r("sys.color.ohos_toggle_bg_transparent")
  @StorageLink("transparentBorderColor") transparentBorderColor: ResourceColor = $r("sys.color.toast_border_color")
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @State controller: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();

  // ==================== 1. 核心改进：直接联动全局状态池 ====================
  // 避开 GlobalLogBus 重复注册导致的逻辑覆盖问题
  @StorageLink('logList') @Watch('onLogListChange') logList: LogMessage[] = [];
  private logDataSource: LogDataSource = new LogDataSource([]);

  @StorageLink('autoEnabled') autoEnabled: boolean = false;
  private isAtBottom: boolean = true;

  onLogListChange() {
    this.logDataSource.reload(this.logList);
    if (this.isAtBottom) {
      this.scrollToBottom();
    }
  }

  private scrollToBottom() {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 16);
  }

  private getTypeColor(type: LogType): Color | string {
    switch (type) {
      case LogType.SEND:
        return this.autoEnabled ? "#ff0055ff" : '#007DFF';
      case LogType.RECEIVE:
        return this.autoEnabled ? "#ff12660c" : '#ff22bf17';
      case LogType.INFO:
        return this.autoEnabled ? "#666666" : '#999999';
      case LogType.ERROR:
        return '#F5222D';
      default:
        return this.autoEnabled ? "#111111" : '#333333';
    }
  }

  // ==================== 2. 核心改进：动态提取硬件板端特征 ====================
  private getTypeLabel(item: LogMessage): string {
    const contentLower = item.content.toLowerCase();

    switch (item.type) {
      case LogType.SEND:
        // 分析发送的数据是流向哪块板的控制参数
        if (contentLower.includes('led') || contentLower.includes('light')) {
          return "SEND-RGB";
        } else if (contentLower.includes('fan') || contentLower.includes('pump') || contentLower.includes('water')) {
          return "SEND-SOI";
        }
        return "SENT";

      case LogType.RECEIVE:
        // 分析接收到的主题属于环境板还是土壤控制板
        if (contentLower.includes('rgb') || contentLower.includes('intensity') || contentLower.includes('temp')) {
          return "RECV-RGB";
        } else if (contentLower.includes('soi') || contentLower.includes('moisture')) {
          return "RECV-SOI";
        }
        return "RECV";

      case LogType.INFO:
        return "INFO";
      case LogType.ERROR:
        return "ERR";
      default:
        return "LOG";
    }
  }

  private getTime(timeStr: string): string {
    return timeStr.split(':').map(num => num.padStart(2, '0')).join(':');
  }

  aboutToAppear(): void {
    // 移除原有的 GlobalLogBus.register(...)，让 Index 唯一的守护进程在后台跑
    this.logDataSource.reload(this.logList);
    this.scrollToBottom();
  }

  onPageShow() {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  onBackPress(): boolean | void {
    if(this.vibrationON) vibration.dotVibration()
    this.getUIContext().getRouter().back();
    return true;
  }

  build() {
    Stack() {
      Column()
        .visibility(this.autoEnabled ? Visibility.Visible : Visibility.None)
        .width("100%").height("100%")
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .shaderEffect({
            effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
            animation: {
              duration: 10000,
              iterations: -1,
              autoPlay: true,
            },
            controller: this.controller
          })
          .buildEffect())

      Column() {
        Blank().height(40)
        Row(){
          HdsButton({
            barWidth: 45,
            barHeight: 57,
            enableClickScale: true,
            enablePointLight: true,
            enableDrag: true,
            iconResource: $r("sys.symbol.chevron_backward"),
            onButtonClick: () => {
              if(this.vibrationON) vibration.dotVibration()
              this.getUIContext().getRouter().back();
            }
          })

          Text("日志")
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .fontSize(22)
            .layoutWeight(1)
            .margin({ left: 10 })
        }
        .zIndex(99)
        .width("100%")
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })

        List({ scroller: this.scroller }) {
          LazyForEach(this.logDataSource, (item: LogMessage) => {
            ListItem() {
              Row({ space: 6 }) {
                Text(`[${this.getTime(item.time)}]`)
                  .fontSize(10)
                  .fontColor(this.autoEnabled ? "#999999" : "#666666")
                  .flexShrink(0)

                // ==================== 3. 应用拆分后的新标签 ====================
                Text(`[${this.getTypeLabel(item)}]`)
                  .fontColor(this.getTypeColor(item.type))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .flexShrink(0)

                Text(item.content)
                  .fontColor(this.getTypeColor(item.type))
                  .fontSize(12)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
                illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
              }).buildEffect())
              .width("100%")
              .align(Alignment.Start)
            }
            .borderRadius(16)
          }, (item: LogMessage) => item.id.toString())
        }
        .onReachEnd(() => { this.isAtBottom = true; })
        .onScrollFrameBegin((offset: number, state: ScrollState) => {
          if (offset < 0) { this.isAtBottom = false; }
          return { offsetRemain: offset };
        })
        .onScrollIndex((end: number) => {
          if (end >= this.logList.length - 4) { this.isAtBottom = true; }
          else { this.isAtBottom = false; }
        })
        .clip(true)
        .width('92%')
        .padding({ left: 8, right: 8, top: 10, bottom: 10 })
        .margin({ bottom: 20 })
        .layoutWeight(1)
        .borderWidth(0.5)
        .borderColor(this.transparentBorderColor)
        .backgroundColor(this.autoEnabled ? this.transparentColor : $r("app.color.background"))
        .borderRadius(16)
        .shadow({ radius: 8, color: "#1a000000", offsetX: 0, offsetY: 2 })

      }
      .width("100%").height("100%")
    }
    .width("100%")
    .height("100%")
    .backgroundColor($r("app.color.backcolor"))
    .ignoreLayoutSafeArea()
  }
}