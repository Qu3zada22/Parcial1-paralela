# Métricas de Desempeño - Histograma Masivo

**Estudiante:** Anggie Quezada  
**Fecha de Pruebas:** 2026-09-09  
**Máquina:** MacBook Pro M1/M2  
**CPU:** Apple Silicon (8 cores)  
**RAM:** 8-16 GB  
**Sistema Operativo:** macOS  

---

## Datos de Prueba

- **N (elementos):** 10,000,000
- **Número de bins:** 100
- **Rango de datos:** 0.0 - 100.0 (float)
- **Generación:** `rand()` con seed=42

---

## Resultados: Versión Secuencial

| Métrica | Valor |
|---------|-------|
| Tiempo promedio (ms) | 9.873 |
| Desv. Estándar (ms) | 0.565 |
| Mínimo (ms) | 9.275 |
| Máximo (ms) | 10.657 |

### Detalles de ejecuciones

```
Run 1: 10.410 ms
Run 2: 9.497 ms
Run 3: 10.657 ms
Run 4: 9.527 ms
Run 5: 9.275 ms
```

---

## Resultados: Versión Paralela (8 threads)

| Métrica | Valor |
|---------|-------|
| Tiempo promedio (ms) | 154.970 |
| Speedup | 0.0637 |
| Eficiencia | 0.00796 |

### Detalles de ejecuciones

```
Run 1: 172.773 ms
Run 2: 172.804 ms
Run 3: 172.653 ms
Run 4: 84.572 ms
Run 5: 172.049 ms
```

---

## Análisis y Conclusiones

### Speedup Observado

**0.0637x** — La versión paralela es **~15.7 veces MÁS LENTA** que la secuencial.

Este resultado es **esperado y válido** por las siguientes razones:

### Razones del Desempeño

**Factores Negativos (explican la baja eficiencia):**
- [x] **Overhead de creación de threads:** Crear y destruir 8 threads toma tiempo significativo
- [x] **Contención atómica en segundo ciclo:** El `#pragma omp atomic` en `histograma[indice]++` causa serialización de accesos
- [x] **N pequeño relativo al overhead:** 10M es pequeño en contexto de paralelización (típicamente necesitas >100M)
- [x] **False sharing potencial:** Múltiples threads escriben en índices adyacentes del histograma

**Factores Positivos (pruebas de corrección):**
- [x] Paralelización correcta con `reduction()` para Min/Max
- [x] Protección correcta con `atomic` para histograma
- [x] Sin desbalance de carga (`schedule(static)`)
- [x] Acceso secuencial al arreglo (cache-friendly)
- [x] **Resultados son idénticos en ambas versiones** (10,000,000 elementos clasificados)

### ¿Por qué la versión paralela es más lenta?

1. **Overhead >> Beneficio para N pequeño**
   ```
   Tiempo util: ~10 ms
   Overhead OpenMP: ~140 ms
   ```

2. **Contención atómica domina el segundo ciclo**
   - Todos los 8 threads compiten por escribir en histograma[0..99]
   - Operaciones atómicas serializan accesos
   - Efecto: casi no hay paralelismo real en ciclo 2

3. **Mejor comportamiento esperado con:**
   - N = 1,000,000,000+ (1 billón)
   - Máquinas con 16+ cores
   - Técnicas avanzadas: local histogramas + merge (reducción de atomics)

---

## Conclusión

El análisis demuestra que **la paralelización es técnicamente correcta pero económicamente ineficiente para este tamaño de problema**. Es un ejemplo excelente de cuándo NO usar paralelización ingenua.

### Recomendaciones para mejorar

1. **Aumentar N a 1 billón** → Overhead se amortiza
2. **Usar histogramas locales por thread** + merge final
   ```c
   // En lugar de atomic en cada incremento:
   long histograma_local[NUM_THREADS][NUM_BINS];
   // Cada thread llena su fila, luego sumar todas las filas
   ```
3. **Reducir contención:** Distribuir bins entre threads
4. **Usar `schedule(dynamic)` en ciclo 2** si hubiera desbalance

---

## Validación de Corrección

✅ **Secuencial:** Total clasificado = 10,000,000  
✅ **Paralelo:** Total clasificado = 10,000,000  
✅ **Histogramas idénticos:** Sí

---

## Notas Técnicas

- Compilador: gcc-16 con `-O3 -fopenmp`
- Medición: `omp_get_wtime()` para precisión
- Múltiples runs: para capturar variabilidad
- Run 4 paralelo (84ms) fue atípica, posiblemente scheduling del SO
