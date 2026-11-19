-- =============================================================================
-- PjBL2 - Tabela de Classificacao de Campeonato (versao arquivo unico)
-- =============================================================================
-- ARQUIVO GERADO por ferramentas/gerar_playground.ps1 a partir de src/*.hs.
-- Cole este arquivo inteiro em https://play.haskell.org e clique em "Run".
-- As secoes abaixo seguem a ordem dos modulos: Camada 1 (Tipos),
-- Camada 2 (Classificacao), Camada 3 (Leitura), Dados e Main.
-- Os dados ficam no proprio codigo (sem getLine), como pede o enunciado.
module Main where

import Control.Exception (evaluate, IOException, try)
import Data.Char (isSpace)
import Data.Either (partitionEithers)
import Data.List (dropWhileEnd, find, inits, intercalate, isPrefixOf, nub, sort, sortBy, sortOn)
import Data.Maybe (fromMaybe, listToMaybe)
import Data.Ord (comparing, Down (..))
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.Environment (getArgs)
import System.IO (hSetEncoding, stdout)
import Text.Read (readMaybe)


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> src/Tipos.hs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- CAMADA 1: Tipos e Dados do Campeonato
-- =============================================================================
-- Modela o dominio com tipos algebricos (records e tipos soma) e define as
-- consultas basicas sobre uma partida. Nenhuma funcao aqui e parcial.


-- | Nome de um time (sinonimo de tipo).
type Time = String

-- | Resultado de uma partida do ponto de vista de um time.
--   Tipo soma fechado: nao existe um "v" minusculo nem um 4o valor.
data Resultado = Vitoria | Empate | Derrota
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Uma partida. Record com campos nomeados, para que os gols do mandante
--   nunca sejam confundidos com os do visitante (o que uma tupla de Ints
--   permitiria sem nenhum aviso do compilador).
data Partida = Partida
  { rodada        :: Int
  , mandante      :: Time
  , golsMandante  :: Int
  , golsVisitante :: Int
  , visitante     :: Time
  } deriving (Show, Eq)

-- | Uma linha da tabela de classificacao.
--   Guarda apenas contagens primitivas; pontos e saldo sao DERIVADOS
--   (Camada 2) para que nunca fiquem inconsistentes com V/E/D e GP/GC.
data Linha = Linha
  { time       :: Time
  , jogos      :: Int
  , vitorias   :: Int
  , empates    :: Int
  , derrotas   :: Int
  , golsPro    :: Int
  , golsContra :: Int
  } deriving (Show, Eq)

-- | Linha "zerada" de um time: elemento neutro da dobra da Camada 2.
linhaVazia :: Time -> Linha
linhaVazia t = Linha t 0 0 0 0 0 0

-- | Verdadeiro se o time jogou a partida (como mandante ou visitante).
participou :: Time -> Partida -> Bool
participou t p = t == mandante p || t == visitante p

-- | Gols (pro, contra) do ponto de vista do time; Nothing se nao jogou.
golsPara :: Time -> Partida -> Maybe (Int, Int)
golsPara t p
  | t == mandante p  = Just (golsMandante p, golsVisitante p)
  | t == visitante p = Just (golsVisitante p, golsMandante p)
  | otherwise        = Nothing

-- | Resultado do ponto de vista do time; Nothing se ele nao jogou.
--   Usa Maybe como functor: o resultado e calculado "dentro" do Just.
resultadoPara :: Time -> Partida -> Maybe Resultado
resultadoPara t p = uncurry classificar <$> golsPara t p
  where
    classificar pro contra = case compare pro contra of
      GT -> Vitoria
      EQ -> Empate
      LT -> Derrota

-- | Todos os times do campeonato, sem repeticao e em ordem alfabetica.
times :: [Partida] -> [Time]
times = sort . nub . concatMap (\p -> [mandante p, visitante p])

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> src/Classificacao.hs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- CAMADA 2: Classificacao com Funcoes de Ordem Superior
-- =============================================================================
-- Calcula a tabela de classificacao e estatisticas do campeonato.
-- Regra desta camada: NENHUMA recursao explicita. Tudo e feito com map,
-- filter, dobras (foldl), composicao (.) e sortBy/sortOn com comparing,
-- Down e (<>) -- Ordering e um Monoid.
--
-- Criterios de classificacao (Brasileirao, sem confronto direto):
--   1. mais pontos
--   2. mais vitorias
--   3. maior saldo de gols
--   4. mais gols pro
--   5. ordem alfabetica do nome (desempate final deterministico)



-- | Pontos conquistados por resultado: 3 / 1 / 0.
pontos :: Resultado -> Int
pontos Vitoria = 3
pontos Empate  = 1
pontos Derrota = 0

-- | Acrescenta UMA partida a linha de um time. E o passo da dobra.
--   Se o time nao jogou a partida, a linha volta intacta (maybe).
acumular :: Linha -> Partida -> Linha
acumular l p = maybe l somar (golsPara (time l) p)
  where
    somar (pro, contra) = l
      { jogos      = jogos l + 1
      , vitorias   = vitorias l + fromEnum (pro > contra)
      , empates    = empates l + fromEnum (pro == contra)
      , derrotas   = derrotas l + fromEnum (pro < contra)
      , golsPro    = golsPro l + pro
      , golsContra = golsContra l + contra
      }

-- | Linha da tabela de um time, acumulada com foldl sobre as partidas das
--   quais ele participou. foldl porque o acumulador (Linha) e o argumento
--   da ESQUERDA de `acumular`, e as partidas sao somadas da primeira para a
--   ultima, como numa tabela real. (ver docs/decisoes.md: foldl x foldl')
linhaDoTime :: [Partida] -> Time -> Linha
linhaDoTime ps t = foldl acumular (linhaVazia t) (filter (participou t) ps)

-- | Pontos ganhos por uma linha da tabela (reaproveita `pontos`, assim a
--   regra 3/1/0 fica definida num unico lugar).
pontosLinha :: Linha -> Int
pontosLinha l = pontos Vitoria * vitorias l
              + pontos Empate  * empates l
              + pontos Derrota * derrotas l

-- | Saldo de gols: gols pro menos gols contra.
saldo :: Linha -> Int
saldo l = golsPro l - golsContra l

-- | Percentual (0 a 100) dos pontos disputados que o time conquistou.
--   0 se o time nao jogou (evita divisao por zero). fromIntegral faz a
--   ponte Int -> Double; nao ha div truncando o resultado.
aproveitamento :: Linha -> Double
aproveitamento l
  | jogos l == 0 = 0
  | otherwise    = 100 * fromIntegral (pontosLinha l)
                       / fromIntegral (3 * jogos l)

-- | Criterios de classificacao, em ordem de prioridade, com um nome para
--   que a demonstracao possa dizer QUAL criterio decidiu um empate.
--   Down inverte a ordem (maior primeiro); o nome fica em ordem crescente.
criterios :: [(String, Linha -> Linha -> Ordering)]
criterios =
  [ ("pontos",           comparing (Down . pontosLinha))
  , ("vitorias",         comparing (Down . vitorias))
  , ("saldo de gols",    comparing (Down . saldo))
  , ("gols pro",         comparing (Down . golsPro))
  , ("ordem alfabetica", comparing time)
  ]

-- | Comparacao por VARIOS criterios numa unica funcao. Funcoes que devolvem
--   Ordering formam um Monoid: (f <> g) x y so consulta g quando f x y == EQ.
--   E a mesma sequencia da lista `criterios` (ha um teste garantindo isso).
criterioClassificacao :: Linha -> Linha -> Ordering
criterioClassificacao =
     comparing (Down . pontosLinha)
  <> comparing (Down . vitorias)
  <> comparing (Down . saldo)
  <> comparing (Down . golsPro)
  <> comparing time

-- | Nome do primeiro criterio que diferencia duas linhas; Nothing se forem
--   identicas em todos os criterios.
criterioDecisivo :: Linha -> Linha -> Maybe String
criterioDecisivo a b = fst <$> find (\(_, cmp) -> cmp a b /= EQ) criterios

-- | Para cada par de times VIZINHOS na tabela com o mesmo numero de pontos,
--   informa qual criterio de desempate colocou um a frente do outro.
desempates :: [Linha] -> [(Time, Time, String)]
desempates ls =
  map explicar (filter mesmosPontos (zip ls (drop 1 ls)))
  where
    mesmosPontos (a, b) = pontosLinha a == pontosLinha b
    explicar (a, b)     = (time a, time b, fromMaybe "nenhum" (criterioDecisivo a b))

-- | Tabela completa, ja ordenada. Composicao: times -> linhas -> ordena.
classificacao :: [Partida] -> [Linha]
classificacao ps = (sortBy criterioClassificacao . map (linhaDoTime ps) . times) ps

-- | Somente as partidas ate a rodada informada (inclusive).
ateRodada :: Int -> [Partida] -> [Partida]
ateRodada n = filter ((<= n) . rodada)

-- | Diferenca absoluta de gols de uma partida.
diferencaGols :: Partida -> Int
diferencaGols p = abs (golsMandante p - golsVisitante p)

-- | Total de gols de uma partida.
totalGols :: Partida -> Int
totalGols p = golsMandante p + golsVisitante p

-- | Partida com a maior diferenca de gols; Nothing para lista vazia.
--   sortOn e estavel: em caso de empate fica a primeira da lista.
--   listToMaybe substitui o `head` (parcial) por uma versao total.
maiorGoleada :: [Partida] -> Maybe Partida
maiorGoleada = listToMaybe . sortOn (Down . diferencaGols)

-- | Media de gols por partida; Nothing para lista vazia.
mediaGols :: [Partida] -> Maybe Double
mediaGols [] = Nothing
mediaGols ps = Just (fromIntegral (sum (map totalGols ps))
                     / fromIntegral (length ps))

-- | Primeiro colocado; Nothing se nao houver partidas.
lider :: [Partida] -> Maybe Linha
lider = listToMaybe . classificacao

-- | Rodadas presentes no campeonato, em ordem crescente e sem repeticao.
rodadas :: [Partida] -> [Int]
rodadas = sort . nub . map rodada

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> src/Leitura.hs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- CAMADA 3: Leitura, Validacao e Saida
-- =============================================================================
-- Converte texto em partidas, validando cada etapa com as monadas Maybe e
-- Either. Nenhuma funcao daqui lanca excecao: toda entrada invalida vira um
-- `Left Erro` que indica a linha (ou a rodada) do problema.
--
-- Formato de cada linha (campos separados por ';'):
--   rodada;mandante;gols mandante;gols visitante;visitante
-- Linhas em branco e linhas que comecam com '#' sao ignoradas.



-- -----------------------------------------------------------------------------
-- Erros
-- -----------------------------------------------------------------------------

-- | Erros de leitura. Todo construtor carrega o numero da linha do texto
--   (contando comentarios e linhas em branco, como num editor).
data Erro
  = CamposInvalidos Int Int             -- ^ linha, quantidade de campos encontrada
  | NumeroInvalido Int String           -- ^ linha, texto que nao e um inteiro
  | PlacarNegativo Int Int              -- ^ linha, placar negativo lido
  | MesmoTime Int Time                  -- ^ linha, time que joga contra si mesmo
  | TimeRepetidoNaRodada Int Int Time   -- ^ linha, rodada, time ja escalado nela
  | TimeVazio Int                       -- ^ linha com nome de time em branco
  | RodadaInvalida Int Int              -- ^ linha, rodada menor que 1
  deriving (Show, Eq)

-- | Linha em que o erro ocorreu (usada para ordenar o relatorio).
linhaDoErro :: Erro -> Int
linhaDoErro (CamposInvalidos n _)        = n
linhaDoErro (NumeroInvalido n _)         = n
linhaDoErro (PlacarNegativo n _)         = n
linhaDoErro (MesmoTime n _)              = n
linhaDoErro (TimeRepetidoNaRodada n _ _) = n
linhaDoErro (TimeVazio n)                = n
linhaDoErro (RodadaInvalida n _)         = n

-- | Mensagem legivel para o usuario.
descreverErro :: Erro -> String
descreverErro e = "linha " ++ show (linhaDoErro e) ++ ": " ++ motivo e
  where
    motivo (CamposInvalidos _ q) =
      "esperados 5 campos separados por ';' "
      ++ "(rodada;mandante;gols;gols;visitante), encontrados " ++ show q
    motivo (NumeroInvalido _ s) =
      "\"" ++ s ++ "\" nao e um numero inteiro valido"
    motivo (PlacarNegativo _ g) =
      "placar negativo (" ++ show g ++ ")"
    motivo (MesmoTime _ t) =
      t ++ " nao pode jogar contra si mesmo"
    motivo (TimeRepetidoNaRodada _ r t) =
      t ++ " ja jogou na rodada " ++ show r
    motivo (TimeVazio _) =
      "nome de time em branco"
    motivo (RodadaInvalida _ r) =
      "rodada " ++ show r ++ " invalida (deve ser 1 ou maior)"

-- -----------------------------------------------------------------------------
-- Utilitarios de texto
-- -----------------------------------------------------------------------------

-- | Quebra uma linha em todos os separadores. Feito com foldr: cada
--   caractere ou abre um novo campo (separador) ou entra no campo atual.
--   separar ';' "a;;b" == ["a","","b"]  e  separar ';' "" == [""]
separar :: Char -> String -> [String]
separar sep = foldr passo [""]
  where
    passo c campos
      | c == sep  = "" : campos
      | otherwise = case campos of
          (atual : resto) -> (c : atual) : resto
          []              -> [[c]]

-- | Remove espacos (e o '\r' de arquivos do Windows) das duas pontas.
aparar :: String -> String
aparar = dropWhileEnd isSpace . dropWhile isSpace

-- | Linhas numeradas que contem dados (sem brancos e sem comentarios '#').
--   A numeracao e a do texto original, para que os erros apontem a linha
--   certa no arquivo.
linhasUteis :: String -> [(Int, String)]
linhasUteis = filter (temDados . snd) . zip [1 ..] . lines
  where
    temDados l = let l' = aparar l in not (null l' || "#" `isPrefixOf` l')

-- -----------------------------------------------------------------------------
-- Leitura de uma partida (monadas Maybe e Either)
-- -----------------------------------------------------------------------------

-- | Converte texto em Int com readMaybe (nunca `read`). O texto e lido como
--   Integer e so entao convertido, para que numeros gigantes nao "deem a
--   volta" silenciosamente no Int. Maybe e usado como monada (>>=) e como
--   functor (<$>); `maybe` faz a ponte para Either.
lerNumero :: Int -> String -> Either Erro Int
lerNumero n s = maybe (Left (NumeroInvalido n s)) Right
                      (readMaybe s >>= caberEmInt)
  where
    caberEmInt :: Integer -> Maybe Int
    caberEmInt x
      | x >= toInteger (minBound :: Int) && x <= toInteger (maxBound :: Int)
                  = Just (fromInteger x)
      | otherwise = Nothing

-- | Falha com o erro dado quando a condicao nao vale.
exigir :: Bool -> Erro -> Either Erro ()
exigir ok e = if ok then Right () else Left e

-- | Exige exatamente 5 campos.
cincoCampos :: Int -> [String] -> Either Erro (String, String, String, String, String)
cincoCampos _ [r, m, gm, gv, v] = Right (r, m, gm, gv, v)
cincoCampos n cs                = Left (CamposInvalidos n (length cs))

-- | Nome de time nao vazio.
lerTime :: Int -> String -> Either Erro Time
lerTime n t = if null t then Left (TimeVazio n) else Right t

-- | Placar nao negativo.
lerPlacar :: Int -> String -> Either Erro Int
lerPlacar n s = do
  g <- lerNumero n s
  exigir (g >= 0) (PlacarNegativo n g)
  pure g

-- | Converte uma linha (com seu numero) em Partida. Bloco `do` na monada
--   Either: o primeiro Left interrompe o calculo, sem "escadinha" de case.
lerPartida :: Int -> String -> Either Erro Partida
lerPartida n linha = do
  (sR, sM, sGM, sGV, sV) <- cincoCampos n (map aparar (separar ';' linha))
  r  <- lerNumero n sR
  exigir (r >= 1) (RodadaInvalida n r)
  m  <- lerTime n sM
  gm <- lerPlacar n sGM
  gv <- lerPlacar n sGV
  v  <- lerTime n sV
  exigir (m /= v) (MesmoTime n m)
  pure (Partida r m gm gv v)

-- -----------------------------------------------------------------------------
-- Leitura do campeonato inteiro
-- -----------------------------------------------------------------------------

-- | Times escalados mais de uma vez na mesma rodada. Para cada partida,
--   compara com as partidas ANTERIORES (inits) e acusa a linha da repeticao.
errosDeRodada :: [(Int, Partida)] -> [Erro]
errosDeRodada nps = concat (zipWith conflitos (inits nps) nps)
  where
    conflitos anteriores (n, p) =
      [ TimeRepetidoNaRodada n (rodada p) t
      | t <- [mandante p, visitante p]
      , any (\(_, q) -> rodada q == rodada p && participou t q) anteriores
      ]

-- | Le o texto inteiro, parando no PRIMEIRO erro (traverse na monada
--   Either) e, se todas as linhas forem validas, verifica que nenhum time
--   joga duas vezes na mesma rodada.
lerCampeonato :: String -> Either Erro [Partida]
lerCampeonato txt = do
  nps <- traverse lerNumerada (linhasUteis txt)
  maybe (Right (map snd nps)) Left (listToMaybe (errosDeRodada nps))
  where
    lerNumerada (n, l) = (,) n <$> lerPartida n l

-- | Relatorio com TODOS os erros do texto (nao apenas o primeiro), em
--   ordem de linha. As linhas validas tambem sao conferidas quanto a
--   times repetidos na mesma rodada.
todosOsErros :: String -> [Erro]
todosOsErros txt = sortOn linhaDoErro (errosDeLinha ++ errosDeRodada validas)
  where
    resultados             = map lerNumerada (linhasUteis txt)
    (errosDeLinha, validas) = partitionEithers resultados
    lerNumerada (n, l)     = (,) n <$> lerPartida n l

-- -----------------------------------------------------------------------------
-- Saida formatada
-- -----------------------------------------------------------------------------

-- | Partida em uma linha: "R3  Cascavel 0 x 5 Athletico".
mostrarPartida :: Partida -> String
mostrarPartida p =
  "R" ++ show (rodada p) ++ "  " ++ mandante p ++ " "
  ++ show (golsMandante p) ++ " x " ++ show (golsVisitante p)
  ++ " " ++ visitante p

-- | Numero com `casas` casas decimais, sem printf (arredonda corretamente).
mostrarDecimal :: Int -> Double -> String
mostrarDecimal casas x
  | casas <= 0 = sinal ++ show inteiro
  | otherwise  = sinal ++ show (inteiro `div` fator) ++ "."
                 ++ alinharDir casas '0' (show (inteiro `mod` fator))
  where
    fator   = 10 ^ casas :: Integer
    inteiro = round (abs x * fromIntegral fator) :: Integer
    sinal   = if x < 0 && inteiro /= 0 then "-" else ""

-- | Alinha a direita / esquerda preenchendo ate a largura dada.
alinharDir, alinharEsq :: Int -> Char -> String -> String
alinharDir n c s = replicate (n - length s) c ++ s
alinharEsq n c s = s ++ replicate (n - length s) c

-- | Saldo sempre com sinal: +7, 0, -4.
comSinal :: Int -> String
comSinal x
  | x > 0     = '+' : show x
  | otherwise = show x

-- | Tabela pronta para impressao: posicao, time, pontos, jogos, vitorias,
--   empates, derrotas, gols pro, gols contra, saldo e aproveitamento.
tabelaFormatada :: [Linha] -> String
tabelaFormatada [] = "(tabela vazia: nenhuma partida registrada)\n"
tabelaFormatada ls = unlines (cabecalho : separador : zipWith formatar [1 ..] ls)
  where
    -- largura da coluna Time: maior nome + 2 (foldr em vez de `maximum`,
    -- que e parcial; aqui a lista ja e nao vazia, mas o habito e o mesmo)
    largTime  = 2 + foldr (max . length . time) (length "Time") ls
    numericas = [("P", 4), ("J", 4), ("V", 4), ("E", 4), ("D", 4),
                 ("GP", 4), ("GC", 4), ("SG", 5), ("%", 7)]
    cabecalho = alinharDir 3 ' ' "#" ++ "  " ++ alinharEsq largTime ' ' "Time"
                ++ concatMap (\(t, w) -> alinharDir w ' ' t) numericas
    separador = replicate (length cabecalho) '-'
    formatar :: Int -> Linha -> String
    formatar pos l =
      alinharDir 3 ' ' (show pos) ++ "  " ++ alinharEsq largTime ' ' (time l)
      ++ concat (zipWith (\(_, w) v -> alinharDir w ' ' v) numericas
           [ show (pontosLinha l), show (jogos l), show (vitorias l)
           , show (empates l), show (derrotas l), show (golsPro l)
           , show (golsContra l), comSinal (saldo l)
           , mostrarDecimal 1 (aproveitamento l) ])

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> src/Dados.hs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- DADOS: campeonato de teste (como String, para funcionar tambem no
-- playground, que nao tem entrada pelo teclado)
-- =============================================================================
-- Campeonato Paranaense ficticio: 6 times, 5 rodadas, turno unico (todos
-- contra todos, 3 jogos por rodada, ninguem joga duas vezes na mesma rodada).
--
-- Casos de borda cobertos de proposito:
--   * empate em 0 x 0 ............ R1 Parana 0 x 0 Operario
--   * vitoria por 3+ gols ......... R3 Cascavel 0 x 5 Athletico (maior goleada)
--   * empate em PONTOS decidido por SALDO:
--       Athletico e Coritiba, 10 pts e 3 vitorias cada; saldo +7 x +3
--   * empate em PONTOS decidido por VITORIAS (mesmo com saldo pior):
--       Operario e Parana, 7 pts; Operario 2V (saldo 0) x Parana 1V (saldo +2)
--   * empate em PONTOS e VITORIAS decidido por SALDO na rodada 3:
--       Londrina e Cascavel, 0 pts; saldo -5 x -8
--   * lider muda: Coritiba lidera apos a 3a rodada, Athletico termina em 1o
--   * time invicto (Parana) e time sem vitorias (Cascavel)
--   * comentarios, linha em branco e espacos extras (ignorados pela leitura)

-- | Campeonato valido usado na demonstracao e nos testes.
dadosCampeonato :: String
dadosCampeonato = unlines
  [ "# rodada;mandante;gols mandante;gols visitante;visitante"
  , "# ---------------- Rodada 1 ----------------"
  , "1;Coritiba;2;0;Cascavel"
  , "1;Athletico;3;1;Londrina"
  , "1;Paraná;0;0;Operário"
  , ""
  , "# ---------------- Rodada 2 ----------------"
  , "2;Coritiba;1;0;Londrina"
  , "2;Cascavel;1;2;Operário"
  , "2;Athletico;1;1;Paraná"
  , ""
  , "# ---------------- Rodada 3 ----------------"
  , "3;Coritiba;2;1;Operário"
  , "3;Londrina;0;2;Paraná"
  , "3;Cascavel;0;5;Athletico"
  , ""
  , "# ---------------- Rodada 4 ----------------"
  , "4;Coritiba;2;2;Paraná"
  , "4;Operário;2;1;Athletico"
  , "4; Londrina ; 1 ; 1 ; Cascavel "
  , ""
  , "# ---------------- Rodada 5 ----------------"
  , "5;Coritiba;0;1;Athletico"
  , "5;Paraná;1;1;Cascavel"
  , "5;Operário;0;1;Londrina"
  ]

-- | Texto com erros de digitacao: pelo menos um de cada construtor de Erro.
--   As linhas 2 e 7 sao validas e servem de referencia para a repeticao.
dadosComErros :: String
dadosComErros = unlines
  [ "# entrada com erros de digitacao"                 -- linha 1
  , "1;Coritiba;2;1;Athletico"                         -- linha 2  (ok)
  , "1;Paraná;dois;0;Operário"                         -- linha 3  NumeroInvalido
  , "1;Londrina;1;1"                                   -- linha 4  CamposInvalidos
  , "2;Cascavel;-1;0;Londrina"                         -- linha 5  PlacarNegativo
  , "2;Operário;1;1;Operário"                          -- linha 6  MesmoTime
  , "2;Athletico;0;0;Paraná"                           -- linha 7  (ok)
  , "2;Coritiba;3;0;Athletico"                         -- linha 8  TimeRepetidoNaRodada
  , "0;Coritiba;1;0;Paraná"                            -- linha 9  RodadaInvalida
  , "3;;1;0;Paraná"                                    -- linha 10 TimeVazio
  ]

-- | Campeonato sem nenhuma partida (so comentarios e linhas em branco).
dadosVazio :: String
dadosVazio = unlines
  [ "# campeonato ainda nao comecou"
  , ""
  ]

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> src/Main.hs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- =============================================================================
-- MAIN: demonstracao das tres camadas
-- =============================================================================
-- Todo o relatorio e montado pela funcao PURA `demonstracao :: String -> String`.
-- `main` e a unica funcao com IO: escolhe a origem dos dados (String embutida
-- em Dados.hs ou, opcionalmente, um arquivo passado como argumento) e imprime.
--
--   ./campeonato                   usa o campeonato de teste de Dados.hs
--   ./campeonato resultados.txt    le as partidas de um arquivo (GHC local)



-- -----------------------------------------------------------------------------
-- Casca de IO (a unica funcao com IO)
-- -----------------------------------------------------------------------------

main :: IO ()
main = do
  setLocaleEncoding utf8          -- readFile em UTF-8 (nomes com acento)
  hSetEncoding stdout utf8        -- saida em UTF-8 em qualquer terminal
  args <- getArgs
  entrada <- case args of
    [] -> pure (Right ("dadosCampeonato (Dados.hs)", dadosCampeonato))
    (arquivo : _) -> do
      lido <- try (readFile arquivo >>= \s -> s <$ evaluate (length s))
      pure (either (\e -> Left (arquivo, e)) (\s -> Right (arquivo, s)) lido)
  putStr (either (uncurry falhaArquivo) (uncurry demonstracao) entrada)

-- -----------------------------------------------------------------------------
-- Nucleo puro da demonstracao
-- -----------------------------------------------------------------------------

-- | Mensagem quando o arquivo informado nao pode ser lido. Mesmo assim a
--   demonstracao roda com os dados embutidos: o programa nunca "quebra".
falhaArquivo :: FilePath -> IOException -> String
falhaArquivo arquivo e =
  "AVISO: nao foi possivel ler \"" ++ arquivo ++ "\" (" ++ show e ++ ").\n"
  ++ "Usando o campeonato de teste embutido.\n\n"
  ++ demonstracao "dadosCampeonato (Dados.hs)" dadosCampeonato

-- | Relatorio completo: Camada 1, Camada 2 (tabela final, tabela numa rodada
--   intermediaria, estatisticas) e Camada 3 (entrada com erros).
demonstracao :: String -> String -> String
demonstracao origem texto =
  titulo "PjBL2 - Tabela de Classificacao de Campeonato (Haskell)"
  ++ "Origem dos dados: " ++ origem ++ "\n"
  ++ either (secaoEntradaInvalida texto) secoesCampeonato (lerCampeonato texto)
  ++ secaoErros
  ++ secaoVazio

-- | Se a entrada principal for invalida, mostra todos os erros dela.
secaoEntradaInvalida :: String -> Erro -> String
secaoEntradaInvalida texto primeiro =
  secao "ENTRADA INVALIDA"
  ++ "lerCampeonato parou no primeiro erro:\n  " ++ descreverErro primeiro ++ "\n\n"
  ++ "todosOsErros encontrou:\n" ++ listarErros (todosOsErros texto)

-- | Camadas 1 e 2 sobre um campeonato valido.
secoesCampeonato :: [Partida] -> String
secoesCampeonato ps =
  secaoCamada1 ps
  ++ secaoTabela ("CAMADA 2 - Classificacao final (" ++ show (length ps) ++ " partidas)") ps
  ++ secaoTabela ("CAMADA 2 - Classificacao apos a rodada " ++ show meio
                  ++ " (ateRodada " ++ show meio ++ ")") (ateRodada meio ps)
  ++ secaoEstatisticas ps
  where
    ultima = foldr max 0 (rodadas ps)
    meio   = (ultima + 1) `div` 2

secaoCamada1 :: [Partida] -> String
secaoCamada1 ps =
  secao "CAMADA 1 - Tipos e dados"
  ++ "Times (" ++ show (length ts) ++ "): " ++ intercalate ", " ts ++ "\n"
  ++ "Rodadas: " ++ intercalate ", " (map show (rodadas ps)) ++ "\n"
  ++ maybe "" exemplo (primeiraPartida ps)
  where
    ts = times ps
    primeiraPartida = foldr (const . Just) Nothing
    forasteiro p = foldr (\t acc -> if participou t p then acc else Just t) Nothing ts
    exemplo p =
      "\nExemplo com a partida  " ++ mostrarPartida p ++ "\n"
      ++ linhaRes (mandante p) p
      ++ linhaRes (visitante p) p
      ++ maybe "" (`linhaRes` p) (forasteiro p)
    linhaRes t p = "  resultadoPara " ++ show t ++ " = " ++ show (resultadoPara t p) ++ "\n"

secaoTabela :: String -> [Partida] -> String
secaoTabela nome ps =
  secao nome
  ++ tabelaFormatada tabela
  ++ maybe "" (\l -> "Lider: " ++ time l ++ "\n") (lider ps)
  ++ explicarDesempates (desempates tabela)
  where
    tabela = classificacao ps

explicarDesempates :: [(Time, Time, String)] -> String
explicarDesempates [] = "Nenhum empate em pontos entre times vizinhos.\n"
explicarDesempates ds = "Empates em pontos e o criterio que decidiu:\n"
  ++ concatMap (\(a, b, c) -> "  " ++ a ++ " a frente de " ++ b ++ " por " ++ c ++ "\n") ds

secaoEstatisticas :: [Partida] -> String
secaoEstatisticas ps =
  secao "CAMADA 2 - Estatisticas"
  ++ "Total de gols ........ " ++ show (sum (map totalGols ps)) ++ "\n"
  ++ "Media de gols ........ " ++ maybe "sem partidas" (mostrarDecimal 2) (mediaGols ps) ++ "\n"
  ++ "Maior goleada ........ " ++ maybe "sem partidas" goleada (maiorGoleada ps) ++ "\n"
  ++ "Aproveitamento lider . " ++ maybe "sem partidas" aprov (lider ps) ++ "\n"
  where
    goleada p = mostrarPartida p ++ "  (diferenca de " ++ show (diferencaGols p) ++ ")"
    aprov l   = time l ++ " " ++ mostrarDecimal 1 (aproveitamento l) ++ "%"

-- | Camada 3: a entrada com erros de Dados.hs.
secaoErros :: String
secaoErros =
  secao "CAMADA 3 - Entrada com erros (dadosComErros)"
  ++ numerarLinhas dadosComErros
  ++ "\nlerCampeonato (para no primeiro erro):\n  "
  ++ either (("Left  -> " ++) . descreverErro) (const "Right (inesperado)") (lerCampeonato dadosComErros)
  ++ "\n\ntodosOsErros (relatorio completo):\n"
  ++ listarErros (todosOsErros dadosComErros)

-- | Caso de borda: campeonato sem nenhuma partida.
secaoVazio :: String
secaoVazio =
  secao "CASO DE BORDA - Campeonato vazio (dadosVazio)"
  ++ either (("Left " ++) . descreverErro) resumoVazio (lerCampeonato dadosVazio)
  where
    resumoVazio ps =
      "lerCampeonato -> Right " ++ show ps ++ "\n"
      ++ tabelaFormatada (classificacao ps)
      ++ "maiorGoleada -> " ++ show (maiorGoleada ps) ++ "\n"
      ++ "mediaGols    -> " ++ show (mediaGols ps) ++ "\n"
      ++ "lider        -> " ++ show (lider ps) ++ "\n"

-- -----------------------------------------------------------------------------
-- Auxiliares de apresentacao
-- -----------------------------------------------------------------------------

titulo :: String -> String
titulo t = linha ++ "\n" ++ t ++ "\n" ++ linha ++ "\n"
  where linha = replicate (length t) '='

secao :: String -> String
secao t = "\n" ++ t ++ "\n" ++ replicate (length t) '-' ++ "\n"

listarErros :: [Erro] -> String
listarErros [] = "  (nenhum erro)\n"
listarErros es = concatMap (\e -> "  - " ++ descreverErro e ++ "\n") es

numerarLinhas :: String -> String
numerarLinhas = unlines . zipWith (\n l -> "  " ++ pad n ++ " | " ++ l) [1 :: Int ..] . lines
  where pad n = let s = show n in replicate (3 - length s) ' ' ++ s
