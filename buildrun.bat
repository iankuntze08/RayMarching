@echo off

if "%1"=="clean" (
    rmdir /s /q build
)

cmake -S . -B build -G Ninja ^
    -DCMAKE_C_COMPILER=clang-cl ^
    -DCMAKE_CXX_COMPILER=clang-cl

if errorlevel 1 exit /b %errorlevel%

cmake --build build

if errorlevel 1 exit /b %errorlevel%

.\build\RaytracingGL.exe
