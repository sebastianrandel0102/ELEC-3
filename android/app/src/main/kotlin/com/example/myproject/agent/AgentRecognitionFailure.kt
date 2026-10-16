package com.example.myproject.agent

import android.speech.SpeechRecognizer
import java.util.Locale

internal data class AgentRecognitionFailure(val code: String, val message: String)

/** Preserve the actual Android cause; an audio/client error is not a language error. */
internal fun agentRecognitionFailure(error: Int, onDevice: Boolean): AgentRecognitionFailure {
    val service = if (onDevice) "On-device speech recognition" else "Android's speech service"
    return when (error) {
        SpeechRecognizer.ERROR_AUDIO -> AgentRecognitionFailure("audio", "The microphone could not capture audio. Close any app using the microphone, check microphone access in Android settings, and retry.")
        SpeechRecognizer.ERROR_CLIENT -> AgentRecognitionFailure("client", "$service could not start this session. Retry or check the installed speech service in Android settings.")
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> AgentRecognitionFailure("permission", "Microphone permission was denied. Allow microphone access for SaveTrack in Android app settings, or type instead.")
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> AgentRecognitionFailure("network", "$service could not connect. Check your connection and try again.")
        SpeechRecognizer.ERROR_NO_MATCH -> AgentRecognitionFailure("no_match", "No words were recognized. Tap Speak a turn and try again, or type your request.")
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> AgentRecognitionFailure("speech_timeout", "No speech was detected before the microphone timed out. Tap Speak a turn and try again.")
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> AgentRecognitionFailure("busy", "The speech service is busy. Stop other voice input, wait a moment, and try again.")
        SpeechRecognizer.ERROR_SERVER -> AgentRecognitionFailure("server", "$service returned a service error. Retry or check the installed speech service in Android settings.")
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> AgentRecognitionFailure("rate_limit", "The speech service has temporarily limited requests. Wait before trying again; you can keep typing.")
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> AgentRecognitionFailure("service_disconnected", "$service disconnected. Retry or check the installed speech service in Android settings.")
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> AgentRecognitionFailure("language_unsupported", "This speech recognizer does not support the requested language. Choose a supported language in Voice settings.")
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> AgentRecognitionFailure("language_unavailable", if (onDevice) "The on-device language model is not installed or ready. Download a model in your speech provider's settings, choose an installed language, or explicitly turn off Require on-device recognition." else "The requested speech language is not available yet. Choose Device default or another installed language in Voice settings.")
        else -> AgentRecognitionFailure("recognition", "$service could not complete this session. Retry or open Voice settings. The Android error number below can help diagnose the problem.")
    }
}

internal fun agentInstalledLanguageMatches(requested: String, installed: List<String>): Boolean {
    val locale = Locale.forLanguageTag(requested.replace('_', '-'))
    return installed.any { tag ->
        val candidate = Locale.forLanguageTag(tag.replace('_', '-'))
        candidate.toLanguageTag().equals(locale.toLanguageTag(), ignoreCase = true) ||
            (locale.country.isEmpty() && locale.script.isEmpty() && candidate.language == locale.language)
    }
}
