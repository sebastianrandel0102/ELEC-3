import '../agent_domain.dart';

class VoiceLocaleRepository {
  const VoiceLocaleRepository();
  static String base(String locale) =>
      locale.replaceAll('_', '-').split('-').first.toLowerCase();
  static bool filipino(String locale) => ['fil', 'tl'].contains(base(locale));
  static String canonical(String locale) =>
      locale.replaceAll('_', '-').toLowerCase();
  String? recognition(
    AgentSettings settings,
    Map<String, dynamic> capabilities,
  ) {
    final key =
        settings.onDevice && capabilities.containsKey('onDeviceLanguages')
        ? 'onDeviceLanguages'
        : 'languages';
    final locales = (capabilities[key] as List? ?? []).cast<String>();
    if (settings.locale.isNotEmpty) {
      // With an on-device recognizer, the native support query will verify the
      // installed model before listening if no installed list is known yet.
      return locales
          .where((l) => canonical(l) == canonical(settings.locale))
          .firstOrNull;
    }
    if (settings.speechLanguage == AgentLanguage.automatic) return '';
    if (settings.speechLanguage == AgentLanguage.filipino ||
        settings.speechLanguage == AgentLanguage.taglish) {
      final fil = locales.where(filipino).firstOrNull;
      if (fil != null) return fil;
      if (settings.speechLanguage == AgentLanguage.filipino) return null;
    }
    return locales.where((l) => base(l) == 'en').firstOrNull;
  }

  String? speech(AgentSettings settings, Map<String, dynamic> capabilities) {
    final locales = (capabilities['ttsLanguages'] as List? ?? [])
        .cast<String>();
    if (settings.ttsLocale.isNotEmpty) {
      return locales
          .where((l) => canonical(l) == canonical(settings.ttsLocale))
          .firstOrNull;
    }
    return ''; // Explicitly uses the device TTS default, separately from ASR.
  }
}
