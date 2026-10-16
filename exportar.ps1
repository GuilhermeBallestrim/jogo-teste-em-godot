<#
.SYNOPSIS
    Testa e exporta o jogo, contornando C: sem espaco.

.DESCRIPTION
    O Godot no Windows guarda os export templates em %APPDATA%\Godot, que fica
    no disco C:. Se o C: estiver lotado, o export falha com
    "No export template found" mesmo que o projeto inteiro esteja no D:.

    Este script detecta isso e redireciona o APPDATA para uma pasta em D:
    apenas nos comandos que ele executa -- nada no C: e alterado.

.PARAMETER GodotPath
    Caminho do executavel do Godot. Padrao: procura no PATH, na area de trabalho
    e em C:\Tools.

.PARAMETER Preset
    Nome do preset em export_presets.cfg.

.PARAMETER SkipTests
    Nao roda os testes antes de exportar.

.PARAMETER SkipTemplates
    Nao tenta baixar os export templates.

.EXAMPLE
    .\exportar.ps1
    .\exportar.ps1 -Preset "Linux"
#>
[CmdletBinding()]
param(
    [string] $GodotPath,
    [string] $Preset = "Windows Desktop",
    [string] $OutputPath = "build\windows\novo-jogo.exe",
    [string] $DataDir = "D:\GodotAppData",
    [string] $TempDir = "D:\GodotTemp",
    [switch] $SkipTests,
    [switch] $SkipTemplates
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# O executavel do Godot e um binario GUI: ele nao escreve $LASTEXITCODE, e o
# PowerShell trata stderr de processo nativo como erro quando
# ErrorActionPreference = Stop. Nos comandos nativos abaixamos para Continue e
# decidimos o sucesso pelo conteudo da saida, nao pelo codigo de retorno.
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------- Godot

function Resolve-Godot {
    param([string] $Hint)

    if ($Hint) {
        if (Test-Path $Hint) { return (Resolve-Path $Hint).Path }
        throw "Godot nao encontrado em '$Hint'."
    }

    $found = Get-Command godot, godot4 -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty Source
    if ($found) { return $found }

    $candidates = @(
        (Join-Path $env:USERPROFILE "Desktop\Godot*.exe"),
        "C:\Tools\Godot*.exe",
        "C:\Program Files\Godot\Godot*.exe"
    )
    foreach ($pattern in $candidates) {
        $hit = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($hit) { return $hit }
    }

    throw "Godot nao encontrado. Informe -GodotPath <caminho>."
}

$godot = Resolve-Godot -Hint $GodotPath
Write-Host "Godot:    $godot" -ForegroundColor DarkGray

# --------------------------------------------------- C: lotado -> D:

# Esse build do Godot nao imprime nada em `--version` (escreve direto no
# console do Windows), entao tiramos a versao do nome do executavel, que segue
# o padrao Godot_v<major>.<minor>.<patch>.exe.
$exeName = Split-Path $godot -Leaf
if ($exeName -notmatch '(\d+\.\d+(?:\.\d+)?)') {
    throw "Nao consegui deduzir a versao a partir de '$exeName'. Renomeie para Godot_v4.5.1.exe ou passe -GodotPath."
}
$version = $Matches[1]
Write-Host "versao:   $version" -ForegroundColor DarkGray

$freeC = (Get-PSDrive C).Free
# Os templates ficam em %APPDATA%, entao procuramos no C: **primeiro**.
# So redirecionamos se o C: estiver sem espaco -- e, mesmo assim, conferimos o
# lugar novo antes de baixar 1 GB de novo.
$templatesDir = Join-Path $env:APPDATA "Godot\export_templates\$version.stable"

function Test-TemplatesPresent {
    param([string] $Dir)
    (Test-Path $Dir) -and
    ((Get-ChildItem $Dir -Filter "*_release_x86_64*" -File -ErrorAction SilentlyContinue |
      Select-Object -First 1) -ne $null)
}

if (-not (Test-TemplatesPresent $templatesDir) -and $freeC -lt 2GB) {
    # O Godot usa tres diretorios no C:, entao redirecionamos os tres juntos:
    #   APPDATA     -> config do editor + export_templates
    #   LOCALAPPDATA-> cache de onde o .tpz e baixado
    #   TEMP/TMP    -> arquivos temporarios da extracao
    # So este processo e redirecionado; nada no C: e alterado.
    foreach ($sub in @("", "Local", "Roaming")) {
        New-Item -ItemType Directory -Force -Path (Join-Path $DataDir $sub) | Out-Null
    }
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    $env:APPDATA = Join-Path $DataDir "Roaming"
    $env:LOCALAPPDATA = Join-Path $DataDir "Local"
    $env:TEMP = $TempDir
    $env:TMP = $TempDir

    Write-Host "C: com $([math]::Round($freeC / 1GB, 2)) GB livres -- redirecionando o Godot para $DataDir" -ForegroundColor Yellow
} else {
    Write-Host "C: com $([math]::Round($freeC / 1GB, 2)) GB livres" -ForegroundColor DarkGray
}

# Recalcula: se redirecionamos, o caminho dos templates mudou.
$templatesDir = Join-Path $env:APPDATA "Godot\export_templates\$version.stable"

# ------------------------------------------------------------- testes

if (-not $SkipTests) {
    Write-Host "`n==> Testes" -ForegroundColor Cyan
    $output = & $godot --headless --path . --script res://tests/test_runner.gd 2>&1 | Out-String
    $errors = ($output -split "`n" | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Compile Error" })

    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "Erro de script detectado nos testes. Export abortado."
    }
    if ($output -notmatch "TESTES: PASSARAM") {
        Write-Host $output -ForegroundColor Red
        throw "Os testes falharam. Export abortado."
    }
    Write-Host ($output.Trim() -split "`n" | Where-Object { $_ -match "verificacoes|TESTES" } | Out-String).Trim() -ForegroundColor Green
}

# ---------------------------------------------------------- templates

function Install-TemplatesManual {
    param([string] $Version, [string] $Destination)

    # O --install-export-templates embutido trava em algumas maquinas
    # (fica pendurado sem abrir conexao nem escrever byte). O download em si
    # e rapido, entao contornamos baixando o .tpz na mao.
    $url = "https://github.com/godotengine/godot/releases/download/$Version-stable/Godot_v$Version-stable_export_templates.tpz"

    # Baixa para o disco com mais espaco. Se o C: estiver no fim, usar o TEMP
    # (que fica no C:) faz o curl falhar com erro 23.
    $scratch = Get-PSDrive C
    $scratchDir = if ($scratch.Free -lt 3GB) { $DataDir } else { $env:TEMP }
    New-Item -ItemType Directory -Force -Path $scratchDir | Out-Null
    $tpz = Join-Path $scratchDir "templates.tpz"
    $work = Join-Path $scratchDir "extract"

    Write-Host "    baixando $url" -ForegroundColor DarkGray
    & curl.exe -L --fail --silent --show-error -o $tpz $url
    if ($LASTEXITCODE -ne 0) { throw "Falha no download do .tpz (curl saiu com $LASTEXITCODE)." }

    $mb = [math]::Round((Get-Item $tpz).Length / 1MB, 1)
    Write-Host "    $mb MB baixados, extraindo..." -ForegroundColor DarkGray

    New-Item -ItemType Directory -Force -Path $work, $Destination | Out-Null
    & tar.exe -xf $tpz -C $work
    if ($LASTEXITCODE -ne 0) { throw "Falha na extracao do .tpz." }

    Move-Item "$work\templates\*" $Destination -Force
    Remove-Item $tpz, $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ((Test-TemplatesPresent $templatesDir)) {
    Write-Host "Templates ja instalados." -ForegroundColor DarkGray
} elseif (-not $SkipTemplates) {
    Write-Host "`n==> Export templates ausentes" -ForegroundColor Cyan
    Write-Host "    tentando o downloader do Godot..." -ForegroundColor DarkGray

    $job = Start-Job -ScriptBlock {
        param($exe, $dir)
        & $exe --headless --install-export-templates
    } -ArgumentList $godot, $templatesDir

    # O downloader embutido trava em algumas maquinas. Se nao terminar em 90s,
    # desistimos e vamos pelo .tpz na mao.
    if (Wait-Job $job -Timeout 90) {
        Receive-Job $job | Out-Null
    } else {
        Write-Host "    o downloader do Godot travou, contornando" -ForegroundColor Yellow
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    if (-not (Test-TemplatesPresent $templatesDir)) {
        Write-Host "    baixando o .tpz manualmente" -ForegroundColor DarkGray
        Install-TemplatesManual -Version $version -Destination $templatesDir
    }
}

if (-not (Test-TemplatesPresent $templatesDir)) {
    Write-Host "`nTemplates ainda ausentes em: $templatesDir" -ForegroundColor Red
    Write-Host "Sem eles o export falha com 'No export template found'." -ForegroundColor Yellow
    exit 1
}

Write-Host "Templates: $templatesDir" -ForegroundColor DarkGray

# ------------------------------------------------------------ export

$outDir = Split-Path $OutputPath -Parent
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

Write-Host "`n==> Exportando preset '$Preset'" -ForegroundColor Cyan
$exportOutput = & $godot --headless --path . --export-release $Preset $OutputPath 2>&1 | Out-String
$exportOutput -split "`n" | Where-Object { $_ -match "ERROR|error" } | ForEach-Object {
    Write-Host $_.Trim() -ForegroundColor Red
}

if (-not (Test-Path $OutputPath)) {
    throw "Export falhou: '$OutputPath' nao foi criado."
}

$size = [math]::Round((Get-Item $OutputPath).Length / 1MB, 1)
Write-Host "`nOK -> $OutputPath ($size MB)" -ForegroundColor Green