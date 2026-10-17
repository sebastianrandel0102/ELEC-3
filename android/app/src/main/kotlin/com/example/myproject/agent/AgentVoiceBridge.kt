package com.example.myproject.agent

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Tap-to-talk only. No audio files, background service, or hotword listener. */
class AgentVoiceBridge(private val activity: Activity, private val channel: MethodChannel) {
    companion object { const val PERMISSION = 7606 }
    private val handler = Handler(Looper.getMainLooper())
    private val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focus: AudioFocusRequest? = null
    private var recognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var defaultTtsLocale = Locale.getDefault()
    private var session = ""
    private var generation = 0
    private var foreground = true
    private var pending: Pair<MethodCall, MethodChannel.Result>? = null
    private var recording = false
    private var lastTranscript = ""
    private var focusListener: AudioManager.OnAudioFocusChangeListener? = null
    private var systemRequest: Int? = null
    private var systemToken: String? = null
    private var nextSystemRequest = 7607

    init { channel.setMethodCallHandler(::call) }
    private fun initializeTts() {
        if (tts != null) return
        tts = TextToSpeech(activity.applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) defaultTtsLocale = tts?.defaultVoice?.locale ?: Locale.getDefault()
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) { event("speaking", id ?: "") }
            override fun onDone(id: String?) { handler.post { if (id == session) abandonFocus(); event("done", id ?: "") } }
            @Deprecated("Android callback")
            override fun onError(id: String?) { handler.post { if (id == session) abandonFocus(); event("error", id ?: "", "message" to "Speech output failed. Read the response on screen.") } }
        })
    }
    private fun event(type: String, token: String = session, vararg values: Pair<String, Any>) {
        val data = mapOf("type" to type, "session" to token) + values.toMap()
        handler.post { channel.invokeMethod("event", data) }
    }
    private fun acquireFocus(): Boolean {
        val focusGeneration = generation
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            if (change < 0) handler.post { if (generation == focusGeneration) interrupt() }
        }
        focusListener = listener
        val status = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setOnAudioFocusChangeListener(listener, handler).build()
            focus = request; audio.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
        return status == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else { @Suppress("DEPRECATION") focusListener?.let { audio.abandonAudioFocus(it) } }
        focus = null
        focusListener = null
    }
    private fun cancelRecognition() {
        generation++; recording = false
        lastTranscript = ""
        recognizer?.cancel(); recognizer?.destroy(); recognizer = null
        abandonFocus()
    }
    fun interrupt() {
        cancelRecognition(); tts?.stop()
        cancelSystemRecognition()
        pending?.second?.error("interrupted", "Voice session interrupted", null); pending = null
        event("interrupted")
    }
    fun foreground(value: Boolean) {
        foreground = value
        if (!value) {
            // The explicitly launched system speech app owns its own microphone.
            // Pausing our activity for that dialog must not cancel its result.
            if (systemRequest != null) { tts?.stop(); abandonFocus() }
            else if (pending == null) interrupt() else { cancelRecognition(); tts?.stop() }
        }
    }
    private fun cancelSystemRecognition() {
        val request = systemRequest
        systemRequest = null; systemToken = null
        if (request != null) activity.finishActivity(request)
    }
    fun activityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != systemRequest) return false
        val token = systemToken ?: return false
        systemRequest = null; systemToken = null
        val hypotheses = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.take(5).orEmpty()
        val words = hypotheses.firstOrNull().orEmpty()
        if (resultCode == Activity.RESULT_OK && words.isNotBlank()) event("final", token, "text" to words,
            "alternatives" to hypotheses, "confidences" to (data?.getFloatArrayExtra(RecognizerIntent.EXTRA_CONFIDENCE_SCORES)?.take(5)?.map { it.toDouble() } ?: emptyList<Double>()))
        else event("systemCanceled", token)
        return true
    }
    fun permissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION) return false
        val request = pending; pending = null
        if (request != null) {
            val permissionGeneration = generation
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) handler.post {
                if (foreground && generation == permissionGeneration) start(request.first, request.second)
                else request.second.error("interrupted", "Return to SaveTrack and tap the microphone again.", null)
            }
            else request.second.error("permission", "Microphone access was not granted. Type instead.", null)
        }
        return true
    }
    private fun call(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> {
                initializeTts()
                val base = mutableMapOf<String, Any>(
                    "recognition" to (SpeechRecognizer.isRecognitionAvailable(activity) || (Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(activity))),
                    "onDevice" to (Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)),
                    "systemRecognition" to (activity.packageManager.resolveActivity(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH), PackageManager.MATCH_DEFAULT_ONLY) != null),
                    "tts" to ttsReady,
                    "ttsDefaultLocale" to defaultTtsLocale.toLanguageTag(),
                    "defaultLocale" to Locale.getDefault().toLanguageTag(),
                    "ttsLanguages" to (if (ttsReady) tts?.availableLanguages?.map { it.toLanguageTag() }?.sorted() ?: emptyList<String>() else emptyList<String>()),
                    "voiceDetails" to (if (ttsReady) tts?.voices?.map { mapOf("name" to it.name, "locale" to it.locale.toLanguageTag(), "network" to it.isNetworkConnectionRequired) } ?: emptyList<Map<String, Any>>() else emptyList<Map<String, Any>>()),
                    "voices" to (if (ttsReady) tts?.voices?.map { it.name }?.sorted() ?: emptyList<String>() else emptyList<String>())
                )
                var returned = false
                fun finish(languages: List<String>) { if (!returned) { returned = true; result.success(base + ("languages" to languages)) } }
                val intent = RecognizerIntent.getVoiceDetailsIntent(activity)
                if (intent == null) finish(emptyList()) else {
                    activity.sendOrderedBroadcast(intent, null, object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            finish(getResultExtras(true)?.getStringArrayList(RecognizerIntent.EXTRA_SUPPORTED_LANGUAGES)?.toList() ?: emptyList())
                        }
                    }, handler, Activity.RESULT_OK, null, null)
                    handler.postDelayed({ finish(emptyList()) }, 1500)
                }
            }
            "start" -> {
                if (recording || pending != null || systemRequest != null) { result.error("busy", "Recognition already active", null); return }
                if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    pending = call to result
                    activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION)
                } else start(call, result)
            }
            "stop" -> {
                val current = generation
                val token = session
                recognizer?.stopListening()
                handler.postDelayed({
                    if (generation == current && recording) {
                        event("final", token, "text" to lastTranscript)
                        cancelRecognition()
                    }
                }, 4000)
                result.success(null)
            }
            "cancel" -> { cancelRecognition(); cancelSystemRecognition(); pending?.second?.error("canceled", "Canceled", null); pending = null; result.success(null) }
            "stopSpeaking" -> { tts?.stop(); abandonFocus(); result.success(null) }
            "speak" -> speak(call, result)
            "startSystem" -> startSystemRecognition(call, result)
            "release" -> { interrupt(); tts?.shutdown(); tts = null; ttsReady = false; result.success(null) }
            else -> result.notImplemented()
        }
    }
    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val onDevice = call.argument<Boolean>("onDevice") == true
        if (!foreground) { result.error("interrupted", "Return to SaveTrack and tap the microphone again.", null); return }
        if (!onDevice && !SpeechRecognizer.isRecognitionAvailable(activity)) { result.error("unavailable", "No Android speech recognition service is available. Check your speech provider or use the Android speech dialog if available.", null); return }
        cancelRecognition(); tts?.stop()
        // Recognition is microphone input, not playback. The speech service may
        // manage its own focus; requesting playback focus here can cancel it.
        session = call.argument<String>("session") ?: ""
        val token = session
        val current = ++generation
        if (onDevice && (Build.VERSION.SDK_INT < 31 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(activity))) {
            result.error("on_device_unavailable", "This phone does not provide an available on-device recognizer. Turn off Require on-device recognition to explicitly allow the device speech service, or type instead.", null); return
        }
        try {
            recognizer = if (onDevice && Build.VERSION.SDK_INT >= 31) SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
                else SpeechRecognizer.createSpeechRecognizer(activity)
            recording = true
            recognizer?.setRecognitionListener(object : RecognitionListener {
                private fun valid() = generation == current && foreground
                private fun text(bundle: Bundle?) = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
                override fun onReadyForSpeech(params: Bundle?) { if (valid()) event("listening", token) }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) { if (valid()) event("amplitude", token, "value" to ((rmsdB + 2) / 12).coerceIn(0f,1f).toDouble()) }
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    if (!valid()) return
                    val failure = agentRecognitionFailure(error, onDevice)
                    event("error", token, "code" to failure.code, "nativeCode" to error, "message" to failure.message)
                    cancelRecognition()
                }
                override fun onResults(results: Bundle?) { if (valid()) {
                    event("final", token, "text" to text(results),
                        "alternatives" to (results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.take(5) ?: emptyList<String>()),
                        "confidences" to (results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)?.take(5)?.map { it.toDouble() } ?: emptyList<Double>()))
                    cancelRecognition()
                } }
                override fun onPartialResults(partialResults: Bundle?) { if (valid()) { lastTranscript = text(partialResults); event("partial", token, "text" to lastTranscript) } }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            val locale = call.argument<String>("locale") ?: ""
            if (locale.isNotEmpty()) intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            if (onDevice && Build.VERSION.SDK_INT >= 33) checkOnDeviceSupport(intent, token, current)
            else recognizer?.startListening(intent)
            // A hard cap releases the microphone even if a service never calls back.
            handler.postDelayed({ if (generation == current && recording) { event("error", token, "message" to "Listening timed out. Review the transcript or retry."); cancelRecognition() } }, 60000)
            result.success(null)
        } catch (_: SecurityException) { cancelRecognition(); result.error("permission", "Allow microphone access for SaveTrack in Android app settings, or type instead.", null) }
        catch (_: Exception) { cancelRecognition(); result.error("client", "The selected Android speech service could not start. Retry or check the installed speech provider in Android settings.", null) }
    }
    private fun checkOnDeviceSupport(intent: Intent, token: String, current: Int) {
        if (Build.VERSION.SDK_INT < 33) return
        var resolved = false
        fun valid() = !resolved && generation == current && foreground
        fun fail(code: Int) {
            if (!valid()) return
            resolved = true
            val failure = agentRecognitionFailure(code, true)
            event("error", token, "code" to failure.code, "nativeCode" to code, "message" to failure.message)
            cancelRecognition()
        }
        fun listen() {
            if (!valid()) return
            resolved = true
            try { recognizer?.startListening(intent) }
            catch (_: Exception) {
                val failure = agentRecognitionFailure(SpeechRecognizer.ERROR_CLIENT, true)
                event("error", token, "code" to failure.code, "nativeCode" to SpeechRecognizer.ERROR_CLIENT, "message" to failure.message)
                cancelRecognition()
            }
        }
        try {
            recognizer?.checkRecognitionSupport(intent, activity.mainExecutor, object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    if (!valid()) return
                    val installed = support.installedOnDeviceLanguages
                    event("support", token, "onDeviceLanguages" to installed)
                    val requested = intent.getStringExtra(RecognizerIntent.EXTRA_LANGUAGE) ?: Locale.getDefault().toLanguageTag()
                    when {
                        installed.isEmpty() -> fail(SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE)
                        !agentInstalledLanguageMatches(requested, installed) -> fail(
                            if (agentInstalledLanguageMatches(requested, support.supportedOnDeviceLanguages) || agentInstalledLanguageMatches(requested, support.pendingOnDeviceLanguages)) SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE
                            else SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED
                        )
                        else -> listen()
                    }
                }
                override fun onError(error: Int) {
                    // Some OEM services implement recognition but not this
                    // optional support query. Let that recognizer report its
                    // actual listening result, without switching providers.
                    if (error == SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT) listen() else fail(error)
                }
            })
        } catch (_: UnsupportedOperationException) { listen() }
        handler.postDelayed({
            if (valid()) {
                resolved = true
                event("error", token, "code" to "support_timeout", "message" to "The phone did not verify its on-device language model. Retry or open Voice settings. No remote fallback was started.")
                cancelRecognition()
            }
        }, 8000)
    }
    private fun startSystemRecognition(call: MethodCall, result: MethodChannel.Result) {
        if (call.argument<Boolean>("onDevice") == true) { result.error("on_device_required", "The Android speech dialog may use its provider. Turn off Require on-device recognition first if you want to allow it.", null); return }
        if (!foreground || systemRequest != null || recording || pending != null) { result.error("busy", "Finish the current voice session first.", null); return }
        cancelRecognition(); tts?.stop()
        session = call.argument<String>("session") ?: ""
        val request = nextSystemRequest++
        systemRequest = request; systemToken = session
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            .putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak your SaveTrack request")
        val locale = call.argument<String>("locale").orEmpty()
        if (locale.isNotEmpty()) intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
        try { activity.startActivityForResult(intent, request); result.success(null) }
        catch (_: ActivityNotFoundException) { systemRequest = null; systemToken = null; result.error("unavailable", "No Android speech dialog is installed. Use text input or enable a speech provider in Android settings.", null) }
    }
    private fun speak(call: MethodCall, result: MethodChannel.Result) {
        if (!foreground || !ttsReady) { result.error("unavailable", "TTS unavailable", null); return }
        cancelRecognition(); tts?.stop()
        if (!acquireFocus()) { result.error("focus", "Audio is in use", null); return }
        session = call.argument<String>("session") ?: ""
        val language = call.argument<String>("locale") ?: ""
        val selectedLocale = if (language.isEmpty()) defaultTtsLocale else Locale.forLanguageTag(language)
        if ((tts?.setLanguage(selectedLocale) ?: -1) < 0) {
            abandonFocus(); result.error("language", "Install a voice for this language", null); return
        }
        val voice = call.argument<String>("voice") ?: ""
        if (voice.isNotEmpty()) {
            val chosen = tts?.voices?.firstOrNull { it.name == voice }
            if (chosen == null) { abandonFocus(); result.error("voice", "Selected voice is no longer installed", null); return }
            if (language.isNotEmpty() && !agentInstalledLanguageMatches(language, listOf(chosen.locale.toLanguageTag()))) {
                abandonFocus(); result.error("language", "Selected voice does not match the spoken-response language. Choose a compatible voice.", null); return
            }
            tts?.voice = chosen
        }
        tts?.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANT).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
        tts?.setSpeechRate((call.argument<Double>("rate") ?: .9).toFloat().coerceIn(.5f,1.5f))
        val text = call.argument<String>("text") ?: ""
        if (text.isEmpty() || text.length > 1200 || tts?.speak(text,TextToSpeech.QUEUE_FLUSH,null,session) != TextToSpeech.SUCCESS) {
            abandonFocus(); result.error("speech", "Could not speak response", null)
        } else result.success(null)
    }
    fun dispose() { interrupt(); tts?.shutdown(); tts = null; channel.setMethodCallHandler(null) }
}
