param([string]$Compiler = "i686-w64-mingw32-clang.exe")
$ErrorActionPreference = "Stop"
$source = Join-Path $PSScriptRoot "LockPort.c"
$output = Join-Path (Split-Path $PSScriptRoot -Parent) "LockPort.dll"
& $Compiler -shared -O2 -Wall -Wextra -Werror -static-libgcc $source -o $output
if ($LASTEXITCODE -ne 0) { throw "LockPort.dll build failed ($LASTEXITCODE)" }
Write-Host "Built $output"
