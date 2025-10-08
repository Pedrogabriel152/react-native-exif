import ReactNativeExif from './NativeReactNativeExif';

export function multiply(a: number, b: number): number {
  return ReactNativeExif.multiply(a, b);
}

export function getLatLong(path: string) {
  return ReactNativeExif.getLatLong(path);
}

export function getExif(path: string) {
  return ReactNativeExif.getExif(path);
}
