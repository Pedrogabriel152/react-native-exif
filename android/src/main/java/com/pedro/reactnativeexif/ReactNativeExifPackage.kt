package com.pedro.reactnativeexif

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import java.util.HashMap

class ReactNativeExifPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == ReactNativeExifModule.NAME) {
      ReactNativeExifModule(reactContext)
    } else {
      null
    }
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
    return ReactModuleInfoProvider {
      // CORRIGIDO: Inicialize o mapa aqui
      val moduleInfos: MutableMap<String, ReactModuleInfo> = HashMap()

      moduleInfos[ReactNativeExifModule.NAME] = ReactModuleInfo(
        ReactNativeExifModule.NAME,
        ReactNativeExifModule.NAME,
        false,  // canOverrideExistingModule
        false,  // needsEagerInit
        false,  // isCxxModule
        true // isTurboModule
      )
      // Retorna o mapa preenchido
      moduleInfos
    }
  }
}
