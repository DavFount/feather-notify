# Feather Notify

Default notification presentation provider for Feather Framework.

Core retains validated server dispatch and provider selection. This resource owns all RedM rendering and the complete legacy presentation set.

Supported styles: `tooltip`, `advanced`, `location`, `right`, `left`, `top_banner`, `advanced_right`, `top`, `center`, `standard`, `bottom_right`, `mission_failed`, `dead_player`, and `warning`.

Server resources call `exports['feather-core']:SendNotification(request)`. Client resources call `exports['feather-notify']:ShowNotification(request)`.

Start `feather-notify` after `feather-core` and before gameplay consumers. Core remains operational when Notify is absent; server dispatch returns `provider_unavailable`.

Tests:

- Server: `NotifyContractSmokeTest <source>`
- Client F8: `NotifyClientSmokeTest`
- Client F8 visual suite: `NotifyStyleSmokeTest`
