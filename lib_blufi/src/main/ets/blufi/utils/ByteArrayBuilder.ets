import { arrayCopy } from "./BlufiUtils"

export class ByteArrayBuilder {
  private data: Uint8Array

  constructor(data?: Uint8Array) {
    this.data = data == undefined ? new Uint8Array(0) : data.slice()
  }

  public append(arr: Uint8Array, offset: number = 0, length: number = arr.length): ByteArrayBuilder {
    const combined = new Uint8Array(this.data.length + length)
    combined.set(this.data, 0)
    arrayCopy(arr, offset, combined, this.data.length, length)
    this.data = combined
    return this
  }

  public length(): number {
    return this.data.length
  }

  public toByteArray(): Uint8Array {
    return this.data
  }
}