# React Native Exif
[![All Contributors](https://img.shields.io/badge/all_contributors-6-orange.svg?style=flat-square)](#contributors) <br />
>An image exif reader

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
import Exif from '@pedro.gabriel/react-native-exif'

...

Exif.getExif('/sdcard/tt.jpg')
    .then(msg => console.warn('OK: ' + JSON.stringify(msg)))
    .catch(msg => console.warn('ERROR: ' + msg))

...

Exif.getExif('content://media/external/images/media/111')
    .then(msg => console.warn('OK: ' + JSON.stringify(msg)))
    .catch(msg => console.warn('ERROR: ' + msg))

...

Exif.getExif('assets-library://asset/asset.JPG?id=xxxx&ext=JPG')
    .then(msg => console.warn('OK: ' + JSON.stringify(msg)))
    .catch(msg => console.warn('ERROR: ' + msg))

```
#### Exif values

Value |
--- |
ImageWidth |
ImageHeight |
Orientation |
originalUri |
exif|

### getLatLong

Fetch geo coordinates as floats.

```javascript
...
Exif.getLatLong('/sdcard/tt.jpg')
    .then(({latitude, longitude}) => {console.warn('OK: ' + latitude + ', ' + longitude)})
    .catch(msg => console.warn('ERROR: ' + msg))
...
```

Version 1.0.0 add react-native 0.81.1 support