import abilityAccessCtrl, { PermissionRequestResult, Permissions } from '@ohos.abilityAccessCtrl'
import common from '@ohos.app.ability.common'
import { bundleManager } from '@kit.AbilityKit'
import { access, ble } from '@kit.ConnectivityKit'
import { router } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { preferences } from '@kit.ArkData'
import BlufiPrivacyDialog from '../component/BlufiPrivacyDialog'

const TAG: string = 'Index'
let self: Index

const PrefName = "pref"
const KeyAgreePrivacyPolicy = "agree_privacy_policy"

@Entry
@Component
struct Index {
  private scroller: Scroller = new Scroller()
  @State private deviceList: Array<ble.ScanResult> = []
  @State scanDeviceNameArr: Array<string> = []
  device?: ble.ScanResult
  @State deviceName: string = ''
  @State deviceId: string = ''
  @State deviceRSSI: number = 0
  @State scanFilterInputName: string = ''
  @State status: boolean = true
  permissions: Permissions[] =
    ['ohos.permission.ACCESS_BLUETOOTH', 'ohos.permission.USE_BLUETOOTH', 'ohos.permission.GET_WIFI_INFO']
  private devices: ble.ScanResult[] = []
  @State isRefreshing: boolean = false //是否正在刷新
  @State promptText: string = '' //下拉提示文字

  preferences?: preferences.Preferences

  // 校验当前是否已经授权了
  async checkAccessToken(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED

    // 获取应用程序的accessTokenID
    let tokenId: number = 0
    try {
      let bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo
      tokenId = appInfo.accessTokenId
    } catch (error) {
      const err: BusinessError = error as BusinessError
      console.log(TAG, `Failed to get bundle info for self. Code is ${err.code}`)
    }

    // 校验应用是否被授予权限
    try {
      grantStatus = await atManager.checkAccessToken(tokenId, permission)
    } catch (error) {
      const err: BusinessError = error as BusinessError
      console.log(TAG, `Failed to check access token. Code is ${err.code}`)
    }
    return grantStatus
  }

  async checkPermissions(context: common.UIAbilityContext, action: ((granted: boolean) => void)): Promise<void> {
    try {
      let grantStatus: abilityAccessCtrl.GrantStatus = await this.checkAccessToken(this.permissions[0])
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        action(true)
      } else {
        action(false)
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError
      console.log(TAG, 'checkPermissions' + `Code is ${err.code}`)
    }
  }

  reqPermissionsFromUser(permissions: Permissions[], context: common.UIAbilityContext): void {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
    atManager.requestPermissionsFromUser(context, permissions).then((data: PermissionRequestResult) => {
      console.log(TAG, 'data:' + data)
      console.log(TAG, 'data permissions:' + data.permissions)
      console.log(TAG, 'data authResults:' + data.authResults)
      console.log(TAG, 'data dialogShownResults:' + data.dialogShownResults)
    }).catch((error: BusinessError) => {
      console.log(TAG, `Failed to request permissions from user. Code is ${error.code}`)
    })
  }

  onReceiveEvent(data: Array<ble.ScanResult>) {
    console.info('BLE scan device find result = '+ JSON.stringify(data))
    console.log(typeof this)
    if (self.deviceList) {
      data.forEach(item => {
        if (item.deviceName) {
          self.deviceList.push(item)
        }
      })
    } else {
      console.log("Device list is null")
    }
  }

  Scan() {
    try {
      ble.on("BLEDeviceFind", (data: Array<ble.ScanResult>) => {
        // this.deviceList.push(...data)
        console.info('BLE scan device find result = '+ JSON.stringify(data))
        let routerParams: object = router.getParams()
        if (routerParams) {
          this.scanFilterInputName = routerParams['blufiName'] as string
        }
        //todo
        data.forEach(item => {
          if (item.deviceName) {
            console.log('item.deviceName: ', item.deviceName)
            console.log('this.scanFilterInputName: ', this.scanFilterInputName)
            console.log('item.deviceName item.deviceName.startsWith(this.scanFilterInputName): ', item.deviceName.startsWith(this.scanFilterInputName))
            if (!this.scanDeviceNameArr.includes(item.deviceName) && item.deviceName.startsWith(this.scanFilterInputName)) {
              this.scanDeviceNameArr.push(item.deviceName)
              this.deviceList.push(item)
            }
          }
        })
      })
      ble.startBLEScan(null)
    } catch (err) {
      console.error('errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message)
    }
  }

  stopScan() {
    try {
      console.log('stopBLEScan')
      ble.stopBLEScan()
    } catch (err) {
      console.error('errCode: ' + (err as BusinessError).code + ', errMessage: ' + (err as BusinessError).message)
    }
  }

  aboutToAppear(): void {
  }

  onRefreshing() {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
    this.checkPermissions(context, (granted: boolean) => {
      if (granted) {
        this.scanBtnAction()
      } else {
        this.isRefreshing = false
        this.reqPermissionsFromUser(this.permissions, context)
      }
    })
  }

  scanBtnAction() {
    setTimeout(() => {
      //关闭下拉刷新
      this.stopScan()
      this.isRefreshing=false
    }, 3000)
    let bleState = access.getState().toString()
    if (bleState === '2') {
      this.Scan()
    } else {
      try {
        access.enableBluetooth()
      } catch (e) {
        console.log(TAG, `Failed to enableBluetooth. Code is ${(e as BusinessError).code}`)
      }
      this.Scan()
    }
  }

  onPageShow(): void {
    console.log('onPageShow')
    if (!this.preferences) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const prefOptions: preferences.Options = {
        name: PrefName
      }
      this.preferences = preferences.getPreferencesSync(context, prefOptions)
    }

    const agreePrivacyPolicy = this.preferences.getSync(KeyAgreePrivacyPolicy, false) as boolean
    if (!agreePrivacyPolicy) {
      this.showPrivacyPolicy()
    }
  }

  onPageHide(): void {
    // TODO：判断弹框是否出现
    this.uppDialogController.close()
  }

  showPrivacyPolicy() {
    this.uppDialogController.open()
  }

  agreed() {
    this.preferences!.putSync(KeyAgreePrivacyPolicy, true)
    this.preferences!.flush((err: BusinessError) => {
    })
  }

  uppDialogController: CustomDialogController = new CustomDialogController({
    builder: BlufiPrivacyDialog({ onAgree: () => {
      this.agreed()
    } }),
    autoCancel: false
  })



  build() {
    Column() {
      Row() {
        Button() {
          Image('')
            .width(30)
            .height(30)
        }
        .backgroundColor(0xFA2D28)
        .height('100%')
        .margin(10)

        Text('EspBluFi')
          .backgroundImageSize({ width: '', height: '' })
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .flexGrow(1)

        Button() {
          Image($r("app.media.blufi_setting"))
            .width(30)
            .height(30)
            .padding(4)
        }
        .backgroundColor(0xFA2D28)
        .height('100%')
        .margin(10)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/Setting'
          }, router.RouterMode.Standard, (error) => {
            if (error) {
              console.log(`Invoke pushUrl failed, code is ${error.code}`)
              return
            }
          })
        })

      }
      .width('100%')
      .height('5%')
      .margin({
        top: '0.00vp',
        right: '0.00vp',
        bottom: '0.00vp',
        left: '0.00vp'
      })
      .backgroundColor(0xFA2D28)

      Column(){
        Refresh({ refreshing: $$this.isRefreshing, promptText: this.promptText }) {
          // 列表容器
          List({ scroller: this.scroller }) {
            ForEach(this.deviceList, (item: ble.ScanResult) => {
              // 单个设备的布局
              ListItem() {
                Column({ space: 10 }) {
                  // 第一行: deviceName 和 deviceRssi
                  Row() {
                    Text(item.deviceName)
                      .width('60%')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                    Text(`RSSI: ${item.rssi}`)
                      .width('40%')
                      .fontSize(14)
                      .fontColor(Color.Grey)
                  }
                  .justifyContent(FlexAlign.SpaceBetween)
                  .alignItems(VerticalAlign.Center)

                  // 第二行: deviceId
                  Row() {
                    Text(item.deviceId)
                      .fontSize(14)
                      .width('100%')
                      .fontColor(Color.Grey)
                      .textAlign(TextAlign.Start)
                  }
                }
              }
              .margin({
                top: '0',
                right: '0',
                bottom: '15',
                left: '0'
              })
              .onClick(() => {
                console.log('点击')
                this.deviceName = item.deviceName
                this.deviceId = item.deviceId
                this.deviceRSSI =item.rssi
                this.device = item
                this.pageTo()
              })
            })
          }
          .padding(10)
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .backgroundColor(Color.White)
        }
        .onStateChange(async (state) => {
          switch (state) {
          //下拉中，下拉距离小于刷新距离
            case RefreshStatus.Drag:
              this.promptText = '下拉可以扫描'
              break
          //下拉中，下拉距离超过刷新距离
            case RefreshStatus.OverDrag:
              this.promptText = '释放立即扫描'
              break
          //刷新状态
            case RefreshStatus.Refresh:
              this.promptText = "正在扫描..."
              this.deviceList = []
              this.scanDeviceNameArr = []
              this.onRefreshing()
              break
          }
        })
      }
    }
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  private pageTo() {
    if (this.deviceId !== null && this.deviceName !== null && this.deviceRSSI !== 0) {
      router.pushUrl({
        url: 'pages/ConfigureOptions',
        params: { deviceId: this.deviceId, device: this.device }
      })
    }
  }
}