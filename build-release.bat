@echo off
setlocal enabledelayedexpansion

set ROOT=%~dp0
set PUBLISH_DIR=%ROOT%artifacts\win-x64
set PROJECT=%ROOT%src\LazExtractor.Cli\LazExtractor.Cli.csproj

echo Building trimmed single-file self-contained release for win-x64...
if exist "%PUBLISH_DIR%" (
    echo Cleaning %PUBLISH_DIR%...
    rmdir /s /q "%PUBLISH_DIR%"
)
mkdir "%PUBLISH_DIR%" >nul

dotnet publish "%PROJECT%" -c Release -r win-x64 --self-contained true ^
    -p:PublishSingleFile=true ^
    -p:IncludeNativeLibrariesForSelfExtract=true ^
    -p:PublishTrimmed=true ^
    -p:TrimMode=link ^
    -o "%PUBLISH_DIR%"
if errorlevel 1 (
    echo Publish failed.
    exit /b 1
)

for /f "delims=" %%A in ('dir /b "%PUBLISH_DIR%\*.exe"') do set OUTPUT_FILE=%%A

if not defined OUTPUT_FILE (
    echo Publish succeeded but no executable found.
    exit /b 1
)

echo Done. Trimmed single-file executable:
echo %PUBLISH_DIR%\%OUTPUT_FILE%
