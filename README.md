# Voice Writter

Real time voice to text dictation for macOS, with automatic grammar correction, that works in any app where you can type. Everything runs on your Mac. Nothing is sent to the cloud. It is fully open source.

You press a global hotkey, speak, and press it again. Voice Writter turns your speech into text, cleans up the grammar with a local language model, and pastes the result wherever your cursor is.

## Features

- System wide dictation. It types into any app: notes, browsers, chat apps, code editors, email.
- On device speech recognition using [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift), which runs Whisper models on the Apple Neural Engine.
- On device grammar correction using a small local language model through [MLX](https://github.com/ml-explore/mlx-swift-lm). It fixes grammar, spelling, and punctuation, and lightly smooths awkward phrasing while keeping your meaning and voice.
- Press Option + Q to start, press it again to stop and insert.
- A floating overlay that shows the status and a microphone level while you speak.
- Private by design. Audio and text never leave your Mac.

## Requirements

- An Apple Silicon Mac (M1 or newer).
- macOS 14 (Sonoma) or newer.
- About 16 GB of RAM works; 32 GB is comfortable.
- Xcode 16 or newer to build it.
- Roughly 2 to 3 GB of disk for the models, downloaded once on first run.

## Build and run

The easiest path:

```bash
./scripts/setup.sh
```

This installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) if needed, generates the Xcode project, and opens it. In Xcode, pick the `VoiceWritter` scheme and press Run.

The first build pulls Swift packages and compiles them, so it takes a few minutes. Xcode will ask you to enable a Swift macro from `mlx-swift-lm`. Click **Trust & Enable**.

`setup.sh` also installs the Metal Toolchain if it is missing, which MLX needs to compile its GPU shaders. If you ever see an error about a missing Metal toolchain, run `xcodebuild -downloadComponent MetalToolchain` once.

To build and launch from the command line instead:

```bash
./scripts/run.sh
```

## Install it permanently

To put the app in your Applications folder and have it start automatically at login:

```bash
./scripts/install.sh
```

This builds an optimized version, signs it with your Apple Development certificate, copies it to `~/Applications/VoiceWritter.app`, and adds a login item. It installs into your user Applications folder because macOS protects the system `/Applications` folder from scripted installs, especially on managed Macs. Because it is signed with your certificate, the permissions you grant carry over and survive future updates. Pass `Debug` (`./scripts/install.sh Debug`) for a faster build with a slightly slower grammar model.

To remove it later:

```bash
launchctl unload ~/Library/LaunchAgents/com.sadmansoumik.voicewritter.plist
rm ~/Library/LaunchAgents/com.sadmansoumik.voicewritter.plist
rm -rf ~/Applications/VoiceWritter.app
```

## First run setup

A setup window opens on first launch and walks you through:

1. **Microphone**: allow it so the app can hear you.
2. **Accessibility**: turn on Voice Writter in System Settings, Privacy and Security, Accessibility. This lets the app type into other apps.
3. **Input Monitoring**: turn on Voice Writter in System Settings, Privacy and Security, Input Monitoring. This lets the app detect the Option + Q shortcut.
4. **Model download**: wait for the transcription and grammar models to download (once).

## How to use it

1. Put your cursor anywhere you can type.
2. **Press Option + Q** and start speaking. The floating overlay shows that it is listening.
3. **Press Option + Q again** to stop. Voice Writter transcribes, cleans up the grammar, and pastes the text where your cursor is.
4. To throw away a dictation, press **Escape**.

Note: while Voice Writter is running, Option + Q is reserved for it and will not type the "œ" character.

You can change the correction style and the models in Settings, reachable from the menu bar icon.

## Models

- **Transcription**: by default the app picks the best Whisper model for your Mac from `argmaxinc/whisperkit-coreml`. You can name a specific variant in Settings.
- **Grammar**: the default is `mlx-community/Qwen2.5-3B-Instruct-4bit`, a small instruct model chosen because it returns corrected text directly and stays fast. You can switch to a lighter or different model in Settings.

Both models load when the app starts and stay in memory so dictation feels instant.

## How it works

```
Option+Q ─▶ record microphone ─▶ (overlay shows listening)
                                   │
                            Option+Q again
                                   ▼
   WhisperKit transcribes ─▶ MLX grammar model ─▶ clean text ─▶ paste into focused app
```

Source layout:

- `Sources/App`: the menu bar app entry point and lifecycle.
- `Sources/Core`: the dictation state machine, the WhisperKit and MLX services, the global hotkey, text insertion, and permissions.
- `Sources/UI`: the floating overlay, the menu, settings, and the setup window.
- `Sources/Models` and `Sources/Support`: preferences, prompts, and small helpers.

## Privacy

Voice Writter does not make network calls except to download the open models from Hugging Face on first run. After that it works fully offline. The app is not sandboxed because typing into other apps through the Accessibility API is not possible from a sandboxed app.

## License

MIT. See `LICENSE`.

## Credits

Built on these open source projects:

- [WhisperKit / argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift) (MIT)
- [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) and [MLX Swift](https://github.com/ml-explore/mlx-swift) (MIT)
