import ReactNativeExif from './NativeReactNativeExif';

/** Mapa tag EXIF -> valor (string) ou null quando a tag não existe. */
export type ExifData = Record<string, string | number | null>;

export type LatLong = { latitude: number; longitude: number };

/** Resultado de um item de lote: `data` preenchido em caso de sucesso, `error` caso contrário. */
export type BatchItem<T> = {
  path: string;
  data: T | null;
  error: string | null;
};

export function getLatLong(path: string) {
  return ReactNativeExif.getLatLong(path);
}

export function getExif(path: string) {
  return ReactNativeExif.getExif(path);
}

/**
 * Lê o EXIF de várias imagens numa única chamada nativa, em paralelo.
 * A promise sempre resolve; falhas aparecem em `error` do item correspondente.
 * O resultado segue a mesma ordem de `paths`.
 */
export async function getExifBatch(
  paths: string[]
): Promise<BatchItem<ExifData>[]> {
  if (paths.length === 0) {
    return [];
  }
  return (await ReactNativeExif.getExifBatch(paths)) as BatchItem<ExifData>[];
}

/**
 * Lê as coordenadas GPS de várias imagens numa única chamada nativa, em paralelo.
 * A promise sempre resolve; falhas aparecem em `error` do item correspondente.
 * O resultado segue a mesma ordem de `paths`.
 */
export async function getLatLongBatch(
  paths: string[]
): Promise<BatchItem<LatLong>[]> {
  if (paths.length === 0) {
    return [];
  }
  return (await ReactNativeExif.getLatLongBatch(paths)) as BatchItem<LatLong>[];
}
