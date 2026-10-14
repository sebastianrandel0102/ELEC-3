import 'ai_domain.dart';

abstract interface class AiGateway {
  Stream<String> generate(AiRequest request);
}

abstract interface class AiGatewayPreflight {
  Future<void> prepare({bool forceRefresh = false});
}

abstract interface class AiContextSource {
  Future<List<AiLocalFacts>> goals();
  Future<AiLocalFacts> planner(DateTime date);
  Future<AiLocalFacts> report(DateTime weekStart);
  Future<bool> isCurrent(AiLocalFacts facts);
}

abstract interface class AiContextWatcher {
  Stream<void> invalidations(AiLocalFacts facts);
}
