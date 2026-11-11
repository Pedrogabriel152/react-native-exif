import ReactNativeExif from './NativeReactNativeExif';

export function getLatLong(path: string) {
  return ReactNativeExif.getLatLong(path);
}

export function getExif(path: string) {
  return ReactNativeExif.getExif(path);
}
