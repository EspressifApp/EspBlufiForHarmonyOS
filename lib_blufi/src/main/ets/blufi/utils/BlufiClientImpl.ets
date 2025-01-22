import { ble, constant } from '@kit.ConnectivityKit'

import { BlufiCallback } from '../BlufiCallback'
import { BlufiNotifyData } from './BlufiNotifyData'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  BlufiCode,
  BlufiUUIDs,
  CtrlSubType,
  DataDirection,
  DataSubType,
  OpMode,
  PackageType,
  SoftApSecurity
} from '../params/BlufiConstatnts'
import { BlufiClient } from '../BlufiClient'
import { ByteArrayBuilder } from './ByteArrayBuilder'
import { FrameCtrlData } from './FrameCtrl'
import { calcCRC } from '../security/BlufiCRC'
import { BlufiAES } from '../security/BlufiAES'
import { ByteArrayInputStream } from './ByteArrayInputStream'
import { BlufiVersionResponse } from '../response/BlufiVersionResponse'
import { BlufiScanResult } from '../response/BlufiScanResult'
import { util } from '@kit.ArkTS'
import { BlufiDH } from '../security/BlufiDH'
import { bigintToUint8Array,
  equalsIgnoreCase,
  uint8ArrayToBigInt, uint8ArrayToHexString, uint8ToInt8 } from './BlufiUtils'
import { BlufiStatusResponse } from '../response/BlufiStatusResponse'
import { getMD5Bytes } from '../security/BlufiMD5'
import { BlufiConfigureParams } from '../params/BlufiConfigureParams'

const LOG_TAG = "BlufiClientImpl"
const LOG_DOMAIN = 1000

const PACKAGE_LENGTH_DEFAULT = 20
const PACKAGE_LENGTH_MIN = 20
const PACKAGE_LENGTH_MAX = 255
const PACKAGE_HEADER_LENGTH = 4

const NEG_SECURITY_SET_TOTAL_LENGTH = 0
const NEG_SECURITY_SET_ALL_DATA = 1

const DH_P_HEX = "cf5cf5c38419a724957ff5dd323b9c45c3cdd261eb740f69aa94b8bb1a5c9640" +
  "9153bd76b24222d03274e4725a5406092e9e82e9135c643cae98132b0d95f7d6" +
  "5347c68afc1e677da90e51bbab5f5cf429c291b4ba39c6b2dc5e8c7231e46aa7" +
  "728e87664532cdf547be20c9a3fa8342be6e34371a27c06f7dc0edddd2f86373"
const DH_P_BN = BigInt("0x" + DH_P_HEX)
const DH_P_LENGTH = 128
const DH_G_BN = 2n
const DH_G_LENGTH = 1
const DH_BIT_LENGTH = 1024
const DH_KEY_LENGTH = 128

type PostCallback = (success: boolean) => void

export class BlufiClientImpl implements BlufiClient {
  public userBlufiCallback?: BlufiCallback
  private packageLengthLimit: number = -1
  private blufiMTU = -1
  private sendSequence: number = -1
  private readSequence: number = -1
  private notifyData?: BlufiNotifyData
  private device: ble.ScanResult
  public gattClient?: ble.GattClientDevice
  private blufiService?: ble.GattService
  private blufiNotifyChar?: ble.BLECharacteristic
  private connectionState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED
  private blufiDH?: BlufiDH
  private aesKey?: Uint8Array
  private encrypted: boolean = false
  private checksum: boolean = false
  private requireAck: boolean = false
  private ackCallbacks: Map<number, () => void> = new Map()
  private textDecoder: util.TextDecoder = new util.TextDecoder()
  private textEncoder: util.TextEncoder = new util.TextEncoder()

  constructor(device: ble.ScanResult) {
    this.device = device
  }

  public getGattClientDevice(): ble.GattClientDevice | undefined {
    return this.gattClient
  }

  public setPostPackageLengthLimit(limit: number): number {
    if (limit < 0) {
      this.packageLengthLimit = -1
      return this.packageLengthLimit
    }

    this.packageLengthLimit = Math.min(
      Math.max(limit, PACKAGE_LENGTH_MIN),
      PACKAGE_LENGTH_MAX
    )
    return this.packageLengthLimit
  }

  public setBlufiCallback(callback?: BlufiCallback) {
    this.userBlufiCallback = callback
  }

  public connect() {
    try {
      const gattClient = ble.createGattClientDevice(this.device.deviceId)
      this.gattClient = gattClient

      gattClient.on('BLEConnectionStateChange', (state: ble.BLEConnectionChangeState) => {
        this.connectionState = state.state
        this.blufiMTU = -1

        this.userBlufiCallback?.onConnectionStateChange(state)

        switch (state.state) {
          case constant.ProfileConnectionState.STATE_CONNECTED:
            this.discoverServices()
            break
          case constant.ProfileConnectionState.STATE_DISCONNECTED:
            break
          case constant.ProfileConnectionState.STATE_CONNECTING:
          case constant.ProfileConnectionState.STATE_DISCONNECTING:
            break
        }
      })
      gattClient.on('BLECharacteristicChange', (characteristic: ble.BLECharacteristic) => {
        const consumed = this.userBlufiCallback?.onCharacteristicChange(characteristic) ?? false
        if (consumed) {
          return
        }
        if (equalsIgnoreCase(characteristic.characteristicUuid, this.blufiNotifyChar?.characteristicUuid)) {
          const value = new Uint8Array(characteristic.characteristicValue)
          if (!this.notifyData) {
            this.notifyData = new BlufiNotifyData()
          }
          const parseResult = this.parseNotification(value, this.notifyData)
          if (parseResult < 0) {
            this.userBlufiCallback?.onError(this, BlufiCode.INVALID_NOTIFICATION)
          } else if (parseResult === 0) {
            this.parseBlufiNotifyData(this.notifyData)
            this.notifyData = undefined
          } else if (parseResult === 1) {
            // has frag package, continue to wait
          }
        }
      })
      gattClient.connect()
    } catch (e) {
      this.userBlufiCallback?.onError(this, BlufiCode.GATT_CONNECT_FAILED)
    }
  }

  public close() {
    this.connectionState = constant.ProfileConnectionState.STATE_DISCONNECTED
    this.gattClient?.close()
    this.gattClient = undefined

    this.userBlufiCallback = undefined
  }

  private discoverServices() {
    try {
      this.gattClient?.getServices((error: BusinessError, gattServices: Array<ble.GattService>) => {
        if (error && error.code != 0) {
          hilog.error(LOG_DOMAIN, LOG_TAG, `discoverServices: ${error.code}, ${error.message}`)
          return
        }

        for (let service of gattServices) {
          if (equalsIgnoreCase(service.serviceUuid, BlufiUUIDs.UUID_SERVICE)) {
            this.blufiService = service
            break
          }
        }

        if (this.blufiService == undefined) {
          this.userBlufiCallback?.onError(this, BlufiCode.GATT_DISCOVER_SERVICE_FAILED)
        } else {
          this.setBLENotificationEnable()
        }
      })
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, "discoverServices: " + e)
      this.userBlufiCallback?.onError(this, BlufiCode.GATT_DISCOVER_SERVICE_FAILED)
    }

  }

  private setBLEMtu(mtu: number) {
    try {
      this.gattClient?.setBLEMtuSize(mtu)
      this.blufiMTU = mtu
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, "setBLEMtu: " + e)
    } finally {
      this.userBlufiCallback?.onGattPrepared(this, BlufiCode.STATUS_SUCCESS)
    }
  }

  private setBLENotificationEnable() {
    try {
      const charUUID = BlufiUUIDs.UUID_NOTIFICATION_CHARACTERISTIC
      const descBuffer = new ArrayBuffer(8)
      const descBufferArray = new Uint8Array(descBuffer)
      descBufferArray[0] = 11
      const descriptors: Array<ble.BLEDescriptor> = [
        {
          serviceUuid: this.blufiService!.serviceUuid,
          characteristicUuid: charUUID,
          descriptorUuid: BlufiUUIDs.UUID_NOTIFICATION_DESCRIPTOR,
          descriptorValue: descBuffer
        }
      ]
      this.blufiNotifyChar = {
        serviceUuid: this.blufiService!.serviceUuid,
        characteristicUuid: charUUID,
        characteristicValue: new ArrayBuffer(0),
        descriptors: descriptors
      }
      this.gattClient?.setCharacteristicChangeNotification(this.blufiNotifyChar, true, (error: BusinessError) => {
        if (error && error.code != 0) {
          hilog.error(LOG_DOMAIN, LOG_TAG, `setCharacteristicChangeNotification callback: ${error.code}, ${error.message}`)
          this.userBlufiCallback?.onError(this, BlufiCode.GATT_ERRO_OPEN_NOTIFY)
        } else {
          this.setBLEMtu(260)
        }
      })
    } catch (e) {
      let error = e as BusinessError
      hilog.error(LOG_DOMAIN, LOG_TAG, `setBLENotificationEnable: ${error.code}, ${error.message}`)
      this.userBlufiCallback?.onError(this, error.code)
    }
  }

  private isConnected(): boolean {
    return this.connectionState == constant.ProfileConnectionState.STATE_CONNECTED
  }

  public negotiateSecurity() {
    this.negotiatePostLength()
  }

  private negotiatePostLength() {
    const type = this.getTypeValue(PackageType.DATA, DataSubType.NEGOTIATE)

    const blufiDH = new BlufiDH(DH_P_BN, DH_G_BN, DH_BIT_LENGTH)

    const pgkLength = DH_P_LENGTH + DH_G_LENGTH + DH_KEY_LENGTH + 6
    const pgkLengthBytes = new Uint8Array([
      NEG_SECURITY_SET_TOTAL_LENGTH,
      (pgkLength >> 8) & 0xff,
      pgkLength & 0xff
    ])

    this.post(false, false, false, type, pgkLengthBytes, (success: boolean) => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, `negotiatePostLength: callback: ${success}`)
      if (success) {
        this.negotiatePostData(blufiDH)
      }
    })

  }

  private negotiatePostData(blufiDH: BlufiDH) {
    const type = this.getTypeValue(PackageType.DATA, DataSubType.NEGOTIATE)
    const dataBuilder = new ByteArrayBuilder(new Uint8Array([NEG_SECURITY_SET_ALL_DATA]))

    const pBytes = bigintToUint8Array(blufiDH.p, DH_P_LENGTH)
    const pLenBytes = new Uint8Array([
      (DH_P_LENGTH >> 8) & 0xff,
      DH_P_LENGTH & 0xff
    ])
    dataBuilder.append(pLenBytes).append(pBytes)

    const gBytes = bigintToUint8Array(blufiDH.g, DH_G_LENGTH)
    const gLenBytes = new Uint8Array([
      (DH_G_LENGTH >> 8) & 0xff,
      DH_G_LENGTH & 0xff
    ])
    dataBuilder.append(gLenBytes).append(gBytes)

    const kBytes = bigintToUint8Array(blufiDH.publicKey, DH_KEY_LENGTH)
    const kLenBytes = new Uint8Array([
      (DH_KEY_LENGTH >> 8) & 0xff,
      DH_KEY_LENGTH & 0xff
    ])
    dataBuilder.append(kLenBytes).append(kBytes)

    this.blufiDH = blufiDH
    this.post(false, false, false, type, dataBuilder.toByteArray(), (success: boolean) => {
      hilog.debug(LOG_DOMAIN, LOG_TAG, `negotiatePostData: callback: ${success}`)
      if (!success) {
        this.blufiDH = undefined
        this.userBlufiCallback?.onNegotiateSecurityResult(this, BlufiCode.NEG_ERR_POST_FAILED)
      }
    })
  }

  private postSetSecurity(ctrlEncrypted: boolean, ctrlChecksum: boolean, dataEncrypted: boolean, dataChecksum: boolean) {
    const type = this.getTypeValue(PackageType.CTRL, CtrlSubType.SET_SEC_MODE)
    let value = 0
    if (dataChecksum) {
      value |= 1
    }
    if (dataEncrypted) {
      value |= 0b10
    }
    if (ctrlChecksum) {
      value |= 0b10000
    }
    if (ctrlEncrypted) {
      value |= 0b100000
    }
    const data = new Uint8Array([value])
    this.post(false, true, false, type, data, (success: boolean) => {
      if (success) {
        this.encrypted = true
        this.checksum = true
        this.userBlufiCallback?.onNegotiateSecurityResult(this, BlufiCode.STATUS_SUCCESS)
      } else {
        this.encrypted = false
        this.checksum = false
        this.userBlufiCallback?.onNegotiateSecurityResult(this, BlufiCode.NEG_ERR_SET_SECURITY)
      }
    })
  }

  public requestCloseConnection() {
    const type = this.getTypeValue(PackageType.CTRL, CtrlSubType.CLOSE_CONNECTION)
    this.post(false, false, false, type)
  }

  public requestDeviceVersion() {
    const type = this.getTypeValue(PackageType.CTRL, CtrlSubType.GET_VERSION)
    this.post(this.encrypted, this.checksum, this.requireAck, type, undefined, (success: boolean) => {
      if (!success) {
        this.userBlufiCallback?.onError(this, BlufiCode.WRITE_DATA_FAILED)
      }
    })
  }

  public requestDeviceStatus() {
    const type = this.getTypeValue(PackageType.CTRL, CtrlSubType.GET_WIFI_STATUS)
    this.post(this.encrypted, this.checksum, this.requireAck, type, undefined, (success: boolean) => {
      if (!success) {
        this.userBlufiCallback?.onError(this, BlufiCode.WRITE_DATA_FAILED)
      }
    })
  }

  public requestDeviceWifiScan() {
    const type = this.getTypeValue(PackageType.CTRL, CtrlSubType.GET_WIFI_LIST)
    this.post(this.encrypted, this.checksum, this.requireAck, type, undefined, (success: boolean) => {
      if (!success) {
        this.userBlufiCallback?.onError(this, BlufiCode.WRITE_DATA_FAILED)
      }
    })
  }

  public postCustomData(data: Uint8Array) {
    const type = this.getTypeValue(PackageType.DATA, DataSubType.CUSTOM_DATA)
    this.post(this.encrypted, this.checksum, this.requireAck, type, data, (success: boolean) => {
      const code = success ? BlufiCode.STATUS_SUCCESS : BlufiCode.WRITE_DATA_FAILED
      this.userBlufiCallback?.onPostCustomDataResult(this, code, data)
    })
  }

  public configure(params: BlufiConfigureParams) {
    switch (params.opMode) {
      case OpMode.MODE_NULL:
      case OpMode.MODE_STA:
      case OpMode.MODE_SOFTAP:
      case OpMode.MODE_STASOFTAP:
        this.postSetOpMode(params)
        break
      default:
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_INVALID_OPMODE)
        break
    }
  }

  private postSetOpMode(params: BlufiConfigureParams) {
    const opMode = params.opMode
    const type = this.getTypeValue(PackageType.CTRL, CtrlSubType.SET_OP_MODE)
    const data = new Uint8Array([opMode])
    this.post(this.encrypted, this.checksum, this.requireAck, type, data, (setSuccess: boolean) => {
      if (!setSuccess) {
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERR_SET_OPMODE)
        return
      }
      this.postConfigureParamsData(params)
    })
  }

  private postConfigureParamsData(params: BlufiConfigureParams) {
    switch (params.opMode) {
      case OpMode.MODE_NULL:
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.STATUS_SUCCESS)
        break
      case OpMode.MODE_STA:
        this.postStaWifiInfo(params, () => {
          this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.STATUS_SUCCESS)
        })
        break
      case OpMode.MODE_SOFTAP:
        this.postSoftApInfo(params, () => {
          this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.STATUS_SUCCESS)
        })
        break
      case OpMode.MODE_STASOFTAP:
        this.postStaWifiInfo(params, () => {
          this.postSoftApInfo(params, () => {
            this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.STATUS_SUCCESS)
          })
        })
        break
    }
  }

  private postStaWifiInfo(params: BlufiConfigureParams, sucCallback: () => void) {
    this.postStaSSID(params, () => {
      this.postStaPassword(params, () => {
        this.postStaConfirmation(() => {
          sucCallback()
        })
      })
    })
  }

  private postStaSSID(params: BlufiConfigureParams, sucCallback: () => void) {
    const ssid = params.staSSID
    if (!ssid) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "postStaSSID: ssid is empty")
      this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERR_POST_STA)
      return
    }
    const ssidType = this.getTypeValue(PackageType.DATA, DataSubType.STA_WIFI_SSID)
    const ssidBytes = this.textEncoder.encodeInto(ssid)
    this.post(this.encrypted, this.checksum, this.requireAck, ssidType, ssidBytes, (success: boolean) => {
      if (!success) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "postStaSSID: failed")
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERR_POST_STA)
        return
      }
      sucCallback()
    })
  }

  private postStaPassword(params: BlufiConfigureParams, sucCallback: () => void) {
    const password = params.staPassword ? params.staPassword : ""
    const passwordType = this.getTypeValue(PackageType.DATA, DataSubType.STA_WIFI_PASSWORD)
    const passwordBytes = this.textEncoder.encodeInto(password)
    this.post(this.encrypted, this.checksum, this.requireAck, passwordType, passwordBytes, (success: boolean) => {
      if (!success) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "postStaPassword: failed")
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERR_POST_STA)
        return
      }
      sucCallback()
    })
  }

  private postStaConfirmation(sucCallback: () => void) {
    const confirmType = this.getTypeValue(PackageType.CTRL, CtrlSubType.CONNECT_WIFI)
    this.post(false, false, this.requireAck, confirmType, undefined, (success: boolean) => {
      if (!success) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "postStaSSID: failed")
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERR_POST_STA)
        return
      }
      sucCallback()
    })
  }

  private postSoftApInfo(params: BlufiConfigureParams, sucCallback: () => void) {
    this.postSoftApSSID(params, () => {
      this.postSoftApPassword(params, () => {
        this.postSoftApChannel(params, () => {
          this.postSoftApMaxConnection(params, () => {
            this.postSoftApSecurityMode(params, () => {
              sucCallback()
            })
          })
        })
      })
    })
  }

  private postSoftApSSID(params: BlufiConfigureParams, sucCallback: () => void) {
    const softApSSID = params.softApSSID
    if (softApSSID) {
      const ssidType = this.getTypeValue(PackageType.DATA, DataSubType.SOFTAP_WIFI_SSID)
      const ssidBytes = this.textEncoder.encodeInto(softApSSID)
      this.post(this.encrypted, this.checksum, this.requireAck, ssidType, ssidBytes, (success: boolean) => {
        if (!success) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, "postSoftApSSID: failed")
          return
        }
        sucCallback()
      })
    } else {
      sucCallback()
    }
  }

  private postSoftApPassword(params: BlufiConfigureParams, sucCallback: () => void) {
    const softApPassword = params.softApPassword
    if (softApPassword) {
      const passwordType = this.getTypeValue(PackageType.DATA, DataSubType.SOFTAP_WIFI_PASSWORD)
      const passwordBytes = this.textEncoder.encodeInto(softApPassword)
      this.post(this.encrypted, this.checksum, this.requireAck, passwordType, passwordBytes, (success: boolean) => {
        if (!success) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, "postSoftApPassword: failed")
          return
        }
        sucCallback()
      })
    } else {
      sucCallback()
    }
  }

  private postSoftApChannel(params: BlufiConfigureParams, sucCallback: () => void) {
    const softApChannel = params.softApChannel
    if (softApChannel > 0) {
      const channelType = this.getTypeValue(PackageType.DATA, DataSubType.SOFTAP_CHANNEL)
      const channelBytes = new Uint8Array([softApChannel])
      this.post(this.encrypted, this.checksum, this.requireAck, channelType, channelBytes, (success: boolean) => {
        if (!success) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, "postSoftApChannel: failed")
          return
        }
        sucCallback()
      })
    } else {
      sucCallback()
    }
  }

  private postSoftApMaxConnection(params: BlufiConfigureParams, sucCallback: () => void) {
    const maxConn = params.softApMaxConnection
    if (maxConn > 0) {
      const maxConnType = this.getTypeValue(PackageType.DATA, DataSubType.SOFTAP_MAX_CONNECTION_COUNT)
      const maxConnBytes = new Uint8Array([maxConn])
      this.post(this.encrypted, this.checksum, this.requireAck, maxConnType, maxConnBytes, (success: boolean) => {
        if (!success) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, "postSoftApMaxConnection: failed")
          return
        }
        sucCallback()
      })
    } else {
      sucCallback()
    }
  }

  private postSoftApSecurityMode(params: BlufiConfigureParams, sucCallback: () => void) {
    const security = params.softApSecurity
    switch (security) {
      case SoftApSecurity.OPEN:
      case SoftApSecurity.WEP:
      case SoftApSecurity.WPA:
      case SoftApSecurity.WPA2:
      case SoftApSecurity.WPA_WPA2:
        break
      default:
        hilog.warn(LOG_DOMAIN, LOG_TAG, "postSoftApSecurityMode: invalid security: " + security)
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERROR_POST_SOFTAP)
        break
    }

    const securityType = this.getTypeValue(PackageType.DATA, DataSubType.SOFTAP_AUTH_MODE)
    const securityBytes = new Uint8Array([security])
    this.post(this.encrypted, this.checksum, this.requireAck, securityType, securityBytes, (success: boolean) => {
      if (!success) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "postSoftApSecurityMode: failed")
        this.userBlufiCallback?.onPostConfigureParams(this, BlufiCode.CONF_ERROR_POST_SOFTAP)
        return
      }
      sucCallback()
    })
  }

  private post(
    encrypt: boolean,
    checksum: boolean,
    requireAck: boolean,
    type: number,
    data?: Uint8Array,
    callback?: PostCallback
  ) {
    if (!data || data.length === 0) {
      this.postWithoutData(encrypt, checksum, requireAck, type, callback)
    } else {
      this.postWithData(encrypt, checksum, requireAck, type, data, callback)
    }
  }

  private postWithoutData(
    encrypt: boolean,
    checksum: boolean,
    requireAck: boolean,
    type: number,
    callback?: PostCallback
  ) {
    const sequence = this.generateSendSequence()
    const postBytes = this.getPostBytes(type, encrypt, checksum, requireAck, false, sequence)
    this.gattWrite(postBytes, sequence, requireAck, callback)
  }

  private postWithData(
    encrypt: boolean,
    checksum: boolean,
    requireAck: boolean,
    type: number,
    data: Uint8Array,
    callback?: PostCallback
  ) {
    const dataIS = new ByteArrayInputStream(data)
    const pkgLengthLimit = this.packageLengthLimit > 0 ? this.packageLengthLimit :
      (this.blufiMTU > 0 ? this.blufiMTU : PACKAGE_LENGTH_DEFAULT)
    let postDataLengthLimit = pkgLengthLimit - PACKAGE_HEADER_LENGTH
    postDataLengthLimit -= 2
    if (checksum) {
      postDataLengthLimit -= 2
    }
    const dataBuf = new Uint8Array(postDataLengthLimit)
    const sendDataFunc = () => {
      let read = dataIS.read(dataBuf, 0, dataBuf.length)
      if (read == -1) {
        return
      }

      const dataBuilder = new ByteArrayBuilder()
      dataBuilder.append(dataBuf, 0, read)
      if (dataIS.available() > 0 && dataIS.available() <= 2) {
        read = dataIS.read(dataBuf, 0, dataIS.available())
        dataBuilder.append(dataBuf, 0, read)
      }

      const sequence = this.generateSendSequence()
      const frag = dataIS.available() > 0
      let totalLenData: Uint8Array | undefined = undefined
      if (frag) {
        const totalLen = dataBuilder.length() + dataIS.available()
        totalLenData = new Uint8Array([
          totalLen & 0xff,
          (totalLen >> 8) & 0xff
        ])
      }
      const dataBytes: Uint8Array = totalLenData == undefined ? dataBuilder.toByteArray() :
        (new ByteArrayBuilder(totalLenData).append(dataBuilder.toByteArray()).toByteArray())

      const postBytes = this.getPostBytes(type, encrypt, checksum, requireAck, frag, sequence, dataBytes)
      this.gattWrite(postBytes, sequence, requireAck, (success: boolean) => {
        if (!success) {
          // 发送失败，停止
          if (callback) {
            callback(false)
          }
          return
        }

        // 发送成功，继续
        if (dataIS.available() > 0) {
          // 数据还未发完，继续发送下一包
          sendDataFunc()
          return
        }

        if (callback) {
          // 数据成功发完
          callback(true)
        }
      })
    }
    sendDataFunc()
  }

  private getPostBytes(
    type: number,
    encrypt: boolean,
    checksum: boolean,
    requireAck: boolean,
    hasFrag: boolean,
    sequence: number,
    data?: Uint8Array
  ): Uint8Array {
    const dataLength = data ? data.length : 0
    const frameCtrl = FrameCtrlData.getFrameCTRLValue(encrypt, checksum, DataDirection.OUTPUT, requireAck, hasFrag)
    const header = new Uint8Array([type, frameCtrl, sequence, dataLength])

    const byteArrayBuilder = new ByteArrayBuilder(header)

    let checksumBytes: Uint8Array | undefined = undefined
    if (checksum) {
      let crc = calcCRC(0, [sequence, dataLength])
      if (dataLength > 0) {
        crc = calcCRC(crc, data!)
      }

      checksumBytes = new Uint8Array([crc & 0xff, (crc >> 8) & 0xff])
    }

    if (encrypt && dataLength > 0) {
      const aes = new BlufiAES(this.aesKey!, this.generateAESIV(sequence))
      data = aes.encrypt(data!)
    }
    if (dataLength > 0) {
      byteArrayBuilder.append(data!)
    }

    if (checksumBytes) {
      byteArrayBuilder.append(checksumBytes)
    }

    return byteArrayBuilder.toByteArray()
  }

  private gattWrite(data: Uint8Array, sequence: number, requireAck: boolean, callback?: PostCallback) {
    if (!this.isConnected) {
      return
    }

    let writeChar: ble.BLECharacteristic = {
      serviceUuid: this.blufiService!.serviceUuid,
      characteristicUuid: BlufiUUIDs.UUID_WRITE_CHARACTERISTIC,
      characteristicValue: data.buffer,
      descriptors: []
    }
    if (requireAck) {
      this.ackCallbacks.set(sequence, () => {
        if (callback) {
          callback(true)
        }
      })
    }
    this.gattClient?.writeCharacteristicValue(
      writeChar,
      ble.GattWriteType.WRITE,
      (error: BusinessError) => {
        const failed = error && error.code != 0
        if (failed) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, `gattWrite writeCharacteristicValue: ${error.code}, ${error.message}`)
        }
        if (callback) {
          if (failed) {
            // 有错误
            callback(false)
          } else if (!requireAck) {
            // 不需要 ack
            callback(true)
          } // else 等待 ack 回调
        }
      }
    )
  }

  private getTypeValue(packageType: number, subType: number): number {
    return (subType << 2) | packageType
  }

  private generateSendSequence(): number {
    this.sendSequence++
    return this.sendSequence & 0xff
  }

  private generateReadSequence(): number {
    this.readSequence++
    return this.readSequence & 0xff
  }

  private generateAESIV(sequence: number) {
    let iv = new Uint8Array(16)
    iv[0] = sequence & 0xff
    return iv
  }

  private parseNotification(response: Uint8Array | undefined | null, notification: BlufiNotifyData) {
    if (!response) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNotification null data")
      return -1
    }
    if (response.length < 4) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNotification data length is less than 4")
      return -2
    }

    const sequence = response[2]
    if (sequence !== this.generateReadSequence()) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNotification read wrong sequence")
      return -3
    }

    const type = response[0]
    notification.updateTypeValue(type)

    const frameCtrl = response[1]
    notification.frameCtrlValue = frameCtrl
    const frameCtrlData = new FrameCtrlData(frameCtrl)

    const dataLen = response[3]
    let dataBytes = response.slice(PACKAGE_HEADER_LENGTH, PACKAGE_HEADER_LENGTH + dataLen)
    if (dataLen !== dataBytes.length) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, `parseNotification read wrong data: ${dataLen} | ${dataBytes.length}`)
      return -100
    }

    if (frameCtrlData.isEncrypted()) {
      const aes = new BlufiAES(this.aesKey!, this.generateAESIV(sequence))
      dataBytes = aes.decrypt(dataBytes)
    }

    if (frameCtrlData.isChecksum()) {
      let crc = calcCRC(0, [sequence, dataLen])
      crc = calcCRC(crc, dataBytes)

      const respChecksum = (response[response.length - 1] << 8) | response[response.length - 2]
      if (crc !== respChecksum) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNotification read wrong crc")
      }
    }

    const dataOffset: number = frameCtrlData.hasFrag() ? 2 : 0
    notification.appendData(dataBytes, dataOffset)

    return frameCtrlData.hasFrag() ? 1 : 0
  }

  private parseBlufiNotifyData(data: BlufiNotifyData) {
    const pkgType = data.pkgType
    const subType = data.subType
    const dataBytes = data.getDataArray()

    switch (pkgType) {
      case PackageType.CTRL:
        this.parseCtrlData(subType, dataBytes)
        break
      case PackageType.DATA:
        this.parseDataData(subType, dataBytes)
        break
    }
  }

  private parseCtrlData(subType: CtrlSubType, data: Uint8Array) {
    if (subType === CtrlSubType.ACK) {
      const ack = data[0]
      this.parseAck(ack)
    }
  }

  private parseAck(ack: number) {
    const ackCallback = this.ackCallbacks.get(ack)
    if (ackCallback) {
      this.ackCallbacks.delete(ack)
      ackCallback()
    }
  }

  private parseDataData(subType: DataSubType, data: Uint8Array) {
    switch (subType) {
      case DataSubType.NEGOTIATE:
        this.parseNegotiate(data)
        break
      case DataSubType.VERSION:
        this.parseVersion(data)
        break
      case DataSubType.WIFI_CONNECTION_STATE:
        this.parseWifiState(data)
        break
      case DataSubType.WIFI_LIST:
        this.parseWifiScanList(data)
        break
      case DataSubType.CUSTOM_DATA:
        this.userBlufiCallback?.onReceiveCustomData(this, BlufiCode.STATUS_SUCCESS, data)
        break
      case DataSubType.ERROR:
        this.parseError(data)
        break
    }
  }

  private parseNegotiate(data: Uint8Array) {
    if (data.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNegotiate data empty")
      this.userBlufiCallback?.onNegotiateSecurityResult(this, BlufiCode.NEG_ERR_DEVICE_KEY)
      return
    }

    const blufiDH = this.blufiDH
    if (!blufiDH) {
      return
    }
    const deviceKeyBN = uint8ArrayToBigInt(data)
    try {
      blufiDH.generateSecret(deviceKeyBN)
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNegotiate generate secret error: " + e)
      this.userBlufiCallback?.onNegotiateSecurityResult(this, BlufiCode.NEG_ERR_SECURITY)
      return
    }
    const secret = blufiDH.secretKey!
    if (!secret) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseNegotiate generate secret failed")
      this.userBlufiCallback?.onNegotiateSecurityResult(this, BlufiCode.NEG_ERR_SECURITY)
      return
    }
    this.aesKey = getMD5Bytes(secret)

    this.postSetSecurity(false, false, true, true)
  }
  
  private parseVersion(data: Uint8Array) {
    if (data.length !== 2) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseVersion: wrong data")
      this.userBlufiCallback?.onDeviceVersionResponse(this, BlufiCode.INVALID_DATA)
      return
    }

    const response = new BlufiVersionResponse(data[0], data[1])
    this.userBlufiCallback?.onDeviceVersionResponse(this, BlufiCode.STATUS_SUCCESS, response)
  }

  private parseWifiState(data: Uint8Array) {
    if (data.length < 3) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, "parseWifiState length error")
      this.userBlufiCallback?.onDeviceStatusResponse(this, BlufiCode.INVALID_DATA)
      return
    }

    const response = new BlufiStatusResponse()
    const dataIS = new ByteArrayInputStream(data)
    response.opMode = dataIS.readUint8()
    response.staConnectionStatus = dataIS.readUint8()
    response.softApConnectionCount = dataIS.readUint8()

    while (dataIS.available() > 0) {
      const infoType = dataIS.readUint8()
      const len = dataIS.readUint8()
      const stateBytes = new Uint8Array(len)
      const read = dataIS.read(stateBytes, 0, len)
      if (read !== len) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "parseWifiState data error")
        this.userBlufiCallback?.onDeviceStatusResponse(this, BlufiCode.INVALID_DATA)
        return
      }
      this.parseWifiStateData(response, infoType, stateBytes)
    }

    this.userBlufiCallback?.onDeviceStatusResponse(this, BlufiCode.STATUS_SUCCESS, response)
  }

  private parseWifiStateData(response: BlufiStatusResponse, infoType: DataSubType, data: Uint8Array) {
    switch (infoType) {
      case DataSubType.STA_WIFI_BSSID:
        response.staBSSID = uint8ArrayToHexString(data)
        break
      case DataSubType.STA_WIFI_SSID:
        response.staSSID = this.textDecoder.decodeToString(data)
        break
      case DataSubType.STA_WIFI_PASSWORD:
        response.staPassword = this.textDecoder.decodeToString(data)
        break
      case DataSubType.SOFTAP_AUTH_MODE:
        response.softApSecurity = data[0]
        break
      case DataSubType.SOFTAP_CHANNEL:
        response.softApChannel = data[0]
        break
      case DataSubType.SOFTAP_MAX_CONNECTION_COUNT:
        response.softApMaxConnectionCount = data[0]
        break
      case DataSubType.SOFTAP_WIFI_PASSWORD:
        response.softApPassword = this.textDecoder.decodeToString(data)
        break
      case DataSubType.SOFTAP_WIFI_SSID:
        response.softApSSID = this.textDecoder.decodeToString(data)
        break
      case DataSubType.STA_WIFI_MAX_CONN_RETRY:
        response.connectionMaxRetry = data[0]
        break
      case DataSubType.WIFI_CONN_END_REASON:
        response.connectionEndReason = data[0]
        break
      case DataSubType.STA_WIFI_CONN_RSSI:
        response.connectionRssi = uint8ToInt8(data[0])
        break
    }
  }

  private parseWifiScanList(data: Uint8Array) {
    const result: BlufiScanResult[] = []

    const dataReader = new ByteArrayInputStream(data)
    while (dataReader.available() > 0) {
      const length = dataReader.readUint8()
      if (length < 1) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "parseWifiScanList invalid length")
        break
      }

      const rssi = dataReader.readUint8()
      const ssidBytes = new Uint8Array(length - 1)
      const ssidRead = dataReader.read(ssidBytes)
      if (ssidRead !== ssidBytes.length) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, "parseWifiScanList invalid ssid data")
        break
      }
      const ssidStr = this.textDecoder.decodeToString(ssidBytes)

      const sr = new BlufiScanResult(BlufiScanResult.TYPE_WIFI, ssidStr, uint8ToInt8(rssi))
      result.push(sr)
    }

    this.userBlufiCallback?.onDeviceScanResult(this, BlufiCode.STATUS_SUCCESS, result)
  }

  private parseError(data: Uint8Array) {
    const errCode = data.length > 0 ? data[0] : 0xff
    this.userBlufiCallback?.onError(this, errCode)
  }
}