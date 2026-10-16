package com.example.myproject

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.myproject.widgets.WidgetBridge

class MainActivity : FlutterActivity() {
    private var widgets: WidgetBridge? = null
    override fun getInitialRoute(): String? =
        if (intent?.action == "savetrack.widget") "/" else super.getInitialRoute()
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        widgets = WidgetBridge(this, MethodChannel(engine.dartExecutor.binaryMessenger, "savetrack/home_widgets"))
        widgets?.accept(intent)
    }
    override fun onNewIntent(intent: Intent) {
        // The URI identifies PendingIntents; the authenticated Dart router owns
        // widget navigation. Do not also feed this URI to Flutter deep linking.
        super.onNewIntent(if (intent.action == "savetrack.widget") Intent(intent).setData(null) else intent)
        widgets?.accept(intent)
    }
}
