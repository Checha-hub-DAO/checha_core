param(
  [string]$SrcDir = ".\c02_pack\C02_symbol_pack_v1.0",
  [int]$Size = 800,
  [int]$Fps = 24,
  [switch]$Overwrite,
  [string]$Tag = "symbols-2025-08-31_1200"
)

function Ensure-ffmpeg {
  if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Warning "ffmpeg не знайдено. Встанови: winget install -e --id FFmpeg.FFmpeg (або Gyan.FFmpeg), потім перезапусти термінал."
    throw "ffmpeg not found"
  }
}

Ensure-ffmpeg

$gifs = Get-ChildItem -Path $SrcDir -Filter *.gif -Recurse
if (-not $gifs) {
  Write-Warning "GIF-файлів не знайдено в $SrcDir"
  exit 0
}

foreach ($g in $gifs) {
  $out = [System.IO.Path]::ChangeExtension($g.FullName, ".mp4")
  if ((-not $Overwrite) -and (Test-Path $out)) {
    Write-Host "⏭️  Skip (exists): $($g.Name)"
    continue
  }
  Write-Host "🎬  Encode MP4: $($g.Name) -> $(Split-Path $out -Leaf)"
  $args = @(
    "-y","-i", $g.FullName,
    "-movflags","+faststart",
    "-pix_fmt","yuv420p",
    "-vf", "scale=$($Size):-2:flags=lanczos,fps=$($Fps)",
    $out
  )
  & ffmpeg $args 2>$null | Out-Null
}

# (опційно) залити MP4 у реліз (розкоментуй рядки нижче)
# if (Get-Command gh -ErrorAction SilentlyContinue) {
#   $mp4s = Get-ChildItem -Path $SrcDir -Filter *.mp4 -Recurse
#   if ($mp4s) {
#     Write-Host "☁️  Upload MP4s to release $Tag"
#     foreach ($m in $mp4s) { gh release upload $Tag $m.FullName --clobber }
#   }
# }

