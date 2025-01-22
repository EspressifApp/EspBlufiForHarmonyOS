import { ByteArrayBuilder } from './ByteArrayBuilder'

export class BlufiNotifyData {
  public typeValue: number
  public pkgType: number
  public subType: number
  public frameCtrlValue: number
  public dataBuilder: ByteArrayBuilder

  constructor() {
    this.typeValue = 0
    this.pkgType = 0
    this.subType = 0
    this.frameCtrlValue = 0
    this.dataBuilder = new ByteArrayBuilder()
  }

  public updateTypeValue(typeValue: number) {
    this.typeValue = typeValue
    this.pkgType = typeValue & 0b11
    this.subType = (typeValue & 0b11111100) >> 2
  }

  public appendData(data: Uint8Array, offset: number) {
    this.dataBuilder.append(data, offset)
  }

  public getDataArray(): Uint8Array {
    return this.dataBuilder.toByteArray()
  }
}