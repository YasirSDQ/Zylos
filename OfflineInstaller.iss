[Setup]
AppId={{5E5D1D50-E3A2-4B6A-B785-3E7F91C1E6F3}
AppName=Zylos
AppVersion=3.0.3
VersionInfoVersion=3.0.3.0
AppPublisher=Zylos
AppCopyright=Copyright (C) 2026 Zylos
DefaultDirName={pf32}\Zylos
DisableProgramGroupPage=yes
DisableDirPage=no
UsePreviousAppDir=no
UsePreviousTasks=no
OutputBaseFilename=Zylos_Universal_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern dark
UninstallDisplayIcon={app}\zylos.exe
SetupIconFile=Logos and icons\icon.ico
PrivilegesRequired=admin
WizardSmallImageFile=Logo\logo_tranprant.png
WizardImageFile=Logo\Left Side completed window logo.png

[Types]
Name: "full"; Description: "Full installation"
Name: "compact"; Description: "Minimal installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "main"; Description: "Zylos App (Core Files)"; Types: full compact custom; Flags: fixed
Name: "plugin_ytdlp"; Description: "yt-dlp (Stable, Nightly, Master)"; Types: full custom; ExtraDiskSpaceRequired: 53526740
Name: "plugin_ffmpeg"; Description: "FFmpeg"; Types: full custom; ExtraDiskSpaceRequired: 145812992
Name: "plugin_warp"; Description: "Cloudflare WARP"; Types: full custom; ExtraDiskSpaceRequired: 59486208

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startup"; Description: "Automatically start Zylos on system startup"; GroupDescription: "Startup options:"

Name: "mode_online"; Description: "Online Installation (Download latest plugins)"; GroupDescription: "Installation Mode:"; Flags: exclusive unchecked
Name: "mode_offline"; Description: "Offline Installation (Use bundled plugins)"; GroupDescription: "Installation Mode:"; Flags: exclusive

[Files]
; The main executable and Flutter DLLs
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main
; The unpacked browser extension
Source: "zylos_extension\*"; DestDir: "{app}\zylos_extension"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main

; Offline plugins bundled from D:\Plugins
Source: "D:\Plugins\yt-dlp.exe"; DestDir: "{localappdata}\Zylos\bin"; Flags: ignoreversion skipifsourcedoesntexist; Components: plugin_ytdlp; Tasks: mode_offline
Source: "D:\Plugins\yt-dlp-nightly.exe"; DestDir: "{localappdata}\Zylos\bin"; Flags: ignoreversion skipifsourcedoesntexist; Components: plugin_ytdlp; Tasks: mode_offline
Source: "D:\Plugins\yt-dlp-stable.exe"; DestDir: "{localappdata}\Zylos\bin"; Flags: ignoreversion skipifsourcedoesntexist; Components: plugin_ytdlp; Tasks: mode_offline
Source: "D:\Plugins\ffmpeg.exe"; DestDir: "{localappdata}\Zylos\bin"; Flags: ignoreversion skipifsourcedoesntexist; Components: plugin_ffmpeg; Tasks: mode_offline
Source: "D:\Plugins\Cloudflare_WARP.msi"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall skipifsourcedoesntexist; Components: plugin_warp; Tasks: mode_offline

[Icons]
Name: "{autoprograms}\Zylos"; Filename: "{app}\zylos.exe"
Name: "{autodesktop}\Zylos"; Filename: "{app}\zylos.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Zylos"; ValueData: """{app}\zylos.exe"" background"; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{sys}\msiexec.exe"; Parameters: "/i ""{tmp}\Cloudflare_WARP.msi"""; StatusMsg: "Installing Cloudflare WARP..."; Components: plugin_warp; Tasks: mode_offline; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\zylos.exe"; Description: "{cm:LaunchProgram,Zylos}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  HasDownloads: Boolean;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    DownloadPage.Clear;
    HasDownloads := False;
    
    if WizardIsTaskSelected('mode_online') then begin
      if WizardIsComponentSelected('plugin_ytdlp') then begin
        DownloadPage.Add('https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe', 'yt-dlp.exe', '');
        HasDownloads := True;
      end;
      
      if WizardIsComponentSelected('plugin_ffmpeg') then begin
        DownloadPage.Add('https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip', 'ffmpeg.zip', '');
        HasDownloads := True;
      end;
      
      if WizardIsComponentSelected('plugin_warp') then begin
        DownloadPage.Add('https://1.1.1.1/Cloudflare_WARP_Release-x64.msi', 'warp.msi', '');
        HasDownloads := True;
      end;
    end;

    if HasDownloads then begin
      DownloadPage.Show;
      try
        try
          DownloadPage.Download;
          
          if WizardIsComponentSelected('plugin_ytdlp') then begin
            Exec('powershell.exe', '-ExecutionPolicy Bypass -WindowStyle Hidden -Command "New-Item -ItemType Directory -Force -Path ''' + ExpandConstant('{localappdata}\Zylos\bin') + '''; Copy-Item -Path ''' + ExpandConstant('{tmp}\yt-dlp.exe') + ''' -Destination ''' + ExpandConstant('{localappdata}\Zylos\bin\yt-dlp.exe') + ''' -Force"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
          end;
          
          if WizardIsComponentSelected('plugin_ffmpeg') then begin
            Exec('powershell.exe', '-ExecutionPolicy Bypass -WindowStyle Hidden -Command "New-Item -ItemType Directory -Force -Path ''' + ExpandConstant('{localappdata}\Zylos\bin') + '''; Expand-Archive -Path ''' + ExpandConstant('{tmp}\ffmpeg.zip') + ''' -DestinationPath ''' + ExpandConstant('{tmp}\ffmpeg_ext') + ''' -Force; Copy-Item ''' + ExpandConstant('{tmp}\ffmpeg_ext\ffmpeg-master-latest-win64-gpl\bin\*.exe') + ''' -Destination ''' + ExpandConstant('{localappdata}\Zylos\bin') + ''' -Force"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
          end;
          
          if WizardIsComponentSelected('plugin_warp') then begin
            Exec(ExpandConstant('{sys}\msiexec.exe'), '/i "' + ExpandConstant('{tmp}\warp.msi') + '"', '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);
          end;
          
        except
          if DownloadPage.AbortedByUser then
            Log('Aborted by user.')
          else
            MsgBox('Download failed: ' + GetExceptionMessage, mbError, MB_OK);
        end;
      finally
        DownloadPage.Hide;
      end;
    end;
  end;
end;
