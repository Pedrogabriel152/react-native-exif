import { TurboModuleRegistry } from 'react-native';
import { getExif, getExifBatch, getLatLong, getLatLongBatch } from '../index';

jest.mock('react-native', () => {
  const nativeModule = {
    getExif: jest.fn(),
    getLatLong: jest.fn(),
    getExifBatch: jest.fn(),
    getLatLongBatch: jest.fn(),
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
  getExifBatch: jest.Mock;
  getLatLongBatch: jest.Mock;
};

beforeEach(() => {
  Object.values(mockNativeModule).forEach((fn) => fn.mockReset());
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

describe('getExifBatch', () => {
  it('envia todos os caminhos numa única chamada nativa', async () => {
    const paths = ['/a.jpg', 'content://media/external/images/media/1'];
    mockNativeModule.getExifBatch.mockResolvedValue([
      { path: paths[0], data: { Make: 'A' }, error: null },
      { path: paths[1], data: { Make: 'B' }, error: null },
    ]);

    const results = await getExifBatch(paths);

    expect(mockNativeModule.getExifBatch).toHaveBeenCalledTimes(1);
    expect(mockNativeModule.getExifBatch).toHaveBeenCalledWith(paths);
    expect(mockNativeModule.getExif).not.toHaveBeenCalled();
    expect(results.map((item) => item.data?.Make)).toEqual(['A', 'B']);
  });

  it('resolve mesmo quando um item falha, com o erro no próprio item', async () => {
    mockNativeModule.getExifBatch.mockResolvedValue([
      { path: '/ok.jpg', data: { Make: 'A' }, error: null },
      {
        path: '/missing.jpg',
        data: null,
        error: 'Nao foi possivel abrir a imagem',
      },
    ]);

    const results = await getExifBatch(['/ok.jpg', '/missing.jpg']);

    expect(results[0]).toEqual({
      path: '/ok.jpg',
      data: { Make: 'A' },
      error: null,
    });
    expect(results[1]).toEqual({
      path: '/missing.jpg',
      data: null,
      error: 'Nao foi possivel abrir a imagem',
    });
  });

  it('lista vazia devolve [] sem chamar o nativo', async () => {
    await expect(getExifBatch([])).resolves.toEqual([]);
    expect(mockNativeModule.getExifBatch).not.toHaveBeenCalled();
  });
});

describe('getLatLongBatch', () => {
  it('devolve as coordenadas na mesma ordem dos caminhos', async () => {
    const paths = ['ph://B', 'ph://A'];
    mockNativeModule.getLatLongBatch.mockResolvedValue([
      { path: 'ph://B', data: { latitude: 2, longitude: -2 }, error: null },
      { path: 'ph://A', data: { latitude: 1, longitude: -1 }, error: null },
    ]);

    const results = await getLatLongBatch(paths);

    expect(mockNativeModule.getLatLongBatch).toHaveBeenCalledWith(paths);
    expect(results.map((item) => item.path)).toEqual(paths);
    expect(results[0]!.data).toEqual({ latitude: 2, longitude: -2 });
  });

  it('item sem permissão traz o erro e não rejeita o lote', async () => {
    mockNativeModule.getLatLongBatch.mockResolvedValue([
      { path: 'ph://A', data: null, error: 'Permissao para fotos negada' },
    ]);

    await expect(getLatLongBatch(['ph://A'])).resolves.toEqual([
      { path: 'ph://A', data: null, error: 'Permissao para fotos negada' },
    ]);
  });

  it('lista vazia devolve [] sem chamar o nativo', async () => {
    await expect(getLatLongBatch([])).resolves.toEqual([]);
    expect(mockNativeModule.getLatLongBatch).not.toHaveBeenCalled();
  });
});
