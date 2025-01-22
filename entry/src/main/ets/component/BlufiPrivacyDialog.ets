import common from '@ohos.app.ability.common'
import CommDialog from './Commdialog'
import { router } from '@kit.ArkUI'

@Preview
@CustomDialog
export default struct BlufiPrivacyDialog {
  private onAgree?: () => void // 点击同意协议时的回调事件
  controller: CustomDialogController = new CustomDialogController({
    builder: BlufiPrivacyDialog(),
    autoCancel: true
  })

  build() {
    Flex() {
      CommDialog({
        title: '关于用户隐私政策',
        controller: this.controller,
        confirmText: '同意',
        cancelText: '拒绝',
        onConfirm: () => {
          if (this.onAgree) {
            this.onAgree()
          }
        },
        onCancel: () => {
          (getContext(this) as common.UIAbilityContext).terminateSelf() // 退出APP
        }
      }) {
        Text() {
          Span('EspBlufi 是一款通过蓝牙控制设备的应用，' +
            '为了更好的服务您，在您使用 APP 过程中，我们扫描您附近的蓝牙设备。更多信息请查看 ')
            .fontSize(13)
          Span('《隐私政策声明》')
            .fontStyle(FontStyle.Italic)
            .fontSize(13)
            .decoration({ type: TextDecorationType.Underline, color: '#DA4436' })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/PrivacyPolicy'
              })
            })
        }
        .lineHeight(28)
      }
    }
  }
}
