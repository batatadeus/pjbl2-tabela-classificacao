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
module Leitura
  ( Erro (..)
  , separar
  , aparar
  , linhasUteis
  , lerNumero
  , lerPartida
  , errosDeRodada
  , lerCampeonato
  , todosOsErros
  , linhaDoErro
  , descreverErro
  , mostrarPartida
  , mostrarDecimal
  , tabelaFormatada
  ) where

import Data.Char (isSpace)
import Data.Either (partitionEithers)
import Data.List (dropWhileEnd, inits, isPrefixOf, sortOn)
import Data.Maybe (listToMaybe)
import Text.Read (readMaybe)

import Classificacao (aproveitamento, pontosLinha, saldo)
import Tipos

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
