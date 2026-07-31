import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let consentSignalsChannel = FlutterMethodChannel(
      name: "de.lemarq.calcrow/consent_signals",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    consentSignalsChannel.setMethodCallHandler { call, result in
      guard call.method == "getTcfConsentState" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let defaults = UserDefaults.standard
      result([
        "gdprApplies": defaults.object(forKey: "IABTCF_gdprApplies") ?? NSNull(),
        "purposeConsents": defaults.string(forKey: "IABTCF_PurposeConsents") ?? NSNull(),
        "purposeLegitimateInterests": defaults.string(
          forKey: "IABTCF_PurposeLegitimateInterests"
        ) ?? NSNull(),
      ])
    }
  }
}
