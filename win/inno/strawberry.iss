; -- demeter_and_strawberry_perl.iss --

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!
; using ISC 5.4.2(a)

; TODO: Restrict the installation path to have  no non-ascii characters in the path
; TODO: do we need to set Environment variable other than Path ? e.g. file extension mapping?
; TODO: Add alot more menu items that the original Strawberry also adds
; TODO: add License  LicenseFile
; TODO: add README   InfoAfterFile
; TODO: check for other perl installations (eg. in the Path variable) and warn or even abort if there is another one

[Setup]
AppName=Demeter with Strawberry Perl Release 4
AppVersion=0.5.4
DefaultDirName=\strawberry
DefaultGroupName=Demeter with Strawberry Perl
; UninstallDisplayIcon={app}\MyProg.exe
Compression=lzma2
SolidCompression=yes
SourceDir=c:\strawberry
OutputDir=c:\output
OutputBaseFilename=demeter-with-strawberry-perl-r4
AppComments=XAS Data Processing and Analysis
AppContact=http://bruceravel.github.com/demeter/
AppCopyright=Demeter is copyright (c) 2006-2011 Bruce Ravel; Ifeffit is copyright (c) 2008, Matt Newville; Perl is copyright 1987-2010, Larry Wall
AppId=Strawberry_Perl_with_Demeter
; AppMutex= TODO!
AppPublisherURL=http://bruceravel.github.com/demeter/

ChangesAssociations=yes
ChangesEnvironment=yes

LicenseFile=Demeter.license.txt
InfoAfterFile=Demeter.readme.txt


[Run]
Filename: "{app}\relocation.pl.bat";

[Dirs]
Name: "{userappdata}\demeter"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueName: "Path"; ValueType: expandsz; ValueData: "{olddata};{code:getPath}"; \
    Check: NeedsAddPath('\perl\site\bin');
; TODO: don't add the leading semi-colon to the Path if there is already a trailing one
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueName: "PGPLOT_DIR"; ValueType: expandsz; ValueData: "{app}\c\lib\pgplot";
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueName: "FONTCONFIG_FILE"; ValueType: expandsz; ValueData: "{app}\c\bin\etc\fonts\fonts.conf";

;; File associations
Root: HKCR; Subkey: ".pl"; ValueType: string; ValueName: ""; ValueData: "Perl"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "Perl"; ValueType: string; ValueName: ""; ValueData: "Perl program"; Flags: uninsdeletekey 
Root: HKCR; Subkey: "Perl\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\perl\bin\perl.exe,0"; Flags: uninsdeletekey
Root: HKCR; Subkey: "Perl\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\perl\bin"" ""%1"""; Flags: uninsdeletekey 

Root: HKCR; Subkey: ".prj"; ValueType: string; ValueName: ""; ValueData: "Athena"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "Athena"; ValueType: string; ValueName: ""; ValueData: "Athena project file"; Flags: uninsdeletekey 
Root: HKCR; Subkey: "Athena\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\perl\site\lib\Demeter\UI\Athena\share\athena_icon.ico"; Flags: uninsdeletekey
Root: HKCR; Subkey: "Athena\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\perl\site\bin\dathena.bat"" ""%1"""; Flags: uninsdeletekey 

Root: HKCR; Subkey: ".fpj"; ValueType: string; ValueName: ""; ValueData: "Artemis"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "Artemis"; ValueType: string; ValueName: ""; ValueData: "Artemis fitting project"; Flags: uninsdeletekey 
Root: HKCR; Subkey: "Artemis\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\perl\site\lib\Demeter\UI\Artemis\share\artemis_icon.ico"; Flags: uninsdeletekey
Root: HKCR; Subkey: "Artemis\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\perl\site\bin\dartemis.bat"" ""%1"""; Flags: uninsdeletekey 


[Files]
Source: "*"; DestDir: "{app}"; Flags: "recursesubdirs"; Excludes: "\cpan\build\*,\cpan\sources\*";

[Tasks]
Name: "desktopicon"; Description: "Create &desktop icons"; GroupDescription: "Additional shortcuts:";

[Icons]
;;; Demeter applications
Name: "{group}\Athena"; Filename: "{app}\perl\site\bin\dathena.bat"; Comment: "XAS Data Processing"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Athena\share\athena_icon.ico"
Name: "{group}\Artemis"; Filename: "{app}\perl\site\bin\dartemis.bat"; Comment: "EXAFS Data Analysis using Feff and Ifeffit"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Artemis\share\artemis_icon.ico"
Name: "{group}\Hephaestus"; Filename: "{app}\perl\site\bin\dhephaestus.bat"; Comment: "A periodic table for the absorption spectroscopist"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Hephaestus\icons\vulcan.ico"
Name: "{group}\Stand-alone Atoms"; Filename: "{app}\perl\site\bin\datoms.bat"; Comment: "Crystallography for the x-ray spectroscopist"; Parameters: "--wx"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Atoms\icons\atoms.ico"
Name: "{group}\Uninstall"; Filename: "{app}\unins000.exe";
;;; Demeter URLs
Name: "{group}\Website - Demeter"; Filename: "{app}\win32\Demeter Website.url"; IconFilename: "{app}\win32\Demeter.ico"
Name: "{group}\Website - Ifeffit Wiki"; Filename: "{app}\win32\Ifeffit Wiki.url"; IconFilename: "{app}\win32\Ifeffit.ico"
Name: "{group}\Website - XAFS.org"; Filename: "{app}\win32\xafs.org.url"; IconFilename: "{app}\win32\xafs.org.ico"
;;; replicating the Start menu entries installed by Strawberry
Name: "{group}\Perl\Perl (command line)"; Filename: "C:\WINDOWS\system32\cmd.exe"; WorkingDir: "{app}"; Comment: "Quick way to get to the command line in order to use Perl."
Name: "{group}\Perl\Strawberry Perl README"; Filename: "{app}\README.txt"; Comment: "Strawberry Perl README"
Name: "{group}\Perl\Strawberry Perl Release Notes"; Filename: "{app}\win32\Strawberry Perl Release Notes.url"; Comment: "Strawberry Perl Release Notes"; IconFilename: "{app}\win32\strawberry.ico";
Name: "{group}\Perl\Related Websites\Beginning Perl (onlne book)"; Filename: "{app}\win32\Beginning Perl (online book).url"; Comment: "Beginning Perl (online book)"; IconFilename: "{app}\win32\perlhelp.ico";
Name: "{group}\Perl\Related Websites\learn.perl.org (tutorials, links)"; Filename: "{app}\win32\learn.perl.org (tutorials, links).url"; Comment: "learn.perl.org (tutorials, links)";  IconFilename: "{app}\win32\perlhelp.ico";
Name: "{group}\Perl\Related Websites\Ovid's CGI Course"; Filename: "{app}\win32\Ovid's CGI Course.url"; Comment: "Ovid's CGI Course"; IconFilename: "{app}\win32\perlhelp.ico";
Name: "{group}\Perl\Related Websites\Strawberry Perl Website"; Filename: "{app}\win32\Strawberry Perl Website.url"; Comment: "Strawberry Perl Website"; IconFilename: "{app}\win32\strawberry.ico";
Name: "{group}\Perl\Related Websites\CPAN Module Search"; Filename: "{app}\win32\CPAN Module Search.url"; Comment: "CPAN Module Search"; IconFilename: "{app}\win32\cpan.ico";
Name: "{group}\Perl\Related Websites\Live Support"; Filename: "{app}\win32\Live Support.url"; Comment: "Live Support"; IconFilename: "{app}\win32\onion.ico";
Name: "{group}\Perl\Related Websites\Perl 5.12.2 Documentation (5.12.3 not available yet)"; Filename: "{app}\win32\Perl 5.12.2 Documentation (5.12.3 not available yet).url"; Comment: "Perl 5.12.2 Documentation (5.12.3 not available yet)"; IconFilename: "{app}\win32\perldoc.ico";
Name: "{group}\Perl\Related Websites\Win32 Perl Wiki"; Filename: "{app}\win32\Win32 Perl Wiki.url"; Comment: "Win32 Perl Wiki"; IconFilename: "{app}\win32\strawberry.ico";
Name: "{group}\Perl\Tools\Check installed versions of modules"; Filename: "{app}\perl\bin\module-version.bat"; WorkingDir: "{app}\perl\"; IconFilename: "{app}\win32\strawberry.ico";
Name: "{group}\Perl\Tools\Create local library areas"; Filename: "{app}\perl\bin\llw32helper.bat"; WorkingDir: "{app}\perl\"; IconFilename: "{app}\win32\strawberry.ico";
Name: "{group}\Perl\Tools\CPAN Client"; Filename: "{app}\perl\bin\cpan.bat"; WorkingDir: "{app}\perl\bin\"; IconFilename: "{app}\win32\cpan.ico";

;;; Application desktop icons
Name: "{commondesktop}\(D)Athena"; Filename: "{app}\perl\site\bin\dathena.bat"; Comment: "XAS Data Processing"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Athena\share\athena_icon.ico"; Tasks: desktopicon
Name: "{commondesktop}\(D)Artemis"; Filename: "{app}\perl\site\bin\dartemis.bat"; Comment: "EXAFS Data Analysis using Feff and Ifeffit"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Artemis\share\artemis_icon.ico"; Tasks: desktopicon
Name: "{commondesktop}\(D)Hephaestus"; Filename: "{app}\perl\site\bin\dhephaestus.bat"; Comment: "A periodic table for the absorption spectroscopist"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Hephaestus\icons\vulcan.ico"; Tasks: desktopicon

[Code]
function getPath(Param: String): string;
begin
  Result := ExpandConstant('{app}') + '\perl\bin;' + ExpandConstant('{app}') + '\perl\site\bin;' + ExpandConstant('{app}') + '\c\bin;'
end;

// From http://stackoverflow.com/questions/3304463/how-do-i-modify-the-path-environment-variable-when-running-an-inno-setup-installe
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  // look for the path with leading and trailing semicolon
  // Pos() returns 0 if not found
  //Result := Pos(';' + ExpandConstant('{app}') + Param + ';', OrigPath) = 0;
  Result := Pos(getPath(''), OrigPath) = 0;
end;

function RemovePath(): boolean;
var
  OrigPath: string;
  start_pos: Longint;
  end_pos: Longint;
  new_str: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  start_pos  := Pos(getPath(''), OrigPath);
  end_pos    := start_pos + Length(getPath(''));
  new_str    := Copy(OrigPath, 0, start_pos-1) + Copy(OrigPath, end_pos, Length(OrigPath));
  RegWriteExpandStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', new_str);
  Result := True;
end;
function InitializeUninstall(): Boolean;
begin
  Result := True;
//  Result := MsgBox('InitializeUninstall:' #13#13 'Uninstall is initializing. Do you really want to start Uninstall?', mbConfirmation, MB_YESNO) = idYes;
//  if Result = False then
//    MsgBox('InitializeUninstall:' #13#13 'Ok, bye bye.', mbInformation, MB_OK);
  RemovePath();  
end;
// C:\Program Files\CollabNet\Subversion Client;%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem;C:\strawberry\c\bin;C:\strawberry\perl\site\bin;C:\strawberry\perl\bin;;C:\Str\perl\bin;C:\Str\perl\site\bin;C:\Str\c\bin;d:\;


// Restrict the installation path to have no space 
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result :=True;
  case CurPageID of
    wpSelectDir :
    begin
    if Pos(' ', ExpandConstant('{app}') ) <> 0 then
      begin
        MsgBox('You cannot install to a path containing spaces. Please select a different path.', mbError, mb_Ok);
        Result := False;
      end;
    end;
  end;
end;
