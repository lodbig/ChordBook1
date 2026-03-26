[Setup]
AppName=ChordBook
AppVersion=1.0.0
DefaultDirName={autopf}\ChordBook
DefaultGroupName=ChordBook
UninstallDisplayIcon={app}\ChordBook.exe
Compression=lzma2
SolidCompression=yes
OutputDir=.\build\windows\runner\Release
OutputBaseFilename=MyApplicationSetup
; הגדרת שפה לעברית
ShowLanguageDialog=no
Languages=hebrew

[Languages]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Files]
; מעלה את ה-EXE וכל ה-DLLs הדרושים מתיקיית ה-Release
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\ChordBook"; Filename: "{app}\ChordBook.exe"
Name: "{commondesktop}\ChordBook"; Filename: "{app}\ChordBook.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "צור קיצור דרך על שולחן העבודה"; GroupDescription: "משימות נוספות:"

[Run]
Filename: "{app}\ChordBook.exe"; Description: "הפעל את האפליקציה"; Flags: nowait postinstall skipifsilent