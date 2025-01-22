import { ConnectionEndReason, OpMode, SoftApSecurity, StaConnectionStatus } from "../params/BlufiConstatnts"

export class BlufiStatusResponse {
  public opMode: number = -1
  public softApSecurity: SoftApSecurity = -1
  public softApConnectionCount: number = -1
  public softApMaxConnectionCount: number = -1
  public softApChannel: number = -1
  public softApPassword?: string
  public softApSSID?: string
  public staConnectionStatus: StaConnectionStatus = -1
  public staBSSID?: string
  public staSSID?: string
  public staPassword?: string
  private readonly connectionRssiLimit = -60
  public connectionMaxRetry: number = -1
  public connectionEndReason: ConnectionEndReason = -1
  public connectionRssi: number = -128

  private isReasonValid(reason: number): boolean {
    return (reason >= 0 && reason <= 24) || reason == 53 || (reason >= 200 && reason <= 207)
  }

  private isRssiValid(rssi: number): boolean {
    return rssi > -128 && rssi <= 127
  }

  private getEndInfo(): string {
    let msg = "Reason code: "
    msg += this.isReasonValid(this.connectionEndReason) ? this.connectionEndReason : "N/A"
    msg += ", Rssi: "
    msg += this.isRssiValid(this.connectionRssi) ? this.connectionRssi : "N/A"
    msg += "\n"

    if (this.connectionEndReason == ConnectionEndReason.WIFI_REASON_NO_AP_FOUND) {
      msg += "NO AP FOUND"
    } else if (this.connectionEndReason == ConnectionEndReason.WIFI_REASON_CONNECTION_FAIL) {
      msg += "AP IN BLACKLIST, PLEASE RETRY"
    } else if (this.isRssiValid(this.connectionRssi)) {
      if (this.connectionRssi < this.connectionRssiLimit) {
        msg += "RSSI IS TO LOW"
      } else if (this.connectionEndReason == ConnectionEndReason.WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT ||
        this.connectionEndReason == ConnectionEndReason.WIFI_REASON_HANDSHAKE_TIMEOUT) {
        msg += "WRONG PASSWORD"
      }
    }
    msg += "\n"

    return msg
  }

  private getConnectingInfo(): string {
    let msg = "Max Retry is "
    if (this.connectionMaxRetry < 0) {
      msg += "N/A"
    } else {
      msg += this.connectionMaxRetry
    }
    msg += "\n"

    return msg
  }

  public isStaConnectWifi(): boolean {
    return this.staConnectionStatus == StaConnectionStatus.CONN_SUCCESS
  }

  public generateStatusInfo(): string {
    let info = "OpMode: "
    switch (this.opMode) {
      case OpMode.MODE_NULL:
        info += "NULL"
        break
      case OpMode.MODE_STA:
        info += "Station"
        break
      case OpMode.MODE_SOFTAP:
        info += "SoftAP"
        break
      case OpMode.MODE_STASOFTAP:
        info += "Station/SoftAP"
        break
    }
    info += "\n"
    switch (this.opMode) {
      case OpMode.MODE_STA:
      case OpMode.MODE_STASOFTAP:
        switch (this.staConnectionStatus) {
          case StaConnectionStatus.CONN_SUCCESS:
            info += "Station connect Wi-Fi now, got IP\n"
            break
          case StaConnectionStatus.CONN_NO_IP:
            info += "Station connect Wi-Fi now, no IP found\n"
            break
          case StaConnectionStatus.CONN_FAIL:
            info += "Station disconnect Wi-Fi now\n"
            info += this.getEndInfo()
            break
          default:
            info += "Station is connecting WiFi now\n"
            info += this.getConnectingInfo()
            break
        }
        if (this.staBSSID != undefined) {
          info = info + "Station connect Wi-Fi bssid: " + this.staBSSID + "\n"
        }
        if (this.staSSID != undefined) {
          info = info + "Station connect Wi-Fi ssid: " + this.staSSID + "\n"
        }
        if (this.staPassword != undefined) {
          info = info + "Station connect Wi-Fi password: " + this.staPassword + "\n"
        }
        break
    }

    switch (this.opMode) {
      case OpMode.MODE_SOFTAP:
      case OpMode.MODE_STASOFTAP:
        switch (this.softApSecurity) {
          case SoftApSecurity.OPEN:
            info += "SoftAP security: OPEN\n"
            break
          case SoftApSecurity.WEP:
            info += "SoftAP security: WEP\n"
            break
          case SoftApSecurity.WPA:
            info += "SoftAP security: WPA\n"
            break
          case SoftApSecurity.WPA2:
            info += "SoftAP security: WPA2\n"
            break
          case SoftApSecurity.WPA_WPA2:
            info += "SoftAP security: WAP/WPA2\n"
            break
        }
        if (this.softApSSID != undefined) {
          info = info + "SoftAP ssid: " + this.softApSSID + "\n"
        }
        if (this.softApPassword != undefined) {
          info = info + "SoftAP password: " + this.softApPassword + "\n"
        }
        if (this.softApChannel >= 0) {
          info = info + "SoftAP channel: " + this.softApChannel + "\n"
        }
        if (this.softApMaxConnectionCount > 0) {
          info = info + "SoftAP max connection: " + this.softApMaxConnectionCount + "\n"
        }
        if (this.softApConnectionCount) {
          info = info + "SoftAP current connection: " + this.softApConnectionCount + "\n"
        }
        break
    }

    let endIndex = info.length
    while (endIndex > 0 && info[endIndex - 1] == '\n') {
      endIndex--
    }

    if (endIndex == info.length) {
      return info
    } else {
      return info.slice(0, endIndex)
    }
  }
}