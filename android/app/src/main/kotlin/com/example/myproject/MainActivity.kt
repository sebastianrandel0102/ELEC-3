package com.example.myproject

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.content.res.Configuration
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.myproject.widgets.WidgetBridge
import com.example.myproject.widgets.WidgetRenderer
import com.example.myproject.agent.AgentVoiceBridge

class MainActivity : FlutterActivity() {
    private var widgets: WidgetBridge? = null
    private var agentVoice: AgentVoiceBridge? = null
    override fun getInitialRoute(): String? =
        if (intent?.action == "savetrack.widget") "/" else super.getInitialRoute()
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        widgets = WidgetBridge(this, MethodChannel(engine.dartExecutor.binaryMessenger, "savetrack/home_widgets"))
        widgets?.accept(intent)
        agentVoice = AgentVoiceBridge(this, MethodChannel(engine.dartExecutor.binaryMessenger, "savetrack/agent_voice"))
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (agentVoice?.permissionResult(requestCode, grantResults) != true) super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onResume() { super.onResume(); agentVoice?.foreground(true) }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (agentVoice?.activityResult(requestCode, resultCode, data) != true) super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onPause() { agentVoice?.foreground(false); super.onPause() }
    override fun cleanUpFlutterEngine(engine: FlutterEngine) { agentVoice?.dispose(); agentVoice = null; super.cleanUpFlutterEngine(engine) }
    override fun onNewIntent(intent: Intent) {
        // The URI identifies PendingIntents; the authenticated Dart router owns
        // widget navigation. Do not also feed this URI to Flutter deep linking.
        super.onNewIntent(if (intent.action == "savetrack.widget") Intent(intent).setData(null) else intent)
        widgets?.accept(intent)
    }
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Theme/font changes repaint saved snapshots; no network work is added.
        WidgetRenderer.updateAll(this)
    }
}
