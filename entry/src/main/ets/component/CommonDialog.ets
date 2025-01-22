@Preview
@Component
struct CommonDialog {
  @Consume
  test: string //接收到上层provide共享的数据
  @Link
  isShow: boolean
  @Link
  dialogLocation: number

  build() {
    Column() {
      Column() {
        Row() {
          Text(this.test)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .height(150)

        // Text(this.test).margin({ bottom: 60 })
      }.width('100%')
      .backgroundColor('#fff')
      .borderRadius({
        topLeft: 16,
        topRight: 16,
        bottomLeft: this.dialogLocation === 1 ? 16 : 0,
        bottomRight: this.dialogLocation === 1 ? 16 : 0
      })
    }
    .onClick(() => {
      this.isShow = false
    })
    .height('100%')
    .width('100%')
    .justifyContent(
      this.dialogLocation === 1 ? FlexAlign.Center :
        this.dialogLocation === 2 ? FlexAlign.End :
          this.dialogLocation === 3 ? FlexAlign.Start :
          FlexAlign.Start)
    .backgroundColor('rgba(0,0,0,0.5)')
  }
}
