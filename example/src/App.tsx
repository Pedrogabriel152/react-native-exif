import {
  Text,
  View,
  StyleSheet,
  TouchableOpacity,
  Image,
  ScrollView,
} from 'react-native';
import {
  getLatLong,
  getLatLongBatch,
  type BatchItem,
  type LatLong,
} from '@pedro.gabriel/react-native-exif';
import { launchImageLibrary, type Asset } from 'react-native-image-picker';
import { useState } from 'react';
import { Button } from './Button';

const MAX_SIZE = 2000;

// No iOS, ph://<id> lê direto da galeria (localização sem abrir o arquivo).
function pathForAsset(asset: Asset): string | undefined {
  return Platform.OS === 'ios' && asset.id ? `ph://${asset.id}` : asset.uri;
}

import { PermissionsAndroid, Platform } from 'react-native';

// Opcional: sem ela tudo funciona, só o GPS de fotos da galeria vem vazio no Android 10+.
async function requestPermissions() {
  if (Platform.OS === 'android' && Platform.Version >= 29) {
    await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.ACCESS_MEDIA_LOCATION
    );
  }
}
requestPermissions();

export default function App() {
  const [value, setValue] = useState({
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
    const asset = result.assets?.[0];
    if (!asset?.uri) {
      return;
    }
    const path = pathForAsset(asset)!;
    const loc = await getLatLong(path);
    setValue((prev) => ({
      ...prev,
      latitude: loc?.latitude ?? 0,
      longitude: loc?.longitude ?? 0,
      value: asset.uri ?? '',
    }));
    console.log(result, loc);
  };

  const [batch, setBatch] = useState<BatchItem<LatLong>[]>([]);

  const _selectMany = async () => {
    // Sem maxWidth/maxHeight: redimensionar recodifica a imagem e pode
    // descartar o EXIF original.
    const result = await launchImageLibrary({
      mediaType: 'photo',
      selectionLimit: 0,
      includeExtra: true,
    });
    if (result.didCancel || !result.assets) {
      return;
    }

    const paths = result.assets
      .map(pathForAsset)
      .filter((path): path is string => !!path);

    const started = Date.now();
    const items = await getLatLongBatch(paths);
    console.log(`${items.length} fotos em ${Date.now() - started}ms`, items);
    setBatch(items);
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
        <Button onPress={_selectMany} loading={false}>
          Várias fotos
        </Button>
      </View>
      <ScrollView style={styles.list}>
        {batch.map((item, index) => (
          <Text key={`${index}-${item.path}`} numberOfLines={1}>
            {index + 1}.{' '}
            {item.data
              ? `${item.data.latitude}/${item.data.longitude}`
              : `erro: ${item.error}`}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  list: {
    maxHeight: 200,
    alignSelf: 'stretch',
    paddingHorizontal: 16,
  },
  image: {
    minWidth: 150,
    minHeight: 150,
    resizeMode: 'contain',
  },
});
