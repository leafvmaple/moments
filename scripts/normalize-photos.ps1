<#
.SYNOPSIS
  Adaptively normalize the color/exposure of all JPG photos in a directory so they share a consistent palette.

.DESCRIPTION
  For each *.jpg in -Path:
    1. Measure mean saturation (S) in HSL.
    2. Compute a per-photo saturation multiplier that pulls S toward -TargetSaturation,
       clamped to [MinMul, MaxMul] to avoid muddiness or chroma-noise amplification.
    3. Apply contrast/exposure normalization in the LAB L-channel only — operating on RGB
       channels independently (as -auto-level + -sigmoidal-contrast do in sRGB) causes
       JPEG block edges to drift into different colors in low-chroma regions like overcast
       skies, producing visible purple/pink chroma blobs once saturation is boosted.
    4. Convert back to sRGB and apply the per-photo saturation multiplier.

  Files are MODIFIED IN PLACE. Keep an untouched copy of the originals elsewhere
  (e.g. the source zip / extracted folder under photos/).

.PARAMETER Path
  Directory containing the *.jpg files to normalize.

.PARAMETER TargetSaturation
  Target mean S (0-100) the script will try to pull each photo toward. Default: 35.

.PARAMETER MinMul
  Floor for the per-photo saturation multiplier. Default 0.85.

.PARAMETER MaxMul
  Ceiling for the per-photo saturation multiplier. Default 2.6 — high enough to rescue
  a washed-out frame (e.g. one where the camera's HDR/AWB collapsed a cloud-dominant
  scene to S~13), without falling back to one-off manual processing. The LAB-L-only
  contrast step earlier in the pipeline keeps a 2.6x boost from blooming chroma noise
  in low-color regions, which is what limited the earlier sRGB-based pipeline.

.PARAMETER TargetLightness
  Target mean L (0-100) the script will try to pull each photo toward. Default: 53.

.PARAMETER BriMin / BriMax
  Floor/ceiling for the per-photo brightness multiplier. Defaults 0.92 / 1.08 — gentle,
  because brightness mismatches are usually less jarring than chroma mismatches and
  over-correcting can crush highlights.

.PARAMETER Quality
  JPEG quality. Default: 88.

.PARAMETER DryRun
  Measure and print, but do not modify files.

.EXAMPLE
  ./scripts/normalize-photos.ps1 -Path public/images/arashiyama

.EXAMPLE
  ./scripts/normalize-photos.ps1 -Path public/images/kyoto -TargetSaturation 30 -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path,
    [int]$TargetSaturation = 35,
    [int]$TargetLightness = 53,
    [double]$MinMul = 0.85,
    [double]$MaxMul = 2.6,
    [double]$BriMin = 0.92,
    [double]$BriMax = 1.08,
    [int]$Quality = 88,
    [switch]$DryRun
)

if (-not (Test-Path -PathType Container $Path)) {
    Write-Error "Directory not found: $Path"
    exit 1
}

# Ensure magick is on PATH (winget-installed apps need the current shell to refresh)
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick (magick) is not available. Install with: winget install ImageMagick.ImageMagick"
    exit 1
}

$files = Get-ChildItem -Path $Path -Filter *.jpg -File
if ($files.Count -eq 0) {
    Write-Warning "No .jpg files found in $Path"
    exit 0
}

$rows = @()
foreach ($file in $files) {
    $srcS = [double](magick "$($file.FullName)" -colorspace HSL -format "%[fx:mean.g*100]" info:)
    $srcL = [double](magick "$($file.FullName)" -colorspace HSL -format "%[fx:mean.b*100]" info:)

    $rawSatMul = if ($srcS -lt 0.01) { $MaxMul } else { $TargetSaturation / $srcS }
    $satMul = [math]::Max($MinMul, [math]::Min($MaxMul, $rawSatMul))
    $rawBriMul = if ($srcL -lt 0.01) { 1.0 } else { $TargetLightness / $srcL }
    $briMul = [math]::Max($BriMin, [math]::Min($BriMax, $rawBriMul))

    $modSat = [int]([math]::Round($satMul * 100))
    $modBri = [int]([math]::Round($briMul * 100))

    # When saturation is being boosted hard (>1.3x), blur LAB a/b channels first.
    # Otherwise a 2x+ modulate amplifies invisible JPEG chroma noise into very visible
    # purple/cyan blobs in low-color regions (overcast skies, white walls). Blur radius
    # scales with SatMul so normal photos are barely touched. Only chroma is blurred —
    # the L channel (where edges and detail live) is untouched.
    $chromaBlur = if ($satMul -gt 1.3) { "0x{0:F1}" -f ($satMul * 2.5) } else { $null }

    if (-not $DryRun) {
        $magickArgs = @("$($file.FullName)")
        if ($chromaBlur) {
            $magickArgs += @("-colorspace", "LAB", "-channel", "GB", "-blur", $chromaBlur, "+channel", "-colorspace", "sRGB")
        }
        $magickArgs += @(
            "-auto-level",
            "-modulate", "$modBri,$modSat,100",
            "-colorspace", "sRGB",
            "-quality", "$Quality",
            "$($file.FullName)"
        )
        & magick @magickArgs
        $outS = [math]::Round([double](magick "$($file.FullName)" -colorspace HSL -format "%[fx:mean.g*100]" info:), 1)
        $outL = [math]::Round([double](magick "$($file.FullName)" -colorspace HSL -format "%[fx:mean.b*100]" info:), 1)
    } else {
        $outS = "(dry)"; $outL = "(dry)"
    }

    $rows += [PSCustomObject]@{
        File   = $file.Name
        SrcS   = [math]::Round($srcS, 1)
        SrcL   = [math]::Round($srcL, 1)
        SatMul = [math]::Round($satMul, 2)
        BriMul = [math]::Round($briMul, 2)
        OutS   = $outS
        OutL   = $outL
    }
}

$rows | Format-Table -AutoSize
if ($DryRun) { Write-Host "Dry run -- no files modified." -ForegroundColor Yellow }
