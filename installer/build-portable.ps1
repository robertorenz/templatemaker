<#
    Builds a single, self-contained, compressed .exe of the Template Designer
    (all of .NET is bundled inside - nothing to install on the target machine)
    and copies it to the repo's  run\  folder.

    Usage:   pwsh installer\build-portable.ps1
#>
[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$Runtime       = 'win-x64'
)

$ErrorActionPreference = 'Stop'
$here    = $PSScriptRoot
$repo    = Split-Path $here -Parent
$proj    = Join-Path $repo 'designer\ClarionTplDesigner\ClarionTplDesigner.csproj'
$pubDir  = Join-Path $here 'payload\single'
$runDir  = Join-Path $repo 'run'

Write-Host "==> Publishing single-file ($Configuration / $Runtime, self-contained + compressed)" -ForegroundColor Cyan
if (Test-Path $pubDir) { Remove-Item $pubDir -Recurse -Force }

dotnet publish $proj -c $Configuration -r $Runtime --self-contained true `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:IncludeAllContentForSelfExtract=true `
    -p:DebugType=none `
    -o $pubDir
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }

$exe = Join-Path $pubDir 'ClarionTplDesigner.exe'
if (-not (Test-Path $exe)) { throw "expected single-file exe not found: $exe" }

New-Item -ItemType Directory -Force -Path $runDir | Out-Null
Copy-Item $exe (Join-Path $runDir 'ClarionTemplateDesigner.exe') -Force

# Bundle the template-authoring assets next to the exe so it's usable out of the box.
# Clear each destination first so the bundle is a clean mirror (Copy-Item -Recurse into an
# existing dir would nest a copy inside it, e.g. run\templates\templates, and leave stale files).
foreach ($d in 'templates','agents','skills') {
    $src = Join-Path $repo $d
    $dst = Join-Path $runDir $d
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    if (Test-Path $src) {
        Copy-Item $src $dst -Recurse -Force
    }
}

$dst = Join-Path $runDir 'ClarionTemplateDesigner.exe'
Write-Host ""
Write-Host "==> Done: $dst" -ForegroundColor Green
"{0:N1} MB" -f ((Get-Item $dst).Length / 1MB) | Write-Host
