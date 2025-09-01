$ErrorActionPreference = "Stop"
# локальні кроки (реіндекс/валідація/таблиця/звіт)
& "C:\CHECHA_CORE\C12\Protocols\_index\Run-Daily.ps1"

# бекап у MinIO через alias (без Endpoint)
& "C:\CHECHA_CORE\C12\Protocols\_index\Backup-To-MinIO.ps1" `
  -BucketPath "checha-core/C12/Protocols" `
  -Alias "checha"   # додай -RemoveExtra і/або -Insecure за потреби