# Gera playground/Main.hs: um UNICO arquivo com as tres camadas, na mesma
# ordem dos modulos (Tipos, Classificacao, Leitura, Dados, Main), pronto para
# colar no https://play.haskell.org (que aceita apenas um arquivo).
#
# Uso (na pasta projeto/):   powershell -ExecutionPolicy Bypass -File ferramentas\gerar_playground.ps1
#
# O que o script faz:
#   1. remove o cabecalho "module X (...) where" de cada arquivo;
#   2. remove os imports entre modulos do projeto;
#   3. junta os imports externos, mesclando as listas do mesmo modulo
#      (evita avisos de import redundante com -Wall).

$ErrorActionPreference = 'Stop'
$raiz    = Split-Path -Parent $PSScriptRoot
$ordem   = @('Tipos', 'Classificacao', 'Leitura', 'Dados', 'Main')
$locais  = $ordem
$utf8    = New-Object System.Text.UTF8Encoding($false)

# Divide "a, b (..), c" em itens, respeitando parenteses aninhados.
function Split-Itens([string]$texto) {
    $itens = @(); $nivel = 0; $atual = ''
    foreach ($c in $texto.ToCharArray()) {
        if ($c -eq '(') { $nivel++ } elseif ($c -eq ')') { $nivel-- }
        if ($c -eq ',' -and $nivel -eq 0) { $itens += $atual.Trim(); $atual = '' }
        else { $atual += $c }
    }
    if ($atual.Trim()) { $itens += $atual.Trim() }
    return $itens
}

$imports = [ordered]@{}   # modulo -> lista de itens
$corpos  = @()

foreach ($m in $ordem) {
    $linhas = [System.IO.File]::ReadAllLines((Join-Path $raiz "src\$m.hs"), $utf8)
    $saida  = New-Object System.Collections.Generic.List[string]
    $noCabecalho = $false
    foreach ($l in $linhas) {
        if ($l -match '^module\s') { $noCabecalho = $true }
        if ($noCabecalho) {
            if ($l -match '\bwhere\s*$') { $noCabecalho = $false }
            continue
        }
        if ($l -match '^import\s+(\S+)\s*\((.*)\)\s*$') {
            $mod = $Matches[1]
            if ($locais -contains $mod) { continue }
            if (-not $imports.Contains($mod)) { $imports[$mod] = New-Object System.Collections.Generic.List[string] }
            foreach ($i in (Split-Itens $Matches[2])) { if (-not $imports[$mod].Contains($i)) { $imports[$mod].Add($i) } }
            continue
        }
        if ($l -match '^import\s+(\S+)\s*$') {
            if ($locais -contains $Matches[1]) { continue }
            throw "import sem lista nao suportado: $l"
        }
        $saida.Add($l)
    }
    # remove linhas em branco do inicio
    while ($saida.Count -gt 0 -and $saida[0].Trim() -eq '') { $saida.RemoveAt(0) }
    $corpos += ,(@('', "-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> src/$m.hs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", '') + $saida)
}

$cab = @(
    '-- ============================================================================='
    '-- PjBL2 - Tabela de Classificacao de Campeonato (versao arquivo unico)'
    '-- ============================================================================='
    '-- ARQUIVO GERADO por ferramentas/gerar_playground.ps1 a partir de src/*.hs.'
    '-- Cole este arquivo inteiro em https://play.haskell.org e clique em "Run".'
    '-- As secoes abaixo seguem a ordem dos modulos: Camada 1 (Tipos),'
    '-- Camada 2 (Classificacao), Camada 3 (Leitura), Dados e Main.'
    '-- Os dados ficam no proprio codigo (sem getLine), como pede o enunciado.'
    'module Main where'
    ''
)
$imps = foreach ($k in ($imports.Keys | Sort-Object)) { "import $k ($((($imports[$k]) | Sort-Object) -join ', '))" }

$tudo = $cab + $imps + @('') + ($corpos | ForEach-Object { $_ })
$destino = Join-Path $raiz 'playground\Main.hs'
New-Item -ItemType Directory -Force (Split-Path $destino) | Out-Null
[System.IO.File]::WriteAllText($destino, (($tudo -join "`n") + "`n"), $utf8)
Write-Host "Gerado: $destino"
