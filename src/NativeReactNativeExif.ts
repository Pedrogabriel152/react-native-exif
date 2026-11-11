import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  getLatLong(
    path: string
  ): Promise<{ latitude: number; longitude: number } | null>;
  getExif(path: string): Promise<Record<string, string | number | null> | null>;
  // Cada item: { path, data, error }. Tipado de forma forte em index.tsx.
  getExifBatch(paths: string[]): Promise<Object[]>;
  getLatLongBatch(paths: string[]): Promise<Object[]>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('ReactNativeExif');
