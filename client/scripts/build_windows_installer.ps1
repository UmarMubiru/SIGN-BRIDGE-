param(
    [string]$ApiBaseUrl,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$clientRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repositoryRoot = (Resolve-Path (Join-Path $clientRoot '..')).Path
$datasetRuntimeOutput = Join-Path $clientRoot 'build\dataset_tools'
$datasetRuntime = Join-Path $datasetRuntimeOutput 'signbridge_dataset_assets'
$datasetWork = Join-Path $clientRoot 'build\dataset-tools-work'
$datasetScript = Join-Path $repositoryRoot 'backend\scripts\extract_local_dataset_assets.py'
$datasetModels = Join-Path $repositoryRoot 'backend\models'
$pubspec = Get-Content (Join-Path $clientRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$') {
    throw 'Could not read a semantic app version from pubspec.yaml.'
}
$appVersion = $Matches[1]

$datasetPython = Join-Path $repositoryRoot 'backend\venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $datasetPython -PathType Leaf)) {
    $systemPython = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $systemPython) {
        throw 'Python was not found. Install Python and the packages in backend/requirements-dataset-export.txt to bundle offline frame analysis.'
    }
    $datasetPython = $systemPython.Source
}
if (-not (Test-Path -LiteralPath $datasetScript -PathType Leaf)) {
    throw "Local dataset extractor was not found at $datasetScript"
}
foreach ($modelName in @('face_landmarker.task', 'hand_landmarker.task')) {
    if (-not (Test-Path -LiteralPath (Join-Path $datasetModels $modelName) -PathType Leaf)) {
        throw "Required MediaPipe model is missing: $modelName"
    }
}

& $datasetPython -m PyInstaller --version *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'PyInstaller is missing. Install backend/requirements-dataset-export.txt before building the Windows installer.'
}

New-Item -ItemType Directory -Path $datasetWork -Force | Out-Null
$pyInstallerArguments = @(
    '-m', 'PyInstaller',
    '--noconfirm',
    '--clean',
    '--onedir',
    '--name', 'signbridge_dataset_assets',
    '--distpath', $datasetRuntimeOutput,
    '--workpath', $datasetWork,
    '--specpath', $datasetWork,
    '--collect-binaries', 'mediapipe',
    '--collect-submodules', 'mediapipe.tasks.python.vision',
    '--collect-submodules', 'mediapipe.tasks.python.core',
    '--collect-submodules', 'mediapipe.tasks.python.components',
    $datasetScript
)
& $datasetPython @pyInstallerArguments
if ($LASTEXITCODE -ne 0) { throw "Bundling local frame-analysis tools failed ($LASTEXITCODE)." }
$datasetRuntimeExecutable = Join-Path $datasetRuntime 'signbridge_dataset_assets.exe'
if (-not (Test-Path -LiteralPath $datasetRuntimeExecutable -PathType Leaf)) {
    throw 'PyInstaller did not create the local frame-analysis executable.'
}
$modelsDestination = Join-Path $datasetRuntime 'models'
New-Item -ItemType Directory -Path $modelsDestination -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $datasetModels 'face_landmarker.task') -Destination $modelsDestination -Force
Copy-Item -LiteralPath (Join-Path $datasetModels 'hand_landmarker.task') -Destination $modelsDestination -Force

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutter) {
    $flutter = Get-Command 'D:\flutter\bin\flutter.bat' -ErrorAction SilentlyContinue
}
if ($null -eq $flutter) {
    throw 'Flutter was not found. Add Flutter to PATH or run this script in a Flutter environment.'
}

if (-not $SkipBuild) {
    Push-Location $clientRoot
    try {
        $buildArgs = @('build', 'windows', '--release')
        if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
            $buildArgs += "--dart-define=SIGNBRIDGE_API_BASE_URL=$ApiBaseUrl"
        }
        & $flutter.Source @buildArgs
        if ($LASTEXITCODE -ne 0) { throw "Flutter Windows release build failed ($LASTEXITCODE)." }
    } finally {
        Pop-Location
    }
}

$bundle = Join-Path $clientRoot 'build\windows\x64\runner\Release'
$executable = Join-Path $bundle 'signbridge.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Windows release executable not found at $executable"
}

$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if ($null -eq $iscc) {
    $candidatePath = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if ($candidatePath) { $isccPath = [string]$candidatePath }
} else {
    $isccPath = $iscc.Source
}
if (-not $isccPath) {
    throw 'Inno Setup 6 was not found. Install Inno Setup 6, then rerun this script.'
}

$installerScript = Join-Path $clientRoot 'windows\installer\SignBridge.iss'
& $isccPath "/DAppVersion=$appVersion" "/DSourceDir=$bundle" "/DDatasetToolsDir=$datasetRuntime" $installerScript
if ($LASTEXITCODE -ne 0) { throw "Inno Setup packaging failed ($LASTEXITCODE)." }

$installer = Join-Path $clientRoot "build\installer\SignBridge-Setup-$appVersion-Windows-x64.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "Installer output was not created at $installer"
}
$checksumPath = "$installer.sha256"
$checksum = Get-FileHash -LiteralPath $installer -Algorithm SHA256
"$($checksum.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($installer))" |
    Set-Content -LiteralPath $checksumPath -Encoding ascii

Write-Output "Installer: $installer"
Write-Output "SHA-256: $checksumPath"
