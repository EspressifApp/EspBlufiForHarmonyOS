@Preview
@Component
export default struct CommDialog {
  private title?: string | Resource = '标题' // 标题
  private controller?: CustomDialogController
  private onConfirm: () => void = () => {
  } // 确认按钮点击事件
  private onCancel?: () => void = () => {
  } // 取消按钮点击事件
  private confirmText?: string | Resource = '确定' // 确定按钮文字
  private cancelText?: string | Resource = '取消' // 取消按钮文字
  @BuilderParam closer: () => void=closerFunc

  build() {
    Column() {
      Text(this.title)
        .width('100%')
        .fontSize(20)
        .fontColor('#182431')
        .margin({
          bottom: 12
        })

      // 占位
      this.closer()

      Row() {
        // 左边的取消按钮
        Button(this.cancelText)
          .onClick(() => {
            if (!this.controller) {
              return
            }
            if (this.onCancel) {
              this.onCancel()
            }
            this.controller.close()
          })
          .fontSize(15)
          .height(40)
          .layoutWeight(1)
          .fontColor('#17A98E')
          .backgroundColor('#00000000')

        // 右边的确认按钮
        if (this.onConfirm) {
          Button(this.confirmText)
            .onClick(() => {
              this.onConfirm()
              if (!this.controller) {
                return
              }
              this.controller.close()
            })
            .fontSize(15)
            .height(40)
            .layoutWeight(1)
            .fontColor('#17A98E')
            .backgroundColor('#00000000')
        }
      }
      .margin({
        top: 12
      })
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
  }
}

@Builder
function closerFunc() {

}
