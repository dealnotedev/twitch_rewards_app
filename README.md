# Twitch Rewards App

A simple application for manipulating OBS settings using Twitch channel points

## Getting Started

1. Authorize on Twitch in application.
2. Enable WebSocket server in OBS (Tools -> WebSocket Server Settings -> Enable WebSocket server -> Apply)
3. Connect to OBS in application (Copy password from WebSocket Server Settings)
4. Create reward template
5. Save all

##

$env:NO_OPUS_OGG_LIBS="1"
flutter build windows