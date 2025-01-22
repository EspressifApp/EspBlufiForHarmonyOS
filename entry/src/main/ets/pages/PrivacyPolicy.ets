import { webview } from '@kit.ArkWeb'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct WebViewPage {
  private webviewController: WebviewController = new webview.WebviewController();

  aboutToAppear() {
    // 配置Web开启调试模式
    webview.WebviewController.setWebDebuggingAccess(true);
  }
  aboutToRecycle(): void {
  }
  build() {
    Row() {
      Column() {
        Web({
          src: $rawfile('PrivacyPolicy.pdf'),
          controller: this.webviewController
        })
          .height('90%')
          .width('100%')
          .javaScriptAccess(true)
          .multiWindowAccess(false)
          .domStorageAccess(true)
          .allowWindowOpenMethod(true)
          .zoomAccess(false)
          .domStorageAccess(true)
        Button('关闭')
          .width('100%')
          .height('5%')
          .backgroundColor(0xFA2D28)
          .margin({ top: 10 })
          .onClick(() => {
            router.back()
          })
      }
      .width('100%')
    }
    .height('100%')
  }
}