@ECHO OFF
SETLOCAL EnableDelayedExpansion

IF /I "%~1"=="help" GOTO SHOWHELP
IF /I "%~1"=="/?" GOTO SHOWHELP

PUSHD "%~dp0"

IF EXIST "..\..\..\build.user.bat" CALL "..\..\..\build.user.bat"

IF NOT DEFINED MPCHC_GIT IF DEFINED GIT SET MPCHC_GIT=%GIT%
IF NOT DEFINED MPCHC_MSYS IF DEFINED MSYS SET MPCHC_MSYS=%MSYS%

IF NOT DEFINED MPCHC_MSYS (
    ECHO ERROR: MPCHC_MSYS is not defined. Please set it to your MSYS2 root (e.g., C:\msys64).
    GOTO MissingVar
)

IF NOT EXIST "%MPCHC_MSYS%" (
    ECHO ERROR: MSYS2 directory not found at %MPCHC_MSYS%
    GOTO MissingVar
)

REM Ensure MSYS2 bin is in PATH for sh execution
SET PATH=%MPCHC_MSYS%\usr\bin;%MPCHC_MSYS%\mingw64\bin;%PATH%

IF EXIST "%~dp0..\environments.bat" CALL "%~dp0..\environments.bat"

:VarOk
SET "BUILDTYPE=build"
SET ARG=%*
SET ARG=%ARG:/=%
SET ARG=%ARG:-=%

FOR %%A IN (%ARG%) DO (
    IF /I "%%A" == "clean" SET "BUILDTYPE=clean"
    IF /I "%%A" == "rebuild" SET "BUILDTYPE=rebuild"
    IF /I "%%A" == "64" SET "BIT=64BIT=yes"
    IF /I "%%A" == "Debug" SET "DEBUG=DEBUG=yes"
)

IF /I "%BUILDTYPE%" == "rebuild" (
    SET "BUILDTYPE=clean"
    CALL :SubMake clean
    SET "BUILDTYPE=build"
    CALL :SubMake
    EXIT /B !MAKE_RETURN!
) ELSE (
    CALL :SubMake
    EXIT /B !MAKE_RETURN!
)

:SubMake
SETLOCAL
IF "%BUILDTYPE%" == "clean" (
    SET JOBS=1
) ELSE (
    SET "BUILDTYPE="
    IF DEFINED NUMBER_OF_PROCESSORS (
        SET JOBS=%NUMBER_OF_PROCESSORS%
    ) ELSE (
        SET JOBS=4
    )
)

SET MAK="%~dp0\ffmpeg-msvc.mak"
PUSHD ..\LAVFilters\src\ffmpeg\

REM Check for NASM/YASM
WHERE nasm >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    WHERE yasm >NUL 2>&1
    IF %ERRORLEVEL% NEQ 0 (
        ECHO WARNING: Neither nasm nor yasm found in PATH. FFmpeg build may fail.
    )
)

CALL make.exe -f %MAK% %BUILDTYPE% -j%JOBS% %BIT% %DEBUG%
ENDLOCAL
IF %ERRORLEVEL% NEQ 0 SET MAKE_RETURN=%ERRORLEVEL%

POPD
EXIT /B

:SHOWHELP
ECHO Usage: %~nx0 [32^|64] [Clean^|Build^|Rebuild] [Debug]
EXIT /B

:MissingVar
ECHO Not all build dependencies were found.
ECHO See "..\..\..\..\..\docs\Compilation.md" for more information.
ENDLOCAL
EXIT /B 1
