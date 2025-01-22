@Preview
@Component
export default struct ListDeviceItem {
  private deviceName: string = ''
  private deviceId: string = ''
  private deviceRssi: string = ''

  build() {
    Row() {

      Text(this.deviceName)
        .fontSize(19)
        .fontWeight(500)
        .width("100%")
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ right: 30 })
        .fontColor(Color.Black)

      Text(this.deviceId)
        .fontSize(19)
        .fontWeight(500)
        .width("100%")
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ right: 30 })
        .fontColor(Color.Black)

      Text(this.deviceRssi)
        .fontSize(19)
        .fontWeight(500)
        .width("100%")
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ right: 30 })
        .fontColor(Color.Black)

      Button('已连接', { buttonStyle: ButtonStyleMode.NORMAL })
        .margin(10)
        .fontColor(Color.Black)

    }
    .backgroundColor(Color.White)
    .width("100%")
    .height(80)
  }
}