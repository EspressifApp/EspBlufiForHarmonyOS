import { router } from '@kit.ArkUI'
import { bundleManager } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { FIVE, FOUR, SIXTY, TEN, THIRTY, TWENTY, } from './Magic'
import {BLUFI_VERSION} from 'lib_blufi'

const TAG: string = 'Setting'

@CustomDialog
struct CustomDialogExample {
  @Link textValue: string
  @Link inputValue: string
  controller?: CustomDialogController
  cancel: () => void = () => {
  }
  confirm: () => void = () => {
  }

  build() {
    Column() {
      Text($r('app.string.Please_enter_the_name_of_the_Bluetooth_device'))
        .fontSize(TWENTY)
        .margin({ top: TEN, bottom: TEN })
      TextInput({ placeholder: '', text: this.textValue })
        .height(SIXTY)
        .width('90%')
        .onChange((value: string) => {
          this.textValue = value
        })
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button($r('app.string.cancel'))
          .backgroundColor(0xffffff)
          .fontColor(Color.Black)
          .onClick(() => {
            if (this.controller !== undefined) {
              this.controller.close()
              this.cancel()
            }
          })
        Button($r('app.string.ok'))
          .backgroundColor(0xffffff)
          .fontColor(Color.Red)
          .onClick(() => {
            if (this.controller !== undefined) {
              this.inputValue = this.textValue
              this.controller.close()
              this.confirm()
            }
          })
      }
      .margin({ bottom: TEN })
    }
    .borderRadius(TEN)
  }
}

@Entry
@Component
struct Setting {
  @State textValue: string = 'BLUFI'
  @State inputValue: string = 'BLUFI'
  @State versionCode: string = ''
  @State sdkApiVersionInfo: string = BLUFI_VERSION
  dialogController: CustomDialogController | null = new CustomDialogController({
    builder: CustomDialogExample({
      cancel: () => {
        this.onCancel()
      },
      confirm: () => {
        this.onAccept()
      },
      textValue: $textValue,
      inputValue: $inputValue
    }),
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -TWENTY },
    gridCount: FOUR,
    customStyle: false,
    cornerRadius: TEN,
  })

  aboutToDisappear() {
    this.dialogController = null
  }

  onCancel() {
  }

  onAccept() {
  }

  exitApp() {
  }

  aboutToAppear(): void {
    this.getAppVersion()
  }

  getAppVersion(): void {
    try {
      let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      bundleManager.getBundleInfoForSelf(bundleFlags, (error, data) => {
        this.versionCode = data.versionCode.toString()
      })
    } catch (error) {
      const err: BusinessError = error as BusinessError
      // Logger.error(TAG, `getBundleInfoForSelf failed: ${err.code}`)
    }
  }

  build() {
    Row() {
      Column() {
        Row() {
          Button() {
            Image($r("app.media.blufi_back"))
              .width(THIRTY)
              .height(THIRTY)
              .padding(4)
          }
          .backgroundColor(0xFA2D28)
          .width('20%')
          .height('100%')
          .onClick(() => {
            router.back({
              url: 'pages/Index',
              params: { blufiName: this.inputValue }
            })
          })

          Text($r('app.string.setting'))
            .fontColor(Color.White)
        }
        .backgroundColor(0xFA2D28)
        .width('100%')
        .height('5.00%')
        .margin({
          top: '0',
          right: '0.00vp',
          bottom: '0.00vp',
          left: '0.00vp'
        })

        Column({ space: FIVE }) {
          Text('BluFi')
            .width('90%')
            .fontColor(0xFA2D28)
            .margin(10)
          Column({ space: FIVE }) {
            Text($r('app.string.BluFi_Device_Filtering'))
              // .fontSize(THIRTY)
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Start)
            Button(this.inputValue)
              .onClick(() => {
                if (this.dialogController !== null) {
                  this.dialogController.open()
                }
              })
              .backgroundColor('#00297bff')
              .width('100%')
              .fontColor(Color.Black)
          }
          .width('90%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)

          Text($r('app.string.version'))
            .width('90%')
            .fontColor(0xFA2D28)

          Column() {
            Text($r('app.string.APP_version'))
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Start)
            Text(this.versionCode)
              .textAlign(TextAlign.Start)
          }
          .width('90%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .height('6%')

          Column() {
            Text($r('app.string.API_version'))
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Start)
            Text(this.sdkApiVersionInfo)
              .textAlign(TextAlign.Start)
          }
          .width('90%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .height('6%')

          Button('查看隐私政策')
            .width('100%')
            .height('5%')
            .backgroundColor(0xFA2D28)
            .margin(10)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/PrivacyPolicy'
              })
            })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor(0xF1F3F5)
    .height('100%')
  }
}


