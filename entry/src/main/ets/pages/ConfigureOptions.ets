
import { BusinessError } from '@kit.BasicServicesKit'
import { ble, constant, } from '@kit.ConnectivityKit'
import { router } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { util } from '@kit.ArkTS'

import { BlufiCallback, BlufiClient,
  BlufiCode,
  BlufiConfigureParams,
  BlufiScanResult,
  BlufiStatusResponse,
  BlufiVersionResponse, newBlufiClient } from 'lib_blufi'

import {
  EIGHT,
  FIVE,
  FOUR,
  FRICTION_NUMBER,
  SIXTEEN,
  SIXTY,
  TEN,
  THIRTY,
  THREE,
  TWENTY,
  TWO,
  TWENTY_FOUR
} from './Magic'


const DOM = 16
const STATE_DISCONNECTED = 0
const STATE_CONNECTED = 2
const TAG: string = 'ConfigureOptions'

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
      Text($r('app.string.string_Enter_user_defined_data'))
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
          .onClick(() => {
            if (this.controller !== undefined) {
              this.controller.close()
              this.cancel()
            }
          })
          .backgroundColor(0xffffff)
          .fontColor(Color.Black)
        Button($r('app.string.ok'))
          .onClick(() => {
            if (this.controller !== undefined) {
              this.inputValue = this.textValue
              this.controller.close()
              this.confirm()
            }
          })
          .backgroundColor(0xffffff)
          .fontColor(Color.Red)
      }
      .margin({ bottom: TEN })
    }.borderRadius(TEN)
  }
}

class MyBlufiCallback extends BlufiCallback {
  uiOptions?: ConfigureOptions

  constructor(ui: ConfigureOptions) {
    super()
    this.uiOptions = ui
  }

  public onConnectionStateChange(state: ble.BLEConnectionChangeState): void {
    hilog.info(DOM, TAG, `onConnectionStateChange: ${state.deviceId}, ${state.state}`)
    if (state.state === STATE_DISCONNECTED) {
      this.uiOptions?.updateMessage('Disconnected device')
      this.uiOptions?.deceiveDisconnectBtnState()
      this.uiOptions?.blufiClientInstance?.close()
    } else if (state.state === STATE_CONNECTED) {
      this.uiOptions?.updateMessage('Connected device')
    }
  }

  public onError(client: BlufiClient, errorCode: number): void {
    hilog.error(DOM, TAG, `error code: ${errorCode}`)
    this.uiOptions?.updateMessage(`An error occurred. The error code is ${errorCode}`)
  }

  public onGattPrepared(client: BlufiClient, status: number): void {
    hilog.info(DOM, TAG, `onGattPrepared: ${status}`)
    if (status === BlufiCode.STATUS_SUCCESS) {
      this.uiOptions?.updateMessage('BluFi connection has prepared')
      this.uiOptions?.deceiveConnectBtnState()
    } else {
      this.uiOptions?.updateMessage(`BluFi connection is abnormal: ${status}`)
    }
  }

  public onNegotiateSecurityResult(client: BlufiClient, status: number): void {
    hilog.info(DOM, TAG, `onNegotiateSecurityResult: ${status}`)
    this.uiOptions!.encryptionBtnEnables = true
    if (status === BlufiCode.STATUS_SUCCESS) {
      this.uiOptions?.updateMessage('Negotiate security complete')
    } else {
      this.uiOptions?.updateMessage(`Negotiate security failed: ${status}`)
    }
  }

  public onDeviceVersionResponse(client: BlufiClient, status: number, response?: BlufiVersionResponse): void {
    hilog.info(DOM, TAG, `onDeviceVersionResponse: ${status}, ${response?.getVersionString()}`)
    this.uiOptions!.versionBtnEnables = true
    if (status === BlufiCode.STATUS_SUCCESS) {
      this.uiOptions?.updateMessage(`Receive device version: ${response?.getVersionString()}`)
    } else {
      this.uiOptions?.updateMessage(`Receive device version error: ${status}`)
    }
  }

  public onDeviceScanResult(client: BlufiClient, status: number, results?: BlufiScanResult[]): void {
    hilog.info(DOM, TAG, `onDeviceScanResult ${status}`)
    this.uiOptions!.scanBtnEnables = true
    if (!results) {
      return
    }
    let scanResultStr = `Receive device scan results:\n`
    for (const bsr of results) {
      hilog.error(DOM, TAG, `DEVICE SCAN: ${bsr.ssid}, ${bsr.rssi}`)
      scanResultStr = scanResultStr + `SSID: ${bsr.ssid}, RSSI: ${bsr.rssi}\n`
    }
    this.uiOptions?.updateMessage(scanResultStr)
  }

  public onPostConfigureParams(client: BlufiClient, status: number): void {
    hilog.info(DOM, TAG, `onPostConfigureParams ${status}`)
    this.uiOptions!.provisionBtnEnables = true
    if (status === BlufiCode.STATUS_SUCCESS) {
      this.uiOptions?.updateMessage('Post configure params complete')
    } else {
      this.uiOptions?.updateMessage(`Post configure params failed: ${status}`)
    }
  }

  public onDeviceStatusResponse(client: BlufiClient, status: number, response?: BlufiStatusResponse): void {
    const statusInfo = response?.generateStatusInfo()
    hilog.info(DOM, TAG, `onDeviceStatusResponse ${status}, response = {\n${statusInfo}\n}`)
    this.uiOptions!.stateBtnEnables = true
    if (status === BlufiCode.STATUS_SUCCESS) {
      this.uiOptions?.updateMessage(`Receive device status: ${statusInfo}`)
    } else {
      this.uiOptions?.updateMessage(`Receive device status error: ${status}`)
    }
  }

  public onPostCustomDataResult(client: BlufiClient, status: number, data?: Uint8Array): void {
    hilog.info(DOM, TAG, `onPostCustomDataResult ${status}`)
    this.uiOptions!.customBtnEnables = true
    if (status === BlufiCode.STATUS_SUCCESS) {
      this.uiOptions?.updateMessage('Post custom data complete')
    } else {
      this.uiOptions?.updateMessage(`Post custom data failed: ${status}`)
    }
  }

  public onReceiveCustomData(client: BlufiClient, status: number, data?: Uint8Array): void {
    hilog.info(DOM, TAG, `onReceiveCustomData ${status}, ${data}}`)
    const resultStr = new util.TextDecoder().decodeToString(data)
    this.uiOptions?.updateMessage(`Receive device custom data: ${resultStr}`)
  }
}

@Entry
@Component
struct ConfigureOptions {
  blufiClientInstance: null | BlufiClient = null
  device?: ble.ScanResult
  @State deviceId: string = ''
  @State ssid: string = ''
  @State password: string = ''
  @State bssid: string = ''
  @State deviceOpMode: string = ''
  @State softAP: string = ''
  @State softAPChannel: string = ''
  @State softAPConnect: string = ''
  @State softAPSSID: string = ''
  @State softAPPassword: string = ''
  @State itemArray: string[] = []
  @State textValue: string = ''
  @State inputValue: string = ''
  @State connectStateSuccess: number = TWO
  @State disconnectBtnEnables: boolean = false
  @State encryptionBtnEnables: boolean = false
  @State versionBtnEnables: boolean = false
  @State provisionBtnEnables: boolean = false
  @State stateBtnEnables: boolean = false
  @State scanBtnEnables: boolean = false
  @State customBtnEnables: boolean = false
  dialogController: CustomDialogController | null = new CustomDialogController({
    builder: CustomDialogExample({
      cancel: () => {
        this.onCancel()
      },
      confirm: () => {
        this.onAccept()
      },
      textValue: $textValue,
      inputValue: $inputValue,
    }),
    cancel: this.exitApp,
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -TWENTY },
    gridCount: FOUR,
    customStyle: false,
    cornerRadius: TEN,
  })
  @State connectState: constant.ProfileConnectionState = 0

  aboutToDisappear() {
    this.dialogController = null
  }

  updateMessage(message: string) {
    this.itemArray.push(message)
  }

  getSingleClient(): BlufiClient {
    if (this.blufiClientInstance === null) {
      this.blufiClientInstance = newBlufiClient(this.device!) as BlufiClient
      this.blufiClientInstance.setPostPackageLengthLimit(260)
      this.blufiClientInstance.setBlufiCallback(new MyBlufiCallback(this))
    }
    return this.blufiClientInstance
  }

  onBackPress(): boolean | void {
    this.blufiClientInstance?.close()
  }

  onCancel() {
  }

  onAccept() {
    const data = new util.TextEncoder().encodeInto(this.inputValue)
    // let data: Uint8Array = BlufiUtil.stringToUint8Array(this.inputValue)
    if (this.blufiClientInstance !== null) {
      this.blufiClientInstance.postCustomData(data)
      this.customBtnEnables = false
    }
  }

  exitApp() {
  }

  aboutToAppear(): void {
    const routerParams: object = router.getParams()
    this.deviceId = routerParams['deviceId'] as string
    this.device = routerParams['device'] as ble.ScanResult
    // const test: BlufiClient = this.getSingleClient()
    // let gattCk = this.gattCallback()
    // let blufiCk = this.blufiCallback()
    // test.setGattCallback(gattCk)
    // test.setBlufiCallback(blufiCk)
    // this.getSingleClient().printDebugLog(true)
  }

  onPageShow(): void {
    const routerParams: object = router.getParams()
    if (routerParams) {
      this.deviceOpMode = routerParams['deviceOpMode'] as string
      this.ssid = routerParams['ssid'] as string
      this.password = routerParams['password'] as string
    }
    if (routerParams && this.blufiClientInstance !== null) {
      hilog.info(DOM, TAG, `routerParams ${routerParams}`)
      this.blufiClientInstance.configure(routerParams as BlufiConfigureParams)
    }
    // this.checkInfo()
  }
  // 连接
  deviceConnectBtn() {

    if(this.blufiClientInstance !== null) {
      this.blufiClientInstance.close()
      this.blufiClientInstance === null
    }
    this.blufiClientInstance = newBlufiClient(this.device!)
    this.blufiClientInstance.setPostPackageLengthLimit(260)
    this.blufiClientInstance.setBlufiCallback(new MyBlufiCallback(this))
    this.blufiClientInstance.connect()
  }

  deceiveConnectBtnState() {
    this.disconnectBtnEnables = true
    this.encryptionBtnEnables = true
    this.versionBtnEnables = true
    this.provisionBtnEnables = true
    this.stateBtnEnables = true
    this.scanBtnEnables = true
    this.customBtnEnables = true
  }

  deceiveDisconnectBtnState() {
    this.disconnectBtnEnables = false
    this.encryptionBtnEnables = false
    this.versionBtnEnables = false
    this.provisionBtnEnables = false
    this.stateBtnEnables = false
    this.scanBtnEnables = false
    this.customBtnEnables = false
  }

  // 断开
  deviceDisconnectBtn() {
    if(this.blufiClientInstance !== null) {
      this.blufiClientInstance.requestCloseConnection()
    }
  }

  // 配网
  wifiNetworkBtn() {
    if (this.blufiClientInstance !== null) {
      if (this.connectState === constant.ProfileConnectionState.STATE_DISCONNECTED) {
        // this.getSingleClient().connect()
      }
      router.pushUrl({ url: 'pages/DistributionNetwork' }).then(() => {
        // Logger.info(TAG, 'wifiNetworkBtn-Succeeded in jumping to the second page.')
      }).catch((err: BusinessError) => {
        // Logger.error(TAG,
        //   `wifiNetworkBtn-Failed to jump to the second page.Code is ${err.code}`)
      })
    }
  }

  // 加密
  encryptionBtn() {
    if (this.blufiClientInstance !== null) {
      this.getSingleClient().negotiateSecurity()
      this.encryptionBtnEnables = false
    }
  }

  // 版本
  versionBtn() {
    if (this.blufiClientInstance !== null) {
      this.getSingleClient().requestDeviceVersion()
      this.versionBtnEnables = false
    }
  }

  // 扫描
  scanBtn() {
    if (this.blufiClientInstance !== null) {
      this.getSingleClient().requestDeviceWifiScan()
      this.scanBtnEnables = false
    }
  }

  // 状态
  statusBtn() {
    if (this.blufiClientInstance !== null) {
      this.getSingleClient().requestDeviceStatus()
      this.stateBtnEnables = false
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
            this.blufiClientInstance?.close()
            router.back({
              url: 'pages/Index'
            })
          })

          Text(this.device?.deviceName)
            .fontColor(Color.White)
            // .fontSize(TWENTY_FOUR)
        }
        .backgroundColor(0xFA2D28)
        .width('100%')
        .height('5.00%')
        .margin({
          top: '0.00vp',
          right: '0.00vp',
          bottom: '0.00vp',
          left: '0.00vp'
        })

        Column() {
          List({ space: TWENTY, initialIndex: 0 }) {
            ForEach(this.itemArray, (item: string) => {
              ListItem() {
                Text(item)
                  .width('100%')
                  .fontSize(SIXTEEN)
                  .textAlign(TextAlign.Start)
                  .borderRadius(THREE)
              }
            }, (item: string, index: number) => `${index}`)
          }
          .listDirection(Axis.Vertical)
          .scrollBar(BarState.Off)
          .friction(FRICTION_NUMBER)
          .divider({
            strokeWidth: 1,
            color: Color.White,
            startMargin: TWENTY,
            endMargin: TWENTY
          })
          .edgeEffect(EdgeEffect.Spring)
          .onScrollIndex((firstIndex: number, lastIndex: number, centerIndex: number) => {
          })
          .onScroll((scrollOffset: number, scrollState: ScrollState) => {
            // Logger.info(TAG, `onScroll scrollState = ScrollState` + scrollState + `, scrollOffset = ` + scrollOffset)
          })
          .width('90%')
          .height('100%')
        }
        .width('100%')
        .height('80%')
        .backgroundColor(0xDCDCDC)
        .padding({ top: FIVE })

        Column() {
          Flex({
            justifyContent: FlexAlign.SpaceEvenly,
            alignContent: FlexAlign.SpaceEvenly,
            wrap: FlexWrap.Wrap
          }) {
            Button($r('app.string.connect'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(!this.disconnectBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .margin({ right: TWO, bottom: TEN })
              .onClick(() => {
                this.deviceConnectBtn()
              })
              .backgroundImagePosition({ x: '0', y: 0 })
            Button($r('app.string.disconnect'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.disconnectBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                this.deviceDisconnectBtn()
              })
              .backgroundImageSize(ImageSize.Auto)
              .backgroundImagePosition({ x: '0', y: 0 })
            Button($r('app.string.encryption'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.encryptionBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                this.encryptionBtn()
              })
            Button($r('app.string.version'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.versionBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                this.versionBtn()
              })
            Button($r('app.string.wifiNetwork'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.provisionBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                this.wifiNetworkBtn()
              })
            Button($r('app.string.status'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.stateBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                this.statusBtn()
              })
            Button($r('app.string.scan'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.scanBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                this.scanBtn()
              })
            Button($r('app.string.widgets'), { type: ButtonType.Normal, stateEffect: true })
              .enabled(this.customBtnEnables)
              .borderRadius(EIGHT)
              .backgroundColor(0xFA2D28)
              .width('20%')
              .onClick(() => {
                if (this.dialogController != null) {
                  this.textValue = ''
                  this.dialogController.open()
                }
              })
          }
          .width('100%')
          .padding({
            top: TEN,
            bottom: TEN,
            left: TEN,
            right: TEN
          })
          .backgroundColor(Color.White)
        }
        .justifyContent(FlexAlign.End)

      }
      .width('100%')
      .height('100%')
    }
    .backgroundColor(Color.White)
    .height('100%')
  }
}