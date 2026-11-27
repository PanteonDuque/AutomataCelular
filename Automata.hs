module Automata
  ( Automata(..)
  , nuevoAutomata
  , nuevoAutomataAleatorio
  , vecindades
  , aplicarRegla
  , tablaRegla
  , paso
  , mostrarCeldas
  , pasoS
  , avanzar
  , simular
  ) where

import Control.Monad       (replicateM, replicateM_)
import Control.Monad.State (State, gets, modify)
import Data.Bits           (shiftR, testBit, (.&.))

-- Estado del autómata.
data Automata = Automata
  { celdas     :: [Bool]  -- True = viva, False = muerta
  , regla      :: Int     -- número de regla de Wolfram (0..255)
  , generacion :: Int     -- generación actual donde 0 = condición inicial
  } deriving (Show, Eq)

-- Una sola célula viva en el centro.
nuevoAutomata :: Int -> Int -> Automata
nuevoAutomata r ancho = Automata
  { celdas     = [ i == ancho `div` 2 | i <- [0 .. ancho - 1] ]
  , regla      = r
  , generacion = 0
  }

-- Condición inicial aleatoria a partir de una semilla.
nuevoAutomataAleatorio :: Int -> Int -> Int -> Automata
nuevoAutomataAleatorio semilla r ancho = Automata
  { celdas     = take ancho (aleatorios semilla)
  , regla      = r
  , generacion = 0
  }

aleatorios :: Int -> [Bool]
aleatorios semilla = map (\x -> (x `shiftR` 16) .&. 1 == 1) (tail (iterate siguiente semilla))
  where
    siguiente x = (1103515245 * x + 12345) `mod` 2147483648

-- Regla de Wolfram

vecindades :: [Bool] -> [(Bool, Bool, Bool)]
vecindades [] = []
vecindades cs = zip3 (last cs : cs) cs (tail cs ++ [head cs])

aplicarRegla :: Int -> (Bool, Bool, Bool) -> Bool
aplicarRegla r (l, c, d) = testBit r (4 * fromEnum l + 2 * fromEnum c + fromEnum d)

-- Tabla de la regla en el orden 111,110,...,000.
tablaRegla :: Int -> [((Bool, Bool, Bool), Bool)]
tablaRegla r = [ (v, aplicarRegla r v) | n <- [7, 6 .. 0 :: Int], let v = bits n ]
  where bits n = (testBit n 2, testBit n 1, testBit n 0)

-- Una generación (versión pura).
paso :: Automata -> Automata
paso a = a { celdas     = map (aplicarRegla (regla a)) (vecindades (celdas a))
           , generacion = generacion a + 1 }

mostrarCeldas :: Automata -> String
mostrarCeldas = map (\v -> if v then '#' else ' ') . celdas

-- La mónada State

-- Un paso de la simulación dentro de State.
pasoS :: State Automata ()
pasoS = modify paso

-- n pasos seguidos.
avanzar :: Int -> State Automata ()
avanzar n = replicateM_ n pasoS

-- Simulación completa: devuelve las n primeras generaciones incluyedo la inicial
-- ya dibujadas, una por línea.
simular :: Int -> State Automata [String]
simular n
  | n <= 0    = return []
  | otherwise = do
      primera <- gets mostrarCeldas
      resto   <- replicateM (n - 1) (pasoS >> gets mostrarCeldas)
      return (primera : resto)
