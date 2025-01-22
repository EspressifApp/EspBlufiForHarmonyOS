import { cryptoFramework } from "@kit.CryptoArchitectureKit";

export function getMD5Bytes(data: Uint8Array): Uint8Array {
  let md = cryptoFramework.createMd("MD5")
  md.updateSync({ data: data })
  return md.digestSync().data
}