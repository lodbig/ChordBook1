[Setup]
AppName=ChordBook
AppVersion=1.0.0
DefaultDirName={autopf}\ChordBook
DefaultGroupName=ChordBook
UninstallDisplayIcon={app}\chordbook.exe
Compression=lzma2
SolidCompression=yes
; כאן עדכנתי ל-x64
OutputDir=.\build\windows\x64\runner\Release
OutputBaseFilename=ChordBookSetup
ShowLanguageDialog=no

[Languages]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Files]
; הוספתי x64 לנתיב המקור
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\ChordBook"; Filename: "{app}\chordbook.exe"
Name: "{commondesktop}\ChordBook"; Filename: "{app}\chordbook.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "צור קיצור דרך על שולחן העבודה"; GroupDescription: "משימות נוספות:"

[Run]
Filename: "{app}\chordbook.exe"; Description: "הפעל את האפליקציה"; Flags: nowait postinstall skipifsilent