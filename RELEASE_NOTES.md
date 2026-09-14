# Zylos v3.0 Release 🚀

<div align="center">

![Zylos Logo](https://raw.githubusercontent.com/YasirSDQ/Zylos/main/Images/Screenshots/Feautre%20Image.jfif)

**The Ultimate Modular Desktop Toolkit**

[![Download Universal](https://img.shields.io/badge/Download-Universal_Setup-blue?style=for-the-badge&logo=windows)](https://github.com/YasirSDQ/Zylos/releases/download/Zylos_v3.0/Zylos_Universal_Setup.exe)
[![Download Online](https://img.shields.io/badge/Download-Online_Setup-green?style=for-the-badge&logo=download)](https://github.com/YasirSDQ/Zylos/releases/download/Zylos_v3.0/Zylos_Online_Setup.exe)
[![Download Offline](https://img.shields.io/badge/Download-Offline_Setup-orange?style=for-the-badge&logo=hdd)](https://github.com/YasirSDQ/Zylos/releases/download/Zylos_v3.0/Zylos_Offline_Setup.exe)
[![Download Extension](https://img.shields.io/badge/Download-Browser_Extension-purple?style=for-the-badge&logo=google-chrome)](https://github.com/YasirSDQ/Zylos/releases/download/Zylos_v3.0/zylos_extension_3.0.zip)

</div>

---

## 📦 Which file should I download?

We offer **three different installers** and a **browser extension** to best suit your needs. Here is a complete catalog of the available assets:

| Asset | Type | Size | Description | Best For |
| :--- | :---: | :---: | :--- | :--- |
| **`Zylos_Universal_Setup.exe`** | 🏆 **Recommended** | ~158 MB | **Hybrid Universal Installer:** Gives you the choice between **Online mode** (downloads latest) and **Offline mode** (uses bundled) right from the setup wizard. | Users who want flexibility during installation or admins deploying to mixed network environments. |
| **`Zylos_Online_Setup.exe`** | 🌐 Web | ~13 MB | **Online Installer:** A lightweight installer that downloads the core application and fetches the **latest versions** of essential plugins on the fly during setup. | Users with a fast internet connection who want the absolute latest plugins at install time. |
| **`Zylos_Offline_Setup.exe`** | 💾 Standalone | ~158 MB | **Offline Installer:** A fully self-contained installer pre-packaged with all essential plugins. Requires **no internet connection** during setup. | Environments with restricted/no internet access, or users who prefer a one-and-done setup. |
| **`zylos_extension_3.0.zip`** | 🧩 Extension | ~2 MB | **Browser Companion:** Captures video/audio links directly from your browser and sends them instantly to the Zylos desktop app. | Power users who want one-click downloading from any website without copying/pasting URLs. |

---

## 🌟 What's New in v3.0?

### 🛠️ Advanced Plugin Management
- **Integrated Downloader:** Powered by `yt-dlp`, supporting **Stable**, **Nightly**, and **Master** builds for comprehensive media downloading from 1000+ sites.
- **Media Conversion:** Seamless integration with `FFmpeg` for fast, reliable media processing and format conversions.
- **Modular Architecture:** Select exactly which plugins you want to include during installation, keeping your application lightweight.

### 🌐 Browser Extension Integration
- **One-Click Capture:** The new **Zylos Browser Extension** detects downloadable media on any webpage.
- **Seamless Handoff:** Automatically sends captured links to the desktop application for processing.
- **Smart Detection:** Identifies video, audio, and playlist URLs across major streaming platforms.
- **Installation:** Simply download the `.zip`, extract it, and load it as an "Unpacked Extension" in Chrome/Edge/Firefox.

### 🔒 Secure & Private
- **Built-in Cloudflare WARP:** Easily utilize secure, private network traffic right out of the box to bypass throttling or geographic restrictions during downloads.
- **No Data Logging:** Your download history and preferences stay local on your machine.

### ⚙️ Customizable Experience
- **Auto Startup:** Configure Zylos to run automatically when your system boots so your tools are always ready.
- **Theme Support:** Switch between Light and Dark modes to match your workflow.
- **Custom Output Paths:** Organize your downloads by type, site, or custom folders.

---

## 💻 Installation Instructions

### 1. Desktop Application
1. Download the installer that best fits your needs from the table above.
2. Run the executable (`.exe`).
3. **If using Universal Setup:** Choose your preferred installation mode (**Online** for latest features, **Offline** for no-internet setup).
4. **Plugin Selection:** Check the boxes for the tools you need (e.g., yt-dlp, FFmpeg, Cloudflare WARP).
5. Follow the remaining on-screen instructions to finish setting up Zylos!

> 💡 **Tip:** If you are unsure which installer to pick, we recommend starting with **`Zylos_Universal_Setup.exe`** for maximum flexibility.

### 2. Browser Extension (New!)
1. Download **`zylos_extension_3.0.zip`** from the assets below.
2. **Extract** the ZIP file to a permanent folder on your computer (do not delete this folder).
3. Open your browser (Chrome, Edge, or Firefox).
4. Navigate to the Extensions page:
   - **Chrome/Edge:** Type `chrome://extensions` in the address bar.
   - **Firefox:** Type `about:debugging#/runtime/this-firefox`.
5. Enable **Developer Mode** (toggle in the top right corner).
6. Click **"Load unpacked"** (or "Load Temporary Add-on" in Firefox).
7. Select the **folder** you extracted in Step 2.
8. The Zylos icon should now appear in your browser toolbar! 🎉

---

## 📸 Sneak Peek

<div align="center">

![Main Interface](https://raw.githubusercontent.com/YasirSDQ/Zylos/main/Images/Screenshots/Main%20Interface.png)
*The sleek new v3.0 Dashboard*

![Download Features](https://raw.githubusercontent.com/YasirSDQ/Zylos/main/Images/Screenshots/Download%20Features.png)
*Powerful downloading capabilities powered by yt-dlp*

![Browser Extension](https://raw.githubusercontent.com/YasirSDQ/Zylos/main/Images/Screenshots/Browser%20Extension.jpg)
*Capture links instantly with the new Browser Extension*

</div>

---

## 🏗️ Technology Stack

Zylos v3.0 is built on the shoulders of giants:

| Component | Technology | Role |
| :--- | :--- | :--- |
| **UI Framework** | [Flutter](https://flutter.dev/) | Cross-platform desktop interface |
| **Download Engine** | [yt-dlp](https://github.com/yt-dlp/yt-dlp) | The world's most popular video downloader |
| **Media Processor** | [FFmpeg](https://github.com/yt-dlp/FFmpeg-Builds) | Audio/Video conversion and merging |
| **Network Security** | Cloudflare WARP | Encrypted tunneling for downloads |

---

## ⚠️ Known Issues & Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **Extension not loading** | Ensure you extracted the ZIP file to a permanent folder before loading it. Do not load directly from the ZIP. |
| **Download fails immediately** | Try enabling "Cloudflare WARP" in settings or switch yt-dlp to the "Nightly" build. |
| **FFmpeg missing error** | Re-run the installer and ensure the "FFmpeg" plugin checkbox is selected. |

---

## 🤝 Contributing

We welcome contributions! Whether it's reporting bugs, suggesting features, or improving code, your help is appreciated.

- **Report Issues:** [GitHub Issues](https://github.com/YasirSDQ/Zylos/issues)
- **Contribute Code:** [Pull Requests](https://github.com/YasirSDQ/Zylos/pulls)
- **Support Dependencies:** Consider contributing to [yt-dlp](https://github.com/yt-dlp/yt-dlp), [FFmpeg](https://github.com/yt-dlp/FFmpeg-Builds), or [Flutter](https://flutter.dev/).

---

<div align="center">

### 📥 Ready to get started?

Scroll to the top and grab the installer that fits your needs!

**Made with ❤️ by YasirSDQ**

[![GitHub Stars](https://img.shields.io/github/stars/YasirSDQ/Zylos?style=social)](https://github.com/YasirSDQ/Zylos)
[![GitHub Forks](https://img.shields.io/github/forks/YasirSDQ/Zylos?style=social)](https://github.com/YasirSDQ/Zylos)
[![License](https://img.shields.io/github/license/YasirSDQ/Zylos)](https://github.com/YasirSDQ/Zylos/blob/main/LICENSE)

</div>
