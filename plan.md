Project: Zylos Converter v3.0.1 - Major UI & Engine Update

Please implement the following comprehensive feature updates, bug fixes, and UI redesigns for the Zylos Converter application. The goal is to create a modern, minimalist interface backed by a highly advanced, automated conversion engine.

1. UI/UX Overhaul & Queue Management
Remove the Output Path Bar: Completely remove the static file path section (e.g., C:\Users\...\Zylos) from the top of the interface. Routing will now happen silently in the background for a cleaner, modern look.

"Clear All" Button: Add a "Clear All" button (or trash icon) in the top right header area next to "+ Add Files." Clicking this must instantly empty the current conversion queue.

Active Queue Metadata: Update the active download/queue list UI. Instead of generically displaying the word "video," the UI must extract and display the actual media resolution (e.g., 1080p, 720p, 4K, 320kbps) for each queued item.

2. The "Master Conversion Hub" (UI Redesign)
Replace the basic "Default Format" dropdown with a prominent "Master Settings" button that opens a centralized modal or side-panel.

Tabbed Navigation: Organize the hub into tabs: Video, Audio, Image, and Cross-Format.

Advanced Format Controls: Reveal contextual advanced settings based on the selected format:

Video: Codec (H.264, HEVC), Framerate (24, 30, 60fps), Aspect Ratio, and Resolution.

Audio: Bitrate (128, 256, 320kbps), Sample Rate (44.1kHz, 48kHz), Channels (Stereo/Mono).

Image: Quality/Compression percentage slider (1% - 100%).

Smart Presets: Add one-click fast presets (e.g., "High Quality", "Web Optimized").

Global "Apply" Logic: Include two action buttons at the bottom of the hub:

Save as Default for Future Files

Apply to All Current Files (instantly overrides all files currently in the queue).

Active State UI: Once master settings are applied, display a small summary text on the main screen (e.g., Target: MP4 | 1080p | 60fps) so the user knows exactly what will happen when they click "Convert All."

3. Cross-Media "Multi-Conversion" Engine
Upgrade the backend logic to support advanced, cross-format media conversions. The "Advanced Settings" must dynamically adapt when these are selected:

Video to Audio: Extract audio tracks (e.g., MP4 to MP3/WAV).

Video to Picture: Extract a specific frame as an image, or convert a short clip to GIF. (Settings: Allow user to pick the exact timestamp for frame extraction).

Picture to Video: Convert a static image into a video file with a silent audio track. (Settings: Allow user to set video duration).

Audio to Video: Merge an audio file with a static visual (black screen, waveform, or album art) to create a playable video file.

Audio to Picture: Extract embedded album art/metadata cover images from audio files and save them as standalone JPG/PNGs.

4. File System Routing & Bug Fixes
Dynamic Output Paths: Programmatically detect the current Windows user's root Downloads folder and automatically create a main directory named Zylos (e.g., C:\Users\[Username]\Downloads\Zylos\).

Format-Specific Auto-Sorting: Automatically create subfolders inside the Zylos directory based on the output format and route files there automatically (e.g., save MP3s to Zylos\mp3\, MP4s to Zylos\mp4\).

"Auto-Detect" Logic Fix: Fix the bug where toggling the "Auto-Detect" switch ON/OFF breaks functionality if a Default Format is selected. If Auto-Detect is ON, it must smoothly override or work alongside the default format. If OFF, it must strictly obey the user's selected Master Format.