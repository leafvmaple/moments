<#
.SYNOPSIS
  Curate a folder of travel photos: cluster near-duplicates by time+GPS, score each
  for sharpness/exposure, and emit a preview for human/AI selection.

.DESCRIPTION
  Workflow:
    1. Read EXIF DateTimeOriginal and GPS coords from every *.jpg in -Path.
    2. Sort by time. Open a new cluster whenever the gap exceeds -TimeGapSec
       OR GPS distance exceeds -GpsGapMeters (when both photos have GPS).
    3. Score each photo:
         sharpness  : Laplacian standard deviation (higher = sharper)
         exposure   : 1 - |mean_L - 0.5| * 2   (1.0 = perfectly mid-tone)
         score      : sharpness * exposure_weight
    4. Within each cluster, mark the top-scoring photo as "recommended".
    5. Emit:
         <Out>/clusters.json    machine-readable cluster + scores + GPS
         <Out>/preview.md       human/AI-readable, thumbnails grouped by cluster

  The AI/human reviews preview.md and either accepts the recommendations or
  swaps in another photo from the same cluster based on story/composition,
  which is the part scripts can't judge.

.PARAMETER Path
  Source folder of original photos. Not modified.

.PARAMETER Out
  Output folder for clusters.json and preview.md. Default: <Path>/_curated.

.PARAMETER TimeGapSec
  Open a new cluster when consecutive photos are more than this many seconds apart.
  Default 60 — tight; raises the chance of "same scene, different angles" being
  caught together. Bump to 300+ for slower-paced shooting.

.PARAMETER GpsGapMeters
  Open a new cluster when consecutive photos are this many meters apart (and both
  have GPS). Default 25.

.EXAMPLE
  ./scripts/curate-photos.ps1 -Path photos/extracted-003
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path,
    [string]$Out,
    [int]$TimeGapSec = 60,
    [double]$GpsGapMeters = 25
)

if (-not (Test-Path -PathType Container $Path)) {
    Write-Error "Directory not found: $Path"; exit 1
}
if (-not $Out) { $Out = Join-Path $Path "_curated" }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick not found. winget install ImageMagick.ImageMagick"; exit 1
}

function ConvertDmsToDecimal([string]$dms, [string]$ref) {
    # Examples in EXIF: "34/1, 39/1, 4920/100"  or  "34, 39, 49.2"
    if (-not $dms) { return $null }
    $parts = $dms -split '[,;]' | ForEach-Object { $_.Trim() }
    $vals = foreach ($p in $parts) {
        if ($p -match '^(-?[\d\.]+)/(-?[\d\.]+)$') { [double]$matches[1] / [double]$matches[2] }
        else { [double]$p }
    }
    if ($vals.Count -lt 3) { return $null }
    $dec = $vals[0] + $vals[1]/60 + $vals[2]/3600
    if ($ref -eq 'S' -or $ref -eq 'W') { $dec = -$dec }
    return [math]::Round($dec, 6)
}

function HaversineMeters([double]$lat1, [double]$lon1, [double]$lat2, [double]$lon2) {
    $R = 6371000.0
    $toRad = [math]::PI / 180
    $dLat = ($lat2 - $lat1) * $toRad
    $dLon = ($lon2 - $lon1) * $toRad
    $a = [math]::Sin($dLat/2) * [math]::Sin($dLat/2) +
         [math]::Cos($lat1*$toRad) * [math]::Cos($lat2*$toRad) *
         [math]::Sin($dLon/2) * [math]::Sin($dLon/2)
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a))
    return [math]::Round($R * $c, 1)
}

$files = Get-ChildItem -Path $Path -Filter *.jpg -File
if ($files.Count -eq 0) { Write-Warning "No .jpg in $Path"; exit 0 }

Write-Host "Reading EXIF + scoring $($files.Count) photos..." -ForegroundColor Cyan
$photos = foreach ($f in $files) {
    $fmt = "%[EXIF:DateTimeOriginal]|%[EXIF:GPSLatitude]|%[EXIF:GPSLatitudeRef]|%[EXIF:GPSLongitude]|%[EXIF:GPSLongitudeRef]"
    $raw = magick identify -format $fmt "$($f.FullName)" 2>$null
    $parts = $raw -split '\|'
    $dt = $null
    if ($parts[0] -match '^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$') {
        $dt = [datetime]::new([int]$matches[1],[int]$matches[2],[int]$matches[3],[int]$matches[4],[int]$matches[5],[int]$matches[6])
    }
    # Fallback: parse filename like "IMG_YYYYMMDD_HHMMSS_xxx.jpg" — used when EXIF was
    # stripped (e.g. MIUI's share/edit-and-save flow appends a Unix-ms suffix and drops EXIF).
    if (-not $dt -and $f.Name -match '_(\d{8})_(\d{6})_') {
        $d = $matches[1]; $t = $matches[2]
        $dt = [datetime]::new(
            [int]$d.Substring(0,4),[int]$d.Substring(4,2),[int]$d.Substring(6,2),
            [int]$t.Substring(0,2),[int]$t.Substring(2,2),[int]$t.Substring(4,2))
    }
    if (-not $dt) {
        Write-Warning "No timestamp for $($f.Name) — skipping"
        continue
    }
    $lat = ConvertDmsToDecimal $parts[1] $parts[2]
    $lon = ConvertDmsToDecimal $parts[3] $parts[4]

    # Sharpness: stdev of Laplacian on a downscaled gray image (fast + robust).
    $sharp = [double](magick "$($f.FullName)" -resize 800x800 -colorspace Gray `
        -define convolve:scale='!' -morphology Convolve Laplacian:0 `
        -format "%[fx:standard_deviation*1000]" info:)
    # Exposure: how close mean lightness is to mid-tone (1.0 = ideal).
    $meanL = [double](magick "$($f.FullName)" -resize 200x200 -colorspace HSL -format "%[fx:mean.b]" info:)
    $expoScore = [math]::Round(1 - [math]::Abs($meanL - 0.5) * 2, 3)
    $sharpScore = [math]::Round($sharp, 1)
    $score = [math]::Round($sharpScore * [math]::Max(0.3, $expoScore), 1)

    Write-Host "  $($f.Name)  t=$($dt.ToString('HH:mm:ss'))  sharp=$sharpScore  expo=$expoScore  score=$score"

    [PSCustomObject]@{
        File = $f.Name
        Path = $f.FullName
        Time = $dt
        Lat  = $lat
        Lon  = $lon
        Sharpness = $sharpScore
        Exposure  = $expoScore
        Score     = $score
    }
}

# Sort by time, then cluster.
$photos = $photos | Sort-Object Time
$clusters = @()
$current = @()
$prev = $null
foreach ($p in $photos) {
    $openNew = $false
    if ($prev) {
        $dt = ($p.Time - $prev.Time).TotalSeconds
        $openNew = ($dt -gt $TimeGapSec)
        if (-not $openNew -and $p.Lat -and $prev.Lat) {
            $dist = HaversineMeters $prev.Lat $prev.Lon $p.Lat $p.Lon
            if ($dist -gt $GpsGapMeters) { $openNew = $true }
        }
    }
    if ($openNew -and $current.Count -gt 0) {
        $clusters += ,@($current)
        $current = @()
    }
    $current += $p
    $prev = $p
}
if ($current.Count -gt 0) { $clusters += ,@($current) }

Write-Host "`nClustered $($photos.Count) photos into $($clusters.Count) clusters." -ForegroundColor Green

# Build output
$jsonClusters = @()
$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# Curate preview — $($photos.Count) photos → $($clusters.Count) clusters")
$mdLines.Add("")
$mdLines.Add("Recommended photo per cluster marked with **(★)**. Review and override based on story/composition.")
$mdLines.Add("")

for ($i = 0; $i -lt $clusters.Count; $i++) {
    $c = $clusters[$i]
    $sorted = $c | Sort-Object Score -Descending
    $rec = $sorted[0]
    $tStart = $c[0].Time.ToString("HH:mm:ss")
    $tEnd = $c[-1].Time.ToString("HH:mm:ss")
    $date = $c[0].Time.ToString("yyyy-MM-dd")
    $gpsTag = if ($c[0].Lat) { "$($c[0].Lat),$($c[0].Lon)" } else { "no-gps" }

    $jsonClusters += [PSCustomObject]@{
        index = $i
        date  = $date
        timeRange = "$tStart-$tEnd"
        gps = $gpsTag
        recommended = $rec.File
        photos = $c | ForEach-Object {
            [PSCustomObject]@{
                file = $_.File
                time = $_.Time.ToString("HH:mm:ss")
                lat = $_.Lat
                lon = $_.Lon
                sharpness = $_.Sharpness
                exposure  = $_.Exposure
                score = $_.Score
                recommended = ($_.File -eq $rec.File)
            }
        }
    }

    $mdLines.Add("## Cluster $i — $date $tStart→$tEnd  ($($c.Count) photos, gps: $gpsTag)")
    $mdLines.Add("")
    foreach ($p in $c) {
        $star = if ($p.File -eq $rec.File) { " **(★)**" } else { "" }
        # Manual relative path from $Out to the photo (PowerShell 5.1 has no -RelativeBasePath).
        $outFull = (Resolve-Path $Out).Path
        $photoFull = (Resolve-Path $p.Path).Path
        $outParts = $outFull -split '[\\/]'
        $photoParts = $photoFull -split '[\\/]'
        $common = 0
        while ($common -lt $outParts.Count -and $common -lt $photoParts.Count -and $outParts[$common] -ieq $photoParts[$common]) { $common++ }
        $relParts = @()
        # NOTE: must NOT shadow the outer cluster-loop's $i — use $k.
        for ($k = 0; $k -lt ($outParts.Count - $common); $k++) { $relParts += '..' }
        for ($k = $common; $k -lt $photoParts.Count; $k++) { $relParts += $photoParts[$k] }
        $rel = $relParts -join '/'
        $mdLines.Add("![$($p.File)]($rel)")
        $mdLines.Add("")
        $mdLines.Add("- $($p.File) @ $($p.Time.ToString('HH:mm:ss')) — sharp=$($p.Sharpness) expo=$($p.Exposure) score=$($p.Score)$star")
        $mdLines.Add("")
    }
    $mdLines.Add("")
}

# PowerShell 5.1's -Encoding utf8 emits BOM + does double-encoding on GBK consoles for
# non-ASCII chars. Use .NET directly for clean UTF-8 (no BOM).
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $Out "clusters.json"), ($jsonClusters | ConvertTo-Json -Depth 6), $utf8)
[System.IO.File]::WriteAllText((Join-Path $Out "preview.md"), ($mdLines -join "`n"), $utf8)

Write-Host "Wrote:" -ForegroundColor Green
Write-Host "  $(Join-Path $Out 'clusters.json')"
Write-Host "  $(Join-Path $Out 'preview.md')"
