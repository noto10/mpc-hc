@ECHO OFF
REM (C) 2009-2019 see Authors.txt
REM Fixed for MSYS2 MinGW-w64 compatibility

SETLOCAL
SET "FILE_DIR=%~dp0"
PUSHD "%FILE_DIR%"

IF EXIST "build.user.bat" CALL "build.user.bat"

IF NOT DEFINED MPCHC_MINGW64 (
    ECHO ERROR: Please define MPCHC_MINGW64 environment variable
    ENDLOCAL
    EXIT /B 1
)

IF NOT EXIST "%MPCHC_MINGW64%\bin\gcc.exe" (
    ECHO ERROR: gcc.exe not found in %MPCHC_MINGW64%\bin
    ENDLOCAL
    EXIT /B 1
)

REM Get GCC Version
FOR /f "tokens=1 delims=." %%K IN ('"%MPCHC_MINGW64%\bin\gcc.exe" -dumpversion') DO SET "GCCVER=%%K"

SET LIBDIR=lib
MKDIR "%LIBDIR%" 2>NUL
MKDIR "%LIBDIR%64" 2>NUL

REM Copy libgcc.a
COPY /V /Y "%MPCHC_MINGW64%\lib\gcc\x86_64-w64-mingw32\%GCCVER%\libgcc.a" "%LIBDIR%64\" >NUL

REM Copy and Strip libmingwex.a (64-bit)
REM Modern MSYS2 puts this in x86_64-w64-mingw32\lib
COPY /V /Y "%MPCHC_MINGW64%\x86_64-w64-mingw32\lib\libmingwex.a" "%LIBDIR%64\" >NUL

REM Try to remove unused objects. Ignore errors as object names change between GCC versions.
lib -remove:lib64_libmingwex_a-strtoimax.o -remove:lib64_libmingwex_a-strtof.o -remove:lib64_libmingwex_a-cos.o -remove:lib64_libmingwex_a-sin.o -remove:lib64_libmingwex_a-pow.o -remove:lib64_libmingwex_a-sqrt.o -remove:lib64_libmingwex_a-sqrtf.o -remove:lib64_libmingwex_a-powi.o "%LIBDIR%64\libmingwex.a" || REM

REM Rename the result to .lib temporarily
RENAME "%LIBDIR%64\libmingwex.a" "libmingwex.lib" 2>NUL

REM Move the stripped library to the final name expected by the linker
MOVE /Y "%LIBDIR%64\libmingwex.lib" "%LIBDIR%64\libmingwex.a" >NUL

ECHO MinGW libraries updated successfully.
ENDLOCAL
EXIT /B 0
