# React Native Exif

## Installation

```sh
yarn add @pedro.gabriel/react-native-exif
react-native link
```

or

```sh
npm install @pedro.gabriel/react-native-exif --save
react-native link
```

## Usage

### getExif

```javascript
import { getExif, getLatLong } from '@pedro.gabriel/react-native-exif'

...

getExif('/sdcard/tt.jpg')
    .then(msg => console.warn('OK: ' + JSON.stringify(msg)))
    .catch(msg => console.warn('ERROR: ' + msg))

...

getExif('content://media/external/images/media/111')
    .then(msg => console.warn('OK: ' + JSON.stringify(msg)))
    .catch(msg => console.warn('ERROR: ' + msg))

...

getExif('assets-library://asset/asset.JPG?id=xxxx&ext=JPG')
    .then(msg => console.warn('OK: ' + JSON.stringify(msg)))
    .catch(msg => console.warn('ERROR: ' + msg))

```

#### Exif values

| Value       |
| ----------- |
| ImageWidth  |
| ImageHeight |
| Orientation |
| originalUri |
| exif        |

### getLatLong

Fetch geo coordinates as floats.

```javascript
...
getLatLong('/sdcard/tt.jpg')
    .then(({latitude, longitude}) => {console.warn('OK: ' + latitude + ', ' + longitude)})
    .catch(msg => console.warn('ERROR: ' + msg))
...
```

Version 1.0.0 add react-native 0.81.1 support
