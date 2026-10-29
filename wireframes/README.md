# SaveTrack — individual wireframe pictures

139 separate PNG files, grouped by feature, restyled to match your supplied reference: white backgrounds, thin black outlines, square corners, regular text, and crossed image and icon placeholders. Each picture contains one screen, dialog, component detail or distinct state. Long pages use a single full-scroll composition.

The wireframes are based on the current Flutter and Android source plus existing local visual references. They use fictional records and simple outline placeholders. They are schematic layouts, not screenshots of a running account. All 106 surface IDs in `docs/mint-atelier-coverage.md` are mapped below; these IDs include substates and embedded components, not 106 separate routes.

Open a PNG link below to view or save that individual picture. Images are 960 pixels wide, rendered at 2× resolution. No collage, PDF, or combined picture is required.

| Feature | Pictures |
| --- | ---: |
| [access](./01-access/) | 10 |
| [home](./02-home/) | 5 |
| [personal goals](./03-personal-goals/) | 18 |
| [shared goals](./04-shared-goals/) | 15 |
| [planner](./05-planner/) | 8 |
| [reminders](./06-reminders/) | 5 |
| [reports](./07-reports/) | 2 |
| [profile settings](./08-profile-settings/) | 8 |
| [ai coach](./09-ai-coach/) | 10 |
| [agent studio](./10-agent-studio/) | 19 |
| [agent settings](./11-agent-settings/) | 9 |
| [widget studio](./12-widget-studio/) | 5 |
| [android widgets](./13-android-widgets/) | 21 |
| [app states](./14-app-states/) | 4 |

## Access

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 001 | [Welcome back](./01-access/001-sign-in.png) | screen | [main.dart](../lib/main.dart) |
| 002 | [Create your account](./01-access/002-create-account.png) | screen | [main.dart](../lib/main.dart) |
| 003 | [Google sign-in handoff](./01-access/003-google-sign-in.png) | state | [main.dart](../lib/main.dart) |
| 004 | [Forgot Password](./01-access/004-forgot-password.png) | dialog | [password_recovery_dialog.dart](../lib/password_recovery_dialog.dart) |
| 005 | [Check your email](./01-access/005-reset-link-sent.png) | dialog | [password_recovery_dialog.dart](../lib/password_recovery_dialog.dart) |
| 006 | [Change Password](./01-access/006-verify-password.png) | dialog | [password_dialog.dart](../lib/password_dialog.dart) |
| 007 | [Set New Password](./01-access/007-new-password.png) | dialog | [password_dialog.dart](../lib/password_dialog.dart) |
| 008 | [Password updated](./01-access/008-password-updated.png) | dialog | [password_dialog.dart](../lib/password_dialog.dart) |
| 009 | [SaveTrack setup](./01-access/009-setup-required.png) | state | [main.dart](../lib/main.dart) |
| 010 | [Opening SaveTrack](./01-access/010-session-loading.png) | state | [main.dart](../lib/main.dart) |

## Home

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 011 | [Today](./02-home/011-today.png) | screen | [home_atelier.dart](../lib/home_atelier.dart) |
| 012 | [Assist](./02-home/012-assist-chooser.png) | sheet | [precision_components.dart](../lib/precision_components.dart) |
| 013 | [Choose a savings goal](./02-home/013-quick-save-goal.png) | sheet | [home_atelier.dart](../lib/home_atelier.dart) |
| 014 | [Customize Home](./02-home/014-customize-home.png) | screen | [atelier_preferences.dart](../lib/atelier_preferences.dart) |
| 015 | [Appearance](./02-home/015-appearance.png) | sheet | [atelier_preferences.dart](../lib/atelier_preferences.dart) |

## Personal Goals

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 016 | [Goals](./03-personal-goals/016-goals-gallery.png) | screen | [home_atelier.dart](../lib/home_atelier.dart) |
| 017 | [Goals](./03-personal-goals/017-goals-grid.png) | screen | [home_atelier.dart](../lib/home_atelier.dart) |
| 018 | [Goals](./03-personal-goals/018-goals-list.png) | screen | [home_atelier.dart](../lib/home_atelier.dart) |
| 019 | [Create a goal](./03-personal-goals/019-goal-type.png) | sheet | [main.dart](../lib/main.dart) |
| 020 | [Create a goal](./03-personal-goals/020-create-goal.png) | dialog | [main.dart](../lib/main.dart) |
| 021 | [Edit goal](./03-personal-goals/021-edit-goal.png) | dialog | [main.dart](../lib/main.dart) |
| 022 | [Laptop](./03-personal-goals/022-goal-details.png) | screen | [precision_flows.dart](../lib/precision_flows.dart) |
| 023 | [Add savings](./03-personal-goals/023-add-savings.png) | dialog | [currency_savings_dialog.dart](../lib/currency_savings_dialog.dart) |
| 024 | [Decrease Savings](./03-personal-goals/024-decrease-savings.png) | dialog | [currency_savings_dialog.dart](../lib/currency_savings_dialog.dart) |
| 025 | [Review conversion](./03-personal-goals/025-conversion-review.png) | dialog | [currency_savings_dialog.dart](../lib/currency_savings_dialog.dart) |
| 026 | [Laptop history](./03-personal-goals/026-transaction-history.png) | sheet | [main.dart](../lib/main.dart) |
| 027 | [Savings added](./03-personal-goals/027-transaction-detail.png) | sheet | [precision_flows.dart](../lib/precision_flows.dart) |
| 028 | [Goal actions](./03-personal-goals/028-goal-actions.png) | sheet | [precision_flows.dart](../lib/precision_flows.dart) |
| 029 | [Delete goal?](./03-personal-goals/029-delete-goal.png) | dialog | [main.dart](../lib/main.dart) |
| 030 | [Goal photo](./03-personal-goals/030-cover-actions.png) | sheet | [goal_cover_widgets.dart](../lib/goal_cover_widgets.dart) |
| 031 | [Crop goal cover](./03-personal-goals/031-cover-crop.png) | dialog | [goal_cover_widgets.dart](../lib/goal_cover_widgets.dart) |
| 032 | [Goal cover](./03-personal-goals/032-cover-viewer.png) | dialog | [goal_cover_widgets.dart](../lib/goal_cover_widgets.dart) |
| 033 | [Goal cover upload](./03-personal-goals/033-cover-upload-recovery.png) | dialog | [main.dart](../lib/main.dart) |

## Shared Goals

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 034 | [Goals](./04-shared-goals/034-shared-goals.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 035 | [Create shared goal](./04-shared-goals/035-create-shared-goal.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 036 | [Goal settings](./04-shared-goals/036-shared-settings.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 037 | [Save Together](./04-shared-goals/037-shared-details.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 038 | [Add contribution](./04-shared-goals/038-shared-contribution.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 039 | [Decrease shared savings](./04-shared-goals/039-shared-decrease.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 040 | [Goal members](./04-shared-goals/040-members.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 041 | [Invite members](./04-shared-goals/041-invitations.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 042 | [Join Save Together](./04-shared-goals/042-join-code.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 043 | [Join Save Together](./04-shared-goals/043-join-preview.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 044 | [Shared activity](./04-shared-goals/044-shared-history.png) | screen | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 045 | [Archive shared goal?](./04-shared-goals/045-archive.png) | dialog | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 046 | [Leave shared goal?](./04-shared-goals/046-leave.png) | dialog | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 047 | [Remove Sam?](./04-shared-goals/047-remove-member.png) | dialog | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |
| 048 | [Revoke invitation?](./04-shared-goals/048-revoke-invitation.png) | dialog | [shared_savings_screens.dart](../lib/shared_savings_screens.dart) |

## Planner

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 049 | [Planner](./05-planner/049-daily-planner.png) | screen | [main.dart](../lib/main.dart) |
| 050 | [Planner](./05-planner/050-weekly-planner.png) | screen | [home_atelier.dart](../lib/home_atelier.dart) |
| 051 | [Add a task](./05-planner/051-add-task.png) | dialog | [main.dart](../lib/main.dart) |
| 052 | [Edit task](./05-planner/052-edit-task.png) | dialog | [main.dart](../lib/main.dart) |
| 053 | [Delete task?](./05-planner/053-delete-task.png) | dialog | [main.dart](../lib/main.dart) |
| 054 | [Smart Suggestions](./05-planner/054-smart-suggestions.png) | sheet | [smart_suggestions.dart](../lib/smart_suggestions.dart) |
| 055 | [Select date](./05-planner/055-date-picker.png) | dialog | [platform_pickers.dart](../lib/platform_pickers.dart) |
| 056 | [Select time](./05-planner/056-time-picker.png) | dialog | [platform_pickers.dart](../lib/platform_pickers.dart) |

## Reminders

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 057 | [Smart Reminders](./06-reminders/057-reminder-agenda.png) | screen | [reminder_widgets.dart](../lib/reminder_widgets.dart) |
| 058 | [Savings Reminder](./06-reminders/058-savings-reminder.png) | sheet | [reminder_widgets.dart](../lib/reminder_widgets.dart) |
| 059 | [Task Reminder](./06-reminders/059-task-reminder.png) | sheet | [reminder_widgets.dart](../lib/reminder_widgets.dart) |
| 060 | [Allow phone reminders](./06-reminders/060-notification-permission.png) | dialog | [reminder_widgets.dart](../lib/reminder_widgets.dart) |
| 061 | [Allow precise reminders](./06-reminders/061-precise-timing.png) | dialog | [reminder_widgets.dart](../lib/reminder_widgets.dart) |

## Reports

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 062 | [Reports](./07-reports/062-reports.png) | screen | [main.dart](../lib/main.dart) |
| 063 | [Savings Pulse](./07-reports/063-savings-pulse.png) | detail | [home_atelier.dart](../lib/home_atelier.dart) |

## Profile Settings

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 064 | [Profile](./08-profile-settings/064-profile.png) | screen | [main.dart](../lib/main.dart) |
| 065 | [Profile Picture](./08-profile-settings/065-photo-actions.png) | sheet | [profile_photo_widgets.dart](../lib/profile_photo_widgets.dart) |
| 066 | [Edit profile photo](./08-profile-settings/066-photo-crop.png) | sheet | [profile_photo_widgets.dart](../lib/profile_photo_widgets.dart) |
| 067 | [Uploading profile photo](./08-profile-settings/067-photo-upload.png) | dialog | [profile_photo_widgets.dart](../lib/profile_photo_widgets.dart) |
| 068 | [Profile photo](./08-profile-settings/068-photo-viewer.png) | dialog | [profile_photo_widgets.dart](../lib/profile_photo_widgets.dart) |
| 069 | [Remove profile photo?](./08-profile-settings/069-remove-photo.png) | dialog | [profile_photo_widgets.dart](../lib/profile_photo_widgets.dart) |
| 070 | [Currency Settings](./08-profile-settings/070-currency-settings.png) | screen | [currency_settings_screen.dart](../lib/currency_settings_screen.dart) |
| 071 | [Choose currency](./08-profile-settings/071-currency-picker.png) | sheet | [currency_widgets.dart](../lib/currency_widgets.dart) |

## Ai Coach

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 072 | [SaveTrack AI](./09-ai-coach/072-ai-welcome.png) | screen | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |
| 073 | [SaveTrack AI](./09-ai-coach/073-ask-anything.png) | screen | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |
| 074 | [SaveTrack AI](./09-ai-coach/074-coach-conversation.png) | screen | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |
| 075 | [Choose a goal](./09-ai-coach/075-context-selection.png) | sheet | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |
| 076 | [Review AI Context](./09-ai-coach/076-context-review.png) | sheet | [ai_widgets.dart](../lib/ai_coach/ai_widgets.dart) |
| 077 | [Make this space yours](./09-ai-coach/077-ai-settings.png) | sheet | [ai_settings_sheet.dart](../lib/ai_coach/ai_settings_sheet.dart) |
| 078 | [Before your first question](./09-ai-coach/078-provider-privacy.png) | dialog | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |
| 079 | [Connect SaveTrack AI](./09-ai-coach/079-ai-connection.png) | sheet | [ai_setup_sheet.dart](../lib/ai_coach/ai_setup_sheet.dart) |
| 080 | [Clear this chat?](./09-ai-coach/080-clear-chat.png) | dialog | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |
| 081 | [Conversation actions](./09-ai-coach/081-ai-menu.png) | sheet | [ai_coach_screen.dart](../lib/ai_coach/ai_coach_screen.dart) |

## Agent Studio

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 082 | [Agent Studio Pro](./10-agent-studio/082-agent-home.png) | screen | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 083 | [Agent Studio Pro](./10-agent-studio/083-agent-conversation.png) | screen | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 084 | [Speak naturally](./10-agent-studio/084-voice-listening.png) | detail | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 085 | [Review your transcript](./10-agent-studio/085-transcript-review.png) | detail | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 086 | [Review these details](./10-agent-studio/086-interpretation.png) | dialog | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 087 | [Mission builder](./10-agent-studio/087-mission-builder.png) | screen | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 088 | [Add step](./10-agent-studio/088-action-picker.png) | sheet | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 089 | [Savings goal](./10-agent-studio/089-step-goal.png) | dialog | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 090 | [Planner task](./10-agent-studio/090-step-task.png) | dialog | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 091 | [Reminder](./10-agent-studio/091-step-reminder.png) | dialog | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 092 | [Prepare contribution](./10-agent-studio/092-step-contribution.png) | dialog | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 093 | [Savings scenario](./10-agent-studio/093-step-scenario.png) | dialog | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 094 | [Equal goal allocation](./10-agent-studio/094-step-allocation.png) | dialog | [agent_step_editor.dart](../lib/agent_studio/agent_step_editor.dart) |
| 095 | [Confirm mission](./10-agent-studio/095-mission-approval.png) | dialog | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 096 | [Mission builder](./10-agent-studio/096-mission-executing.png) | state | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 097 | [Mission builder](./10-agent-studio/097-mission-partial.png) | state | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 098 | [What-If scenario](./10-agent-studio/098-what-if-result.png) | detail | [agent_action_preview.dart](../lib/agent_studio/presentation/agent_action_preview.dart) |
| 099 | [Equal goal allocation](./10-agent-studio/099-allocation-preview.png) | detail | [agent_action_preview.dart](../lib/agent_studio/presentation/agent_action_preview.dart) |
| 100 | [Mission history](./10-agent-studio/100-mission-history.png) | screen | [agent_history_screen.dart](../lib/agent_studio/presentation/agent_history_screen.dart) |

## Agent Settings

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 101 | [Agent settings](./11-agent-settings/101-agent-settings.png) | screen | [agent_settings_screen.dart](../lib/agent_studio/agent_settings_screen.dart) |
| 102 | [Language & voice](./11-agent-settings/102-language-voice.png) | screen | [agent_language_settings.dart](../lib/agent_studio/agent_language_settings.dart) |
| 103 | [Voice & audio](./11-agent-settings/103-voice-settings.png) | detail | [agent_settings_screen.dart](../lib/agent_studio/agent_settings_screen.dart) |
| 104 | [Voice needs attention](./11-agent-settings/104-voice-recovery.png) | state | [agent_screen.dart](../lib/agent_studio/agent_screen.dart) |
| 105 | [Agent Autopilot](./11-agent-settings/105-autopilot.png) | screen | [autopilot_settings_screen.dart](../lib/agent_studio/autopilot/autopilot_settings_screen.dart) |
| 106 | [Enable automatic actions?](./11-agent-settings/106-autopilot-confirm.png) | dialog | [autopilot_settings_screen.dart](../lib/agent_studio/autopilot/autopilot_settings_screen.dart) |
| 107 | [Autopilot Activity](./11-agent-settings/107-automatic-actions.png) | screen | [autopilot_activity_screen.dart](../lib/agent_studio/autopilot/autopilot_activity_screen.dart) |
| 108 | [Memory center](./11-agent-settings/108-memory-center.png) | screen | [agent_settings_screen.dart](../lib/agent_studio/agent_settings_screen.dart) |
| 109 | [Save this preference?](./11-agent-settings/109-memory-approval.png) | dialog | [agent_settings_screen.dart](../lib/agent_studio/agent_settings_screen.dart) |

## Widget Studio

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 110 | [Home Screen Widgets](./12-widget-studio/110-widget-gallery.png) | screen | [widget_settings_screen.dart](../lib/home_widgets/widget_settings_screen.dart) |
| 111 | [Customize Your Widget](./12-widget-studio/111-configure-savings-goal.png) | screen | [widget_settings_screen.dart](../lib/home_widgets/widget_settings_screen.dart) |
| 112 | [Customize Your Widget](./12-widget-studio/112-configure-today-s-planner.png) | screen | [widget_settings_screen.dart](../lib/home_widgets/widget_settings_screen.dart) |
| 113 | [Customize Your Widget](./12-widget-studio/113-configure-quick-save.png) | screen | [widget_settings_screen.dart](../lib/home_widgets/widget_settings_screen.dart) |
| 114 | [Customize Your Widget](./12-widget-studio/114-configure-today-overview.png) | screen | [widget_settings_screen.dart](../lib/home_widgets/widget_settings_screen.dart) |

## Android Widgets

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 115 | [Savings Goal · Compact](./13-android-widgets/115-savings-goal-compact.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 116 | [Today's Planner · Compact](./13-android-widgets/116-planner-compact.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 117 | [Quick Save · Compact](./13-android-widgets/117-quick-save-compact.png) | widget · Compact | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 118 | [Today Overview · Compact](./13-android-widgets/118-today-overview-compact.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 119 | [Savings Goal · Medium](./13-android-widgets/119-savings-goal-medium.png) | widget · Medium | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 120 | [Today's Planner · Medium](./13-android-widgets/120-planner-medium.png) | widget · Medium | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 121 | [Quick Save · Medium](./13-android-widgets/121-quick-save-medium.png) | widget · Medium | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 122 | [Today Overview · Medium](./13-android-widgets/122-today-overview-medium.png) | widget · Medium | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 123 | [Savings Goal · Expanded](./13-android-widgets/123-savings-goal-expanded.png) | widget · Expanded | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 124 | [Today's Planner · Expanded](./13-android-widgets/124-planner-expanded.png) | widget · Expanded | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 125 | [Quick Save · Expanded](./13-android-widgets/125-quick-save-expanded.png) | widget · Expanded | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 126 | [Today Overview · Expanded](./13-android-widgets/126-today-overview-expanded.png) | widget · Expanded | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 127 | [Quick Save · Review amount](./13-android-widgets/127-quick-review.png) | widget · Medium | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 128 | [Quick Save · Save pending](./13-android-widgets/128-quick-pending.png) | widget · Medium | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 129 | [Quick Save · Save not confirmed](./13-android-widgets/129-quick-retry.png) | widget · Medium | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 130 | [Quick Save · Contribution confirmed](./13-android-widgets/130-quick-saved.png) | widget · Medium | [QuickSaveRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/QuickSaveRenderer.kt) |
| 131 | [Widget · Sign in to SaveTrack](./13-android-widgets/131-signed-out.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 132 | [Widget · Choose your widget settings](./13-android-widgets/132-setup-needed.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 133 | [Widget · Open SaveTrack to refresh](./13-android-widgets/133-stale-data.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 134 | [Widget · Choose another goal](./13-android-widgets/134-unavailable-goal.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |
| 135 | [Widget · Open SaveTrack](./13-android-widgets/135-hidden-privacy.png) | widget · Compact | [WidgetRenderer.kt](../android/app/src/main/kotlin/com/example/myproject/widgets/WidgetRenderer.kt) |

## App States

| ID | Individual picture | Type | Source |
| --- | --- | --- | --- |
| 136 | [Goals](./14-app-states/136-empty-goals.png) | state | [main.dart](../lib/main.dart) |
| 137 | [Planner](./14-app-states/137-empty-planner.png) | state | [main.dart](../lib/main.dart) |
| 138 | [Loading content](./14-app-states/138-loading-content.png) | state | [main.dart](../lib/main.dart) |
| 139 | [Goals](./14-app-states/139-connection-error.png) | state | [main.dart](../lib/main.dart) |

## Scope and reading notes

- The five main destinations are Today, Goals, Planner, Reports and Profile. Goals has Personal and Shared tabs.
- Agent, AI, reports and photo flows include important modal and state variants. Component-detail images are marked as such; they do not imply new application routes.
- The Android widget set includes Savings Goal, Today's Planner, Quick Save and Today Overview in all three size tiers, plus confirmation, pending, retry, success, privacy and unavailable states. Exact widget geometry varies with the launcher, font scale and configuration.
- Main app layouts use the phone composition. Light/Dark colors and tablet/desktop breakpoints are not repeated because this is a black-and-white outline wireframe set. OS-owned account, gallery, notification-settings and speech dialogs are represented by their app handoff, not invented as SaveTrack screens. Firebase's hosted password-reset web page is external.
- Some labels are shortened for wireframe clarity. Amounts, dates, names, chart bars and conversations are illustrative. Conversion results use placeholders rather than an invented exchange rate.
- The Today image includes the optional Assist section, marked accordingly. Owner-only shared-goal controls appear in the owner view; the separate Leave goal image represents the member flow.

## Reproducible sources

[Manifest](./source/manifest.json) describes every picture and its source file. [Source audit](./source/source-audit.json) records the scanned source paths and surface declarations. [Coverage](./source/coverage.md) maps the existing 106 surface IDs to pictures. [Validation](./source/validation.json) records file and coverage checks.

The deterministic renderer is [render.ps1](./source/render.ps1). Run it from PowerShell with `& .\wireframes\source\render.ps1`. It only writes the wireframe output folder and does not build or modify the application.

