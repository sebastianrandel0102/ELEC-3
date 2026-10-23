# Mint Atelier screenshot index

These are deterministic synthetic Flutter test renders. They use the actual production components and bundled typefaces. Keyboard images simulate system insets; they do not depict an operating-system keyboard. Voice artwork does not establish host speech support. Native Android renders are separate under `build/mint-atelier/native/`.

[Implementation and verification](mint-atelier-iphone.md) · [106-surface coverage](mint-atelier-coverage.md)

| Surface / state | Light | Dark |
| --- | --- | --- |
| Today overview | [390×844](../test/goldens/precision81-home-light.png) | [390×844](../test/goldens/precision81-home-dark.png) |
| Today gallery / activity | [390×1100](../test/goldens/atelier71-home-light.png) | [390×1100](../test/goldens/atelier71-home-dark.png) |
| Goals | [390×844](../test/goldens/precision81-goals-light.png) | [390×844](../test/goldens/precision81-goals-dark.png) |
| Goal details | [390×844](../test/goldens/precision81-details-light.png) | [390×844](../test/goldens/precision81-details-dark.png) |
| Profile | [390×844](../test/goldens/precision81-profile-light.png) | [390×844](../test/goldens/precision81-profile-dark.png) |
| Assist choices | [390×844](../test/goldens/precision81-assist-light.png) | [390×844](../test/goldens/precision81-assist-dark.png) |
| Authentication | [390×844](../test/goldens/mint-atelier-auth-light.png) | [390×844](../test/goldens/mint-atelier-auth-dark.png) |
| Planner | [390×844](../test/goldens/mint-atelier-planner-light.png) | [390×844](../test/goldens/mint-atelier-planner-dark.png) |
| Reports | [390×844](../test/goldens/mint-atelier-reports-light.png) | [390×844](../test/goldens/mint-atelier-reports-dark.png) |
| Shared savings | [390×844](../test/goldens/mint-atelier-shared-light.png) | [390×844](../test/goldens/mint-atelier-shared-dark.png) |
| Empty goals | [390×844](../test/goldens/mint-atelier-empty-light.png) | [390×844](../test/goldens/mint-atelier-empty-dark.png) |
| Loading | [390×844](../test/goldens/mint-atelier-loading-light.png) | [390×844](../test/goldens/mint-atelier-loading-dark.png) |
| Startup failure | [390×844](../test/goldens/mint-atelier-failure-light.png) | [390×844](../test/goldens/mint-atelier-failure-dark.png) |
| Narrow keyboard / 160% text | [320×693](../test/goldens/mint-atelier-keyboard-light.png) | [320×693](../test/goldens/mint-atelier-keyboard-dark.png) |
| Narrow Planner / 200% text | [320×693](../test/goldens/mint-atelier-large-text-light.png) | [320×693](../test/goldens/mint-atelier-large-text-dark.png) |
| AI welcome | [390×844](../test/goldens/ai-atelier-welcome-light.png) | [390×844](../test/goldens/ai-atelier-welcome-dark.png) |
| AI conversation | [390×844](../test/goldens/ai-atelier-conversation-light.png) | [390×844](../test/goldens/ai-atelier-conversation-dark.png) |
| AI settings | [390×844](../test/goldens/ai-atelier-settings.png) | — |
| AI response / facts | [390×844](../test/goldens/ai-atelier-response-cards.png) | — |
| Agent home | [390×844](../test/goldens/agent_atelier_home_light.png) | [390×844](../test/goldens/agent_atelier_home_dark.png) |
| Agent mission | [390×844](../test/goldens/agent_atelier_mission.png) | — |
| Agent voice | — | [390×844](../test/goldens/agent_atelier_voice.png) |

Native Android picker artwork uses these reviewed RemoteViews reference frames with synthetic facts:

| Widget | Native 300×220 capture |
| --- | --- |
| Goal | [View](../android/app/src/main/res/drawable/st_widget_preview_goal.png) |
| Planner | [View](../android/app/src/main/res/drawable/st_widget_preview_planner.png) |
| Quick Save | [View](../android/app/src/main/res/drawable/st_widget_preview_quick_save.png) |
| Today | [View](../android/app/src/main/res/drawable/st_widget_preview_today.png) |

Original baseline PNGs remain in `build/mint-atelier/before/goldens/`. Source and screenshot hashes are recorded in `build/mint-atelier/`. See the implementation report for before/after annotations, the native capture workaround and host limitations.
