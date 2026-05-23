import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { vibration } from '../service/vibration';
import { LogMessage, LogType } from '../viewmodel/ConsoleBean.ts';

@Component
export struct consolePage {
  onCloseSplit?: () => void;
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @Consume('pageStack') pageStack: NavPathStack;
  @Link logList: LogMessage[];
  private scroller: Scroller = new Scroller();

  // 添加日志的方法
  public addLog(type: LogType, content: string) {
    const now = new Date();
    const timeStr = `${now.getHours()}:${now.getMinutes()}:${now.getSeconds()}`;
    this.logList.push({
      id: Date.now(),
      time: timeStr,
      type,
      content
    });

    // 自动滚到底部
    this.scroller.scrollEdge(Edge.Bottom);
  }
  private getTypeColor(type: LogType): Color | string {
    switch (type) {
      case LogType.SEND: return '#F39C12';    // 橙色
      case LogType.RECEIVE: return '#27AE60'; // 绿色
      case LogType.ERROR: return '#E74C3C';   // 红色
      default: return Color.Black;
    }
  }

  onPageShow() {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  build() {
    HdsNavDestination() {
      Column() {
        List({ scroller: this.scroller }) { // 绑定 scroller
          ForEach(this.logList, (item: LogMessage) => {
            ListItem() {
              Row({ space: 5 }) {
                Text(`[${item.time}]`).fontSize(10).fontColor(Color.Gray)
                Text(item.type === LogType.SEND ? "OUT" : "IN")
                  .fontColor(this.getTypeColor(item.type))
                  .fontWeight(FontWeight.Bold)
                Text(item.content).fontColor(Color.White).fontSize(12).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding(10)
        .backgroundColor('#1A000000')
        .borderRadius(8)
      }
      .padding(10)
    }
    .onBackPressed(() => {
      if(this.vibrationON) vibration.dotVibration()
      if (this.onCloseSplit) {
        this.onCloseSplit();
        return true;
      }
      this.pageStack.pop();
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
          backgroundStyle: {
            backgroundColor: $r("sys.color.ohos_id_color_background"),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r("sys.color.font_primary"),
              subTitleColor: $r("sys.color.font_secondary"),
            },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r("sys.color.ohos_id_color_background_transparent"),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r("sys.color.font_primary"),
              subTitleColor: $r("sys.color.font_secondary"),
            },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
          },
        },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      content: {
        title: {
          mainTitle: "终端",
        },
        menu: {
          value: [
            {
              content: {
                label: "clear",
                icon: $r("sys.symbol.clock"),
                isEnabled: true,
                action: () => {
                  if(this.vibrationON) vibration.dotVibration()
                  this.logList = [];
                },
              },
            },
          ],
        },
        backIcon: {
          action: () => {
            if(this.vibrationON) vibration.dotVibration()
            if (this.onCloseSplit) {
              this.onCloseSplit();
            }
            this.pageStack.pop();
          },
        },
      },
    });
  }
}

@Builder
export function ConsolePageBuilder(){
  consolePage()
}