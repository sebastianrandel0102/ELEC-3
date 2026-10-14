import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system.dart';
import 'ai_app_check.dart';
import 'ai_domain.dart';
import 'firebase_ai_gateway.dart' show mapAiError;

Future<bool?> showAiSetup(
  BuildContext context, {
  required Future<void> Function() verify,
}) => showModalBottomSheet<bool>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (context) => AiSetupSheet(verify: verify),
);

class AiSetupSheet extends StatefulWidget {
  const AiSetupSheet({super.key, required this.verify});
  final Future<void> Function() verify;
  @override
  State<AiSetupSheet> createState() => _AiSetupSheetState();
}

class _AiSetupSheetState extends State<AiSetupSheet> {
  final _key = TextEditingController();
  bool _checking = false;
  AiFailure? _failure;
  bool get _needsKey =>
      kIsWeb &&
      !AiAppCheck.ready &&
      AiAppCheck.provider != AiProtectionProvider.webDebug;
  bool get _debug => [
    AiProtectionProvider.webDebug,
    AiProtectionProvider.androidDebug,
    AiProtectionProvider.appleDebug,
  ].contains(AiAppCheck.provider);

  Future<void> _open(String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Unable to open');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Firebase Console.')),
        );
      }
    }
  }

  Future<void> _verify() async {
    setState(() {
      _checking = true;
      _failure = null;
    });
    try {
      if (_needsKey) await AiAppCheck.saveWebSiteKey(_key.text);
      await widget.verify();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _failure = mapAiError(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.shield_outlined, color: teal, size: 32),
        const SizedBox(height: 14),
        const Text(
          'Connect SaveTrack AI',
          style: TextStyle(
            color: ink,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Firebase must verify this app before it can ask Gemini a question. Your question stays in the composer until protection is ready.',
          style: TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 18),
        _step(
          '1',
          _debug
              ? 'Register this development device'
              : 'Register this app in App Check',
          _debug
              ? 'Find the Firebase App Check debug token in the browser console or device logs. In Firebase → App Check → Apps, choose SaveTrack and add it under Manage debug tokens.'
              : 'In Firebase → App Check → Apps, register the SaveTrack web app with reCAPTCHA v3 and its published domain. Android uses Play Integrity; Apple uses native attestation.',
        ),
        OutlinedButton.icon(
          onPressed: _checking ? null : () => _open(AiAppCheck.appCheckUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Open Firebase App Check'),
        ),
        if (_needsKey) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Public reCAPTCHA v3 site key',
              helperText: 'Use the site key registered for this web app. Never enter a secret key.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The public key is saved only for this browser. Future builds can also include it in their build configuration.',
            style: TextStyle(color: muted, height: 1.5, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        _step(
          '2',
          'Enable Gemini in Firebase AI Logic',
          'Choose Gemini Developer API and confirm access to the configured Flash-Lite model. Keep the project on Spark; no billing upgrade is needed.',
        ),
        TextButton.icon(
          onPressed: _checking ? null : () => _open(AiAppCheck.aiLogicUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Open Firebase AI Logic'),
        ),
        const SizedBox(height: 14),
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _failure!.message,
                style: const TextStyle(
                  color: SaveTrackDesign.error,
                  height: 1.5,
                ),
              ),
            ),
          ),
        FilledButton(
          onPressed: _checking ? null : _verify,
          child: _checking
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Flexible(child: Text('Checking protection…')),
                  ],
                )
              : Text(
                  _needsKey
                      ? 'Save site key & check connection'
                      : 'Check connection',
                ),
        ),
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _step(String number, String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SaveTrackDesign.lightMint,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
