param(
  [string]$SrcDir = ".\c02_pack\C02_symbol_pack_v1.0",
  [int]$Size = 800,
  [int]$Fps = 24,
  [switch]$Overwrite,
  [string]$Tag = "symbols-2025-08-31_1200"
)

function Resolve-ffmpeg {
  $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Path }

  $py = Get-Command python -ErrorAction SilentlyContinue
  if ($py) {
    try {
      $ffexe = & python -c "import imageio_ffmpeg as i; print(i.get_ffmpeg_exe() or '')"
      if ($LASTEXITCODE -eq 0 -and $ffexe -and (Test-Path $ffexe)) { return $ffexe }
    } catch { }
  }

  $candidates = @(
    "C:\Program Files\FFmpeg\bin\ffmpeg.exe",
    "C:\ffmpeg\bin\ffmpeg.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

  return $null
}

$ffmpeg = Resolve-ffmpeg
if (-not $ffmpeg) {
  Write-Warning "ffmpeg не знайдено. Встанови: winget install -e --id FFmpeg.FFmpeg (або інший спосіб)."
  throw "ffmpeg not found"
}

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
  $vf = "scale=$($Size):-2:flags=lanczos,fps=$($Fps)"
  $args = @(
    "-y","-i", $g.FullName,
    "-movflags","+faststart",
    "-pix_fmt","yuv420p",
    "-vf", $vf,
    $out
  )
  & "$ffmpeg" $args 2>$null | Out-Null
}

# (опційно) залити MP4 у реліз — розкоментуй нижче
# if (Get-Command gh -ErrorAction SilentlyContinue) {
#   $mp4s = Get-ChildItem -Path $SrcDir -Filter *.mp4 -Recurse
#   if ($mp4s) {
#     Write-Host "☁️  Upload MP4s to release $Tag"
#     foreach ($m in $mp4s) { gh release upload $Tag $m.FullName --clobber }
#   }
# }
