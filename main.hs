module Main (main) where

import Automata
import Control.Monad.State     (evalState)
import Data.Time.Clock.POSIX   (getPOSIXTime)
import System.Environment      (getArgs)
import System.Exit             (exitFailure)
import System.IO               (hPutStrLn, stderr)
import Text.Read               (readMaybe)

uso :: String
uso = unlines
  [ "uso: ./prog <regla 0-255> <ancho> <generaciones> [aleatorio [semilla]]"
  , "ej:  ./prog 90 31 8"
  , "     ./prog 30 61 30 aleatorio        (condicion inicial aleatoria)"
  , "     ./prog 30 61 30 aleatorio 42     (aleatoria con semilla fija)" ]

falla :: String -> IO a
falla msg = hPutStrLn stderr msg >> hPutStrLn stderr uso >> exitFailure

main :: IO ()
main = do
  args <- getArgs
  case args of
    (r : w : g : extra) ->
      case (readMaybe r, readMaybe w, readMaybe g) of
        (Just reg, Just ancho, Just gens)
          | reg < 0 || reg > 255 -> falla "la regla debe estar entre 0 y 255"
          | ancho < 1            -> falla "el ancho debe ser >= 1"
          | gens < 0             -> falla "las generaciones deben ser >= 0"
          | otherwise            -> do
              inicial <- condicionInicial reg ancho extra
              mapM_ putStrLn (evalState (simular gens) inicial)
        _ -> falla "los argumentos deben ser numeros enteros"
    _ -> falla "faltan argumentos"

condicionInicial :: Int -> Int -> [String] -> IO Automata
condicionInicial reg ancho ("aleatorio" : resto) = do
  semilla <- case resto of
    (s : _) -> maybe (falla "semilla invalida") return (readMaybe s)
    []      -> floor . (* 1000) <$> getPOSIXTime
  return (nuevoAutomataAleatorio semilla reg ancho)
condicionInicial reg ancho _ = return (nuevoAutomata reg ancho)
