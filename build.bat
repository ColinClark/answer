@echo off
REM MicroBrowser Build Script for Windows
REM Builds the application for release

echo Building MicroBrowser...

REM Check for required environment variables
if "%STATISTA_MCP_ENDPOINT%"=="" (
    echo Warning: STATISTA_MCP_ENDPOINT not set, using default
    set STATISTA_MCP_ENDPOINT=https://api.statista.ai/v1/mcp
)

if "%STATISTA_MCP_API_KEY%"=="" (
    echo Warning: STATISTA_MCP_API_KEY not set
)

REM Create build directory
if not exist build mkdir build
cd build

REM Configure with CMake
echo Configuring...
cmake -DCMAKE_BUILD_TYPE=Release ..
if %ERRORLEVEL% neq 0 (
    echo Configuration failed!
    exit /b 1
)

REM Build
echo Building...
cmake --build . --config Release
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build successful!
echo Executable: %CD%\Release\MicroBrowser.exe
echo Done!

cd ..