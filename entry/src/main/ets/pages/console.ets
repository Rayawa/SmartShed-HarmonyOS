import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { vibration } from '../service/vibration';
import { LogMessage, LogType } from '../viewmodel/ConsoleBean';

@Component
export struct consolePage {
  onCloseSplit?: () => void;
  private scroller: Scroller = new Scroller();
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @Consume('pageStack') pageStack: NavPathStack;

  @State @Watch('onLogListChange') logList: LogMessage[] = [];
  private isAtBottom: boolean = true;
  onLogListChange() {
    if (this.isAtBottom) {
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 50);
    }
  }
  private getTypeColor(type: LogType): Color | string {
    switch (type) {
      case LogType.SEND:
        return '#007DFF';
      case LogType.RECEIVE:
        return '#30BF17';
      case LogType.INFO:
        return '#999999';
      case LogType.ERROR:
        return '#F5222D';
      default:
        return '#333333';
    }
  }

  private getTypeLabel(type: LogType): string {
    switch (type) {
      case LogType.SEND:
        return "SENT";
      case LogType.RECEIVE:
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

  onPageShow() {
    this.scroller.scrollEdge(Edge.Bottom);
    console.info("进入console页面")
  }

  build() {
    HdsNavDestination() {
      Column() {
        Blank().height(100)
        List({ scroller: this.scroller }) {
          ForEach(this.logList, (item: LogMessage) => {
            ListItem() {
              Row({ space: 5 }) {
                Text(`[${this.getTime(item.time)}]`)
                  .fontSize(10)
                  .fontColor(Color.Gray)
                  .flexShrink(0)

                Text(`[${this.getTypeLabel(item.type)}]`)
                  .fontColor(this.getTypeColor(item.type))
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .flexShrink(0)

                Text(item.content)
                  .fontColor(this.getTypeColor(item.type))
                  .fontSize(12)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .borderRadius(16)
          })
        }
        .onScrollIndex((end: number) => {
          if (end >= this.logList.length - 1) {
            this.isAtBottom = true;
          } else {
            this.isAtBottom = false;
          }
        })
        .width('90%')
        .padding(10)
        .margin({ bottom: 20 })
        .layoutWeight(1)
        .borderWidth(0.5)
        .borderColor($r("app.color.border"))
        .backgroundColor($r("app.color.background"))
        .borderRadius(16)
        .shadow({
          radius: 8,
          color: "#1a000000",
          offsetX: 0,
          offsetY: 2,
        })
      }
      .backgroundColor($r("app.color.background"))
    }
    .backgroundColor($r("app.color.background"))
    .onBackPressed(() => {
      if (this.vibrationON) vibration.dotVibration();
      if (this.onCloseSplit) {
        this.onCloseSplit();
      }
      return false;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r("sys.color.ohos_id_color_background") },
          contentStyle: {
            titleStyle: { mainTitleColor: $r("sys.color.font_primary"), subTitleColor: $r("sys.color.font_secondary") },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r("sys.color.ohos_id_color_background_transparent") },
          contentStyle: {
            titleStyle: { mainTitleColor: $r("sys.color.font_primary"), subTitleColor: $r("sys.color.font_secondary") },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
          },
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      content: {
        title: { mainTitle: "终端" },
        backIcon: {
          action: () => {
            if (this.vibrationON) vibration.dotVibration()
            if (this.onCloseSplit) {
              this.onCloseSplit();
              console.info("堆叠关闭")
            }
            this.pageStack.pop();
          },
        },
      },
    });
  }
}

@Builder
export function ConsolePageBuilder() {
  consolePage()
}