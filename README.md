# Tumbler Drive — Flutter Game

A playable Flutter driving-game prototype built without Unity.

## Features

- Top-down open-world style driving
- Vehicle acceleration, drag, braking and steering physics
- Road network and free-space terrain
- Buildings/trees as collision obstacles
- Collision causes Game Over
- Restart button
- Touch steering control
- Throttle and brake controls
- GPS permission and current latitude/longitude HUD
- Designed to run on Android/iOS with Flutter

## Run

1. Install Flutter.
2. Open this project.
3. Run:

```bash
flutter pub get
flutter run
```

For Android GPS, the project already includes the required location permissions.

## Google Maps setup

The lobby includes a satellite map screen centered on the device's current GPS
position. Replace `YOUR_GOOGLE_MAPS_API_KEY` in
`android/app/src/main/res/values/google_maps.xml` and
`ios/Runner/AppDelegate.swift` with a Google Maps Platform API key. Enable the
Maps SDK for Android and Maps SDK for iOS for that key. The map also requires
location permission on the device.

## Important

This is a pure-Flutter 2D/top-down driving game. It is not a full Unity-quality 3D simulator. The GPS values are real device GPS readings, while the playable world is a local game world. To turn the world into a real satellite/road-based 3D environment, a map/3D engine such as Unity or a dedicated map SDK would be needed.
"# gps_drive" 
