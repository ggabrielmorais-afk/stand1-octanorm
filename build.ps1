# Gera o pacote .rbz a partir da fonte (loader + pasta STAND1_Octanorm).
# Uso:  powershell -ExecutionPolicy Bypass -File build.ps1
# (mesmo esquema do STAND1_EVA/build.ps1)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Le a versao do loader
$loader = Join-Path $root "STAND1_Octanorm_loader.rb"
$ver = (Select-String -Path $loader -Pattern "version\s*=\s*'([\d.]+)'").Matches[0].Groups[1].Value
if (-not $ver) { throw "Versao nao encontrada no loader." }

$out = Join-Path $root "STAND1_Octanorm_v$ver.rbz"
if (Test-Path $out) { Remove-Item $out -Force }

# Arquiva versoes anteriores: mantem so o .rbz atual na pasta principal.
$arquivo = Join-Path $root "versoes_anteriores"
New-Item -ItemType Directory -Force $arquivo | Out-Null
Get-ChildItem -Path $root -Filter "STAND1_Octanorm_v*.rbz" | Where-Object { $_.Name -ne "STAND1_Octanorm_v$ver.rbz" } | ForEach-Object {
  Move-Item $_.FullName (Join-Path $arquivo $_.Name) -Force
}

# Empacota com barras NORMAIS (/): o instalador .rbz do SketchUp exige forward slash.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($out, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $loader, "STAND1_Octanorm_loader.rb") | Out-Null

  # Pasta STAND1_Octanorm inteira, menos os testes
  $srcDir = Join-Path $root "STAND1_Octanorm"
  Get-ChildItem -Path $srcDir -Recurse -File | Where-Object { $_.FullName -notlike "*\tests\*" } | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel) | Out-Null
  }
} finally {
  $zip.Dispose()
}

Write-Host "Gerado: $out"
Write-Host "Lembre de atualizar latest.json (versao, rbz e notas) antes do commit."
