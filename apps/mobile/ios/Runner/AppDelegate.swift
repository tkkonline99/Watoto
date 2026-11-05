import Flutter
import StoreKit
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
    let channel = FlutterMethodChannel(
      name: "app.watoto.iap",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if #available(iOS 15.0, *) {
        Task {
          await Self.handleStoreKitCall(call: call, result: result)
        }
      } else {
        result(nil)
      }
    }
  }

  @available(iOS 15.0, *)
  private static func handleStoreKitCall(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) async {
    switch call.method {
    case "buy":
      guard let args = call.arguments as? [String: Any],
            let productId = args["productId"] as? String else {
        result(nil)
        return
      }
      do {
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
          result(nil)
          return
        }
        let purchaseResult = try await product.purchase()
        switch purchaseResult {
        case .success(let verification):
          if case .verified(let transaction) = verification {
            await transaction.finish()
            result([
              "platform": "ios",
              "receipt": verification.jwsRepresentation,
            ])
          } else {
            result(nil)
          }
        case .userCancelled, .pending:
          result(nil)
        @unknown default:
          result(nil)
        }
      } catch {
        result(nil)
      }

    case "restore":
      do {
        try await AppStore.sync()
        for await entitlement in Transaction.currentEntitlements {
          if case .verified(_) = entitlement {
            result([
              "platform": "ios",
              "receipt": entitlement.jwsRepresentation,
            ])
            return
          }
        }
        result(nil)
      } catch {
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
