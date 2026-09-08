# Privacy

Dev Notch is local-first. It has no Dev Notch analytics or telemetry service and does not send analytics or telemetry to Dev Notch servers.

## Local access

Depending on the providers and integrations enabled by the user, Dev Notch may locally access:

- Codex CLI and local Codex account/usage metadata
- Claude CLI and Dev Notch-owned Claude hook configuration
- Google Antigravity CLI and Dev Notch-owned Antigravity hook configuration
- OpenCode configuration and account metadata
- a DeepSeek API credential already stored for OpenCode, used only to request DeepSeek account balance
- local AI activity metadata such as provider, model, session state, context usage, and timestamps

## Data excluded by default

- No credential leakage was observed in implemented tests and log inspection.
- Dev Notch does not intentionally collect or persist prompt text, AI responses, source-code contents, tool-result contents, or passwords. Credentials are not copied into Dev Notch preferences, logs, bundle resources, release scripts, or release artifacts.

Provider requests go directly to the relevant local tool or provider service. Those tools and services have their own privacy policies and account settings.
