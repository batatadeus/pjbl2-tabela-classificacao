-- =============================================================================
-- TESTES: cada caso compara o resultado obtido com o esperado
-- =============================================================================
-- Executar (na pasta projeto/):
--   runghc -isrc tests/Testes.hs
-- ou compilar:
--   ghc -Wall -isrc -outputdir build -o build/testes tests/Testes.hs
--
-- O programa imprime OK/FALHOU por caso, um resumo final e termina com
-- codigo de saida 1 se algum caso falhar.
module Main (main) where

import Data.Either (isLeft, isRight)
import Data.List (isInfixOf, isPrefixOf, nub, sortBy)
import System.Exit (exitFailure, exitSuccess)
import System.IO (hSetEncoding, stdout, utf8)

import Classificacao
import Dados
import Leitura
import Tipos

-- -----------------------------------------------------------------------------
-- Infraestrutura
-- -----------------------------------------------------------------------------

-- | Funcao auxiliar sugerida no enunciado.
testar :: (Eq a, Show a) => String -> a -> a -> IO ()
testar nome obtido esperado
  | obtido == esperado = putStrLn ("OK      " ++ nome)
  | otherwise          = putStrLn ("FALHOU  " ++ nome ++ ": " ++ show obtido
                                   ++ "\n        esperado: " ++ show esperado)

-- | Igual a `testar`, mas devolve se passou (para o resumo final).
caso :: (Eq a, Show a) => String -> a -> a -> IO Bool
caso nome obtido esperado = (obtido == esperado) <$ testar nome obtido esperado

-- | Comparacao de Double com tolerancia.
quase :: Double -> Double -> Bool
quase a b = abs (a - b) < 1e-9

grupo :: String -> IO ()
grupo nome = putStrLn ("\n== " ++ nome ++ " ==")

-- -----------------------------------------------------------------------------
-- Dados auxiliares
-- -----------------------------------------------------------------------------

-- | Campeonato de teste ja lido (lista vazia se, por erro, a leitura falhar;
--   nesse caso os testes de leitura acusam o problema).
campeonato :: [Partida]
campeonato = either (const []) id (lerCampeonato dadosCampeonato)

exemplo :: Partida
exemplo = Partida 1 "Coritiba" 2 1 "Athletico"

-- | Quatro times, todos com 1 ponto, 0 vitorias e saldo 0:
--   so "gols pro" e "ordem alfabetica" desempatam.
empatesTotais :: [Partida]
empatesTotais =
  [ Partida 1 "Gama" 2 2 "Delta"
  , Partida 1 "Alfa" 1 1 "Beta"
  ]

classificacaoFinal :: [Linha]
classificacaoFinal =
  [ Linha "Athletico" 5 3 1 1 11  4
  , Linha "Coritiba"  5 3 1 1  7  4
  , Linha "Operário"  5 2 1 2  5  5
  , Linha "Paraná"    5 1 4 0  6  4
  , Linha "Londrina"  5 1 1 3  3  7
  , Linha "Cascavel"  5 0 2 3  3 11
  ]

classificacaoRodada3 :: [Linha]
classificacaoRodada3 =
  [ Linha "Coritiba"  3 3 0 0 5 1
  , Linha "Athletico" 3 2 1 0 9 2
  , Linha "Paraná"    3 1 2 0 3 1
  , Linha "Operário"  3 1 1 1 3 3
  , Linha "Londrina"  3 0 0 3 1 6
  , Linha "Cascavel"  3 0 0 3 1 9
  ]

-- -----------------------------------------------------------------------------
-- Camada 1
-- -----------------------------------------------------------------------------

testesCamada1 :: [IO Bool]
testesCamada1 =
  [ caso "resultadoPara mandante (vitoria)"     (resultadoPara "Coritiba" exemplo)  (Just Vitoria)
  , caso "resultadoPara visitante (derrota)"    (resultadoPara "Athletico" exemplo) (Just Derrota)
  , caso "resultadoPara time que nao jogou"     (resultadoPara "Paraná" exemplo)    Nothing
  , caso "resultadoPara empate (dos dois lados)"
      (map (`resultadoPara` Partida 1 "A" 0 0 "B") ["A", "B"]) [Just Empate, Just Empate]
  , caso "participou mandante/visitante/outro"
      (map (`participou` exemplo) ["Coritiba", "Athletico", "Paraná"]) [True, True, False]
  , caso "golsPara visitante inverte o placar"  (golsPara "Athletico" exemplo) (Just (1, 2))
  , caso "times do campeonato (alfabetica)"     (times campeonato)
      ["Athletico", "Cascavel", "Coritiba", "Londrina", "Operário", "Paraná"]
  , caso "times sem repeticao"                  (let ts = times campeonato in length ts == length (nub ts)) True
  , caso "times []"                             (times []) []
  , caso "campeonato: 15 partidas"              (length campeonato) 15
  , caso "campeonato: >= 6 times"               (length (times campeonato) >= 6) True
  , caso "campeonato: >= 5 rodadas"             (length (rodadas campeonato) >= 5) True
  , caso "campeonato: ninguem joga 2x na rodada"
      (errosDeRodada (zip [1 ..] campeonato)) []
  , caso "campeonato: todo time joga 1x por rodada"
      (all (\r -> length (filter ((== r) . rodada) campeonato) * 2 == length (times campeonato))
           (rodadas campeonato)) True
  , caso "campeonato: tem empate 0 x 0"
      (any (\p -> golsMandante p == 0 && golsVisitante p == 0) campeonato) True
  , caso "campeonato: tem vitoria por 3+ gols"  (any ((>= 3) . diferencaGols) campeonato) True
  ]

-- -----------------------------------------------------------------------------
-- Camada 2
-- -----------------------------------------------------------------------------

testesCamada2 :: [IO Bool]
testesCamada2 =
  [ caso "pontos V/E/D"                         (map pontos [Vitoria, Empate, Derrota]) [3, 1, 0]
  , caso "linhaDoTime Paraná (invicto)"         (linhaDoTime campeonato "Paraná") (Linha "Paraná" 5 1 4 0 6 4)
  , caso "linhaDoTime time inexistente"         (linhaDoTime campeonato "Toledo") (linhaVazia "Toledo")
  , caso "acumular ignora partida de outros"    (acumular (linhaVazia "Toledo") exemplo) (linhaVazia "Toledo")
  , caso "pontosLinha Athletico"                (pontosLinha (linhaDoTime campeonato "Athletico")) 10
  , caso "saldo Cascavel"                       (saldo (linhaDoTime campeonato "Cascavel")) (-8)
  , caso "aproveitamento Athletico (10/15)"
      (quase (aproveitamento (linhaDoTime campeonato "Athletico")) (200 / 3)) True
  , caso "aproveitamento de quem nao jogou = 0" (aproveitamento (linhaVazia "Toledo")) 0
  , caso "classificacao completa (conferida a mao)" (classificacao campeonato) classificacaoFinal
  , caso "desempate: Athletico x Coritiba decidido por SALDO"
      (criterioDecisivo (linhaDoTime campeonato "Athletico") (linhaDoTime campeonato "Coritiba"))
      (Just "saldo de gols")
  , caso "desempate: Operário x Paraná decidido por VITORIAS (saldo do Paraná e maior)"
      (criterioDecisivo (linhaDoTime campeonato "Operário") (linhaDoTime campeonato "Paraná"))
      (Just "vitorias")
  , caso "desempates na tabela final"
      (desempates (classificacao campeonato))
      [("Athletico", "Coritiba", "saldo de gols"), ("Operário", "Paraná", "vitorias")]
  , caso "desempate por gols pro e por ordem alfabetica"
      (desempates (classificacao empatesTotais))
      [("Delta", "Gama", "ordem alfabetica"), ("Gama", "Alfa", "gols pro"), ("Alfa", "Beta", "ordem alfabetica")]
  , caso "criterioClassificacao == sequencia da lista criterios"
      (map (sortBy criterioClassificacao) [classificacaoFinal, reverse classificacaoFinal, classificacao empatesTotais])
      (map (sortBy (foldr ((<>) . snd) mempty criterios)) [classificacaoFinal, reverse classificacaoFinal, classificacao empatesTotais])
  , caso "ordenacao independe da ordem de entrada"
      (classificacao (reverse campeonato)) classificacaoFinal
  , caso "ateRodada 3 tem 9 partidas"           (length (ateRodada 3 campeonato)) 9
  , caso "classificacao (ateRodada 3)"          (classificacao (ateRodada 3 campeonato)) classificacaoRodada3
  , caso "classificacao (ateRodada 3) /= final" (classificacao (ateRodada 3 campeonato) /= classificacao campeonato) True
  , caso "rodada 3: Londrina x Cascavel decidido por SALDO"
      (desempates (classificacao (ateRodada 3 campeonato))) [("Londrina", "Cascavel", "saldo de gols")]
  , caso "lider apos a rodada 3 = Coritiba"     (time <$> lider (ateRodada 3 campeonato)) (Just "Coritiba")
  , caso "lider final = Athletico"              (time <$> lider campeonato) (Just "Athletico")
  , caso "ateRodada 0 = []"                     (ateRodada 0 campeonato) []
  , caso "ateRodada alem do fim = tudo"         (ateRodada 99 campeonato) campeonato
  , caso "maiorGoleada campeonato"              (maiorGoleada campeonato) (Just (Partida 3 "Cascavel" 0 5 "Athletico"))
  , caso "maiorGoleada empate -> primeira"
      (maiorGoleada [Partida 1 "A" 2 0 "B", Partida 1 "C" 0 2 "D"]) (Just (Partida 1 "A" 2 0 "B"))
  , caso "maiorGoleada [] = Nothing"            (maiorGoleada []) Nothing
  , caso "mediaGols campeonato (35/15)"         (fmap (quase (35 / 15)) (mediaGols campeonato)) (Just True)
  , caso "mediaGols [] = Nothing"               (mediaGols []) Nothing
  , caso "classificacao [] = []"                (classificacao []) []
  , caso "lider [] = Nothing"                   (lider []) Nothing
  ]

-- -----------------------------------------------------------------------------
-- Camada 3
-- -----------------------------------------------------------------------------

testesCamada3 :: [IO Bool]
testesCamada3 =
  [ caso "separar campos"                       (separar ';' "1;Coritiba;2;1;Athletico") ["1", "Coritiba", "2", "1", "Athletico"]
  , caso "separar campo vazio no meio"          (separar ';' "a;;b") ["a", "", "b"]
  , caso "separar texto vazio"                  (separar ';' "") [""]
  , caso "separar separador no fim"             (separar ';' "a;") ["a", ""]
  , caso "lerPartida valida"                    (lerPartida 1 "1;Coritiba;2;2;Athletico") (Right (Partida 1 "Coritiba" 2 2 "Athletico"))
  , caso "lerPartida com espacos e \\r"         (lerPartida 1 " 2 ; Paraná ; 0 ; 3 ; Operário \r") (Right (Partida 2 "Paraná" 0 3 "Operário"))
  , caso "lerCampeonato entrada valida -> Right" (isRight (lerCampeonato dadosCampeonato)) True
  , caso "lerCampeonato le as 15 partidas"      (length <$> lerCampeonato dadosCampeonato) (Right 15)
  , caso "todosOsErros entrada valida = []"     (todosOsErros dadosCampeonato) []
  -- um teste por construtor de Erro
  , caso "Erro CamposInvalidos (4 campos)"      (lerPartida 4 "1;Londrina;1;1") (Left (CamposInvalidos 4 4))
  , caso "Erro CamposInvalidos (6 campos)"      (lerPartida 7 "1;A;1;1;B;C") (Left (CamposInvalidos 7 6))
  , caso "Erro NumeroInvalido (placar \"dois\")" (lerPartida 3 "1;Paraná;dois;0;Operário") (Left (NumeroInvalido 3 "dois"))
  , caso "Erro NumeroInvalido (placar \"2a\")"  (lerPartida 3 "1;A;2a;0;B") (Left (NumeroInvalido 3 "2a"))
  , caso "Erro NumeroInvalido (rodada \"x\")"   (lerPartida 2 "x;A;1;0;B") (Left (NumeroInvalido 2 "x"))
  , caso "Erro NumeroInvalido (estouro de Int)" (lerPartida 2 "1;A;99999999999999999999;0;B") (Left (NumeroInvalido 2 "99999999999999999999"))
  , caso "lerNumero rejeita \"+2\", \"2.0\", \"\" e \" \""
      (map (lerNumero 1) ["+2", "2.0", "", " "])
      [Left (NumeroInvalido 1 "+2"), Left (NumeroInvalido 1 "2.0"), Left (NumeroInvalido 1 ""), Left (NumeroInvalido 1 " ")]
  , caso "lerNumero aceita \"02\" (limitacao L5)" (lerNumero 1 "02") (Right 2)
  , caso "Erro PlacarNegativo"                (lerPartida 5 "2;Cascavel;-1;0;Londrina") (Left (PlacarNegativo 5 (-1)))
  , caso "Erro MesmoTime"                       (lerPartida 6 "2;Operário;1;1;Operário") (Left (MesmoTime 6 "Operário"))
  , caso "Erro TimeRepetidoNaRodada"
      (lerCampeonato "1;A;1;0;B\n1;B;2;2;C\n") (Left (TimeRepetidoNaRodada 2 1 "B"))
  , caso "Erro TimeVazio"                       (lerPartida 10 "3;;1;0;Paraná") (Left (TimeVazio 10))
  , caso "Erro RodadaInvalida"                  (lerPartida 9 "0;Coritiba;1;0;Paraná") (Left (RodadaInvalida 9 0))
  , caso "lerCampeonato para no primeiro erro"  (lerCampeonato dadosComErros) (Left (NumeroInvalido 3 "dois"))
  , caso "todosOsErros lista todos (7 erros)"
      (todosOsErros dadosComErros)
      [ NumeroInvalido 3 "dois", CamposInvalidos 4 4, PlacarNegativo 5 (-1)
      , MesmoTime 6 "Operário", TimeRepetidoNaRodada 8 2 "Athletico"
      , RodadaInvalida 9 0, TimeVazio 10 ]
  , caso "todosOsErros: mandante E visitante repetidos"
      (todosOsErros "1;A;1;0;B\n1;B;0;0;A\n")
      [TimeRepetidoNaRodada 2 1 "B", TimeRepetidoNaRodada 2 1 "A"]
  , caso "limitacao L4: lerCampeonato x todosOsErros"
      (let t = "1;A;1;0;B\n1;A;2;2;C\n1;D;x;0;E\n"
       in (lerCampeonato t, todosOsErros t))
      (Left (NumeroInvalido 3 "x"), [TimeRepetidoNaRodada 2 1 "A", NumeroInvalido 3 "x"])
  , caso "numero da linha conta comentarios/brancos"
      (lerCampeonato "# comentario\n\n1;A;x;0;B\n") (Left (NumeroInvalido 3 "x"))
  , caso "campeonato vazio -> Right []"         (lerCampeonato dadosVazio) (Right [])
  , caso "texto vazio -> Right []"              (lerCampeonato "") (Right [])
  , caso "CRLF (arquivo do Windows)"            (lerCampeonato "1;A;1;0;B\r\n") (Right [Partida 1 "A" 1 0 "B"])
  , caso "lixo nao derruba: Left"               (all (isLeft . lerCampeonato) [";;;;;;", "abc", "1;A;1;0", "1;A;;0;B"]) True
  , caso "descreverErro indica a linha"         ("linha 3:" `isPrefixOf` descreverErro (NumeroInvalido 3 "dois")) True
  , caso "descreverErro indica a rodada"        ("rodada 2" `isInfixOf` descreverErro (TimeRepetidoNaRodada 8 2 "Athletico")) True
  , caso "mostrarDecimal 1 (200/3)"             (mostrarDecimal 1 (200 / 3)) "66.7"
  , caso "mostrarDecimal 2 (35/15)"             (mostrarDecimal 2 (35 / 15)) "2.33"
  , caso "mostrarDecimal 1 0"                   (mostrarDecimal 1 0) "0.0"
  , caso "mostrarDecimal 1 (-0.04)"             (mostrarDecimal 1 (-0.04)) "0.0"
  , caso "tabelaFormatada []"                   (tabelaFormatada []) "(tabela vazia: nenhuma partida registrada)\n"
  , caso "tabelaFormatada: cabecalho + 6 linhas" (length (lines (tabelaFormatada classificacaoFinal))) 8
  , caso "tabelaFormatada: 1o colocado"
      (take 2 (drop 2 (lines (tabelaFormatada classificacaoFinal))))
      [ "  1  Athletico    10   5   3   1   1  11   4   +7   66.7"
      , "  2  Coritiba     10   5   3   1   1   7   4   +3   66.7" ]
  , caso "tabelaFormatada: colunas exigidas no cabecalho"
      (words (head' (lines (tabelaFormatada classificacaoFinal))))
      ["#", "Time", "P", "J", "V", "E", "D", "GP", "GC", "SG", "%"]
  ]
  where
    head' = foldr const ""

-- -----------------------------------------------------------------------------
-- Execucao
-- -----------------------------------------------------------------------------

main :: IO ()
main = do
  hSetEncoding stdout utf8
  grupo "Camada 1 - Tipos e dados"
  r1 <- sequence testesCamada1
  grupo "Camada 2 - Classificacao"
  r2 <- sequence testesCamada2
  grupo "Camada 3 - Leitura e validacao"
  r3 <- sequence testesCamada3
  let resultados = r1 ++ r2 ++ r3
      total      = length resultados
      falhas     = length (filter not resultados)
  putStrLn ("\nResumo: " ++ show (total - falhas) ++ "/" ++ show total ++ " casos OK, "
            ++ show falhas ++ " falha(s).")
  if falhas == 0 then exitSuccess else exitFailure
