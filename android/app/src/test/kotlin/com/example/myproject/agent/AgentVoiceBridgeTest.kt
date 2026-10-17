package com.example.myproject.agent

import android.app.Activity
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.ResolveInfo
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.os.Bundle
import android.os.Looper
import android.speech.RecognitionService
import android.speech.RecognitionSupport
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSpeechRecognizer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 31, 35])
class AgentVoiceBridgeTest {
    private class Messenger : BinaryMessenger {
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler?>()
        val events = mutableListOf<MethodCall>()
        override fun send(channel: String, message: ByteBuffer?) {
            if (message != null) { message.flip(); events.add(StandardMethodCodec.INSTANCE.decodeMethodCall(message)) }
        }
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) { send(channel,message); callback?.reply(null) }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) { handlers[channel]=handler }
        fun call(name: String, args: Map<String,Any> = emptyMap()): Any? {
            val input = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(name,args))
            input.flip()
            var value: Any? = null
            handlers.getValue("voice")!!.onMessage(input) { output ->
                output?.flip()
                value = try { StandardMethodCodec.INSTANCE.decodeEnvelope(output!!) } catch (e: FlutterException) { e }
            }
            shadowOf(Looper.getMainLooper()).idle()
            return value
        }
    }
    @Test fun backgroundInterruptionStopsAudioAndPreventsSpeech() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        val messenger=Messenger()
        val bridge=AgentVoiceBridge(host.get(),MethodChannel(messenger,"voice"))
        bridge.foreground(false)
        val failure=messenger.call("speak",mapOf("session" to "test","text" to "Private response")) as FlutterException
        assertEquals("unavailable",failure.code)
        assertTrue(messenger.events.any { it.method == "event" && (it.arguments as Map<*,*>)["type"] == "interrupted" })
        bridge.dispose(); host.pause().stop().destroy()
    }
    @Test fun cancelReleaseAndUnknownPermissionAreSafeWithoutStartingMicrophone() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        val messenger=Messenger()
        val bridge=AgentVoiceBridge(host.get(),MethodChannel(messenger,"voice"))
        assertFalse(bridge.permissionResult(123,intArrayOf()))
        assertNull(messenger.call("cancel"))
        assertNull(messenger.call("stopSpeaking"))
        assertNull(messenger.call("release"))
        bridge.dispose()
        assertNull(messenger.handlers["voice"])
        host.pause().stop().destroy()
    }

    @Test fun audioClientServerAndLanguageFailuresRemainDistinct() {
        val audio=agentRecognitionFailure(SpeechRecognizer.ERROR_AUDIO,true)
        val client=agentRecognitionFailure(SpeechRecognizer.ERROR_CLIENT,true)
        val server=agentRecognitionFailure(SpeechRecognizer.ERROR_SERVER,true)
        val language=agentRecognitionFailure(SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,true)
        assertEquals("audio",audio.code); assertFalse(audio.message.contains("language"))
        assertEquals("client",client.code); assertFalse(client.message.contains("language"))
        assertEquals("server",server.code)
        assertEquals("language_unavailable",language.code); assertTrue(language.message.contains("not installed"))
    }

    @Test fun canonicalLanguageMatchingDoesNotAssumeEveryEnglishDialectIsInstalled() {
        assertTrue(agentInstalledLanguageMatches("en-US",listOf("en-us")))
        assertTrue(agentInstalledLanguageMatches("en",listOf("en-US")))
        assertFalse(agentInstalledLanguageMatches("en-PH",listOf("en-US")))
        assertFalse(agentInstalledLanguageMatches("fil-PH",listOf("en-US")))
    }

    @Test fun microphoneRecognitionDoesNotRequestPlaybackAudioFocusAndPreservesErrorCode() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        val activity=host.get()
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(Manifest.permission.RECORD_AUDIO)
        val info=ResolveInfo().apply { serviceInfo=ServiceInfo().apply { packageName="test.speech"; name="TestRecognizer" } }
        shadowOf(activity.packageManager).addResolveInfoForIntent(Intent(RecognitionService.SERVICE_INTERFACE),info)
        val messenger=Messenger(); val bridge=AgentVoiceBridge(activity,MethodChannel(messenger,"voice"))
        assertNull(messenger.call("start",mapOf("session" to "microphone","onDevice" to false,"locale" to "en-US")))
        val recognizer=ShadowSpeechRecognizer.getLatestSpeechRecognizer()
        assertNotNull(shadowOf(recognizer).lastRecognizerIntent)
        assertNull(shadowOf(activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager).lastAudioFocusRequest)
        shadowOf(recognizer).triggerOnError(SpeechRecognizer.ERROR_AUDIO)
        shadowOf(Looper.getMainLooper()).idle()
        val error=messenger.events.last { (it.arguments as Map<*,*>)["type"] == "error" }.arguments as Map<*,*>
        assertEquals(3,error["nativeCode"]); assertEquals("audio",error["code"])
        bridge.dispose(); host.pause().stop().destroy()
    }

    @Test @Config(sdk = [33,36])
    fun onDeviceRecognizerWithoutDownloadedModelDoesNotStartListeningOrUseRemoteFallback() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(Manifest.permission.RECORD_AUDIO)
        ShadowSpeechRecognizer.setIsOnDeviceRecognitionAvailable(true)
        val messenger=Messenger(); val bridge=AgentVoiceBridge(host.get(),MethodChannel(messenger,"voice"))
        assertNull(messenger.call("start",mapOf("session" to "local","onDevice" to true,"locale" to "en-US")))
        val recognizer=ShadowSpeechRecognizer.getLatestSpeechRecognizer()
        val shadow=shadowOf(recognizer)
        assertNull(shadow.lastRecognizerIntent)
        shadow.triggerSupportResult(RecognitionSupport.Builder().setSupportedOnDeviceLanguages(listOf("en-US")).build())
        shadowOf(Looper.getMainLooper()).idle()
        val error=messenger.events.last { (it.arguments as Map<*,*>)["type"] == "error" }.arguments as Map<*,*>
        assertEquals(13,error["nativeCode"]); assertEquals("language_unavailable",error["code"])
        assertNull(shadow.lastRecognizerIntent); assertTrue(shadow.isDestroyed)
        assertNull(shadowOf(host.get()).nextStartedActivity)
        bridge.dispose(); host.pause().stop().destroy()
    }

    @Test @Config(sdk = [33,36])
    fun downloadedOnDeviceModelStartsAndOptionalUnsupportedQueryDoesNotSwitchProviders() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(Manifest.permission.RECORD_AUDIO)
        ShadowSpeechRecognizer.setIsOnDeviceRecognitionAvailable(true)
        val messenger=Messenger(); val bridge=AgentVoiceBridge(host.get(),MethodChannel(messenger,"voice"))
        messenger.call("start",mapOf("session" to "installed","onDevice" to true,"locale" to "en-US"))
        val shadow=shadowOf(ShadowSpeechRecognizer.getLatestSpeechRecognizer())
        shadow.triggerSupportResult(RecognitionSupport.Builder().setInstalledOnDeviceLanguages(listOf("en-US")).build())
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("en-US",shadow.lastRecognizerIntent.getStringExtra(RecognizerIntent.EXTRA_LANGUAGE))
        messenger.call("cancel")
        messenger.call("start",mapOf("session" to "oem","onDevice" to true,"locale" to "en-US"))
        val oem=shadowOf(ShadowSpeechRecognizer.getLatestSpeechRecognizer())
        oem.triggerSupportError(SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT)
        shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(oem.lastRecognizerIntent)
        assertNull(shadowOf(host.get()).nextStartedActivity)
        bridge.dispose(); host.pause().stop().destroy()
    }

    @Test fun systemSpeechDialogRequiresConsentPolicyAndReturnsOnlyAReviewableTranscript() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        val messenger=Messenger(); val bridge=AgentVoiceBridge(host.get(),MethodChannel(messenger,"voice"))
        val refused=messenger.call("startSystem",mapOf("session" to "private","onDevice" to true)) as FlutterException
        assertEquals("on_device_required",refused.code); assertNull(shadowOf(host.get()).nextStartedActivity)
        messenger.call("startSystem",mapOf("session" to "system","onDevice" to false))
        val launched=shadowOf(host.get()).nextStartedActivityForResult
        assertEquals(RecognizerIntent.ACTION_RECOGNIZE_SPEECH,launched.intent.action)
        bridge.foreground(false)
        assertEquals(5,launched.intent.getIntExtra(RecognizerIntent.EXTRA_MAX_RESULTS,0))
        val words=Intent().putStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS,arrayListOf("Prepare PHP 50","Prepare PHP 500"))
            .putExtra(RecognizerIntent.EXTRA_CONFIDENCE_SCORES,floatArrayOf(.8f,-1f))
        assertTrue(bridge.activityResult(launched.requestCode,Activity.RESULT_OK,words))
        shadowOf(Looper.getMainLooper()).idle()
        val result=messenger.events.last { (it.arguments as Map<*,*>)["type"] == "final" }.arguments as Map<*,*>
        assertEquals("Prepare PHP 50",result["text"]); assertEquals("system",result["session"])
        assertEquals(listOf("Prepare PHP 50","Prepare PHP 500"),result["alternatives"])
        assertEquals(2,(result["confidences"] as List<*>).size)
        bridge.dispose(); host.pause().stop().destroy()
    }

    @Test fun cancelRejectsAStaleSystemSpeechResult() {
        val host=Robolectric.buildActivity(Activity::class.java).setup()
        val messenger=Messenger(); val bridge=AgentVoiceBridge(host.get(),MethodChannel(messenger,"voice"))
        messenger.call("startSystem",mapOf("session" to "old","onDevice" to false))
        val launched=shadowOf(host.get()).nextStartedActivityForResult
        messenger.call("cancel")
        assertFalse(bridge.activityResult(launched.requestCode,Activity.RESULT_OK,Intent().putStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS,arrayListOf("stale"))))
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(messenger.events.none { (it.arguments as Map<*,*>)["type"] == "final" })
        bridge.dispose(); host.pause().stop().destroy()
    }
}
