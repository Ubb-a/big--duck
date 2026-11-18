param(
    [string]$RustRepo = (Join-Path $PSScriptRoot "..\rust"),
    [string]$NdkPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($NdkPath)) {
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_NDK_HOME) -and (Test-Path $env:ANDROID_NDK_HOME)) {
        $NdkPath = $env:ANDROID_NDK_HOME
    } else {
        $ndkParent = "$env:LOCALAPPDATA\Android\Sdk\ndk"
        if (Test-Path $ndkParent) {
            $NdkPath = Get-ChildItem -Path $ndkParent -Directory |
                Sort-Object { [version]($_.Name -replace '[^0-9.]', '') } -ErrorAction SilentlyContinue |
                Select-Object -Last 1 -ExpandProperty FullName
            if ([string]::IsNullOrWhiteSpace($NdkPath)) {
                $NdkPath = Get-ChildItem -Path $ndkParent -Directory | Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($NdkPath) -or -not (Test-Path $NdkPath)) {
    throw "Android NDK not found. Install NDK in Android Studio or pass -NdkPath <path>."
}

$env:ANDROID_NDK_HOME = $NdkPath
Write-Host "Using Android NDK: $NdkPath"

# Prefer MSYS2 UCRT64 GNU toolchain on Windows hosts without Windows SDK libs
if (Test-Path "C:\msys64\ucrt64\bin") {
    $env:PATH = "C:\msys64\ucrt64\bin;$env:PATH"
}

$toolchain = "stable-x86_64-pc-windows-gnu"

if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
    Write-Host "Installing cargo-ndk..."
    cargo +$toolchain install cargo-ndk
}

rustup target add --toolchain $toolchain aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

$jniOut = Join-Path $PSScriptRoot "..\android\app\src\main\jniLibs"
New-Item -ItemType Directory -Force -Path $jniOut | Out-Null

Push-Location $RustRepo
try {
    cargo +$toolchain ndk `
        -t arm64-v8a `
        -t armeabi-v7a `
        -t x86_64 `
        -o $jniOut `
        build --release -p teledrive-mobile-bridge
    if ($LASTEXITCODE -ne 0) {
        throw "cargo ndk build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host "Built Android Rust libraries into $jniOut"
