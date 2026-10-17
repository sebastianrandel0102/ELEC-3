import '../agent_domain.dart';
import 'date_expression_parser.dart';
import 'money_expression_parser.dart';

/// Domain adapters for short field responses and compound title corrections.
/// They only patch typed drafts; repository access and approval live elsewhere.
class DraftFieldResolver {
  const DraftFieldResolver();
  AgentAction apply(
    AgentAction action,
    MoneyExpression money,
    DateExpression calendar,
    String command,
  ) {
    final values = action.toJson();
    if (action is GoalDraft ||
        action is ContributionDraft ||
        action is ScenarioDraft ||
        action is AllocationDraft) {
      final key = action is ScenarioDraft
          ? RegExp(r'\b(target|worth|budget)\b').hasMatch(command) ||
                    action.target.isEmpty &&
                        !RegExp(r'\b(contribution|save|weekly|daily|monthly)\b')
                            .hasMatch(command)
                ? 'target'
                : 'contribution'
          : action is AllocationDraft
          ? 'budget'
          : 'amount';
      if (money.amount.isNotEmpty || money.ambiguous) {
        values[key] = money.amount;
      }
      if (money.currency.isNotEmpty || money.currencyAmbiguous) {
        values['currency'] = money.currency;
      }
    }
    if (action is GoalDraft || action is ScenarioDraft) {
      if (calendar.date != null || calendar.ambiguousDate) {
        values['deadline'] = calendar.date?.toIso8601String();
      }
    }
    if (action is TaskDraft || action is ReminderDraft) {
      if (calendar.date != null || calendar.ambiguousDate) {
        values['day'] = calendar.date?.toIso8601String();
      }
      if (calendar.time.isNotEmpty || calendar.ambiguousTime) {
        values['time'] = calendar.time;
      }
    }
    if (action is TaskDraft) {
      if (RegExp(r'\b(priority high|high priority|urgent|mataas)\b')
          .hasMatch(command)) {
        values['priority'] = 'High';
      }
      if (RegExp(r'\b(priority low|low priority|mababa)\b').hasMatch(command)) {
        values['priority'] = 'Low';
      }
      if (RegExp(r'\b(priority normal|normal priority)\b').hasMatch(command)) {
        values['priority'] = 'Normal';
      }
    }
    if (action is ReminderDraft) {
      if (calendar.weekday != null) values['weekday'] = calendar.weekday;
      if (calendar.frequency.isNotEmpty) {
        values['frequency'] = calendar.frequency;
      } else if (calendar.date != null) {
        values['frequency'] = 'once';
      }
      if (calendar.unsupportedRecurrence) values['frequency'] = '';
    }
    return AgentAction.fromJson(values);
  }
}
