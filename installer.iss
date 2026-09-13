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
OutputBaseFilename=Zylos_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern dark
UninstallDisplayIcon={app}\zylos.exe
SetupIconFile=Logos and icons\icon.ico
PrivilegesRequired=admin
WizardSmallImageFile=Logo\logo_tranprant.png
WizardImageFile=Logo\Left Side completed window logo.png

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startup"; Description: "Automatically start Zylos on system startup"; GroupDescription: "Startup options:"
Name: "plugin_ytdlp"; Description: "Download yt-dlp"; GroupDescription: "Plugins (Can also be downloaded later in app):"; Flags: unchecked
Name: "plugin_ffmpeg"; Description: "Download FFmpeg"; GroupDescription: "Plugins (Can also be downloaded later in app):"; Flags: unchecked
Name: "plugin_warp"; Description: "Download and install Cloudflare WARP"; GroupDescription: "Plugins (Can also be downloaded later in app):"; Flags: unchecked

[Files]
; The main executable and Flutter DLLs
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; The unpacked browser extension
Source: "zylos_extension\*"; DestDir: "{app}\zylos_extension"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Zylos"; Filename: "{app}\zylos.exe"
Name: "{autodesktop}\Zylos"; Filename: "{app}\zylos.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Zylos"; ValueData: """{app}\zylos.exe"" background"; Flags: uninsdeletevalue; Tasks: startup

[Run]
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
    
    if WizardIsTaskSelected('plugin_ytdlp') then begin
      DownloadPage.Add('https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe', 'yt-dlp.exe', '');
      HasDownloads := True;
    end;
    
    if WizardIsTaskSelected('plugin_ffmpeg') then begin
      DownloadPage.Add('https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip', 'ffmpeg.zip', '');
      HasDownloads := True;
    end;
    
    if WizardIsTaskSelected('plugin_warp') then begin
      DownloadPage.Add('https://1.1.1.1/Cloudflare_WARP_Release-x64.msi', 'warp.msi', '');
      HasDownloads := True;
    end;

    if HasDownloads then begin
      DownloadPage.Show;
      try
        try
          DownloadPage.Download;
          
          if WizardIsTaskSelected('plugin_ytdlp') then begin
            Exec('powershell.exe', '-ExecutionPolicy Bypass -WindowStyle Hidden -Command "New-Item -ItemType Directory -Force -Path ''' + ExpandConstant('{localappdata}\Zylos\bin') + '''; Copy-Item -Path ''' + ExpandConstant('{tmp}\yt-dlp.exe') + ''' -Destination ''' + ExpandConstant('{localappdata}\Zylos\bin\yt-dlp.exe') + ''' -Force"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
          end;
          
          if WizardIsTaskSelected('plugin_ffmpeg') then begin
            Exec('powershell.exe', '-ExecutionPolicy Bypass -WindowStyle Hidden -Command "New-Item -ItemType Directory -Force -Path ''' + ExpandConstant('{localappdata}\Zylos\bin') + '''; Expand-Archive -Path ''' + ExpandConstant('{tmp}\ffmpeg.zip') + ''' -DestinationPath ''' + ExpandConstant('{tmp}\ffmpeg_ext') + ''' -Force; Copy-Item ''' + ExpandConstant('{tmp}\ffmpeg_ext\ffmpeg-master-latest-win64-gpl\bin\*.exe') + ''' -Destination ''' + ExpandConstant('{localappdata}\Zylos\bin') + ''' -Force"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
          end;
          
          if WizardIsTaskSelected('plugin_warp') then begin
            Exec('msiexec.exe', '/i "' + ExpandConstant('{tmp}\warp.msi') + '" /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
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
