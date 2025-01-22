import { arrayCopy } from "./BlufiUtils"

export class ByteArrayInputStream {
  private array: Uint8Array
  private count: number
  private pos: number

  constructor(array: Uint8Array) {
    this.array = array
    this.count = array.length
    this.pos = 0
  }

  public read(buf: Uint8Array, off: number = 0, len: number = buf.byteLength): number {
    if (this.pos >= this.count) {
      return -1
    }

    let avail = this.count - this.pos
    if (len > avail) {
      len = avail
    }
    if (len <= 0) {
      return 0
    }

    arrayCopy(this.array, this.pos, buf, off, len)
    this.pos += len
    return len
  }

  public readUint8(): number {
    return (this.pos < this.count) ? (this.array[this.pos++] & 0xff) : -1
  }

  public readUint8Array(len: number): Uint8Array {
    const retLen = Math.min(this.available(), len)
    const ret = new Uint8Array(retLen)
    this.read(ret)
    return ret
  }

  public available(): number {
    return this.count - this.pos
  }

  public reset() {
    this.pos = 0
  }
}