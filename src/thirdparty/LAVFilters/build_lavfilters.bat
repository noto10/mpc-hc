@ECHO OFF
SETLOCAL EnableDelayedExpansion
SET "FILE_DIR=%~dp0"
PUSHD "%FILE_DIR%"

SET ROOT_DIR=..\..\..
SET "COMMON=%FILE_DIR%%ROOT_DIR%\common.bat"

CALL "%COMMON%" :SubSetPath
IF %ERRORLEVEL% NEQ 0 GOTO ErrorExit

CALL "%COMMON%" :SubDoesExist gcc.exe
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: gcc.exe not found in your MinGW installation
    GOTO ErrorExit
)

SET ARG=/%*
SET ARG=%ARG:/=%
SET ARG=%ARG:-=%
SET ARGB=0
SET ARGBC=0
SET ARGCOMP=0
SET ARGPL=0
SET INPUT=0
SET VALID=0

IF /I "%ARG%" == "?" GOTO ShowHelp

FOR %%G IN (%ARG%) DO (
    IF /I "%%G" == "help"     GOTO ShowHelp
    IF /I "%%G" == "Build"    SET "BUILDTYPE=Build"     & SET /A ARGB+=1
    IF /I "%%G" == "Clean"    SET "BUILDTYPE=Clean"     & SET /A ARGB+=1
    IF /I "%%G" == "Rebuild"  SET "BUILDTYPE=Rebuild"   & SET /A ARGB+=1
    IF /I "%%G" == "Both"     SET "ARCH=Both"           & SET /A ARGPL+=1
    IF /I "%%G" == "Win32"    SET "ARCH=x86"            & SET /A ARGPL+=1
    IF /I "%%G" == "x86"      SET "ARCH=x86"            & SET /A ARGPL+=1
    IF /I "%%G" == "x64"      SET "ARCH=x64"            & SET /A ARGPL+=1
    IF /I "%%G" == "Debug"    SET "RELEASETYPE=Debug"   & SET /A ARGBC+=1
    IF /I "%%G" == "Release"  SET "RELEASETYPE=Release" & SET /A ARGBC+=1
    IF /I "%%G" == "VS2017"   SET "COMPILER=VS2017"     & SET /A ARGCOMP+=1
    IF /I "%%G" == "VS2019"   SET "COMPILER=VS2019"     & SET /A ARGCOMP+=1
    IF /I "%%G" == "Silent"   SET "SILENT=True"         & SET /A VALID+=1
    IF /I "%%G" == "Nocolors" SET "NOCOLORS=True"       & SET /A VALID+=1
)

FOR %%X IN (%*) DO SET /A INPUT+=1
SET /A VALID+=%ARGB%+%ARGPL%+%ARGBC%+%ARGCOMP%

IF %VALID% NEQ %INPUT% GOTO UnsupportedSwitch

IF %ARGB%    GTR 1 (GOTO UnsupportedSwitch) ELSE IF %ARGB% == 0    (SET "BUILDTYPE=Build")
IF %ARGPL%   GTR 1 (GOTO UnsupportedSwitch) ELSE IF %ARGPL% == 0   (SET "ARCH=Both")
IF %ARGBC%   GTR 1 (GOTO UnsupportedSwitch) ELSE IF %ARGBC% == 0   (SET "RELEASETYPE=Release")
IF %ARGCOMP% GTR 1 (GOTO UnsupportedSwitch) ELSE IF %ARGCOMP% == 0 (SET "COMPILER=VS2019")

IF NOT EXIST "%MPCHC_VS_PATH%" CALL "%COMMON%" :SubVSPath
IF NOT EXIST "!MPCHC_VS_PATH!" (
    ECHO ERROR: Visual Studio install path not found or invalid. You should add MPCHC_VS_PATH to build.user.bat
    GOTO MissingVar
)

SET "TOOLSET=!MPCHC_VS_PATH!\Common7\Tools\vsdevcmd"
IF NOT EXIST "%TOOLSET%" (
    ECHO ERROR: Visual Studio tool path invalid
    GOTO MissingVar
)

SET "BIN_DIR=%ROOT_DIR%\bin"
CALL "%COMMON%" :SubParseConfig

IF /I "%ARCH%" == "Both" (
    SET "ARCH=x86" & CALL :Main
    SET "ARCH=x64" & CALL :Main
) ELSE (
    CALL :Main
)

GOTO End

:Main
IF %ERRORLEVEL% NEQ 0 EXIT /B
IF /I "%ARCH%" == "x86" (SET TOOLSETARCH=x86) ELSE (SET TOOLSETARCH=amd64)
CALL "%TOOLSET%" -no_logo -arch=%TOOLSETARCH%

IF /I "%BUILDTYPE%" == "Rebuild" (
    SET "BUILDTYPE=Clean" & CALL :SubMake
    SET "BUILDTYPE=Build" & CALL :SubMake
    SET "BUILDTYPE=Rebuild"
    EXIT /B
)

IF /I "%BUILDTYPE%" == "Clean" (CALL :SubMake & EXIT /B)
CALL :SubMake
EXIT /B

:End
IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
POPD
ENDLOCAL
EXIT /B

:SubMake
IF %ERRORLEVEL% NEQ 0 EXIT /B
IF /I "%ARCH%" == "x86" (SET "ARCHVS=Win32") ELSE (SET "ARCHVS=x64")

REM Build FFmpeg
sh build_ffmpeg.sh %ARCH% %RELEASETYPE% %BUILDTYPE% %COMPILER%
IF %ERRORLEVEL% NEQ 0 (
    CALL "%COMMON%" :SubMsg "ERROR" "'sh build_ffmpeg.sh' failed!"
    EXIT /B 1
)

PUSHD src
REM Build LAVFilters
MSBuild.exe LAVFilters.sln /nologo /consoleloggerparameters:Verbosity=minimal /nodeReuse:true /m /t:%BUILDTYPE% /property:Configuration=%RELEASETYPE%;Platform=%ARCHVS%
IF %ERRORLEVEL% NEQ 0 (
    CALL "%COMMON%" :SubMsg "ERROR" "MSBuild LAVFilters failed!"
    POPD
    EXIT /B 1
)
POPD

IF /I "%RELEASETYPE%" == "Debug" (
    SET "SRCFOLDER=src\bin_%ARCHVS%d"
) ELSE (
    SET "SRCFOLDER=src\bin_%ARCHVS%"
)

IF /I "%ARCH%" == "x64" (
    SET "DESTFOLDER=%BIN_DIR%\mpc-hc_%ARCH%\LAVFilters64"
) ELSE (
    SET "DESTFOLDER=%BIN_DIR%\mpc-hc_%ARCH%\LAVFilters"
)

IF /I "%BUILDTYPE%" == "Build" (
    IF NOT EXIST "%DESTFOLDER%" MD "%DESTFOLDER%"
    COPY /Y /V "%SRCFOLDER%\*.dll" "%DESTFOLDER%" >NUL
    COPY /Y /V "%SRCFOLDER%\*.ax" "%DESTFOLDER%" >NUL
    COPY /Y /V "%SRCFOLDER%\*.manifest" "%DESTFOLDER%" >NUL
)

EXIT /B

:MissingVar
ECHO Not all build dependencies were found.
ECHO See "%ROOT_DIR%\docs\Compilation.md" for more information.
EXIT /B 1

:UnsupportedSwitch
ECHO Unsupported commandline switch!
EXIT /B 1

:ShowHelp
ECHO Usage: %~nx0 [Clean^|Build^|Rebuild] [x86^|x64^|Both] [Debug^|Release] [VS2017^|VS2019]
EXIT /B 1

:ErrorExit
POPD
ENDLOCAL
EXIT /B 1
