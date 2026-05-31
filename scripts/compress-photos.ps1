<#
.SYNOPSIS
  Re-encode all JPG/PNG photos in a directory at a target JPEG quality, without
  modifying color/exposure. Use this as the default pipeline; do filtering
  manually before placing the source files.

.DESCRIPTION
  For each *.jpg in -Path, run `magick <file> -quality Q <file>` in place.
  For each *.png (e.g. AI-enhanced outputs that ship without EXIF in JPEG form),
  convert to .jpg at the same quality, preserve EXIF, and delete the original
  .png. The PNG → JPG conversion is needed because Windows Explorer / many
  consumer tools don't read PNG eXIf chunks reliably.

  Strips EXIF orientation issues and shrinks file size while preserving the
  visual content the user (or their external editor) has already chosen.

  This replaces the previous `normalize-photos.ps1` pipeline as the default —
  color/saturation normalization is no longer applied automatically because
  users typically want full control over their own filters.

  Files are MODIFIED IN PLACE (PNG → JPG also deletes the source PNG). Keep
  an untouched copy of the originals elsewhere (e.g. `photos/<slug>/`).

.PARAMETER Path
  Directory containing the *.jpg / *.png files to compress.

.PARAMETER Quality
  JPEG quality (1-100). Default: 88. Lower = smaller file, more compression
  artifacts. 88 typically halves file size with no visible loss.

.PARAMETER DryRun
  Print what would be done, but do not modify files.

.EXAMPLE
  ./scripts/compress-photos.ps1 -Path public/images/kyoto

.EXAMPLE
  ./scripts/compress-photos.ps1 -Path public/images/kyoto -Quality 82
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path,
    [int]$Quality = 88,
    [switch]$DryRun
)

if (-not (Test-Path -PathType Container $Path)) {
    Write-Error "Directory not found: $Path"
    exit 1
}

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick (magick) is not available. Install with: winget install ImageMagick.ImageMagick"
    exit 1
}

$files = Get-ChildItem -Path $Path -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png)$' }
if ($files.Count -eq 0) {
    Write-Warning "No .jpg / .png files found in $Path"
    exit 0
}

$rows = @()
foreach ($file in $files) {
    $beforeBytes = $file.Length
    $isPng = $file.Extension -match '^\.png$'
    if ($isPng) {
        $outPath = [System.IO.Path]::ChangeExtension($file.FullName, '.jpg')
        if (-not $DryRun) {
            & magick "$($file.FullName)" -quality $Quality "$outPath"
            Remove-Item -Force $file.FullName
            $afterBytes = (Get-Item $outPath).Length
        } else {
            $afterBytes = "(dry)"
        }
        $row = [PSCustomObject]@{
            File   = "$($file.Name) → $([System.IO.Path]::GetFileName($outPath))"
            Before = if ($beforeBytes -is [int64]) { "{0:N0}" -f $beforeBytes } else { $beforeBytes }
            After  = if ($afterBytes -is [int64]) { "{0:N0}" -f $afterBytes } else { $afterBytes }
        }
    } else {
        if (-not $DryRun) {
            & magick "$($file.FullName)" -quality $Quality "$($file.FullName)"
            $afterBytes = (Get-Item $file.FullName).Length
        } else {
            $afterBytes = "(dry)"
        }
        $row = [PSCustomObject]@{
            File   = $file.Name
            Before = if ($beforeBytes -is [int64]) { "{0:N0}" -f $beforeBytes } else { $beforeBytes }
            After  = if ($afterBytes -is [int64]) { "{0:N0}" -f $afterBytes } else { $afterBytes }
        }
    }
    $rows += $row
}

$rows | Format-Table -AutoSize
if ($DryRun) { Write-Host "Dry run -- no files modified." -ForegroundColor Yellow }
