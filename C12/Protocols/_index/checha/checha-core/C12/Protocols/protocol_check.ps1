\
    param(
      [Parameter(Mandatory=$true)][string]$Query,
      [string]$IndexPath = "C:\CHECHA_CORE\C12\Protocols\_index\protocols_index.json"
    )

    if (!(Test-Path $IndexPath)) { Write-Error "Index not found: $IndexPath"; exit 1 }

    $json = Get-Content $IndexPath -Raw | ConvertFrom-Json
    $items = $json.protocols

    $byId = $items | Where-Object { $_.id -ieq $Query }
    if ($byId) {
      $p = $byId
    } else {
      $q = $Query.ToLower()
      $p = $items | Where-Object {
        $_.topic.ToLower().Contains($q) -or
        ($_.tags -join ",").ToLower().Contains($q)
      }
    }

    if (-not $p) { Write-Output "РќС–С‡РѕРіРѕ РЅРµ Р·РЅР°Р№РґРµРЅРѕ РїРѕ Р·Р°РїРёС‚Сѓ: $Query"; exit 0 }

    $p | Sort-Object updated_at -Descending | ForEach-Object {
      Write-Output ("[{0}] {1} вЂ” СЃС‚Р°С‚СѓСЃ: {2} | РѕРЅРѕРІР»РµРЅРѕ: {3} | С„Р°Р№Р»: {4}" -f `
        $_.id, $_.topic, $_.status, $_.updated_at, $_.path)
    }
