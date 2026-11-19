-- =============================================================================
-- MAIN: demonstracao das tres camadas
-- =============================================================================
-- Todo o relatorio e montado pela funcao PURA `demonstracao :: String -> String`.
-- `main` e a unica funcao com IO: escolhe a origem dos dados (String embutida
-- em Dados.hs ou, opcionalmente, um arquivo passado como argumento) e imprime.
--
--   ./campeonato                   usa o campeonato de teste de Dados.hs
--   ./campeonato resultados.txt    le as partidas de um arquivo (GHC local)
module Main (main) where

import Control.Exception (IOException, evaluate, try)
import Data.List (intercalate)
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.Environment (getArgs)
import System.IO (hSetEncoding, stdout)

import Classificacao
import Dados
import Leitura
import Tipos

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
