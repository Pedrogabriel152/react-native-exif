import { Text, View, StyleSheet, TouchableOpacity, Image } from 'react-native';
import { getLatLong } from '@pedro/react-native-exif';
import { launchImageLibrary } from 'react-native-image-picker';
import { useState } from 'react';
import { Button } from './Button';

// const result = multiply(3, 7);
const MAX_SIZE = 2000;

import { PermissionsAndroid, Platform } from 'react-native';

async function requestPermissions() {
  if (Platform.OS === 'android') {
    const granted = await PermissionsAndroid.requestMultiple([
      PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
      // Adicione a permissão de acesso à localização de mídia
      PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
      PermissionsAndroid.PERMISSIONS.ACCESS_MEDIA_LOCATION,
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
      PermissionsAndroid.PERMISSIONS.READ_MEDIA_IMAGES,
      PermissionsAndroid.PERMISSIONS.READ_MEDIA_VIDEO,
    ]);

    if (granted) {
      return true;
    }

    return true;
  }
  return true;
}
requestPermissions();

export default function App() {
  const [value, _setValue] = useState({
    latitude: 0,
    longitude: 0,
    altitude: 0,
    accuracy: 0,
    heading: 0,
    speed: 0,
    timestamp: 0,
    value: '',
  });

  const _selectFile = async () => {
    // const test = await requestPermissions()
    // console.log(test)
    // if (!test) {
    //   return;
    // }
    console.log('selectFile');
    let result = await launchImageLibrary({
      mediaType: 'photo',
      maxWidth: MAX_SIZE,
      maxHeight: MAX_SIZE,
      quality: 1,
      includeExtra: true,
    });

    if (result.didCancel) {
      return;
    }
    if (!result.assets || !result.assets.length || !result?.assets[0]!.uri) {
      return;
    }
    var loc = await getLatLong(result.assets[0].uri);
    console.log(result, loc);
  };

  return (
    <View style={styles.container}>
      <View>
        <TouchableOpacity onPress={() => {}}>
          <Image source={{ uri: value.value }} style={styles.image} />
          <Text>
            {value.latitude}/{value.longitude}
          </Text>
        </TouchableOpacity>
        <Button onPress={_selectFile} loading={false}>
          Teste
        </Button>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  image: {
    minWidth: 150,
    minHeight: 150,
    resizeMode: 'contain',
  },
});
