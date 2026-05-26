import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';

@Component
export struct HdsButton {
  @Prop barWidth: number = 50;
  @Prop barHeight: number = 50;
  @Prop contentPadding: number = 8;
  @Prop containerSize: SizeOptions | undefined = undefined;

  @Prop iconResource: Resource | undefined = undefined;
  @Prop iconSize: number = 24;
  @Prop iconColor: ResourceColor[] = [Color.Gray];

  @Prop maskColor: ResourceColor = Color.Transparent
  @Prop barBottomMargin: number = 0;
  @Prop barPosition: BarPosition = BarPosition.End;
  @Prop barOverlap: boolean = true;
  @StorageLink('activeThemeId') activeThemeId: string = 'default';
  @Prop justifyContent: FlexAlign = FlexAlign.Center;

  @Prop enableDrag: boolean = false;
  @Prop enableClickScale: boolean = false;
  @Prop enablePointLight: boolean = false;

  @StorageLink('isHdsTabsEnabled') isHdsTabsEnabled: boolean = true;
  @StorageLink('currentColorMode') currentColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

  @State isLight: boolean = false;
  @State isTouched: boolean = false;
  @State offsetX: number = 0;
  @State offsetY: number = 0;

  @State thisWidth: number = 0;
  @State thisHeight: number = 0;

  public onButtonClick: (() => void) | undefined = undefined;

  @Builder
  defaultButtonBuilder() {
    if (this.iconResource) {
      SymbolGlyph(this.iconResource)
        .fontSize(this.iconSize)
        .fontColor(this.iconColor)
    }
  }

  @BuilderParam buttonContent: () => void = this.defaultButtonBuilder;
  @StorageLink('materialLevel') materialLevel: number = 10;
  @StorageLink('materialType') materialType: number = 100;
  private TabsController: HdsTabsController = new HdsTabsController();

  build() {
    Stack() {
      Stack() {
        if (this.isHdsTabsEnabled && deviceInfo.distributionOSApiVersion >= 60100) {
          HdsTabs({
            barPosition: BarPosition.End
          }) {
          }
          .clip(false)
          .align(Alignment.Center)
          .height(this.thisHeight > 0 ? this.thisHeight : this.barHeight - 12)
          .barWidth(this.thisWidth > 0 ? this.thisWidth : this.barWidth)
          .barHeight(this.thisHeight > 0 ? this.thisHeight : this.barHeight - 12)
          .barOverlap(this.barOverlap)
          .barPosition(this.barPosition)
          .backgroundColor(Color.Transparent)
          .shadow(undefined)
          .vertical(false)
          .monopolizeEvents(false)
          .barFloatingStyle({
            barWidth: {
              smallWidth: this.thisWidth > 0 ? this.thisWidth : this.barWidth,
              mediumWidth: this.thisWidth > 0 ? this.thisWidth : this.barWidth,
              largeWidth: this.thisWidth > 0 ? this.thisWidth : this.barWidth
            },
            lightColor: Color.White,
            gradientMask: {
              maskColor: Color.Transparent,
            },
            barBottomMargin: 0,
            systemMaterialEffect: {
              materialType: this.materialType,
              materialLevel: this.materialLevel
            },
            barSideMargin: 0,
          })
        } else {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ?
              'rgba(0,0,0,0.05)' : 'rgba(255,255,255,0.1)')
        }
      }
      .width(this.barWidth)
      .height(this.barHeight - 12)
      .borderRadius((this.barHeight < this.barWidth) ? (this.barHeight - 12) / 2 : this.barWidth / 2)
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
      .onAreaChange((_: Area, newValue: Area) => {
        this.thisWidth = new Number(newValue.width).valueOf();
        this.thisHeight = new Number(newValue.height).valueOf();
      })

      Stack({ alignContent: Alignment.Center }) {
        this.buttonContent()
      }
      .width(this.barWidth)
      .height(this.barHeight - 12)
      .hitTestBehavior(HitTestMode.Transparent)
      .onClick(() => {
        if (this.onButtonClick) {
          this.onButtonClick();
        }
      })

      if (this.enableDrag || this.enableClickScale || this.enablePointLight) {
        Stack()
          .width(this.barWidth)
          .height(this.barHeight - 12)
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.Transparent)
          .monopolizeEvents(false)
          .onTouch((event: TouchEvent) => {
            animateTo({
              curve: curves.responsiveSpringMotion(0.4, 0.5),
            }, () => {
              if (event.type === TouchType.Down) {
                if (this.enablePointLight) this.isLight = true;
                if (this.enableClickScale) this.isTouched = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.isLight = false;
                this.isTouched = false;
                if (!this.enableDrag) {
                  this.offsetX = 0;
                  this.offsetY = 0;
                }
              }
            })
          })
          .gesture(
            PanGesture({ direction: this.enableDrag ? PanDirection.All : PanDirection.None })
              .onActionStart(() => {
                animateTo({ curve: curves.responsiveSpringMotion(0.4) }, () => {
                  this.offsetX = 0;
                  this.offsetY = 0;
                })
              })
              .onActionUpdate((event: GestureEvent) => {
                if (!this.enableDrag) return;
                animateTo({ curve: curves.responsiveSpringMotion(0.4) }, () => {
                  this.offsetX = event.offsetX;
                  this.offsetY = event.offsetY;
                })
              })
              .onActionEnd(() => {
                if (!this.enableDrag) return;
                animateTo({ curve: curves.responsiveSpringMotion(0.4, 0.5) }, () => {
                  this.offsetX = 0;
                  this.offsetY = 0;
                })
              })
              .onActionCancel(() => {
                animateTo({ curve: curves.responsiveSpringMotion(0.4, 0.5) }, () => {
                  this.offsetX = 0;
                  this.offsetY = 0;
                })
              })
          )
      }
    }
    .width(this.barWidth)
    .height(this.barHeight - 12)
    .borderRadius((this.barHeight < this.barWidth) ? (this.barHeight - 12) / 2 : this.barWidth / 2)
    .clip(false)
    .offset({
      x: this.enableDrag ? this.offsetX / 30 : 0,
      y: this.enableDrag ? this.offsetY / 30 : 0
    })
    .scale({
      x: (this.enableClickScale && this.isTouched ? 1.05 : 1) *
         (this.enableDrag ? (1 + Math.abs(this.offsetX / 1200)) / (1 + Math.abs(this.offsetY / 1200)) : 1),
      y: (this.enableClickScale && this.isTouched ? 1.05 : 1) *
         (this.enableDrag ? (1 + Math.abs(this.offsetY / 1200)) / (1 + Math.abs(this.offsetX / 1200)) : 1),
    })
    .shadow(this.isHdsTabsEnabled ?ShadowStyle.OUTER_FLOATING_SM:undefined)
    .visualEffect(this.enablePointLight ? (this.isHdsTabsEnabled ?
      new hdsEffect.HdsEffectBuilder()
        .pointLight({
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
        })
        .buildEffect() :
      new hdsEffect.HdsEffectBuilder()
        .pointLight({
          illuminatedType: this.isLight ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
          sourceType: this.isLight ? hdsEffect.PointLightSourceType.SOFT : hdsEffect.PointLightSourceType.SOFT,
          options: {
            color: Color.White,
            intensity: this.isLight ? 1.0 : 0,
            height: this.isLight ? 150 : 0,
            bloom: 0
          }
        })
        .buildEffect()) : undefined)
    .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
  }
}
