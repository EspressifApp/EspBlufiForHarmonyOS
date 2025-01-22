export function bigintToUint8Array(bn: bigint, byteLength: number): Uint8Array {
  const arr = new Uint8Array(byteLength)
  for (let i = 0; i < byteLength; i++) {
    arr[byteLength - i - 1] = Number(bn & BigInt(0xff))
    bn >>= BigInt(8)
  }
  return arr
}

export function uint8ArrayToBigInt(bytes: Uint8Array): bigint {
  let result = 0n
  for (const byte of bytes) {
    result = (result << 8n) | BigInt(byte)
  }
  return result
}

export function uint8ArrayToHexString(arr: Uint8Array): string {
  let hex = ""
  for (let index = 0; index < arr.length; index++) {
    const b = arr[index];
    let str = b.toString(16)
    if (str.length === 1) {
      str = "0" + str
    }
    hex += str
  }
  return hex
}

export function uint8ToInt8(value: number): number {
  value = value & 0xff
  return value <= 127 ? value : value - 256
}

export function arrayCopy(src: Uint8Array, srcPos: number, dest:Uint8Array, destPos: number, length: number) {
  for (let i = 0; i < length; i++) {
    dest[i + destPos] = src[i + srcPos]
  }
}

export function equalsIgnoreCase(s1: string | undefined, s2: string | undefined): boolean {
  if (s1) {
    s1 = s1.toLowerCase()
  }
  if (s2) {
    s2 = s2.toLowerCase()
  }
  return s1 == s2
}