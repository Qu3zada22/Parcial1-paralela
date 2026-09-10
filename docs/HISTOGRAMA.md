# Histograma Masivo - Documentación Técnica

**Autor:** Anggie Quezada  
**Problema:** Histograma Masivo  
**Lenguaje:** C  
**Paralelización:** OpenMP  

---

## 1. Descripción del Problema

### Contexto
Se tiene un arreglo unidimensional con una cantidad masiva de mediciones de temperatura en punto flotante. El objetivo es clasificar cada medición en 100 rangos distintos (bins) y contar cuántas mediciones caen en cada uno, **sin asumir de antemano cuál es el valor mínimo o máximo del conjunto de datos**.

### Entrada
- Arreglo de `float` de tamaño `N = 10,000,000` (escalado de "miles de millones" para pruebas locales)
- Datos generados aleatoriamente en rango aproximado 0-100

### Salida
- Arreglo de `long` con 100 contadores (uno por bin)
- Validación: suma total de contadores = N

---

## 2. Solución Secuencial

### Algoritmo

```
1. Primer ciclo: Buscar Min y Max
   - Recorrer arreglo [0..N-1]
   - Actualizar mínimo y máximo encontrados

2. Calcular ancho de rango
   - anchoRango = (Max - Min) / 100

3. Segundo ciclo: Construir histograma
   - Recorrer arreglo [0..N-1]
   - Para cada dato:
     * Calcular índice = (dato - Min) / anchoRango
     * Validar que índice esté en [0..99]
     * Incrementar histograma[índice]
```

### Complejidad
- **Tiempo:** O(2N) = O(N)
- **Espacio:** O(N) para el arreglo + O(100) para histograma

---

## 3. Estrategia de Paralelización

### Tipo de Descomposición
**Paralelismo de datos puro** en ambos ciclos. El arreglo se divide en bloques contiguos entre los hilos.

### Ciclo 1: Búsqueda de Min/Max

**Patrón:** Reducción

```c
#pragma omp parallel for reduction(max:Max) reduction(min:Min)
for (int i = 1; i < N; i++) {
    float dato = arreglo[i];
    if (dato > Max) Max = dato;
    if (dato < Min) Min = dato;
}
```

- Cada hilo calcula su propio mínimo y máximo local
- OpenMP combina automáticamente los resultados parciales
- **Ventaja:** Sin race conditions, sin overhead de sincronización dentro del ciclo

### Ciclo 2: Construcción del Histograma

**Patrón:** Actualización de datos compartidos con protección atómica

```c
#pragma omp parallel for schedule(static)
for (int i = 0; i < N; i++) {
    float dato = arreglo[i];
    int indice = (int)((dato - Min) / anchoRango);
    
    if (indice >= NUM_BINS) indice = NUM_BINS - 1;
    if (indice < 0) indice = 0;
    
    #pragma omp atomic
    histograma[indice]++;
}
```

- Cada hilo clasifica independientemente sus datos
- `#pragma omp atomic` protege el incremento (es atómico a nivel de hardware)
- `schedule(static)` es óptimo porque cada iteración cuesta lo mismo

---

## 4. Análisis de Colisiones (Race Conditions)

### Primer Ciclo
| Variable | Tipo | Protección |
|----------|------|-----------|
| `Max`, `Min` | Compartida (lectura + escritura) | `reduction()` |

Sin protección: dos hilos pueden leer el mismo Max, comparan contra datos diferentes, y se pierde una actualización válida.

### Segundo Ciclo
| Variable | Tipo | Protección |
|----------|------|-----------|
| `histograma[indice]` | Compartida (escritura) | `atomic` |

Sin protección: dos hilos pueden calcular el mismo índice, y el `++` internamente es leer-sumar-escribir (3 operaciones), causando pérdida de conteos.

---

## 5. Decisiones de Diseño

### ¿Por qué el Histograma es "fácil" de paralelizar?

1. **Sin desbalance de carga:** Cada iteración cuesta O(1) → se puede usar `schedule(static)`
2. **Sin dependencias entre iteraciones:** Cada elemento del arreglo se procesa independientemente
3. **Operaciones simples:** Comparaciones y búsqueda de índice, sin lógica compleja
4. **Estructuras de datos simples:** Arreglos 1D, sin punteros cruzados

**Comparación con otros algoritmos:**
- **Grafos:** Algunos nodos tienen muchos más vecinos → desbalance de carga
- **Multiplicación de Matrices:** Requiere dos niveles de bucles anidados + sincronización
- **Blur:** Datos espaciales correlacionados → potencial para falsos compartidos

---

## 6. Compilación y Ejecución

### Compilar
```bash
make all
```

Genera:
- `bin/histograma_secuencial`
- `bin/histograma_paralelo`

### Ejecutar versión secuencial
```bash
make run_sec
# o
./bin/histograma_secuencial
```

### Ejecutar versión paralela
```bash
make run_par
# o
./bin/histograma_paralelo
```

### Ejecutar benchmark
```bash
./benchmark.sh 5 8  # 5 ejecuciones con 8 threads
```

---

## 7. Resultados Esperados

### Validez Funcional
- Ambas versiones producen exactamente el mismo histograma
- Total clasificado siempre = N

### Desempeño
- **Versión secuencial:** ~0.01 segundos (en i7/M1 con N=10M)
- **Versión paralela:** Variable según número de threads y overhead
  - Con overhead de creación de threads: posiblemente más lenta para N pequeño
  - Con N muy grande (miles de millones): speedup observable en máquinas con muchos cores

---

## 8. Métricas Individuales (Anggie)

[Completar después de ejecutar benchmark.sh con datos reales]

- Tiempo secuencial promedio: _____
- Tiempo paralelo promedio (8 threads): _____
- Speedup: _____
- Eficiencia: _____
- Observaciones: _____

---

## Referencias

- OpenMP Directive Syntax: https://www.openmp.org/
- Reduction Clause: https://www.openmp.org/spec-html/5.0/openmpsu59.html
- Atomic Directive: https://www.openmp.org/spec-html/5.0/openmpsu60.html
