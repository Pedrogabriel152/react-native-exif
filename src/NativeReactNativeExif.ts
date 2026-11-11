import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  getLatLong(
    path: string
  ): Promise<{ latitude: number; longitude: number } | null>;
  getExif(path: string): Promise<Record<string, string | number | null> | null>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('ReactNativeExif');
