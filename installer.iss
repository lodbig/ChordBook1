[Setup]
AppName=ChordBook
AppVersion=1.0.0
DefaultDirName={autopf}\ChordBook
DefaultGroupName=ChordBook
UninstallDisplayIcon={app}\chordbook.exe
Compression=lzma2
SolidCompression=yes
OutputDir=.\build\windows\runner\Release
OutputBaseFilename=ChordBookSetup
; הגדרת שפה לעברית כברירת מחדל
ShowLanguageDialog=no

[Languages]
; כאן מגדירים את השפה, לא בתוך [Setup]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Files]
; ודא ששם ה-EXE כאן תואם לשם הפרויקט שלך (chordbook.exe)
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\ChordBook"; Filename: "{app}\chordbook.exe"
Name: "{commondesktop}\ChordBook"; Filename: "{app}\chordbook.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "צור קיצור דרך על שולחן העבודה"; GroupDescription: "משימות נוספות:"

[Run]
Filename: "{app}\chordbook.exe"; Description: "הפעל את האפליקציה"; Flags: nowait postinstall skipifsilent