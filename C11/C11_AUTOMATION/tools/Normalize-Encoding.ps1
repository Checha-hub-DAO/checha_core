[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Root,
  [string]$Pattern = "*.md",
  [switch]$Recurse,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Encoders
$encUtf8Bom    = New-Object System.Text.UTF8Encoding($true)          # target: UTF-8 with BOM
$encUtf8Strict = New-Object System.Text.UTF8Encoding($false, $true)  # throw on invalid
$encUtf8Loose  = New-Object System.Text.UTF8Encoding($false, $false) # no-throw
$encCp1251     = [System.Text.Encoding]::GetEncoding(1251)

function Get-CyrRatio([string]$s) {
  if (-not $s) { return 0.0 }
  $len = $s.Length
  if ($len -le 0) { return 0.0 }
  $c = [regex]::Matches($s, '\p{IsCyrillic}').Count
  [math]::Round($c / [double]$len, 6)
}

function Try-DecodeUtf8Strict([byte[]]$bytes, [ref]$textOut) {
  try { $textOut.Value = $encUtf8Strict.GetString($bytes); return $true }
  catch { $textOut.Value = $encUtf8Loose.GetString($bytes); return $false }
}

function Repair-Mojibake([string]$utf8Text) {
  # Interpret current Unicode string as if it were CP1251 bytes, then decode as UTF-8
  [Text.Encoding]::UTF8.GetString($encCp1251.GetBytes($utf8Text))
}

$files = Get-ChildItem -Path $Root -Filter $Pattern -File -Recurse:$Recurse

$normalized = 0; $skippedOk = 0; $englishLikely = 0; $errors = 0

foreach ($f in $files) {
  try {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)

    # Base read: strict/loose UTF-8
    $textRef = '' | ForEach-Object { New-Object psobject -Property @{ Value = $_ } }
    $isStrict = Try-DecodeUtf8Strict $bytes ([ref]$textRef.Value)
    $curText  = [string]$textRef.Value
    $baseScore = Get-CyrRatio $curText

    # Candidates
    $candRepaired = Repair-Mojibake $curText
    $candDefault  = Get-Content -Raw -Encoding Default $f.FullName

    $scoreRep = Get-CyrRatio $candRepaired
    $scoreDef = Get-CyrRatio $candDefault
    $maxScore = [math]::Max($baseScore, [math]::Max($scoreRep, $scoreDef))

    # Clearly non-Cyrillic? skip
    if ($maxScore -lt 0.01) { $englishLikely++; continue }

    $bestText = $curText; $bestScore = $baseScore; $bestTag = 'base'
    if ($scoreRep -gt $bestScore) { $bestText = $candRepaired; $bestScore = $scoreRep; $bestTag = 'repaired' }
    if ($scoreDef -gt $bestScore) { $bestText = $candDefault;  $bestScore = $scoreDef; $bestTag = 'default'  }

    $shouldWrite = (-not $isStrict) -or (($bestScore - $baseScore) -ge 0.01)

    if ($shouldWrite) {
      if ($DryRun) {
        Write-Host "Would normalize ($bestTag) -> UTF-8 BOM: $($f.FullName)"
      } else {
        [IO.File]::WriteAllText($f.FullName, $bestText, $encUtf8Bom)
        Write-Host "Normalized ($bestTag) -> UTF-8 BOM: $($f.FullName)"
      }
      $normalized++
    } else {
      $skippedOk++
    }
  }
  catch {
    $errors++
    Write-Warning "Error: $($f.FullName) :: $($_.Exception.Message)"
  }
}

Write-Host ""
Write-Host ("SUMMARY: normalized={0}; skippedOk={1}; englishLikely={2}; errors={3}" -f `
  $normalized, $skippedOk, $englishLikely, $errors)