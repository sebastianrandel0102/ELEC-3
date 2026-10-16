import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'agent_domain.dart';

abstract interface class AgentStore {
  Future<AgentSettings> settings(String uid);
  Future<void> saveSettings(String uid, AgentSettings settings);
  Future<List<AgentMission>> history(String uid);
  Future<void> saveHistory(String uid, List<AgentMission> missions);
  Future<void> clear(String uid);
}

/// Local, account-scoped, opt-in history. Never persists approvals or chat/audio.
/// SharedPreferences is app-local storage, not an encrypted vault.
class PreferenceAgentStore implements AgentStore {
  String _key(String uid, String suffix) => 'savetrack.agent.v1.$uid.$suffix';
  @override
  Future<AgentSettings> settings(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return AgentSettings.fromJson(
        jsonDecode(prefs.getString(_key(uid, 'settings')) ?? '{}')
            as Map<String, dynamic>,
      );
    } catch (_) {
      return AgentSettings();
    }
  }

  @override
  Future<void> saveSettings(String uid, AgentSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key(uid, 'settings'),
      jsonEncode(settings.toJson()),
    )) {
      throw const AgentFailure('Could not save Agent settings.');
    }
  }

  @override
  Future<List<AgentMission>> history(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final result = <AgentMission>[];
    try {
      final raw = prefs.getString(_key(uid, 'history')) ?? '[]';
      if (raw.length > 2000000) return [];
      for (final value in (jsonDecode(raw) as List).take(50)) {
        try {
          final m = AgentMission.fromJson(value as Map<String, dynamic>);
          if (m.uid != uid || m.createdAt.isBefore(cutoff)) continue;
          // A restart never resumes approval or executes anything automatically.
          result.add(
            m.copyWith(
              status:
                  m.status == MissionStatus.executing ||
                      m.status == MissionStatus.approved
                  ? MissionStatus.partiallyCompleted
                  : m.status,
              steps: [
                for (final s in m.steps)
                  s.status == StepStatus.executing
                      ? s.copyWith(
                          status: StepStatus.failed,
                          result: 'Execution interrupted. Review and retry to reconcile the server record.',
                        )
                      : s,
              ],
            ),
          );
        } catch (_) {
          /* Ignore a corrupt entry without exposing its contents. */
        }
      }
    } catch (_) {
      return [];
    }
    return result;
  }

  @override
  Future<void> saveHistory(String uid, List<AgentMission> missions) async {
    final prefs = await SharedPreferences.getInstance();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final values = missions
        .where((m) => m.uid == uid && !m.createdAt.isBefore(cutoff))
        .take(50)
        .map((m) => m.toJson())
        .toList();
    if (!await prefs.setString(_key(uid, 'history'), jsonEncode(values))) {
      throw const AgentFailure('Could not save mission recovery history.');
    }
  }

  @override
  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid, 'history'));
  }
}
