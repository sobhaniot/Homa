package com.eleknow.homa_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // تنظیمات خصوصی اپ گوشی؛ برنامهٔ تبلت مستقل باقی می‌ماند.
        val preferences = getSharedPreferences("homa_phone", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "homa/config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> result.success(preferences.getString("settings", null))
                    "save" -> {
                        val raw = call.arguments as? String
                        if (raw == null) result.error("invalid", "تنظیمات نامعتبر", null)
                        else if (preferences.edit().putString("settings", raw).commit()) result.success(null)
                        else result.error("save", "ذخیره ناموفق", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
