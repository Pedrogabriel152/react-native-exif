# React Native Exif

Read EXIF metadata and GPS coordinates from images on Android and iOS, with
native implementations built on `androidx.exifinterface` (Android) and
`ImageIO` / `Photos` (iOS).

- Works with file paths, `file://`, `content://` (Android) and `ph://` /
  `assets-library://` (iOS photo library).
- Only reads the metadata blocks, never loads the whole image into memory.
- Reads run off the JS and native-modules threads, in parallel.
- Batch APIs read many images in a single native call.

## Requirements

- React Native **0.81+** with the New Architecture (TurboModules)
- iOS 13.4+
- Android `minSdkVersion` 24+

## Installation

```sh
yarn add @pedro.gabriel/react-native-exif
# or
npm install @pedro.gabriel/react-native-exif
```

iOS:

```sh
cd ios && pod install
```

Autolinking handles the rest. `react-native link` is not needed.

## Permissions

The library does not request permissions. Ask for them in your app before
reading images.

**iOS:** to read `ph://` / `assets-library://` assets, add the following to
`Info.plist`. The library only shows the permission prompt if the user has not
decided yet.

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to read the location and metadata of your photos.</string>
```

**Android:** to read images from the media store (`content://`):

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />
```

> **Known limitation (Android 10+):** for `content://` URIs from the media
> store, Android hides GPS tags unless the URI was opened with
> `MediaStore.setRequireOriginal`. The library does not do this yet, so
> `getLatLong` may return `0, 0` for those URIs. File paths are not affected.

## Supported paths

| Path                                     | Android | iOS |
| ---------------------------------------- | :-----: | :-: |
| `/absolute/path/photo.jpg`               |   ✅    | ✅  |
| `file:///absolute/path/photo.jpg`        |   ✅    | ✅  |
| `content://media/external/images/...`    |   ✅    |  —  |
| `ph://<localIdentifier>`                 |    —    | ✅  |
| `assets-library://asset/asset.JPG?id=…`  |    —    | ✅  |

> **Tip (iOS):** when using an image picker, pass `ph://${asset.id}` instead
> of the temporary file `uri`. Picker copies may be re-encoded and lose
> their EXIF data. With `ph://`, `getLatLong` reads the location straight from
> the Photos database without opening the file.

## Usage

```ts
import {
  getExif,
  getLatLong,
  getExifBatch,
  getLatLongBatch,
} from '@pedro.gabriel/react-native-exif';
```

### getExif(path)

Returns every [supported tag](#returned-tags) plus `originalUri`.

```ts
const exif = await getExif('/sdcard/DCIM/photo.jpg');
console.log(exif.Make, exif.Model, exif.DateTimeOriginal);
```

Rejects with code `EXIF_ERROR` if the image cannot be opened.

### getLatLong(path)

Returns signed decimal coordinates (south and west are negative).

```ts
const { latitude, longitude } = await getLatLong(
  'content://media/external/images/media/111'
);
```

If the image has no GPS data, it resolves with `{ latitude: 0, longitude: 0 }`.
Rejects with `EXIF_ERROR` if the image cannot be opened.

### getExifBatch(paths)

Reads many images in **one native call**, in parallel. The promise **always
resolves**: each item carries either `data` or `error`, so one bad file does
not fail the whole batch. Results come back in the same order as `paths`.

```ts
const results = await getExifBatch([
  '/sdcard/DCIM/a.jpg',
  '/sdcard/DCIM/missing.jpg',
]);

// [
//   { path: '/sdcard/DCIM/a.jpg',       data: { Make: 'Apple', ... }, error: null },
//   { path: '/sdcard/DCIM/missing.jpg', data: null, error: '… (No such file or directory)' },
// ]

for (const { path, data, error } of results) {
  if (error) {
    console.warn(`Could not read ${path}: ${error}`);
  } else {
    console.log(path, data.DateTimeOriginal);
  }
}
```

### getLatLongBatch(paths)

Same as `getExifBatch`, but each `data` is `{ latitude, longitude }` (`0, 0`
when the image has no GPS).

```ts
const photos = result.assets ?? []; // e.g. from react-native-image-picker
const paths = photos.map((a) => (Platform.OS === 'ios' ? `ph://${a.id}` : a.uri!));

const locations = await getLatLongBatch(paths);
const withGps = locations.filter(
  (item) => item.data && (item.data.latitude !== 0 || item.data.longitude !== 0)
);
```

On iOS, the photo library permission is checked **once per batch**, and all
`ph://` assets are looked up in a single query.

### Types

```ts
type ExifData = Record<string, string | number | null>;
type LatLong = { latitude: number; longitude: number };
type BatchItem<T> = { path: string; data: T | null; error: string | null };
```

## Returned tags

`getExif` always returns these keys. Each value is a **string**, or `null`
when the image does not have that tag. The string format follows each
platform's native API. For example, `GPSLatitude` is a rational string
(`"23/1,33/1,1818/100"`) on Android and a decimal (`"23.5505"`) on iOS. Use
`getLatLong` to get coordinates in the same format on both platforms.

| Group       | Keys |
| ----------- | ---- |
| Date/time   | `DateTime`, `DateTimeOriginal`, `DateTimeDigitized`, `SubSecTime` |
| Camera      | `Make`, `Model`, `Software` |
| Exposure    | `ExposureTime`, `ExposureProgram`, `ExposureBiasValue`, `ShutterSpeedValue`, `MaxApertureValue`, `FocalLength`, `Flash`, `MeteringMode`, `WhiteBalance` |
| GPS         | `GPSLatitude`, `GPSLatitudeRef`, `GPSLongitude`, `GPSLongitudeRef`, `GPSAltitude`, `GPSAltitudeRef`, `GPSDateStamp`, `GPSTimeStamp`, `GPSProcessingMethod` |
| Image       | `ImageWidth`, `ImageLength`, `Orientation`, `XResolution`, `YResolution`, `ResolutionUnit`, `ColorSpace`, `Compression`, `BitsPerSample`, `SamplesPerPixel`, `PlanarConfiguration`, `PhotometricInterpretation`, `YCbCrPositioning`, `CompressedBitsPerPixel` |
| Thumbnail   | `ThumbnailImageWidth`, `ThumbnailImageLength`, `ThumbnailOrientation` |
| EXIF/DNG    | `ExifVersion`, `InteroperabilityIndex`, `DNGVersion`, `DefaultCropSize` |
| RAW (Android only, `null` on iOS) | `ORFPreviewImageStart`, `ORFPreviewImageLength`, `ORFAspectFrame`, `RW2SensorLeftBorder`, `RW2SensorRightBorder`, `RW2SensorTopBorder`, `RW2ISO` |
| Extra       | `originalUri`: the path you passed in |

Large binary tags (`MakerNote`, embedded RAW previews) are not returned.

## Errors

The single-image functions reject with code `EXIF_ERROR`, and the error
message describes the cause (file not found, permission denied, asset not
found…). The batch functions never reject for a single image. They report the
same message in the item's `error`.

## Changelog

### 2.0.0

- **New:** `getExifBatch` and `getLatLongBatch` for reading many images in one call.
- **Performance:** reads only the metadata blocks; no more loading the full image
  (including iCloud photos) into memory on iOS; reads run in parallel off the
  native-modules thread on Android; fixed a file descriptor leak on Android.
- **iOS:** `getLatLong` for `ph://` uses the Photos location directly; the
  permission prompt is shown only when the user has not decided yet.
- **Breaking:** removed the `multiply` export, which was left over from the template.
- **Breaking:** `getExif` no longer returns `MakerNote`, `ORFThumbnailImage`
  or `RW2JpgFromRaw`.

### 1.0.0

- React Native 0.81.1 support.

## License

MIT
