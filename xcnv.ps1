<#
  xcnv / xconvert — quick media converter for Windows
  Usage:  xcnv input.ext [-c WxH] output.ext

  Requires ffmpeg and ImageMagick (magick) in PATH.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$XCNV_VERSION = "1.0.0"
$script:Quiet = $false

function Show-Help {
    @"
xcnv $XCNV_VERSION — quick media converter (ffmpeg + ImageMagick)

Usage:
  xcnv <input> [-c WxH] <output>

Options:
  -c W x H      resize to WxH pixels (e.g. -c 255x255)
                without -c, the original resolution is kept
  -q, --quiet   no status messages, only errors
  -h, --help    show this help
  -V, --version show version

Examples:
  xcnv photo.png photo.jpg
  xcnv photo.png -c 255x255 photo.ico
  xcnv wallpaper.jpg -c 1280x720 wallpaper.webp
  xcnv clip.mp4 -c 640x360 clip.webm
  xcnv song.mp3 song.ogg
  xcnv anim.gif -c 480x480 anim.mp4
"@
}

function Fail([string]$msg, [int]$code = 1) {
    [Console]::Error.WriteLine("Error: $msg")
    exit $code
}

function Has-Exe([string]$name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Say($m) {
    if (-not $script:Quiet) { Write-Output $m }
}

function Warn([string]$m) {
    [Console]::Error.WriteLine("Warning: $m")
}

# ---- argument parsing -----------------------------------------------------
if (-not $Rest -or $Rest.Count -lt 1) { Show-Help; exit 2 }

$positional = @()
foreach ($a in $Rest) {
    if ($a -in @('-h', '--help'))      { Show-Help; exit 0 }
    elseif ($a -in @('-V', '--version')) { Write-Output "xcnv $XCNV_VERSION"; exit 0 }
    elseif ($a -in @('-q', '--quiet')) { $script:Quiet = $true }
    else                               { $positional += $a }
}

if ($positional.Count -lt 2) { Show-Help; exit 2 }

$Input_ = $positional[0]
$i = 1
$Width = 0; $Height = 0
if ($positional[$i] -eq '-c') {
    if ($positional.Count -lt 4) { Fail "-c needs a size (e.g. -c 255x255) and an output file" 2 }
    $res = $positional[$i + 1]; $i += 2
    if ($res -match '^([0-9]+)[xX]([0-9]+)$') {
        $Width = [int]$Matches[1]; $Height = [int]$Matches[2]
    } else {
        Fail "invalid size '$res' - use WIDTHxHEIGHT, e.g. 255x255" 2
    }
}
$Output = $positional[$i]

if (-not (Test-Path -LiteralPath $Input_)) { Fail "input file not found: $Input_" }

$InExt  = [IO.Path]::GetExtension($Input_).TrimStart('.').ToLowerInvariant()
$OutExt = [IO.Path]::GetExtension($Output).TrimStart('.').ToLowerInvariant()

$IMG = @('png','jpg','jpeg','jpe','jfif','webp','gif','bmp','tiff','tif','ico','heic','heif','avif','ppm','pgm','pbm','tga','svg','eps')
$VID = @('mp4','mkv','webm','avi','mov','wmv','flv','m4v','mpg','mpeg','ts','3gp','ogv')
$AUD = @('mp3','m4a','aac','wav','flac','ogg','oga','opus','wma','ac3','aiff')

# ---- helpers --------------------------------------------------------------
function Get-Dim([string]$f) {
    if (Has-Exe magick) {
        try {
            $d = & magick identify -format '%wx%h' "$f[0]" 2>$null | Select-Object -First 1
            if ($d) { return [string]$d }
        } catch { }
    }
    if (Has-Exe ffprobe) {
        try {
            $d = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x $f 2>$null | Select-Object -First 1
            if ($d) { return [string]$d }
        } catch { }
    }
    return '-'
}

# available ffmpeg encoders — never force a missing one
$script:EncList = ''
if (Has-Exe ffmpeg) {
    try { $script:EncList = (& ffmpeg -hide_banner -encoders 2>$null) -join "`n" } catch { }
}
function Has-Enc([string]$n) {
    return [bool]($script:EncList -match "(?m)^\s*\S*\s+$([regex]::Escape($n))\s")
}
function Pick-Enc([string[]]$candidates) {
    foreach ($e in $candidates) { if (Has-Enc $e) { return $e } }
    return ''
}

$H264 = Pick-Enc @('libx264','libopenh264')
$VP9  = Pick-Enc @('libvpx-vp9')
$AAC  = Pick-Enc @('aac')
$OPUS = Pick-Enc @('libopus','opus')

function Get-EncArgs([string]$ext) {
    $a = @()
    switch ($ext) {
        'mp4' {  }
        'm4v' {  }
        'mov' {  }
    }
    switch -regex ($ext) {
        '^(mp4|m4v|mov)$' {
            if ($H264) { $a += @('-c:v', $H264, '-crf', '23') }
            if ($AAC)  { $a += @('-c:a', $AAC) }
            $a += @('-movflags', '+faststart', '-pix_fmt', 'yuv420p')
        }
        '^mkv$' {
            if ($H264) { $a += @('-c:v', $H264, '-crf', '23') }
            if ($AAC)  { $a += @('-c:a', $AAC) }
        }
        '^webm$' {
            if ($VP9)  { $a += @('-c:v', $VP9, '-crf', '32', '-b:v', '0') }
            if ($OPUS) { $a += @('-c:a', $OPUS) }
            $a += @('-pix_fmt', 'yuv420p')
        }
        '^avi$' {
            if ($H264) { $a += @('-c:v', $H264, '-crf', '23') }
        }
    }
    return ,$a
}

$VF = @()
if ($Width) {
    $ScaleFilter = "scale=${Width}:${Height}:force_original_aspect_ratio=decrease,pad=${Width}:${Height}:(ow-iw)/2:(oh-ih)/2"
    $VF = @('-vf', $ScaleFilter)
}

$InIsGif = ($InExt -eq 'gif')

# ---- image -> image -------------------------------------------------------
if (($IMG -contains $InExt) -and ($IMG -contains $OutExt) -and -not $InIsGif) {
    if (-not (Has-Exe magick)) { Fail "ImageMagick not found (install it and add 'magick' to PATH)" }
    if ($OutExt -eq 'ico') {
        $sw = if ($Width)  { $Width }  else { 256 }
        $sh = if ($Height) { $Height } else { 256 }
        $s = [Math]::Max($sw, $sh)
        if ($s -gt 256) {
            $s = 256
            Warn "ICO supports at most 256x256 - using ${s}x${s} (you asked ${sw}x${sh})"
        } elseif ($sw -ne $sh) {
            Warn "ICO icons are square - using ${s}x${s} (you asked ${sw}x${sh})"
        }
        $sw = $s; $sh = $s
        & magick "$Input_[0]" -background none -resize "${sw}x${sh}!" -define "icon:auto-resize=$sw" -strip $Output
        Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output (${sw}x${sh} ICO)"
        exit 0
    }
    if ($Width) {
        & magick "$Input_[0]" -resize "${Width}x${Height}!" -strip $Output
        Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output (${Width}x${Height})"
    } else {
        & magick "$Input_[0]" -strip $Output
        Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output"
    }
    exit 0
}

# ---- gif -> image (first frame) ------------------------------------------
if ($InIsGif -and ($IMG -contains $OutExt) -and $OutExt -ne 'gif') {
    if (-not (Has-Exe magick)) { Fail "ImageMagick not found" }
    if ($Width) { & magick "$Input_[0]" -resize "${Width}x${Height}!" -strip $Output }
    else        { & magick "$Input_[0]" -strip $Output }
    Say "OK: $Input_ (gif, $(Get-Dim $Input_)) -> $Output (first frame)"
    exit 0
}

if (-not (Has-Exe ffmpeg)) { Fail "ffmpeg not found (install it and add it to PATH)" }

# ---- gif -> video --------------------------------------------------------
if ($InIsGif -and ($VID -contains $OutExt)) {
    $enc = Get-EncArgs $OutExt
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ @VF @enc $Output
    if ($LASTEXITCODE -ne 0) { Fail "conversion failed ($Input_ -> $Output)" }
    Say "OK: $Input_ (gif) -> $Output"
    exit 0
}

# ---- video -> gif --------------------------------------------------------
if ($OutExt -eq 'gif') {
    $sc  = if ($Width) { $Width } else { 480 }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("xcnv_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $pal = Join-Path $tmp 'pal.png'
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ -vf "fps=12,scale=${sc}:-1:flags=lanczos,palettegen" $pal
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ -i $pal -filter_complex "fps=12,scale=${sc}:-1:flags=lanczos[x];[x][1:v]paletteuse" $Output
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { Fail "conversion failed ($Input_ -> $Output)" }
    Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output (gif)"
    exit 0
}

# ---- video -> still image ------------------------------------------------
if (@('png','jpg','jpeg','webp','bmp','tiff','tif') -contains $OutExt) {
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ @VF -frames:v 1 $Output
    if ($LASTEXITCODE -ne 0) { Fail "conversion failed ($Input_ -> $Output)" }
    Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output"
    exit 0
}

# ---- audio out -----------------------------------------------------------
if ($AUD -contains $OutExt) {
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ -vn $Output
    if ($LASTEXITCODE -ne 0) { Fail "conversion failed ($Input_ -> $Output)" }
    Say "OK: $Input_ -> $Output (audio)"
    exit 0
}

# ---- everything else: known container or copy-then-default ---------------
$enc = Get-EncArgs $OutExt
if ($enc.Count -gt 0) {
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ @VF @enc $Output
} else {
    & ffmpeg -hide_banner -loglevel error -y -i $Input_ @VF -c copy $Output 2>$null
    if ($LASTEXITCODE -ne 0) { & ffmpeg -hide_banner -loglevel error -y -i $Input_ @VF $Output }
}
if ($LASTEXITCODE -ne 0) { Fail "conversion failed ($Input_ -> $Output)" }

if ($Width) { Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output (${Width}x${Height})" }
else        { Say "OK: $Input_ ($(Get-Dim $Input_)) -> $Output" }
exit 0
