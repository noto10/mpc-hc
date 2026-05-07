@ECHO OFF
EXIT /B

:End
IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
POPD
ENDLOCAL
EXIT /B

:SubMake
IF %ERRORLEVEL% NEQ 0 EXIT /B
IF /I "%ARCH%" == "x86" (SET "ARCHVS=Win32") ELSE (SET "ARCHVS=x64")

REM =====================================================
REM Build FFmpeg using bash directly
REM =====================================================

"C:\msys64\usr\bin\bash.exe" build_ffmpeg.sh %ARCH% %RELEASETYPE% %BUILDTYPE% %COMPILER%

IF %ERRORLEVEL% NEQ 0 (
    CALL "%COMMON%" :SubMsg "ERROR" "'build_ffmpeg.sh' failed!"
    EXIT /B 1
)

PUSHD src

REM =====================================================
REM Build LAVFilters
REM =====================================================

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
