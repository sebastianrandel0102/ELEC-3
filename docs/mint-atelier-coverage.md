# Mint Atelier surface and component coverage

These are existing surfaces or substates, not 106 separate routes. **Direct refinement** identifies a changed local layout, control, picker or palette. **Shared system** identifies an existing composition adopting the updated foundations. Evidence names refer to relevant fixture/regression families; they do not claim every live state was exercised. See [the implementation report](mint-atelier-iphone.md) for final results and host limits.

## Surfaces

| ID | Surface | Owning source | Treatment / capability | Relevant automated evidence |
| --- | --- | --- | --- | --- |
| S001 | Firebase setup failure | [lib/main.dart#SetupScreen](../lib/main.dart) | Direct refinement | widget_test; redesign; Google/password |
| S002 | Authenticated session loading | [lib/main.dart#SessionLoading](../lib/main.dart) | Direct refinement | widget_test; redesign; Google/password |
| S003 | Email sign-in | [lib/main.dart#AuthScreen](../lib/main.dart) | Direct refinement | widget_test; redesign; Google/password |
| S004 | Account registration | [lib/main.dart#AuthScreen](../lib/main.dart) | Direct refinement | widget_test; redesign; Google/password |
| S005 | Google sign-in handoff | [lib/main.dart#_signInWithGoogle](../lib/main.dart) | Direct refinement | widget_test; redesign; Google/password |
| S006 | Password recovery request | [lib/password_recovery_dialog.dart#PasswordRecoveryDialog](../lib/password_recovery_dialog.dart) | Shared system | widget_test; redesign; Google/password |
| S007 | Password recovery sent and resend | [lib/password_recovery_dialog.dart#PasswordRecoveryDialog](../lib/password_recovery_dialog.dart) | Shared system | widget_test; redesign; Google/password |
| S008 | Password change verification | [lib/password_dialog.dart#PasswordDialog](../lib/password_dialog.dart) | Shared system | widget_test; redesign; Google/password |
| S009 | New password and completion | [lib/password_dialog.dart#PasswordDialog](../lib/password_dialog.dart) | Shared system | widget_test; redesign; Google/password |
| S010 | Five-tab application shell | [lib/main.dart#HomeShell](../lib/main.dart) | Direct refinement | precision_edition; home_atelier; mint_atelier |
| S011 | Assist chooser | [lib/precision_components.dart#AuroraAssistChooser](../lib/precision_components.dart) | Shared system | precision_edition; home_atelier; mint_atelier |
| S012 | Today overview | [lib/home_atelier.dart#HomeAtelier](../lib/home_atelier.dart) | Direct refinement | precision_edition; home_atelier; mint_atelier |
| S013 | Home goal gallery | [lib/home_atelier.dart#GoalGallery](../lib/home_atelier.dart) | Direct refinement | precision_edition; home_atelier; mint_atelier |
| S014 | Quick-save goal selection | [lib/home_atelier.dart#_chooseSavingsGoal](../lib/home_atelier.dart) | Shared system | precision_edition; home_atelier; mint_atelier |
| S015 | Customize Home | [lib/atelier_preferences.dart#CustomizeHomeScreen](../lib/atelier_preferences.dart) | Shared system | precision_edition; home_atelier; mint_atelier |
| S016 | Appearance selection | [lib/atelier_preferences.dart#showAppearancePicker](../lib/atelier_preferences.dart) | Shared system | precision_edition; home_atelier; mint_atelier |
| S017 | Personal goal browser | [lib/home_atelier.dart#GoalBrowser](../lib/home_atelier.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S018 | Goal filter and sort controls | [lib/home_atelier.dart#GoalFilter and GoalSort](../lib/home_atelier.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S019 | Goal gallery grid and list variants | [lib/home_atelier.dart#GoalGallery and AtelierGoalTile](../lib/home_atelier.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S020 | Goal type chooser | [lib/main.dart#showGoalTypeChoice](../lib/main.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S021 | Create personal goal | [lib/main.dart#showGoalForm](../lib/main.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S022 | Edit personal goal | [lib/main.dart#showGoalForm](../lib/main.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S023 | Personal goal details | [lib/precision_flows.dart#PersonalGoalOverview](../lib/precision_flows.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S024 | Add personal savings | [lib/currency_savings_dialog.dart#CurrencySavingsDialog](../lib/currency_savings_dialog.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S025 | Currency conversion review in savings | [lib/currency_savings_dialog.dart#LockedMoneyEntry presentation](../lib/currency_savings_dialog.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S026 | Decrease personal savings | [lib/decrease_savings_dialog.dart#DecreaseSavingsDialog and lib/currency_savings_dialog.dart](../lib/decrease_savings_dialog.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S027 | Personal transaction history | [lib/precision_flows.dart and lib/main.dart#showTransactionHistory](../lib/precision_flows.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S028 | Personal transaction detail | [lib/precision_flows.dart#PersonalTransactionTile](../lib/precision_flows.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S029 | Delete personal goal confirmation | [lib/main.dart#delete goal flow](../lib/main.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S030 | Goal cover action menu | [lib/goal_cover_widgets.dart#showGoalCoverActions](../lib/goal_cover_widgets.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S031 | Goal cover crop editor | [lib/goal_cover_widgets.dart and lib/goal_cover_processing.dart](../lib/goal_cover_widgets.dart) | Direct refinement | home_atelier; goal_cover; currency; savings_decrease |
| S032 | Goal cover viewer and upload recovery | [lib/goal_cover_widgets.dart#GoalCoverPreview and GoalCoverRouteGuard](../lib/goal_cover_widgets.dart) | Shared system | home_atelier; goal_cover; currency; savings_decrease |
| S033 | Save Together overview | [lib/shared_savings_screens.dart#SharedGoalsPanel](../lib/shared_savings_screens.dart) | Direct refinement | shared_savings; mint_aurora; mint_atelier |
| S034 | Create shared goal | [lib/shared_savings_screens.dart#SharedGoalFormScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S035 | Shared goal settings | [lib/shared_savings_screens.dart#SharedGoalFormScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S036 | Shared goal details | [lib/shared_savings_screens.dart#SharedGoalDetailsScreen](../lib/shared_savings_screens.dart) | Direct refinement | shared_savings; mint_aurora; mint_atelier |
| S037 | Shared contribution entry | [lib/shared_savings_screens.dart#SharedContributionScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S038 | Shared savings decrease | [lib/shared_savings_screens.dart#SharedContributionScreen decrease mode](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S039 | Shared members | [lib/shared_savings_screens.dart#SharedMembersScreen](../lib/shared_savings_screens.dart) | Direct refinement | shared_savings; mint_aurora; mint_atelier |
| S040 | Invitation issue and management | [lib/shared_savings_screens.dart#SharedInvitesScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S041 | Redeem invitation and join preview | [lib/shared_savings_screens.dart#SharedInvitationScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S042 | Shared activity history | [lib/shared_savings_screens.dart#SharedHistoryScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S043 | Archive shared goal | [lib/shared_savings_screens.dart#SharedActionDialog](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S044 | Leave shared goal | [lib/shared_savings_screens.dart#SharedGoalDetailsScreen leave flow](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S045 | Remove shared member | [lib/shared_savings_screens.dart#SharedMembersScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S046 | Revoke shared invitation | [lib/shared_savings_screens.dart#SharedInvitesScreen](../lib/shared_savings_screens.dart) | Shared system | shared_savings; mint_aurora; mint_atelier |
| S047 | Daily Planner | [lib/main.dart#PlannerScreen](../lib/main.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S048 | Weekly Planner | [lib/home_atelier.dart#WeeklyPlanner](../lib/home_atelier.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S049 | Create planner task | [lib/main.dart#showTaskForm](../lib/main.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S050 | Edit planner task | [lib/main.dart#showTaskForm](../lib/main.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S051 | Delete planner task | [lib/main.dart#confirmDelete and task deletion callback](../lib/main.dart) | Shared system | home_atelier; smart_suggestions; reminders; mint_atelier |
| S052 | Smart task recommendations | [lib/smart_suggestions.dart and lib/smart_task_recommendation_service.dart](../lib/smart_suggestions.dart) | Shared system | home_atelier; smart_suggestions; reminders; mint_atelier |
| S053 | Planner date selection | [lib/main.dart#PlannerDateHeader and task date picker](../lib/main.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S054 | Smart Reminders agenda | [lib/reminder_widgets.dart#SmartRemindersScreen](../lib/reminder_widgets.dart) | Shared system | home_atelier; smart_suggestions; reminders; mint_atelier |
| S055 | Savings reminder editor | [lib/reminder_widgets.dart#ReminderEditor](../lib/reminder_widgets.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S056 | Task reminder editor | [lib/reminder_widgets.dart#ReminderEditor](../lib/reminder_widgets.dart) | Direct refinement | home_atelier; smart_suggestions; reminders; mint_atelier |
| S057 | Notification and precise-timing status | [lib/reminder_widgets.dart#SmartRemindersScreen phone controls](../lib/reminder_widgets.dart) | Shared system; OS capability gates retained | home_atelier; smart_suggestions; reminders; mint_atelier |
| S058 | Reports overview | [lib/main.dart#ReportsScreen and ReportsLayout](../lib/main.dart) | Direct refinement | home_atelier; redesign; mint_atelier |
| S059 | Savings Pulse chart and metrics | [lib/home_atelier.dart#SavingsPulse and PulseContent](../lib/home_atelier.dart) | Direct refinement | home_atelier; redesign; mint_atelier |
| S060 | Shared savings reports | [lib/shared_savings_screens.dart#SharedGoalsPanel report mode](../lib/shared_savings_screens.dart) | Shared system | home_atelier; redesign; mint_atelier |
| S061 | Daily and weekly task reports | [lib/main.dart#ReportTaskMetric](../lib/main.dart) | Shared system | home_atelier; redesign; mint_atelier |
| S062 | Profile and settings index | [lib/main.dart#ProfileContent](../lib/main.dart) | Shared system | precision_edition; profile_photo; currency |
| S063 | Profile photo actions | [lib/profile_photo_widgets.dart#ProfilePhotoAction](../lib/profile_photo_widgets.dart) | Shared system | precision_edition; profile_photo; currency |
| S064 | Profile photo crop and upload | [lib/profile_photo_widgets.dart#ProfilePhotoEditor](../lib/profile_photo_widgets.dart) | Shared system | precision_edition; profile_photo; currency |
| S065 | Profile photo viewer and fallback | [lib/profile_photo_widgets.dart#ProfilePhotoPreview and ProfileAvatar](../lib/profile_photo_widgets.dart) | Shared system | precision_edition; profile_photo; currency |
| S066 | Currency Settings | [lib/currency_settings_screen.dart#CurrencySettingsScreen](../lib/currency_settings_screen.dart) | Direct refinement | precision_edition; profile_photo; currency |
| S067 | Searchable currency picker | [lib/currency_widgets.dart#CurrencyPicker and chooseCurrency](../lib/currency_widgets.dart) | Direct refinement | precision_edition; profile_photo; currency |
| S068 | Currency converter | [lib/currency_settings_screen.dart#CurrencyConverter](../lib/currency_settings_screen.dart) | Shared system | precision_edition; profile_photo; currency |
| S069 | SaveTrack AI welcome | [lib/ai_coach/ai_coach_screen.dart#AiCoachScreen and lib/ai_coach/ai_widgets.dart](../lib/ai_coach/ai_coach_screen.dart) | Direct refinement | ai_conversation_atelier; ai_coach; ai_app_check |
| S070 | Ask Anything conversation | [lib/ai_coach/ai_coach_screen.dart and lib/ai_coach/ai_conversation_widgets.dart](../lib/ai_coach/ai_coach_screen.dart) | Direct refinement | ai_conversation_atelier; ai_coach; ai_app_check |
| S071 | SaveTrack Coach conversation | [lib/ai_coach/ai_coach_screen.dart#AiCoachScreen](../lib/ai_coach/ai_coach_screen.dart) | Direct refinement | ai_conversation_atelier; ai_coach; ai_app_check |
| S072 | AI context source selection | [lib/ai_coach/ai_coach_screen.dart#_chooseContext](../lib/ai_coach/ai_coach_screen.dart) | Direct refinement | ai_conversation_atelier; ai_coach; ai_app_check |
| S073 | AI context approval review | [lib/ai_coach/ai_widgets.dart#_AiContextReviewSheet](../lib/ai_coach/ai_widgets.dart) | Shared system | ai_conversation_atelier; ai_coach; ai_app_check |
| S074 | AI verified fact cards | [lib/ai_coach/ai_widgets.dart#AiFactCard](../lib/ai_coach/ai_widgets.dart) | Shared system | ai_conversation_atelier; ai_coach; ai_app_check |
| S075 | AI settings and appearance | [lib/ai_coach/ai_settings_sheet.dart](../lib/ai_coach/ai_settings_sheet.dart) | Shared system | ai_conversation_atelier; ai_coach; ai_app_check |
| S076 | AI provider privacy notice | [lib/ai_coach/ai_coach_screen.dart#_providerNotice](../lib/ai_coach/ai_coach_screen.dart) | Shared system | ai_conversation_atelier; ai_coach; ai_app_check |
| S077 | AI connection and App Check setup | [lib/ai_coach/ai_setup_sheet.dart#AiSetupSheet](../lib/ai_coach/ai_setup_sheet.dart) | Shared system | ai_conversation_atelier; ai_coach; ai_app_check |
| S078 | Clear AI chat or revoke context | [lib/ai_coach/ai_coach_screen.dart#_clear and overflow actions](../lib/ai_coach/ai_coach_screen.dart) | Shared system | ai_conversation_atelier; ai_coach; ai_app_check |
| S079 | Agent Studio home | [lib/agent_studio/agent_screen.dart#AgentStudioScreen](../lib/agent_studio/agent_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S080 | Agent typed composer and follow-ups | [lib/agent_studio/agent_screen.dart#_composer and _send](../lib/agent_studio/agent_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S081 | Agent voice listening | [lib/agent_studio/agent_screen.dart#_voicePanel and AgentVoiceOrb](../lib/agent_studio/agent_screen.dart) | Shared system; existing voice bridge only; typed fallback | agent_atelier; agent_studio; language; voice; autopilot |
| S082 | Agent transcript review | [lib/agent_studio/agent_screen.dart and lib/agent_studio/agent_voice.dart](../lib/agent_studio/agent_screen.dart) | Shared system; existing voice bridge only; typed fallback | agent_atelier; agent_studio; language; voice; autopilot |
| S083 | Agent interpretation and clarification | [lib/agent_studio/intelligence/interpretation_preview.dart and lib/agent_studio/agent_screen.dart#_clarification](../lib/agent_studio/intelligence/interpretation_preview.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S084 | Agent mission builder | [lib/agent_studio/agent_screen.dart#_mission and _step](../lib/agent_studio/agent_screen.dart) | Direct refinement | agent_atelier; agent_studio; language; voice; autopilot |
| S085 | Agent action picker | [lib/agent_studio/agent_step_editor.dart#showAgentActionPicker](../lib/agent_studio/agent_step_editor.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S086 | Agent step editor | [lib/agent_studio/agent_step_editor.dart#_StepEditor](../lib/agent_studio/agent_step_editor.dart) | Direct refinement | agent_atelier; agent_studio; language; voice; autopilot |
| S087 | Agent final mission approval | [lib/agent_studio/agent_screen.dart#_review](../lib/agent_studio/agent_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S088 | Agent execution and partial results | [lib/agent_studio/agent_screen.dart#_mission and lib/agent_studio/agent_engine.dart](../lib/agent_studio/agent_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S089 | Agent What-If scenario | [lib/agent_studio/presentation/agent_action_preview.dart#AgentActionPreview](../lib/agent_studio/presentation/agent_action_preview.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S090 | Agent goal allocation preview | [lib/agent_studio/presentation/agent_action_preview.dart and lib/agent_studio/agent_step_editor.dart](../lib/agent_studio/presentation/agent_action_preview.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S091 | Agent mission history | [lib/agent_studio/presentation/agent_history_screen.dart#AgentHistoryScreen](../lib/agent_studio/presentation/agent_history_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S092 | Agent general settings | [lib/agent_studio/agent_settings_screen.dart#AgentSettingsScreen](../lib/agent_studio/agent_settings_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S093 | Agent language selection | [lib/agent_studio/agent_settings_screen.dart and lib/agent_studio/agent_language_settings.dart](../lib/agent_studio/agent_settings_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S094 | Agent voice and audio settings | [lib/agent_studio/agent_settings_screen.dart#AgentSettingsScreen voice controls](../lib/agent_studio/agent_settings_screen.dart) | Shared system; existing voice bridge only; typed fallback | agent_atelier; agent_studio; language; voice; autopilot |
| S095 | Agent voice recovery | [lib/agent_studio/agent_screen.dart and android/app/src/main/kotlin/com/example/myproject/agent/AgentRecognitionFailure.kt](../lib/agent_studio/agent_screen.dart) | Shared system; existing voice bridge only; typed fallback | agent_atelier; agent_studio; language; voice; autopilot |
| S096 | Autopilot execution settings | [lib/agent_studio/autopilot/autopilot_settings_screen.dart#AgentAutopilotSettingsScreen](../lib/agent_studio/autopilot/autopilot_settings_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S097 | Automatic Actions activity ledger | [lib/agent_studio/autopilot/autopilot_activity_screen.dart#AgentAutopilotActivityScreen](../lib/agent_studio/autopilot/autopilot_activity_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S098 | Agent memory management | [lib/agent_studio/agent_settings_screen.dart#_MemoryScreen](../lib/agent_studio/agent_settings_screen.dart) | Shared system | agent_atelier; agent_studio; language; voice; autopilot |
| S099 | Home Screen Widgets gallery | [lib/home_widgets/widget_settings_screen.dart#HomeWidgetsSettingsScreen](../lib/home_widgets/widget_settings_screen.dart) | Direct refinement | home_widgets; native widget tests |
| S100 | Widget configuration studio | [lib/home_widgets/widget_settings_screen.dart#WidgetConfigurationScreen](../lib/home_widgets/widget_settings_screen.dart) | Direct refinement | home_widgets; native widget tests |
| S101 | Native Goal widget | [android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) | Direct refinement; Android RemoteViews only; no WidgetKit | home_widgets; native widget tests |
| S102 | Native Planner widget | [android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) | Direct refinement; Android RemoteViews only; no WidgetKit | home_widgets; native widget tests |
| S103 | Native Quick Save widget | [android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) | Direct refinement; Android RemoteViews only; no WidgetKit | home_widgets; native widget tests |
| S104 | Native Today widget | [android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt and res/layout/st_widget_today.xml](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) | Direct refinement; Android RemoteViews only; no WidgetKit | home_widgets; native widget tests |
| S105 | Widget signed-out and unavailable states | [lib/home_widgets/widget_host.dart and android/app/src/main/kotlin/com/example/myproject/widgets/WidgetStore.kt](../lib/home_widgets/widget_host.dart) | Direct refinement; Android RemoteViews only; no WidgetKit | home_widgets; native widget tests |
| S106 | Sign-out flow | [lib/main.dart#ProfileScreen signOut](../lib/main.dart) | Shared system | redesign; profile/account |

## Components

Each family uses shared Light/Dark color, typography, spacing, radius and reduced-motion roles where applicable. Existing actions and record identities remain authoritative.

| ID | Component | Reused / refined implementation |
| --- | --- | --- |
| K001 | Collapsing large title | AuroraLargeTitle |
| K002 | Bottom navigation | SaveTrackNavigation |
| K003 | Compact navigation bar | existing Scaffold AppBar and route headers |
| K004 | Assist choice row | AuroraAssistChooser |
| K005 | Savings hero | SavingsOverview MintHero and PersonalGoalOverview |
| K006 | Quick action | AuroraQuickAction |
| K007 | Greeting block | AuroraGreeting |
| K008 | Section header | AtelierSectionHeader |
| K009 | Grouped settings container | AuroraGroupedSection |
| K010 | Settings row | ProfileContent and AgentSettingsScreen rows |
| K011 | Avatar | ProfileAvatar |
| K012 | Goal cover | GoalCoverImage |
| K013 | Gallery goal card | AtelierGoalTile |
| K014 | Compact goal row | GoalCard and GoalGallery list mode |
| K015 | Filter chip | GoalBrowser existing filters |
| K016 | Search field | GoalBrowser and currency picker |
| K017 | Sort selector | GoalSort control |
| K018 | Segmented control | AuroraModeSelector AuroraTabs and AiModeSelector |
| K019 | Primary button | GradientButton current solid presentation |
| K020 | Secondary button | existing OutlinedButton patterns |
| K021 | Destructive button | existing delete/archive/leave confirmations |
| K022 | Tertiary action | existing TextButton actions |
| K023 | Labelled text field | existing TextFormField and TextField patterns |
| K024 | Secure password field | AuthScreen and PasswordDialog |
| K025 | Exact money field | CurrencySavingsDialog and shared contribution forms |
| K026 | Date and time control | PlannerDateHeader, ReminderEditor and `showSaveTrackDatePicker` / `showSaveTrackTimePicker` in `lib/platform_pickers.dart` |
| K027 | Priority selector | task form existing priority dropdown |
| K028 | Linear progress | MintProgress |
| K029 | Progress ring | ProgressRing and DailyCompletion |
| K030 | Transaction row | PersonalTransactionTile and SharedActivityTile |
| K031 | Member row | SharedMembersScreen and MemberAvatar |
| K032 | Invitation card | SharedInvitesScreen |
| K033 | Reminder row | ReminderTimeline and SmartRemindersScreen |
| K034 | Planner task row | TaskTile |
| K035 | Smart suggestion card | smart_suggestions.dart |
| K036 | Savings chart | SavingsPulse AuroraChartSurface and PulseContent |
| K037 | Report metric | ReportMetric and ReportTaskMetric |
| K038 | Empty state | EmptyPanel and StateSurface |
| K039 | Error notice | ErrorPanel AuroraNotice and AiErrorNotice |
| K040 | Skeleton | AuroraSkeleton AuroraLoadingSurface and LoadingPanel |
| K041 | Synchronization status | AuroraSyncStatus |
| K042 | Modal sheet | existing showModalBottomSheet surfaces |
| K043 | Confirmation dialog | existing showDialog and SharedActionDialog patterns |
| K044 | AI and Agent composer | AiComposer and Agent _composer |
| K045 | Conversation message | AiConversationMessage and Agent bubbles |
| K046 | Verified fact card | AiFactCard and AI context summary |
| K047 | Mission step card | AgentActionPreview and Agent _step |
| K048 | Mission progress timeline | AgentStudioScreen mission presentation |
| K049 | Voice orb | AgentVoiceOrb and AgentOrbArtwork |
| K050 | Permission control | Agent settings ReminderEditor and widget privacy choices |
| K051 | Native widget preview | WidgetPreviewCard and widget_visuals |

## Review and host boundaries

- All five destinations, exact financial inputs, membership actions, recurrence, context approval and mission execution policies remain on existing models and services.
- Captured records are synthetic. Live services, device permissions, screen readers and runtime performance need the acceptance checks in the report.
- Native Android renders and Flutter widget preview approximations are separate evidence. Host support follows the existing bridge.
- No Figma editing surface was used. Flutter contracts and annotated Light/Dark screenshots are the handoff artifacts.
