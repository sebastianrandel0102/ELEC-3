import '../agent_domain.dart';

/// Matching normalization only; original utterances and names stay untouched.
class MultilingualNormalizer {
  const MultilingualNormalizer();
  String normalize(String input) => input
      .replaceAll(RegExp('[\u2018\u2019]'), "'")
      .replaceAll(RegExp('[\u201c\u201d]'), '"')
      .replaceAll(RegExp('[\u2010-\u2014]'), '-')
      .replaceAll('\u00a0', ' ')
      .replaceAllMapped(
        RegExp('[\uff01-\uff5e]'),
        (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xfee0),
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase()
      .replaceAllMapped(
        RegExp(r"\b(gsto|gsto ko|gawa ka|pls|plz|tmrw|bks|d2|jan)\b"),
        (m) => const {
          'gsto': 'gusto',
          'gsto ko': 'gusto ko',
          'gawa ka': 'gawa ka',
          'pls': 'please',
          'plz': 'please',
          'tmrw': 'tomorrow',
          'bks': 'bukas',
          'd2': 'dito',
          'jan': 'jan',
        }[m[0]]!,
      );
}

class AgentLanguageDetector {
  const AgentLanguageDetector();
  AgentLanguage detect(
    String input, {
    AgentLanguage previous = AgentLanguage.automatic,
  }) {
    final text = const MultilingualNormalizer().normalize(input);
    if (RegExp(r'^(okay|ok|yes|no|go|oo|opo|sige|yun|iyon|it|that)[.!]?$')
        .hasMatch(text)) {
      return previous;
    }
    final fil = RegExp(
      r'\b(ako|ko|mo|ka|ng|sa|para|gusto|gawa|gawan|ipon|bukas|paalala|tuwing|huwag|wag|lang|pala|yung|po|naman|dagdagan|bawasan|ayusin|magtabi|maghulog|limang|libo|daan)\b',
    ).allMatches(text).length;
    final en = RegExp(
      r'\b(create|make|goal|savings|target|task|tasks|remind|reminder|every|tomorrow|please|save|add|help|want|hundred|thousand|weekly|plan)\b',
    ).allMatches(text).length;
    if (fil > 0 && en > 0) return AgentLanguage.taglish;
    if (fil > 0) return AgentLanguage.filipino;
    if (en > 0) return AgentLanguage.english;
    return previous;
  }
}

String agentLanguageLabel(AgentLanguage language) => switch (language) {
  AgentLanguage.automatic => 'Automatic',
  AgentLanguage.english => 'English',
  AgentLanguage.filipino => 'Filipino / Tagalog',
  AgentLanguage.taglish => 'Taglish',
};

/// Agent-only resources; canonical action names never depend on translations.
class AgentStrings {
  const AgentStrings(this.language);
  final AgentLanguage language;
  static const _filipino = <String, String>{
    'Agent settings': 'Mga setting ng Agent',
    'Execute approved actions': 'Isagawa ang mga aprubadong hakbang',
    'Create personal goals': 'Gumawa ng personal na goal',
    'Create Planner tasks': 'Gumawa ng gawain sa Planner',
    'Create reminders': 'Gumawa ng paalala',
    'Prepare contributions': 'Ihanda ang dagdag ipon',
    'Private context access': 'Pahintulot sa pribadong detalye',
    'Spoken replies': 'Mga sagot na binibigkas',
    'Voice & audio privacy': 'Boses at pagkapribado ng audio',
    'Hide financial details in speech': 'Itago ang detalye ng pera sa boses',
    'Require on-device recognition': 'Gamitin lang ang recognizer sa device',
    'Local history & memory': 'Lokal na kasaysayan at mga kagustuhan',
    'Save mission history on this device':
        'Itago ang kasaysayan ng mission sa device',
    'Clear mission history': 'Burahin ang kasaysayan ng mission',
    'Use approved preference memory': 'Gamitin ang mga pinayagang kagustuhan',
    'Mission history': 'Kasaysayan ng mission',
    'Clear conversation': 'Burahin ang usapan',
    'Switch to text': 'Mag-type na lang',
    'Open voice mode': 'Gamitin ang boses',
    'Keep editing': 'Ituloy ang pag-edit',
    'Edit details': 'I-edit ang detalye',
    'Add step': 'Magdagdag ng hakbang',
    'Save draft': 'Itago ang draft',
    'Cancel mission': 'Kanselahin ang mission',
    'A few details first': 'Linawin muna ang ilang detalye',
    'Needs details': 'May kulang pang detalye',
    'Ready for review': 'Handa nang suriin',
    'Draft': 'Draft pa lang',
    'Completed': 'Natapos',
    'Canceled': 'Kinansela',
    'Partially completed': 'May mga natapos na hakbang',
    'Cancel': 'Kanselahin',
    'Save draft details': 'Itago ang detalye ng draft',
    'Goal name': 'Pangalan ng goal',
    'Target amount': 'Target na halaga',
    'Task title': 'Pamagat ng gawain',
    'Currency (required)': 'Currency (kailangan)',
    'Deadline': 'Takdang petsa',
    'Task date': 'Petsa ng gawain',
    'Reminder time': 'Oras ng paalala',
    'Load my personal goals': 'Ipakita ang mga personal kong goal',
    'Weekday': 'Araw ng linggo',
  };
  String text(String value) => choose(value, _filipino[value] ?? value);
  String choose(String en, String fil, [String? taglish]) => switch (language) {
    AgentLanguage.filipino => fil,
    AgentLanguage.taglish => taglish ?? fil,
    _ => en,
  };
  String get welcome => choose(
    'A little intention.\nA clear next step.',
    'Ano ang gusto mong gawin?',
    'Anong gusto mong i-plan today?',
  );
  String get hint => choose(
    'What would you like to accomplish?',
    'Sabihin kung ano ang gusto mong gawin…',
    'Type or sabihin ang plan mo…',
  );
  String get languageSettings =>
      choose('Language & Understanding', 'Wika at Pag-unawa');
  String get privateSpokenNotice => choose(
    'Your SaveTrack response is ready. Review the details privately on your screen. Changes require on-screen approval.',
    'Handa na ang sagot ng SaveTrack. Suriin nang pribado ang mga detalye sa screen. Kailangan ng kumpirmasyon sa screen bago may baguhin.',
    'Ready na ang sagot ng SaveTrack. Check mo nang pribado ang details sa screen. Kailangan pa rin ng approval sa screen.',
  );
  String get draftNotice => choose(
    'I prepared an editable local proposal. No records have changed.',
    'Naghanda ako ng lokal na draft na puwedeng i-edit. Wala pang nabagong rekord.',
    'Ready na ang editable draft. Wala pang nabagong record.',
  );
  String get review =>
      choose('Review mission', 'Suriin ang mission', 'Review ang mission');
  String get confirm =>
      choose('Approve selected actions', 'Kumpirmahin ang mga Pagbabago');
  String get transcript =>
      choose('Review recognized text', 'Suriin ang narinig na teksto');
  String get amount => choose(
    'What exact amount should I use?',
    'Magkano mismo ang gagamitin natin?',
  );
  String get currency => choose(
    'Which currency should I use?',
    'Anong currency ang gagamitin natin?',
  );
  String get date => choose(
    'Which exact date? Use YYYY-MM-DD.',
    'Anong eksaktong petsa? Gamitin ang YYYY-MM-DD.',
  );
  String get time => choose(
    'What time, including AM or PM?',
    'Anong oras, kasama ang AM o PM?',
  );
  String get goal => choose(
    'Which personal goal? Select a goal below.',
    'Aling personal na goal? Pumili sa ibaba.',
  );
  String get step => choose(
    'Which step should change? Use “step 1”, “step 2”, or edit a card.',
    'Aling hakbang ang babaguhin? Sabihin ang “step 1” o i-edit ang card.',
  );
  String summary(AgentAction action) => choose(action.summary, switch (action) {
    GoalDraft a =>
      '${a.name} · ${agentMoney(a.amount, a.currency)} · ${a.deadline == null ? 'Kailangan ng takdang petsa' : agentDay(a.deadline!)}',
    TaskDraft a =>
      '${a.title} · ${a.day == null ? 'Kailangan ng petsa' : agentDay(a.day!)} · ${a.time.isEmpty ? 'Malayang oras' : a.time} · ${a.priority}',
    ContributionDraft a =>
      '${agentMoney(a.amount, a.currency)} · Bubuksan ang Add Savings para sa hiwalay na kumpirmasyon',
    ReminderDraft a =>
      '${a.frequency} · ${a.weekday == null ? '' : ['Lunes', 'Martes', 'Miyerkules', 'Huwebes', 'Biyernes', 'Sabado', 'Linggo'][a.weekday!.clamp(1, 7) - 1]} ${a.day == null ? '' : agentDay(a.day!)} · ${a.time.isEmpty ? 'Kailangan ng oras' : a.time} · ${a.targetStep.isEmpty ? 'Personal na item' : 'Nakaugnay na hakbang'}',
    _ => action.summary,
  });
  String action(AgentAction action) =>
      choose(action.label, switch (action.type) {
        AgentActionType.createGoal => 'Gumawa ng savings goal',
        AgentActionType.createTask => 'Gumawa ng gawain',
        AgentActionType.createReminder => 'Mag-set ng paalala',
        AgentActionType.contribution => 'Ihanda ang dagdag ipon',
        AgentActionType.scenario => 'Kuwentahin ang savings plan',
        AgentActionType.allocation => 'Kuwentahin ang hatian ng ipon',
      });
}
