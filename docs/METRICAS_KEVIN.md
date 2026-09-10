# Métricas de Desempeño - Multiplicación de Matrices Densas

**Estudiante:** Kevin Villagrán  
**Fecha de Pruebas:** 2026-09-09  
**Máquina:** Laptop Windows  
**CPU:** 12th Gen Intel Core i7-12650H (10 cores físicos / 16 hilos lógicos)  
**RAM:** 15.7 GB  
**Sistema Operativo:** Windows 11 Home (10.0.26200)  

---

## Datos de Prueba

- **N (dimensión de las matrices):** 1000 x 1000
- **Elementos por matriz:** 1,000,000
- **Operaciones:** 2 x N³ = 2,000,000,000 flops
- **Tipo de dato:** `double`
- **Generación:** `rand() % 10` con seed=42
- **Algoritmo:** C = A x B, triple ciclo anidado (orden i-j-k) según el diagrama de flujo
- **Descomposición:** por bloques de filas de C entre P trabajadores (`schedule(static)`)

---

## Resultados: Versión Secuencial

Baseline medido con el mismo binario ejecutado con **P=1 trabajador**, para que
secuencial y paralelo compartan datos, compilador y banderas de optimización.

| Métrica | Valor |
|---------|-------|
| Tiempo promedio (ms) | 588.804 |
| Desv. Estándar (ms) | 16.444 |
| Mínimo (ms) | 565.708 |
| Máximo (ms) | 610.385 |

### Detalles de ejecuciones

```
Run 1: 565.708 ms
Run 2: 584.953 ms
Run 3: 596.643 ms
Run 4: 610.385 ms
Run 5: 586.329 ms
```

---

## Resultados: Versión Paralela (8 threads)

| Métrica | Valor |
|---------|-------|
| Tiempo promedio (ms) | 167.290 |
| Desv. Estándar (ms) | 14.456 |
| Mínimo (ms) | 155.790 |
| Máximo (ms) | 187.285 |
| Speedup | 3.5197 |
| Eficiencia | 0.4400 |

### Detalles de ejecuciones

```
Run 1: 178.078 ms
Run 2: 155.790 ms
Run 3: 158.529 ms
Run 4: 156.766 ms
Run 5: 187.285 ms
```

---

## Escalabilidad: tiempo vs. número de trabajadores

Promedio de 3 ejecuciones por configuración, N=1000.

| P (trabajadores) | Tiempo (s) | Speedup | Eficiencia |
|------------------|-----------|---------|------------|
| 1  | 0.6107 | 1.000 | 100.0% |
| 2  | 0.3165 | 1.930 | 96.5% |
| 4  | 0.1975 | 3.093 | 77.3% |
| 8  | 0.1473 | 4.147 | 51.8% |
| 10 | 0.1603 | 3.810 | 38.1% |
| 16 | 0.1979 | 3.087 | 19.3% |

**Punto óptimo: P=8** (speedup 4.15x). A partir de ahí el rendimiento se degrada.

---

## Análisis y Conclusiones

### Speedup Observado

**3.52x con 8 threads** — La versión paralela es **~3.5 veces MÁS RÁPIDA** que la secuencial,
con un pico de **4.15x** en la medición de escalabilidad.

A diferencia del histograma, aquí la paralelización **sí es rentable**, porque el trabajo
por hilo (N²/P elementos, cada uno con N multiplicaciones) es órdenes de magnitud mayor
que el overhead de crear los threads.

### Razones del Desempeño

**Factores Positivos (explican el speedup real):**
- [x] **Cero sincronización en el ciclo caliente:** cada trabajador escribe únicamente las filas de C que le fueron asignadas, así que no hace falta `atomic` ni `critical`
- [x] **B es de solo lectura:** compartida entre todos los hilos sin riesgo de condición de carrera
- [x] **Granularidad gruesa:** con N=1000 y P=8, cada hilo hace 125 filas x 1000 columnas x 1000 productos = 125M operaciones, muy por encima del costo de crear el thread
- [x] **Sin desbalance de carga:** todas las filas cuestan exactamente lo mismo, por lo que `schedule(static)` reparte perfecto y no hay hilos ociosos
- [x] **Sin false sharing:** los bloques de filas son contiguos y grandes, cada hilo trabaja en líneas de cache distintas
- [x] **Resultados idénticos en ambas versiones** (checksum = 20,224,732,496 en las 10 ejecuciones)

**Factores Negativos (explican por qué no llega a 8x):**
- [x] **Límite de ancho de banda de memoria:** el acceso `B[k*n+j]` recorre B por columnas, saltando N*8 bytes por iteración; los hilos saturan el bus de memoria antes de saturar los cores
- [x] **Cores híbridos (P-cores + E-cores):** el i7-12650H tiene 6 P-cores y 4 E-cores; los E-cores son más lentos y con `schedule(static)` reciben la misma cantidad de filas, así que los P-cores terminan y esperan en la barrera
- [x] **Hyperthreading no aporta:** de P=10 a P=16 se usan hilos lógicos que comparten unidades de ejecución, y el tiempo empeora (0.160 s → 0.198 s)

### ¿Por qué la eficiencia cae de 96.5% a 19.3%?

1. **P=2 y P=4 escalan casi ideal** (96.5% y 77.3%): hay P-cores físicos libres y ancho de banda suficiente.

2. **P=8 ya cruza al territorio de E-cores** (51.8%): la barrera implícita del `parallel for` hace que todos esperen al hilo más lento.
   ```
   Speedup ideal con 8:  8.00x
   Speedup obtenido:     4.15x
   Pérdida:              núcleos heterogéneos + ancho de banda
   ```

3. **P=16 usa hyperthreading** (19.3%): dos hilos por core físico compiten por la misma FPU, sin ganancia real y con más overhead de scheduling.

---

## Conclusión

El análisis demuestra que **la paralelización es técnicamente correcta y económicamente rentable** para este problema. Es el caso opuesto al histograma: aquí la razón trabajo/overhead es alta y no existe contención entre hilos, así que el speedup es real y sostenido.

### Recomendaciones para mejorar

1. **Cambiar el orden de ciclos a i-k-j** → B se recorre por filas (secuencial en memoria) en vez de por columnas, mejorando el uso de cache drásticamente
   ```c
   // En lugar de acumular en 'suma' con B[k*n+j] saltando por columnas:
   for (int k = 0; k < n; k++) {
       double a = A[fila*n + k];
       for (int j = 0; j < n; j++)
           C[fila*n + j] += a * B[k*n + j];   // acceso contiguo a B
   }
   ```
2. **Usar `schedule(dynamic)` o `guided`** → compensa que los E-cores sean más lentos que los P-cores
3. **Bloqueo por tiles (cache blocking)** → dividir en submatrices que quepan en L2 para reducir el tráfico a RAM
4. **Limitar a P=8** en esta máquina → es el punto óptimo; más threads empeoran el tiempo
5. **Aumentar N a 2000-4000** → más trabajo por hilo amortiza aún mejor el overhead

---

## Validación de Corrección

✅ **Secuencial (P=1):** Checksum = 20,224,732,496  
✅ **Paralelo (P=8):** Checksum = 20,224,732,496  
✅ **Matrices idénticas:** Sí (checksum estable en las 10 ejecuciones y en P=1,2,4,8,10,16)

---

## Notas Técnicas

- Compilador: `clang -O3 -fopenmp` (el `gcc-16` del Makefile no está disponible en Windows; el gcc de MSYS2 falla al invocar `cc1.exe` en esta máquina)
- Medición: `omp_get_wtime()` alrededor del `parallel for` únicamente; no incluye reserva de memoria ni llenado de las matrices
- Múltiples runs: 5 por versión para capturar variabilidad, 3 por punto en la tabla de escalabilidad
- Desviación estándar muestral (n-1)
- Run 5 paralelo (187 ms) fue la más alta, posiblemente scheduling del SO sobre los E-cores
- El checksum sirve como verificación de que la paralelización no altera el resultado
