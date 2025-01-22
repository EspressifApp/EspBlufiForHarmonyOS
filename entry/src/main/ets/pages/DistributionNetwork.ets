import { router } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import wifiManager from '@ohos.wifiManager'
import { OpMode, BlufiConfigureParams, SoftApSecurity } from 'lib_blufi'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  FIVE,
  FIVE_HUNDRED,
  FOUR_HUNDRED,
  SIXTEEN,
  TEN,
  THIRTY,
  THREE_HUNDRED,
  TWENTY_FOUR,
  TWO_HUNDRED
} from './Magic'

const TAG: string = 'DistributionNetwork'

@CustomDialog
struct CustomDialogExample {
  controller: CustomDialogController
  build() {
    Column() {
      // Text('SoftAP 密码不能为空')
      //   .justifyContent(FlexAlign.Center)
      Row() {
        Text('SoftAP 密码不能为空')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .height(70)
    }
    .onClick(() => {
      this.controller.close()
    })
  }
}

@Entry
@Component
struct DistributionNetwork {
  @State @Watch('onTextDeviceUpdated') textDevice: string = 'NULL'
  @State @Watch('onTextSoftAPUpdated') textSoftAP: string = 'OPEN'
  @State textSoftAPChannel: string = '1'
  @State textSoftAPConnect: string = '1'
  @State index: number = -1
  @State arrowPosition: ArrowPosition = ArrowPosition.END
  @State select: number = 0
  @State softAPSelectVisibility: Visibility = Visibility.None
  @State softAPSelectChannelVisibility: Visibility = Visibility.None
  @State softAPSelectConnectVisibility: Visibility = Visibility.None
  @State softAPSSIDVisibility: Visibility = Visibility.None
  @State softAPPasswordVisibility: Visibility = Visibility.None
  @State selectWifiVisibility: Visibility = Visibility.None
  @State softAPSSID: string = ''
  @State softAPPassword: string = ''
  @State wifiSSID: string = ''
  @State wifiPassword: string = ''
  private wifiSSIDList: string[] = ['']
  private wifiBSSIDList: string[] = ['']
  dialogController: CustomDialogController = new CustomDialogController({
    builder: CustomDialogExample({}),
  })
  // @Provide test: string = 'SoftAP 密码不能为空'
  // @State isShow: boolean = false
  // @State dialogLocation: number = 0 // 1 中央  2 底部  3 顶部



  onTextDeviceUpdated() {
    this.selected()
  }

  onTextSoftAPUpdated() {
    this.selected()
  }

  wifi() {
    try {
      let isWifiActive: boolean = wifiManager.isWifiActive()
      if (isWifiActive === true) {
        this.wifiScan()
      } else {
        isWifiActive = true
        this.wifiScan()
      }
      // Logger.info(TAG, 'isWifiActive:' + isWifiActive)
    } catch (error) {
      let code: number = (error as BusinessError).code
      // Logger.error(TAG, 'failed:' + `Code is ${code}`)
    }

    // 获取扫描结果
    this.getWifiResult()
    TextPickerDialog.show({
      range: this.wifiSSIDList,
      selected: this.select,
      onAccept: (value: TextPickerResult) => {
        this.select = value.index as number
        // Logger.info(TAG, 'TextPickerDialog:onAccept()' + value)
        this.wifiSSID = value.value as string
      },
      onCancel: () => {
        // Logger.info(TAG, 'TextPickerDialog:onCancel()')
      },
      onChange: (value: TextPickerResult) => {
        // Logger.info(TAG, 'TextPickerDialog:onChange()' + value)
      }
    })
  }

  wifiScan() {
    try {
      wifiManager.scan()
    } catch (error) {
      let code: number = (error as BusinessError).code
      // Logger.error(TAG, 'wifiScan:failed:' + `Code is ${code}`)
    }
  }

  getWifiResult() {
    try {
      let scanInfoList: wifiManager.WifiScanInfo[] = wifiManager.getScanInfoList()
      // Logger.info(TAG, 'scanInfoList:' + scanInfoList)
      let len: number = scanInfoList.length
      // Logger.info(TAG, 'wifi received scan info: ' + len)
      if (len > 0) {
        scanInfoList.forEach((scanInfo) => {
          this.wifiSSIDList.push(scanInfo.ssid)
        })
      }
    } catch (error) {
      let code: number = (error as BusinessError).code
      // Logger.error(TAG, 'failed:' + `Code is ${code}`)
    }
  }
  //
  // showDialog(location: number) {
  //   this.isShow = true
  //   this.dialogLocation = location
  // }

  selected() {
    if (this.textDevice === 'STA') {
      this.selectWifiVisibility = Visibility.Visible
      this.softAPSelectVisibility = Visibility.None
      this.softAPSelectChannelVisibility = Visibility.None
      this.softAPSelectConnectVisibility = Visibility.None
      this.softAPSSIDVisibility = Visibility.None
      this.softAPPasswordVisibility = Visibility.None
    } else if (this.textDevice === 'SoftAP') {
      this.selectWifiVisibility = Visibility.None
      this.softAPSelectVisibility = Visibility.Visible
      this.softAPSelectChannelVisibility = Visibility.Visible
      this.softAPSelectConnectVisibility = Visibility.Visible
      this.softAPSSIDVisibility = Visibility.Visible
      this.softAPPasswordVisibility = this.textSoftAP !== 'OPEN' ? Visibility.Visible : Visibility.None
    } else if (this.textDevice === 'SoftAP&STA') {
      this.selectWifiVisibility = Visibility.Visible
      this.softAPSelectVisibility = Visibility.Visible
      this.softAPSelectChannelVisibility = Visibility.Visible
      this.softAPSelectConnectVisibility = Visibility.Visible
      this.softAPSSIDVisibility = Visibility.Visible
      this.softAPPasswordVisibility = this.textSoftAP !== 'OPEN' ? Visibility.Visible : Visibility.None
    } else {
      this.selectWifiVisibility = Visibility.None
      this.softAPSelectVisibility = Visibility.None
      this.softAPSelectChannelVisibility = Visibility.None
      this.softAPSelectConnectVisibility = Visibility.None
      this.softAPSSIDVisibility = Visibility.None
      this.softAPPasswordVisibility = Visibility.None
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
            try {
              router.back({
                url: 'pages/ConfigureOptions'
              })
              // Logger.info(TAG, 'Succeeded in returning to the first page.')
            } catch (error) {
              let code: number = (error as BusinessError).code
              // Logger.error(TAG, `Failed to return to the first page.Code is ${code}`)
            }
          })

          Text('配网')
            .fontColor(Color.White)
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

        // 选择设备模式
        Column() {
          Text($r('app.string.Select_Device_Mode'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          Select([{ value: 'NULL' },
            { value: 'STA' },
            { value: 'SoftAP' },
            { value: 'SoftAP&STA' }
          ])
            .selected(this.index)
            .value(this.textDevice)
            .font({ size: SIXTEEN, weight: FIVE_HUNDRED })
            .fontColor('#182431')
            .selectedOptionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .optionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .arrowPosition(this.arrowPosition)
            .menuAlign(MenuAlignType.START, { dx: 0, dy: 0 })
            .optionWidth(TWO_HUNDRED)
            .optionHeight(THREE_HUNDRED)
            .width('90%')
            .onSelect((index: number, text?: string | undefined) => {
              this.index = index
              if (text) {
                this.textDevice = text
              }
            })
        }

        // SoftAP 加密
        Column() {
          Text($r('app.string.SoftAP_encryption'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          Select([{ value: 'OPEN' },
            { value: 'WPA PSK' },
            { value: 'WPA2 PSK' },
            { value: 'WPA WAP2 PSK' }])
            .selected(this.index)
            .value(this.textSoftAP)
            .font({ size: SIXTEEN, weight: FIVE_HUNDRED })
            .fontColor('#182431')
            .selectedOptionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .optionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .arrowPosition(this.arrowPosition)
            .menuAlign(MenuAlignType.START, { dx: 0, dy: 0 })
            .optionWidth(TWO_HUNDRED)
            .optionHeight(THREE_HUNDRED)
            .width('90%')
            .onSelect((index: number, text?: string | undefined) => {
              this.index = index
              if (text) {
                this.textSoftAP = text
              }
            })
        }
        .visibility(this.softAPSelectVisibility)
        // SoftAP 信道
        Column() {
          Text($r('app.string.SoftAP_channel'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          Select([{ value: '1' },
            { value: '2' },
            { value: '3' },
            { value: '4' },
            { value: '5' },
            { value: '6' },
            { value: '7' },
            { value: '8' },
            { value: '9' },
            { value: '10' },
            { value: '11' },
            { value: '12' },
            { value: '13' }])
            .selected(this.index)
            .value(this.textSoftAPChannel)
            .font({ size: SIXTEEN, weight: FIVE_HUNDRED })
            .fontColor('#182431')
            .selectedOptionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .optionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .arrowPosition(this.arrowPosition)
            .menuAlign(MenuAlignType.START, { dx: 0, dy: 0 })
            .optionWidth(TWO_HUNDRED)
            .optionHeight(THREE_HUNDRED)
            .width('90%')
            .onSelect((index: number, text?: string | undefined) => {
              this.index = index
              if (text) {
                this.textSoftAPChannel = text
              }
            })
        }
        .visibility(this.softAPSelectChannelVisibility)

        // SoftAP 最大连接数
        Column() {
          Text($r('app.string.SoftAP_max_connect'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          Select([{ value: '1' },
            { value: '2' },
            { value: '3' },
            { value: '4' }])
            .selected(this.index)
            .value(this.textSoftAPConnect)
            .font({ size: SIXTEEN, weight: FIVE_HUNDRED })
            .fontColor('#182431')
            .selectedOptionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .optionFont({ size: SIXTEEN, weight: FOUR_HUNDRED })
            .arrowPosition(this.arrowPosition)
            .menuAlign(MenuAlignType.START, { dx: 0, dy: 0 })
            .optionWidth(TWO_HUNDRED)
            .optionHeight(THREE_HUNDRED)
            .width('90%')
            .onSelect((index: number, text?: string | undefined) => {
              this.index = index
              if (text) {
                this.textSoftAPConnect = text
              }
            })
        }
        .visibility(this.softAPSelectConnectVisibility)

        // SoftAP ssid
        Column() {
          Text($r('app.string.SoftAP_ssid'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          TextInput({ placeholder: 'SoftAP ssid', text: this.wifiSSID })
            .margin({ top: FIVE })
            .width('90%')
            .onChange((inputSoftAPSSID: string) => {
              this.softAPSSID = inputSoftAPSSID
            })
            .onSubmit((EnterKeyType) => {
            })
        }
        .visibility(this.softAPSSIDVisibility)

        // SoftAP 密码
        Column() {
          Text($r('app.string.SoftAP_password'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          TextInput({ placeholder: $r('app.string.SoftAP_password') })
            .type(InputType.Password)
            .margin({ top: TEN })
            .width('90%')
            .onChange((inputSoftAPPassword: string) => {
              this.softAPPassword = inputSoftAPPassword
            })
            .onSubmit((EnterKeyType) => {
            })
        }
        .visibility(this.softAPPasswordVisibility)

        // 选择WiFi
        Column() {
          Text($r('app.string.select_wifi'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(FIVE)
          Row() {
            TextInput({ placeholder: 'WiFi ssid', text: this.wifiSSID })
              .margin({ top: FIVE })
              .width('80%')
              .onChange((inputWiFiSSID: string) => {
                this.wifiSSID = inputWiFiSSID
              })
              .onSubmit((EnterKeyType) => {
              })
            Image($r('app.media.ic_public_rotate'))
              .width(TWENTY_FOUR)
              .height(TWENTY_FOUR)
              .margin({ left: TEN })
              .onClick(() => {
                this.wifi()
              })
          }

          Text($r('app.string.wifi_password'))
            .width('90%')
            .fontColor(Color.Black)
            .padding(TEN)
          TextInput({ placeholder: $r('app.string.wifi_password') })
            .type(InputType.Password)
            .margin({ top: TEN })
            .width('90%')
            .onChange((password: string) => {
              this.wifiPassword = password
            })
            .onSubmit((EnterKeyType) => {
            })

        }
        .visibility(this.selectWifiVisibility)
        .padding(FIVE)

        Button($r('app.string.config'))
          .width('50%')
          .backgroundColor(0xFA2D28)
          .margin({ top: TEN })
          .onClick(() => {
            let configParams = new BlufiConfigureParams()
            if (this.textDevice === 'NULL') {
              configParams.opMode = OpMode.MODE_NULL
            } else if (this.textDevice === 'STA') {
              configParams.opMode = OpMode.MODE_STA
              configParams.staSSID = this.wifiSSID
              configParams.staPassword = this.wifiPassword
            } else if (this.textDevice === 'SoftAP') {
              if (this.textSoftAP !== 'OPEN') {
                if (!this.softAPPassword) {
                  console.log(TAG, 'SoftAP 密码不能为空')
                  this.dialogController.open()
                  return
                }
              }
              configParams.opMode = OpMode.MODE_SOFTAP
              configParams.softApSSID = this.softAPSSID
              configParams.softApPassword = this.softAPPassword
              configParams.softApChannel = Number(this.textSoftAPChannel)
              configParams.softApMaxConnection = Number(this.textSoftAPConnect)
              if (this.textSoftAP === 'OPEN') {
                configParams.softApSecurity = SoftApSecurity.OPEN
              } else if (this.textSoftAP === 'WPA PSK') {
                configParams.softApSecurity = SoftApSecurity.WPA
              } else if (this.textSoftAP === 'WPA2 PSK') {
                configParams.softApSecurity = SoftApSecurity.WPA2
              } else if (this.textSoftAP === 'WPA WAP2 PSK') {
                configParams.softApSecurity = SoftApSecurity.WPA_WPA2
              }
            } else if (this.textDevice === 'SoftAP&STA') {
              if (this.textSoftAP !== 'OPEN') {
                if (!this.softAPPassword) {
                  console.log(TAG, 'SoftAP 密码不能为空')
                  this.dialogController.open()
                  return
                }
              }
              configParams.opMode = OpMode.MODE_STASOFTAP
              configParams.softApSSID = this.softAPSSID
              configParams.softApPassword = this.softAPPassword
              configParams.softApChannel = Number(this.textSoftAPChannel)
              configParams.softApMaxConnection = Number(this.textSoftAPConnect)
              if (this.textSoftAP === 'OPEN') {
                configParams.softApSecurity = SoftApSecurity.OPEN
              } else if (this.textSoftAP === 'WPA PSK') {
                configParams.softApSecurity = SoftApSecurity.WPA
              } else if (this.textSoftAP === 'WPA2 PSK') {
                configParams.softApSecurity = SoftApSecurity.WPA2
              } else if (this.textSoftAP === 'WPA WAP2 PSK') {
                configParams.softApSecurity = SoftApSecurity.WPA_WPA2
              }
              configParams.staSSID = this.wifiSSID
              configParams.staPassword = this.wifiPassword
            }
            try {
              router.back({
                url: 'pages/ConfigureOptions',
                params: configParams
              })
              // Logger.info(TAG, 'Succeeded in returning to the first page.')
            } catch (error) {
              let code: number = (error as BusinessError).code
              // Logger.error(TAG, `Failed to return to the first page.Code is ${code}`)
            }
          })

      }
      .width('100%')
      .height('100%')
    }
    .backgroundColor(0xF1F3F5)
    .height('100%')
  }
}
