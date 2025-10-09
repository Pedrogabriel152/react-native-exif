import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  multiply(a: number, b: number): number;
  // getExif(imageUri: string): Record<string, string | number | null>;
  getLatLong(
    path: string
  ): Promise<{ latitude: number; longitude: number } | null>;
  getExif(path: string): Promise<Record<string, string | number | null> | null>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('ReactNativeExif');
