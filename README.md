# Zylos 🚀

Zylos is a versatile and powerful desktop application built with Flutter, designed to offer an extensive set of tools via modular plugins. With an advanced, unified installer, Zylos provides users the flexibility of both full offline installations (pre-packaged with essential plugins) and online installations (downloading the latest plugins on the fly).

## 🌟 Features

- **Hybrid Installer:** Choose between Online mode (downloads latest plugins) and Offline mode (uses bundled plugins for environments with no internet access).
- **Video Downloading:** Integrated with `yt-dlp` (supports Stable, Nightly, and Master builds) for comprehensive media downloading.
- **Media Conversion:** Seamlessly utilizes `FFmpeg` for fast and reliable media processing and conversions.
- **Secure Connections:** Built-in integration with `Cloudflare WARP` to ensure secure, private network traffic right out of the box.
- **Auto Startup:** Configure Zylos to run automatically when your system starts.

## 📸 Screenshots

> *Add your screenshots here!*

| Home Dashboard | Settings | Plugin Manager |
| --- | --- | --- |
| ![Home](docs/screenshots/home.png) | ![Settings](docs/screenshots/settings.png) | ![Plugins](docs/screenshots/plugins.png) |

*(Replace the placeholder links above with actual screenshot paths once captured.)*

## 📦 Installation

You can install Zylos using the universal installer provided in the releases.

1. Run `Zylos_Universal_Setup.exe`.
2. Choose your installation mode:
   - **Online Installation:** Fetches the latest versions of yt-dlp, FFmpeg, and WARP.
   - **Offline Installation:** Installs the pre-bundled versions (perfect for offline environments).
3. Select the plugins you want to include.
4. Follow the remaining setup instructions.

## 💻 Tech Stack

- **Frontend/Core:** [Flutter](https://flutter.dev/)
- **Installer Engine:** [Inno Setup](https://jrsoftware.org/isinfo.php)
- **Bundled Plugins:** [yt-dlp](https://github.com/yt-dlp/yt-dlp), [FFmpeg](https://ffmpeg.org/), [Cloudflare WARP](https://1.1.1.1/)

## 🛠️ Development

To build the project locally, ensure you have Flutter installed:

```bash
# Get dependencies
flutter pub get

# Build Windows application
flutter build windows
```

To compile the installer, open `OfflineInstaller.iss` in Inno Setup Compiler and compile it to generate the `Zylos_Universal_Setup.exe`.
