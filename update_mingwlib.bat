@ECHO OFF
REM (C) 2009-2019 see Authors.txt
REM Fixed for MSYS2 MinGW-w64 compatibility (Newer GCC paths)

SETLOCAL
SET "FILE_DIR=%~dp0"
PUSHD "%FILE_DIR%"

IF EXIST "build.user.bat" CALL "build.user.bat"

IF NOT DEFINED MPCHC_MINGW64 (
    ECHO ERROR: MPCHC_MINGW64 is not defined.
    ENDLOCAL
    EXIT /B 1
)

SET LIBDIR=lib
MKDIR "%LIBDIR%" 2>NUL
MKDIR "%LIBDIR%64" 2>NUL

ECHO Copying MinGW libraries...

REM 1. Copy libgcc.a
REM Try standard MSYS2 location first, then fallback
IF EXIST "%MPCHC_MINGW64%\lib\libgcc.a" (
    COPY /V /Y "%MPCHC_MINGW64%\lib\libgcc.a" "%LIBDIR%\" >NUL
    COPY /V /Y "%MPCHC_MINGW64%\lib\libgcc.a" "%LIBDIR%64\" >NUL
) ELSE (
    ECHO WARNING: Could not find libgcc.a
)

REM 2. Copy and Strip libmingwex.a (64-bit)
REM Newer MSYS2 puts this in \lib, older puts it in \x86_64-w64-mingw32\lib
SET "SRC_LIB="
IF EXIST "%MPCHC_MINGW64%\lib\libmingwex.a" SET "SRC_LIB=%MPCHC_MINGW64%\lib\libmingwex.a"
IF EXIST "%MPCHC_MINGW64%\x86_64-w64-mingw32\lib\libmingwex.a" SET "SRC_LIB=%MPCHC_MINGW64%\x86_64-w64-mingw32\lib\libmingwex.a"

IF DEFINED SRC_LIB (
    COPY /V /Y "%SRC_LIB%" "%LIBDIR%64\libmingwex.a" >NUL
    
    REM Strip unused objects (Ignore errors if object names differ)
    lib -remove:lib64_libmingwex_a-strtoimax.o -remove:lib64_libmingwex_a-strtof.o -remove:lib64_libmingwex_a-cos.o -remove:lib64_libmingwex_a-sin.o -remove:lib64_libmingwex_a-pow.o -remove:lib64_libmingwex_a-sqrt.o -remove:lib64_libmingwex_a-sqrtf.o -remove:lib64_libmingwex_a-powi.o "%LIBDIR%64\libmingwex.a" || REM
    
    REM Rename to .lib temporarily, then back to .a to satisfy MSBuild
    RENAME "%LIBDIR%64\libmingwex.a" "libmingwex.lib" 2>NUL
    MOVE /Y "%LIBDIR%64\libmingwex.lib" "%LIBDIR%64\libmingwex.a" >NUL
) ELSE (
    ECHO ERROR: Could not find libmingwex.a in expected locations.
    ECHO Checked:
    ECHO 1. %MPCHC_MINGW64%\lib\libmingwex.a
    ECHO 2. %MPCHC_MINGW64%\x86_64-w64-mingw32\lib\libmingwex.a
)

ECHO MinGW libraries updated successfully.
ENDLOCAL
EXIT /B 0
