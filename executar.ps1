# Compila (com -Wall) e executa a demonstracao das tres camadas.
# Uso:  .\executar.ps1                       (dados embutidos em src/Dados.hs)
#       .\executar.ps1 exemplos\com_erros.txt (le as partidas de um arquivo)
param([string]$Arquivo)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (Test-Path 'C:\ghcup\bin') { $env:PATH = "C:\ghcup\bin;$env:PATH" }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force build | Out-Null
ghc -Wall -isrc -outputdir build/obj -o build/campeonato src/Main.hs
if ($LASTEXITCODE -ne 0) { Write-Host 'Falha na compilacao.'; exit 1 }

Write-Host ''
$argumentos = @(); if ($Arquivo) { $argumentos = @($Arquivo) }
try {
    & .\build\campeonato.exe @argumentos
} catch {
    # Alguns Windows (Smart App Control) bloqueiam .exe recem-compilados.
    Write-Host "Executavel bloqueado pelo Windows; rodando com runghc..."
    runghc -isrc src/Main.hs @argumentos
}
