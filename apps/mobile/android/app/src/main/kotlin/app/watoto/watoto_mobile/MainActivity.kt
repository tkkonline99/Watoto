package app.watoto.watoto_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.watoto.iap"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "buy", "restore" -> {
                    // Returns null until Google Play Billing client SKU is active
                    // in Play Console; StoreKitPlayPurchaseBridge handles null
                    // gracefully as a cancelled/unavailable purchase.
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
