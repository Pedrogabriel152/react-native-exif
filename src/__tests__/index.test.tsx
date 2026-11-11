import { TurboModuleRegistry } from 'react-native';
import { getExif, getLatLong } from '../index';

jest.mock('react-native', () => {
  const nativeModule = {
    getExif: jest.fn(),
    getLatLong: jest.fn(),
  };
  return {
    TurboModuleRegistry: {
      getEnforcing: jest.fn(() => nativeModule),
    },
  };
});

const mockNativeModule = (TurboModuleRegistry.getEnforcing as jest.Mock).mock
  .results[0]!.value as {
  getExif: jest.Mock;
  getLatLong: jest.Mock;
};

beforeEach(() => {
  mockNativeModule.getExif.mockReset();
  mockNativeModule.getLatLong.mockReset();
});

describe('módulo nativo', () => {
  it('é resolvido pelo nome "ReactNativeExif"', () => {
    expect(TurboModuleRegistry.getEnforcing).toHaveBeenCalledWith(
      'ReactNativeExif'
    );
  });

  it('falha ao importar quando o módulo nativo não está linkado', () => {
    jest.isolateModules(() => {
      const { TurboModuleRegistry: registry } = require('react-native');
      registry.getEnforcing.mockImplementationOnce(() => {
        throw new Error(
          "TurboModuleRegistry.getEnforcing(...): 'ReactNativeExif' could not be found."
        );
      });

      expect(() => require('../index')).toThrow(/ReactNativeExif/);
    });
  });
});

describe('getExif', () => {
  it('repassa o caminho ao nativo e devolve o resultado', async () => {
    const exif = {
      Make: 'Apple',
      Model: 'iPhone 15',
      DateTimeOriginal: '2024:05:10 14:30:00',
      GPSLatitude: null,
      originalUri: 'file:///tmp/foto.jpg',
    };
    mockNativeModule.getExif.mockResolvedValue(exif);

    await expect(getExif('file:///tmp/foto.jpg')).resolves.toEqual(exif);
    expect(mockNativeModule.getExif).toHaveBeenCalledTimes(1);
    expect(mockNativeModule.getExif).toHaveBeenCalledWith(
      'file:///tmp/foto.jpg'
    );
  });

  it.each([
    '/sdcard/DCIM/foto.jpg',
    'file:///sdcard/DCIM/foto.jpg',
    'content://media/external/images/media/42',
    'ph://ABC-123/L0/001',
  ])('não altera o caminho %s', async (path) => {
    mockNativeModule.getExif.mockResolvedValue({});

    await getExif(path);

    expect(mockNativeModule.getExif).toHaveBeenCalledWith(path);
  });

  it('propaga a rejeição do nativo', async () => {
    const error = Object.assign(new Error('Nao foi possivel abrir a imagem'), {
      code: 'EXIF_ERROR',
    });
    mockNativeModule.getExif.mockRejectedValue(error);

    await expect(getExif('/nao/existe.jpg')).rejects.toMatchObject({
      code: 'EXIF_ERROR',
      message: 'Nao foi possivel abrir a imagem',
    });
  });
});

describe('getLatLong', () => {
  it('repassa o caminho ao nativo e devolve as coordenadas', async () => {
    const coords = { latitude: -23.5505, longitude: -46.6333 };
    mockNativeModule.getLatLong.mockResolvedValue(coords);

    await expect(getLatLong('/sdcard/foto.jpg')).resolves.toEqual(coords);
    expect(mockNativeModule.getLatLong).toHaveBeenCalledWith(
      '/sdcard/foto.jpg'
    );
  });

  it('devolve 0,0 quando a imagem não tem GPS (contrato do nativo)', async () => {
    mockNativeModule.getLatLong.mockResolvedValue({
      latitude: 0,
      longitude: 0,
    });

    await expect(getLatLong('/sdcard/sem-gps.jpg')).resolves.toEqual({
      latitude: 0,
      longitude: 0,
    });
  });

  it('propaga a rejeição do nativo', async () => {
    mockNativeModule.getLatLong.mockRejectedValue(
      Object.assign(new Error('Permissao para fotos negada'), {
        code: 'EXIF_ERROR',
      })
    );

    await expect(getLatLong('ph://ABC-123')).rejects.toMatchObject({
      code: 'EXIF_ERROR',
    });
  });

  it('suporta chamadas concorrentes', async () => {
    mockNativeModule.getLatLong.mockImplementation(async (path: string) => ({
      latitude: path.length,
      longitude: -path.length,
    }));

    const results = await Promise.all(
      ['/a.jpg', '/bb.jpg', '/ccc.jpg'].map(getLatLong)
    );

    expect(results).toEqual([
      { latitude: 6, longitude: -6 },
      { latitude: 7, longitude: -7 },
      { latitude: 8, longitude: -8 },
    ]);
  });
});
