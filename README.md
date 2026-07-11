# ufo-abduction

A portrait 3D arcade game for Android, built with Godot 4.7.

Guide a low-poly UFO around a floating farm island, abduct the requested creatures, build score combos, and charge Frenzy before the 60-second shift ends. The project takes gameplay and presentation inspiration from *Suck It Up* while using original procedural models, materials, environments, UI, and code.

## Current features

- Orthographic, isometric-style 3D camera
- Layered floating farm island
- Procedural low-poly UFO, animals, barn, pond, crops, and fences
- Animated translucent tractor beam
- Cows, chickens, pigs, and sheep
- Target matching, penalties, combo scoring, and Frenzy mode
- Persistent local best score
- Portrait Android presentation
- Touch and desktop mouse controls
- No network permission or external services

## Controls

### Android

- Drag while touching the screen to steer.
- Keep your finger held down to activate the tractor beam.
- Release your finger to turn the beam off.
- Tap the title or results screen to start a round.

### Godot desktop preview

1. Open project.godot in Godot 4.7.
2. Press **F5** to run the project.
3. Click the title screen to begin.
4. Hold the left mouse button and drag to steer and abduct.
5. Press **F8** to stop the preview.

## Reference images

The eight visual references supplied for development are stored in the references/ folder.

That folder contains a .gdignore file, preventing Godot from importing or packaging the screenshots into the Android build. They are reference material only and are not used as game assets.

## Android development setup

The tested local toolchain uses:

- Godot 4.7 stable
- Android SDK: C:\Users\radit\AppData\Local\Android\Sdk
- Java SDK: C:\Program Files\Android\Android Studio\jbr
- Godot 4.7 Android debug and release export templates
- Android SDK Build Tools 36.0.0

To configure another machine:

1. Install Godot 4.7 and its matching export templates from **Editor > Manage Export Templates**.
2. Open **Editor > Editor Settings > Export > Android**.
3. Set the Java SDK and Android SDK paths.
4. Open **Project > Export** and select the included **Android** preset.

## Build and install

The Android preset:

- Exports to build/ufo-abduction.apk
- Uses package ID com.radit.ufoabduction
- Targets ARM64
- Enables immersive portrait display
- Enables ETC2/ASTC mobile texture compression
- Requests no internet permission

Export through **Project > Export > Android > Export Project**.

For command-line debug builds:

    & 'C:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --export-debug Android 'build\ufo-abduction.apk'

The generated debug APK can be installed directly on an ARM64 Android device. Android may require permission to install applications from unknown sources.

For a Play Store release, change the export format to AAB, increment the version code, and configure a private release keystore. Do not publish a build signed with Godot's debug key.

## Project structure

- main.gd - procedural 3D world, models, gameplay, touch controls, and UI
- main.tscn - main 3D scene
- project.godot - Godot project and mobile rendering settings
- export_presets.cfg - Android export configuration
- references/ - excluded development screenshots
- build/ - generated Android packages