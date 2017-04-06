; -- demeter_and_strawberry_perl.iss --

#define MyInstName "Demeter_Installer_for_Windows"
#define MyAppVersion "0.9.25"
#define MyAppPublisher "Bruce Ravel"
#define MyAppURL "http://bruceravel.github.io/demeter"
#define Demeter "Demeter with Strawberry Perl"
#define Bits "64"
#define Pre "pre2"

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!
; using ISC 5.4.2(a)

; TODO: Restrict the installation path to have  no non-ascii characters in the path
; TODO: do we need to set Environment variable other than Path ? e.g. file extension mapping?
; TODO: Add alot more menu items that the original Strawberry also adds
; TODO: add License  LicenseFile
; TODO: add README   InfoAfterFile
; TODO: check for other perl installations (eg. in the Path variable) and warn or even abort if there is another one

[Setup]
;AppId={{D68911A8-D821-4411-AE5D-DA36327C000E}
AppId=Strawberry_Perl_with_Demeter
AppName={#Demeter} {#MyAppVersion}
AppVersion={#MyAppVersion} ({#Bits})
DefaultDirName={userappdata}\DemeterPerl
UsePreviousAppDir=no
DefaultGroupName={#Demeter}
; UninstallDisplayIcon={app}\MyProg.exe
Compression=lzma2
SolidCompression=yes
SourceDir=c:\strawberry
OutputDir=c:\output\{#MyAppVersion}
;OutputBaseFilename=Demeter_{#MyAppVersion}_with_Strawberry_Perl_({#Bits})_{#Pre}
OutputBaseFilename=Demeter_{#MyAppVersion}_with_Strawberry_Perl_({#Bits})
AppComments=XAS Data Processing and Analysis
AppContact={#MyAppURL}
AppCopyright=Demeter is copyright (c) 2006-2016 Bruce Ravel; Ifeffit is copyright (c) 2008, Matt Newville; Larch is copyright (c) 2016, Matt Newville and Tom Trainor; Perl is copyright 1987-2011, Larry Wall
; AppMutex= TODO!
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}

PrivilegesRequired = lowest

ChangesAssociations=yes
ChangesEnvironment=yes

SetupIconFile=Demeter.ico
WizardImageFile=Demeter_installer.bmp

LicenseFile=Demeter.license.txt
InfoAfterFile=Demeter.readme.txt


[Run]
Filename: "{app}\relocation.pl.bat";
;Filename: "{app}\modify_path.pl.bat"; Parameters: """{app}"""
;Filename: "{app}\munge_pathenv.pl.bat"; Parameters: """{app}"""


[Dirs]
Name: "{userappdata}\demeter"

[Registry]
Root: HKCU; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueName: "Path"; ValueType: expandsz; ValueData: "{olddata};{code:getPath}"; \
    Check: NeedsAddPath('\perl\site\bin');
; TODO: don't add the leading semi-colon to the Path if there is already a trailing one
Root: HKCU; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueName: "PGPLOT_DIR"; ValueType: expandsz; ValueData: "{app}\c\lib\pgplot";
Root: HKCU; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueName: "FONTCONFIG_FILE"; ValueType: expandsz; ValueData: "{app}\c\bin\etc\fonts\fonts.conf";

;; File associations
Root: HKCU; Subkey: ".pl"; ValueType: string; ValueName: ""; ValueData: "Perl"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Perl"; ValueType: string; ValueName: ""; ValueData: "Perl program"; Flags: uninsdeletekey 
Root: HKCU; Subkey: "Perl\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\perl\bin\perl.exe,0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Perl\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\perl\bin"" ""%1"""; Flags: uninsdeletekey 

Root: HKCU; Subkey: ".prj"; ValueType: string; ValueName: ""; ValueData: "Athena"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Athena"; ValueType: string; ValueName: ""; ValueData: "Athena project file"; Flags: uninsdeletekey 
Root: HKCU; Subkey: "Athena\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\perl\site\lib\Demeter\UI\Athena\share\athena_icon.ico"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Athena\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\perl\site\bin\dathena.bat"" ""%1"""; Flags: uninsdeletekey 

Root: HKCU; Subkey: ".fpj"; ValueType: string; ValueName: ""; ValueData: "Artemis"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Artemis"; ValueType: string; ValueName: ""; ValueData: "Artemis fitting project"; Flags: uninsdeletekey 
Root: HKCU; Subkey: "Artemis\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\perl\site\lib\Demeter\UI\Artemis\share\artemis_icon.ico"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Artemis\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\perl\site\bin\dartemis.bat"" ""%1"""; Flags: uninsdeletekey 


[Files]
Source: "*"; DestDir: "{app}"; Flags: "recursesubdirs"; Excludes: "\cpan\build\*,\cpan\sources\*,\perl\site\lib\Xray\BLA.pm,\perl\site\lib\Xray\BLA\*,\perl\site\lib\Demeter\UI\Metis.pm,\perl\site\lib\Demeter\UI\Metis\*,\perl\site\bin\bla*,\perl\site\bin\metis*,\c\hdf5\*,\perl\site\lib\PDL\IO\HDF5.pm,\perl\site\lib\PDL\IO\HDF5\*,\perl\site\lib\auto\PDL\IO\HDF5\HDF5.xs.dll";

[Tasks]
Name: "desktopicon"; Description: "Create &desktop icons"; GroupDescription: "Additional shortcuts:";

[Icons]
;;; Demeter applications
Name: "{group}\Athena"; Filename: "{app}\perl\site\bin\dathena.bat"; Comment: "XAS Data Processing"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Athena\share\athena_icon.ico"
Name: "{group}\Artemis"; Filename: "{app}\perl\site\bin\dartemis.bat"; Comment: "EXAFS Data Analysis using Feff and Ifeffit"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Artemis\share\artemis_icon.ico"
Name: "{group}\Hephaestus"; Filename: "{app}\perl\site\bin\dhephaestus.bat"; Comment: "A periodic table for the absorption spectroscopist"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Hephaestus\icons\vulcan.ico"
Name: "{group}\Stand-alone Atoms"; Filename: "{app}\perl\site\bin\datoms.bat"; Comment: "Crystallography for the absorption spectroscopist"; Parameters: "--wx"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Atoms\icons\atoms.ico"
Name: "{group}\Uninstall"; Filename: "{app}\unins000.exe";
Name: "{group}\Gnuplot shell"; Filename: "{app}\c\bin\gnuplot\bin\wgnuplot.exe"; Comment: "Stand-alone gnuplot plotting shell"; WorkingDir: "{app}"; IconFilename: "{app}\c\bin\gnuplot\bin\gnuplot.ico"
Name: "{group}\Log folder"; Filename: "{userappdata}\demeter"; Comment: "Location of Demeter log files"; WorkingDir: "{userappdata}";
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
Name: "{commondesktop}\Athena"; Filename: "{app}\perl\site\bin\dathena.bat"; Comment: "XAS Data Processing"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Athena\share\athena_icon.ico"; Tasks: desktopicon
Name: "{commondesktop}\Artemis"; Filename: "{app}\perl\site\bin\dartemis.bat"; Comment: "EXAFS Data Analysis using Feff and Ifeffit"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Artemis\share\artemis_icon.ico"; Tasks: desktopicon
Name: "{commondesktop}\Hephaestus"; Filename: "{app}\perl\site\bin\dhephaestus.bat"; Comment: "A periodic table for the absorption spectroscopist"; WorkingDir: "{app}"; IconFilename: "{app}\perl\site\lib\Demeter\UI\Hephaestus\icons\vulcan.ico"; Tasks: desktopicon

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
  if not RegQueryStringValue(HKEY_CURRENT_USER,
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
  if not RegQueryStringValue(HKEY_CURRENT_USER,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  start_pos  := Pos(getPath(''), OrigPath);
  end_pos    := start_pos + Length(getPath(''));
  new_str    := Copy(OrigPath, 0, start_pos-1) + Copy(OrigPath, end_pos, Length(OrigPath));
  RegWriteExpandStringValue(HKEY_CURRENT_USER,
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
//function NextButtonClick(CurPageID: Integer): Boolean;
//begin
//  Result :=True;
//  case CurPageID of
//    wpSelectDir :
//    begin
//    if Pos(' ', ExpandConstant('{app}') ) <> 0 then
//      begin
//        MsgBox('You cannot install to a path containing spaces. Please select a different path.', mbError, mb_Ok);
//        Result := False;
//      end;
//    end;
//  end;
//end;





// see http://stackoverflow.com/questions/2000296/innosetup-how-to-automatically-uninstall-previous-installed-version
/////////////////////////////////////////////////////////////////////
function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\Strawberry_Perl_with_Demeter_is1');
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;


/////////////////////////////////////////////////////////////////////
function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;


/////////////////////////////////////////////////////////////////////
function UnInstallOldVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
// Return Values:
// 1 - uninstall string is empty
// 2 - error executing the UnInstallString
// 3 - successfully executed the UnInstallString

  // default return value
  Result := 0;

  // get the uninstall string of the old app
  sUnInstallString := GetUninstallString();
  if sUnInstallString <> '' then begin
    sUnInstallString := RemoveQuotes(sUnInstallString);
    if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES','', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      Result := 3
    else
      Result := 2;
  end else
    Result := 1;
end;

/////////////////////////////////////////////////////////////////////
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep=ssInstall) then
  begin
    if (IsUpgrade()) then
    begin
      UnInstallOldVersion();
    end;
  end;
end;