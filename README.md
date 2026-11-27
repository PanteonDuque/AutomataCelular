# INFO188 — Tarea 1: Autómata Celular Elemental 1D


**Profesor:** Cristóbal A. Navarro 

## Integrantes:

- Antonio Duque 
- Benjamin Parra 
- Jason 
- Hans
  
## Descripcion

Este proyecto implementa en Haskell un **autómata celular elemental unidimensional** con condiciones de borde periódicas. El sistema modela una fila de células binarias (vivas o muertas) que evolucionan en pasos discretos según una de las 256 reglas elementales de Wolfram (0 a 255).

- **Condición inicial aleatoria** (con semilla automática basada en el reloj del sistema o semilla fija para ejecuciones reproducibles).
- **Simulación con la mónada `State`** ([Haskell Wiki — State Monad](https://wiki.haskell.org/State_Monad)), encapsulando las transiciones de estado mediante `modify`, `gets`, `replicateM_` y `replicateM` sin pasar manualmente el estado entre funciones.


## Estructura del proyecto

- `Automata.hs` Módulo principal de lógica: definición del tipo `Automata`, constructores (centrado y aleatorio), vecindades con bordes periódicos, evaluación de reglas de Wolfram, función pura `paso` y simulación con la mónada `State` (`pasoS`, `avanzar`, `simular`).
- `main.hs` Punto de entrada del programa: lectura y validación de argumentos por línea de comandos, inicialización del autómata (estándar o aleatorio) y ejecución de la simulación mediante `evalState`. 
- `Makefile` Reglas de compilación optimizada (`ghc -O2`) y limpieza de binarios y archivos intermedios. 

## Requisitos y compilación

### Dependencias

- **GHC** (Glasgow Haskell Compiler)
- **GNU Make**
- Paquetes de Haskell: `base`, `mtl` (`Control.Monad.State`) 

### Compilar y limpiar

Para generar el ejecutable `./prog` con optimización `-O2`:

```bash
make
```

Internamente ejecuta:

```bash
ghc -O2 main.hs -o prog
```

Para eliminar el binario y los archivos objeto/interfaz (`*.o`, `*.hi`):

```bash
make clean
```

## Uso del programa

```bash
./prog <regla 0-255> <ancho> <generaciones> 
```

Opcional
```bash
./prog <regla 0-255> <ancho> <generaciones> aleatorio [semilla]
```

### Parámetros

| Parámetro | Restricción | Descripción |
| `<regla>` | Entero en `[0, 255]` | Número de la regla elemental de Wolfram. |
| `<ancho>` | Entero `>= 1` | Cantidad de células en la fila. |
| `<generaciones>` | Entero `>= 0` | Número total de generaciones a imprimir (incluyendo la generación 0). |

| Opcional |
| `aleatorio` | Literal `aleatorio` | Activa la condición inicial aleatoria en lugar de una sola célula viva al centro. |
| `[semilla]` | Entero | Semilla explícita para la generación aleatoria; si se omite, se deriva del tiempo POSIX actual en milisegundos. |

### Validación de errores

Si faltan argumentos, algún valor no es un entero válido o queda fuera de rango, el programa escribe el mensaje de error, tambien muestra una guía donde se dan los parámetros de los datos a ingresar y un ejemplo


```bash
los argumentos deben ser numeros enteros
uso: ./prog <regla 0-255> <ancho> <generaciones> [aleatorio [semilla]]
ej:  ./prog 90 31 8
     ./prog 30 61 30 aleatorio        (condicion inicial aleatoria)
     ./prog 30 61 30 aleatorio 42     (aleatoria con semilla fija)
```

## Diseño e implementación

### Modelo de datos y condiciones iniciales

El estado del autómata se representa como un registro en `Automata.hs`:

```haskell
data Automata = Automata
  { celdas     :: [Bool]  -- True = viva, False = muerta
  , regla      :: Int     -- número de regla de Wolfram (0..255)
  , generacion :: Int     -- generación actual donde 0 = condición inicial
  } deriving (Show, Eq)
```

Se proveen dos constructores para la generación 0:

1. **Condición inicial estándar (`nuevoAutomata`)**: crea una lista de longitud `ancho` con una única célula viva en el índice `ancho \`div\` 2`.
2. **Condición inicial aleatoria (`nuevoAutomataAleatorio`)**: genera la fila inicial usando un generador lineal congruencial (LCG) puro definido en `aleatorios`:

```haskell
siguiente x = (1103515245 * x + 12345) `mod` 2147483648
```

De cada valor pseudoaleatorio se extrae el bit 16 mediante `(x \`shiftR\` 16) .&. 1 == 1` para evitar la baja entropía de los bits menos significativos. Cuando el usuario ejecuta `./prog ... aleatorio` sin semilla, `main.hs` obtiene una semilla entera a partir de `getPOSIXTime` escalado a milisegundos (`floor . (* 1000) <$> getPOSIXTime`).

### Reglas elementales de Wolfram y bordes periódicos

Para calcular la siguiente generación con **bordes periódicos** (topología circular donde la primera célula es vecina de la última y viceversa), la función `vecindades` construye todas las tripletas `(izquierda, centro, derecha)` en una sola pasada con `zip3`:

```haskell
vecindades :: [Bool] -> [(Bool, Bool, Bool)]
vecindades [] = []
vecindades cs = zip3 (last cs : cs) cs (tail cs ++ [head cs])
```

Cada tripleta `(l, c, d)` se interpreta como un número binario de 3 bits entre `0` (`000`) y `7` (`111`), y `aplicarRegla` consulta directamente el bit correspondiente del entero de la regla usando `Data.Bits.testBit`:

```haskell
aplicarRegla :: Int -> (Bool, Bool, Bool) -> Bool
aplicarRegla r (l, c, d) = testBit r (4 * fromEnum l + 2 * fromEnum c + fromEnum d)
```

Por ejemplo, para la **regla 30** (`30 = 00011110` en binario), `tablaRegla 30` produce el siguiente mapeo:

| Vecindad `(l, c, d)` | `111` | `110` | `101` | `100` | `011` | `010` | `001` | `000` |
| **Índice de bit** | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
| **Nuevo estado (regla 30)** | `0` | `0` | `0` | `1` | `1` | `1` | `1` | `0` |

La transición pura de una generación se define en `paso :: Automata -> Automata`, que aplica `aplicarRegla (regla a)` a cada vecindad e incrementa `generacion` en 1. La representación visual se realiza con `mostrarCeldas`, mapeando `True` a `'#'` y `False` a `' '`.

### Simulación con la mónada `State`

Para desacoplar el manejo del estado y evitar pasar el registro `Automata` manualmente entre pasos sucesivos, se implementó la simulación sobre `State Automata` (siguiendo el enfoque de [Haskell Wiki — State Monad](https://wiki.haskell.org/State_Monad)):

- **`pasoS :: State Automata ()`**: actualiza implícitamente el estado interno aplicando `modify paso`.
- **`avanzar :: Int -> State Automata ()`**: ejecuta `n` transiciones consecutivas mediante `replicateM_ n pasoS`.
- **`simular :: Int -> State Automata [String]`**: obtiene la representación de la generación inicial con `gets mostrarCeldas` y luego encadena `n - 1` pasos con `replicateM (n - 1) (pasoS >> gets mostrarCeldas)`, devolviendo las `n` líneas listas para imprimir.

En `main.hs`, la computación monádica se evalúa una única vez con el estado inicial:

```haskell
mapM_ putStrLn (evalState (simular gens) inicial)
```

## Ejemplos de ejecución

### Regla 90 (patrón fractal tipo triángulo de Sierpiński)

```bash
$ ./prog 90 31 8
               #               
              # #              
             #   #             
            # # # #            
           #       #           
          # #     # #          
         #   #   #   #         
        # # # # # # # #        
```

### Regla 30 (evolución caótica desde una célula central)

```bash
$ ./prog 30 31 8
               #               
              ###              
             ##  #             
            ## ####            
           ##  #   #           
          ## #### ###          
         ##  #    #  #         
        ## ####  ######        
```

### Regla 110 (comportamiento complejo)

```bash
$ ./prog 110 31 8
               #               
              ##               
             ###               
            ## #               
           #####               
          ##   #               
         ###  ##               
        ## # ###               
```

### Condición inicial aleatoria con semilla fija

```bash
$ ./prog 30 31 8 aleatorio 42
#### ## ##    # #####    ######
     #  # #  ## #    #  ##     
    ##### ####  ##  ##### #    
   ##     #   ### ###     ##   
  ## #   ### ##   #  #   ## #  
 ##  ## ##   # # ###### ##  ## 
## ###  # # ## # #      # ### #
   #  ### # #  # ##    ## #   #
```

Para una semilla automática distinta en cada ejecución:

```bash
$ ./prog 30 61 30 aleatorio
```
