# Executa a bateria de testes (tests/Testes.hs). Codigo de saida 0 = tudo OK.
# Usa runghc (interpretado): nao gera .exe, entao funciona mesmo quando o
# Windows bloqueia executaveis recem-compilados.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (Test-Path 'C:\ghcup\bin') { $env:PATH = "C:\ghcup\bin;$env:PATH" }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

runghc -isrc tests/Testes.hs
exit $LASTEXITCODE
