param(
  [string]$OutFile = "codecompanion.txt"
)

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$uri = 'https://github.com/olimorris/codecompanion.nvim/raw/refs/heads/main/doc/codecompanion.txt'

try {
  # Create directory if user passed a path
  $outPath = [System.IO.Path]::GetFullPath($OutFile)
  $outDir = [System.IO.Path]::GetDirectoryName($outPath)
  if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }

  # Prefer Invoke-WebRequest for PS7, fallback to .NET HttpClient
  if (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue) {
    Invoke-WebRequest -Uri $uri -OutFile $outPath -UseBasicParsing -TimeoutSec 60
  } else {
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(60)
    $bytes = $client.GetByteArrayAsync($uri).GetAwaiter().GetResult()
    [System.IO.File]::WriteAllBytes($outPath, $bytes)
  }
  Write-Host "Downloaded to $outPath"
} catch {
  Write-Error $_
  exit 1
}
