# Validacao automatica do projeto contra os requisitos do enunciado PjBL2.
# Uso (na pasta projeto/):
#   powershell -ExecutionPolicy Bypass -File validacao\validar_requisitos.ps1
#
# Verifica: estrutura de entrega, assinaturas obrigatorias, regras de estilo
# (sem recursao explicita na Camada 2, sem funcoes parciais, sem read/getLine),
# uso exigido de map/filter/dobra/(.)/sortBy/comparing/Down/<>/readMaybe/
# traverse/do/Maybe, compilacao com -Wall -Werror, testes e saida do main.

$ErrorActionPreference = 'Continue'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz
if (Test-Path 'C:\ghcup\bin') { $env:PATH = "C:\ghcup\bin;$env:PATH" }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$utf8 = New-Object System.Text.UTF8Encoding($false)

$script:ok = 0; $script:falhas = 0
function Check([string]$nome, [bool]$cond, [string]$detalhe = '') {
    if ($cond) { $script:ok++; Write-Host ("[OK]     " + $nome) }
    else { $script:falhas++; Write-Host ("[FALHOU] " + $nome + $(if ($detalhe) { " -> $detalhe" })) -ForegroundColor Red }
}
function Secao([string]$t) { Write-Host "`n== $t ==" -ForegroundColor Cyan }

# Le um .hs sem comentarios de linha (--) e sem blocos {- -}, sem strings.
function Get-Codigo([string]$arq) {
    $txt = [IO.File]::ReadAllText((Join-Path $raiz $arq), $utf8)
    $txt = [regex]::Replace($txt, '(?s)\{-.*?-\}', '')
    # linha a linha: primeiro esvazia strings, depois corta comentarios "--"
    $linhas = $txt -split "`n" | ForEach-Object {
        $l = [regex]::Replace($_, '"(?:\\.|[^"\\])*"', '""')
        [regex]::Replace($l, '--.*$', '')
    }
    return ($linhas -join "`n")
}

# ---------------------------------------------------------------------------
Secao 'Estrutura de entrega (Secao 6)'
foreach ($f in 'src/Tipos.hs','src/Classificacao.hs','src/Leitura.hs','src/Dados.hs','src/Main.hs',
               'tests/Testes.hs','docs/decisoes.md','README.md') {
    Check "existe $f" (Test-Path (Join-Path $raiz $f))
}

$tipos = Get-Codigo 'src/Tipos.hs'
$clas  = Get-Codigo 'src/Classificacao.hs'
$leit  = Get-Codigo 'src/Leitura.hs'
$main  = Get-Codigo 'src/Main.hs'
$todos = $tipos + "`n" + $clas + "`n" + $leit + "`n" + (Get-Codigo 'src/Dados.hs') + "`n" + $main

# ---------------------------------------------------------------------------
Secao 'Camada 1 - tipos e funcoes obrigatorias'
Check 'type Time = String'                    ($tipos -match '(?m)^type Time\s*=\s*String')
Check 'data Resultado = Vitoria | Empate | Derrota' ($tipos -match 'data Resultado\s*=\s*Vitoria\s*\|\s*Empate\s*\|\s*Derrota')
Check 'data Partida e record (rodada, mandante, golsMandante, golsVisitante, visitante)' `
      ($tipos -match '(?s)data Partida = Partida\s*\{\s*rodada.*mandante.*golsMandante.*golsVisitante.*visitante')
Check 'data Linha e record (time, jogos, vitorias, empates, derrotas, golsPro, golsContra)' `
      ($tipos -match '(?s)data Linha = Linha\s*\{\s*time.*jogos.*vitorias.*empates.*derrotas.*golsPro.*golsContra')
Check 'participou :: Time -> Partida -> Bool'         ($tipos -match 'participou\s*::\s*Time\s*->\s*Partida\s*->\s*Bool')
Check 'resultadoPara :: Time -> Partida -> Maybe Resultado' ($tipos -match 'resultadoPara\s*::\s*Time\s*->\s*Partida\s*->\s*Maybe Resultado')
Check 'times :: [Partida] -> [Time]'                  ($tipos -match 'times\s*::\s*\[Partida\]\s*->\s*\[Time\]')

# ---------------------------------------------------------------------------
Secao 'Camada 2 - funcoes obrigatorias'
$sigs2 = @{
  'pontos'         = 'pontos\s*::\s*Resultado\s*->\s*Int'
  'linhaDoTime'    = 'linhaDoTime\s*::\s*\[Partida\]\s*->\s*Time\s*->\s*Linha'
  'pontosLinha'    = 'pontosLinha\s*::\s*Linha\s*->\s*Int'
  'saldo'          = 'saldo\s*::\s*Linha\s*->\s*Int'
  'aproveitamento' = 'aproveitamento\s*::\s*Linha\s*->\s*Double'
  'classificacao'  = 'classificacao\s*::\s*\[Partida\]\s*->\s*\[Linha\]'
  'ateRodada'      = 'ateRodada\s*::\s*Int\s*->\s*\[Partida\]\s*->\s*\[Partida\]'
  'maiorGoleada'   = 'maiorGoleada\s*::\s*\[Partida\]\s*->\s*Maybe Partida'
  'mediaGols'      = 'mediaGols\s*::\s*\[Partida\]\s*->\s*Maybe Double'
}
foreach ($k in $sigs2.Keys | Sort-Object) { Check "assinatura $k" ($clas -match $sigs2[$k]) }
Check 'usa map'                      ($clas -match '\bmap\b')
Check 'usa filter'                   ($clas -match '\bfilter\b')
Check 'usa dobra (foldl/foldr)'      ($clas -match '\bfold[lr]\b')
Check 'linhaDoTime acumula com dobra' ($clas -match 'linhaDoTime ps t\s*=\s*fold[lr]')
Check 'usa composicao (.)'           ($clas -match '\w\s+\.\s+\w|\(\w+\s*\.\s*\w+')
Check 'ordena com sortBy/sortOn'     ($clas -match '\bsort(By|On)\b')
Check 'usa comparing'                ($clas -match '\bcomparing\b')
Check 'usa Down'                     ($clas -match '\bDown\b')
Check 'combina criterios com <>'     ($clas -match 'comparing[^\n]*\n\s*<>\s*comparing')
Check 'aproveitamento usa fromIntegral (sem div)' (($clas -match 'fromIntegral') -and -not ($clas -match '(?s)aproveitamento l\s*\|.*?\bdiv\b.*?criterios'))

# Recursao explicita: uma funcao de topo cujo corpo menciona o proprio nome.
$recursivas = @()
$blocos = [regex]::Split($clas, '(?m)^(?=[a-z]\w*\s*::)')
foreach ($b in $blocos) {
    if ($b -match '^([a-z]\w*)\s*::') {
        $nome = $Matches[1]
        $corpo = ($b -split "`n" | Where-Object { $_ -notmatch "^$nome\s*::" }) -join "`n"
        $rhs = [regex]::Replace($corpo, "(?m)^$nome\b[^=|]*", '')   # remove o lado esquerdo das equacoes
        if ($rhs -cmatch "\b$nome\b") { $recursivas += $nome }
    }
}
Check 'Camada 2 sem recursao explicita' ($recursivas.Count -eq 0) ("recursivas: " + ($recursivas -join ', '))

# ---------------------------------------------------------------------------
Secao 'Camada 3 - funcoes obrigatorias'
foreach ($c in 'CamposInvalidos','NumeroInvalido','PlacarNegativo','MesmoTime','TimeRepetidoNaRodada') {
    Check "Erro tem construtor $c (com Int de linha/rodada)" ($leit -match "\b$c\s+Int")
}
Check 'separar :: Char -> String -> [String]'                 ($leit -match 'separar\s*::\s*Char\s*->\s*String\s*->\s*\[String\]')
Check 'lerPartida :: Int -> String -> Either Erro Partida'    ($leit -match 'lerPartida\s*::\s*Int\s*->\s*String\s*->\s*Either Erro Partida')
Check 'lerCampeonato :: String -> Either Erro [Partida]'      ($leit -match 'lerCampeonato\s*::\s*String\s*->\s*Either Erro \[Partida\]')
Check 'todosOsErros :: String -> [Erro]'                      ($leit -match 'todosOsErros\s*::\s*String\s*->\s*\[Erro\]')
Check 'tabelaFormatada :: [Linha] -> String'                  ($leit -match 'tabelaFormatada\s*::\s*\[Linha\]\s*->\s*String')
Check 'main :: IO ()'                                         ($main -match '(?m)^main\s*::\s*IO\s*\(\)')
Check 'lerPartida usa do na monada Either'                    ($leit -match '(?m)^lerPartida n linha = do')
Check 'lerCampeonato usa traverse ou mapM'                    ($leit -match '(?s)lerCampeonato txt = do.*?\b(traverse|mapM)\b')
Check 'usa readMaybe (Text.Read)'                             ($leit -match 'import Text\.Read \(readMaybe\)' -and $leit -match '\breadMaybe\b')
Check 'Maybe como functor/monada (<$>, >>= ou maybe)'         ($todos -match '<\$>|>>=|\bmaybe\b')

# ---------------------------------------------------------------------------
Secao 'Regras de robustez e estilo (Secoes 4 e 5)'
$parciais = 'head','tail','init','last','maximum','minimum','foldr1','foldl1','fromJust','maximumBy','minimumBy','!!','error','undefined'
# -cmatch: diferencia maiusculas (senao "Text.Read" casaria com "read")
$achadas = @($parciais | Where-Object { $todos -cmatch ('(?<![\w''])' + [regex]::Escape($_) + '(?![\w''])') })
Check 'nenhuma funcao parcial (head, maximum, foldr1, !!, fromJust...)' ($achadas.Count -eq 0) ($achadas -join ', ')
Check 'nao usa read (so readMaybe)'                    (-not ($todos -cmatch '\bread\b'))
Check 'nao usa getLine/getContents/interact'           (-not ($todos -cmatch '\b(getLine|getContents|interact)\b'))
$sigsIO = [regex]::Matches($todos, '(?m)^(\w+)\s*::[^\n]*\bIO\b') | ForEach-Object { $_.Groups[1].Value }
Check 'main e a unica funcao com IO'                   (($sigsIO -join ',') -eq 'main') ("funcoes com IO: " + ($sigsIO -join ', '))
$imps = [regex]::Matches($todos, '(?m)^import\s+(?:qualified\s+)?([\w.]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$locais = 'Tipos','Classificacao','Leitura','Dados'
$naoBase = $imps | Where-Object { $locais -notcontains $_ -and $_ -notmatch '^(Data|Text|System|Control|GHC)\.' }
Check 'somente modulos do pacote base'                 ($naoBase.Count -eq 0) ($naoBase -join ', ')
Write-Host ("         modulos importados: " + (($imps | Where-Object { $locais -notcontains $_ }) -join ', '))

# ---------------------------------------------------------------------------
Secao 'Compilacao com -Wall -Werror (nenhum aviso)'
New-Item -ItemType Directory -Force build | Out-Null
ghc -Wall -Werror -isrc -outputdir build/val-main -o build/val-campeonato src/Main.hs *> build/val-main.log
Check 'src/Main.hs compila com -Wall -Werror'         ($LASTEXITCODE -eq 0) 'ver build/val-main.log'
ghc -Wall -Werror -isrc -outputdir build/val-testes -o build/val-testes tests/Testes.hs *> build/val-testes.log
Check 'tests/Testes.hs compila com -Wall -Werror'     ($LASTEXITCODE -eq 0) 'ver build/val-testes.log'
if (Test-Path playground/Main.hs) {
    ghc -Wall -Werror -outputdir build/val-play -o build/val-play playground/Main.hs *> build/val-play.log
    Check 'playground/Main.hs (arquivo unico) compila com -Wall -Werror' ($LASTEXITCODE -eq 0) 'ver build/val-play.log'
}

# ---------------------------------------------------------------------------
Secao 'Testes (Secao 7) e saida do main'
$saidaTestes = runghc -isrc tests/Testes.hs 2>&1 | Out-String
$codTestes = $LASTEXITCODE
$resumo = ($saidaTestes -split "`n" | Where-Object { $_ -match '^Resumo' }) -join ''
Check "bateria de testes passa ($($resumo.Trim()))" ($codTestes -eq 0)
foreach ($c in 'resultadoPara mandante','resultadoPara visitante','resultadoPara time que nao jogou','times do campeonato',
               'classificacao completa','desempate: Athletico x Coritiba','classificacao (ateRodada 3) /= final',
               'maiorGoleada [] = Nothing','mediaGols [] = Nothing','lerCampeonato entrada valida -> Right',
               'Erro CamposInvalidos','Erro NumeroInvalido','Erro PlacarNegativo','Erro MesmoTime',
               'Erro TimeRepetidoNaRodada','todosOsErros lista todos') {
    Check "caso obrigatorio presente e OK: $c" ($saidaTestes -match ('OK\s+' + [regex]::Escape($c)))
}

$saidaMain = runghc -isrc src/Main.hs 2>&1 | Out-String
Check 'main termina sem excecao'                    ($LASTEXITCODE -eq 0)
Check 'main mostra a tabela final'                  ($saidaMain -match 'Classificacao final')
Check 'main mostra tabela de rodada intermediaria'  ($saidaMain -match 'Classificacao apos a rodada 3')
Check 'main mostra estatisticas'                    ($saidaMain -match 'Maior goleada' -and $saidaMain -match 'Media de gols')
Check 'main mostra tratamento de entrada com erros' ($saidaMain -match 'todosOsErros')
Check 'ordem: final -> intermediaria -> estatisticas -> erros' `
      ($saidaMain.IndexOf('Classificacao final') -lt $saidaMain.IndexOf('apos a rodada') -and
       $saidaMain.IndexOf('apos a rodada') -lt $saidaMain.IndexOf('Estatisticas') -and
       $saidaMain.IndexOf('Estatisticas') -lt $saidaMain.IndexOf('Entrada com erros'))

# ---------------------------------------------------------------------------
Write-Host "`n========================================"
Write-Host ("Validacao: {0} OK, {1} falha(s)" -f $script:ok, $script:falhas)
Write-Host "========================================"
if ($script:falhas -gt 0) { exit 1 } else { exit 0 }
