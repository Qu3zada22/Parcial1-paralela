# Multiplicación de Matrices Densas - Documentación Técnica
[Enlace al repo](https://github.com/Qu3zada22/Parcial1-paralela)

## Problema: Multiplicación de Matrices Densas

## 1. Contexto y Datos
Se tienen dos matrices cuadradas A y B, y se quiere calcular una tercera matriz C mediante C = A × B. Cada elemento C[fila][j] se obtiene multiplicando los elementos correspondientes de una fila de A y una columna de B, y sumando esos productos.

### Datos de prueba
- Tamaño de la muestra (n): 1000 x 1000 por defecto (N_DEFAULT = 1000), un tamaño suficiente para que el cómputo (O(n³)) sea perceptible y aproveche varios núcleos, sin agotar la memoria disponible.
- Origen: Valores pseudoaleatorios entre 0 y 9, generados con semilla 42, simulando datos numéricos genéricos de entrada.
- Estructura en memoria: Arreglos lineales de tipo `double` reservados con `malloc`/`calloc` (no matrices 2D fijas), accedidos como `A[fila * n + columna]`. Esto permite elegir `n` en tiempo de ejecución en vez de usar arreglos de tamaño fijo en la pila.

## 2. Solución Secuencial

### Algoritmo
1. Recorrer cada fila de A
2. Para cada fila, recorrer cada columna de B
3. Inicializar suma = 0
4. Recorrer k desde 0 hasta n - 1
5. Acumular A[fila][k] × B[k][j] en suma
6. Guardar suma en C[fila][j]

**Complejidad:** O(n³) en tiempo (tres ciclos anidados), O(n²) en espacio (las tres matrices).

## 3. Estrategia de Paralelización

Para acelerar el programa, dividimos el trabajo entre varios hilos usando OpenMP con un enfoque de **paralelismo de datos por filas**: cada hilo recibe un bloque de filas de C y usa las mismas filas de A para calcularlas. La matriz B es compartida y solo se consulta (lectura).

### ¿Qué directiva usamos y por qué?

```c
#pragma omp parallel for schedule(static)
for (int fila = 0; fila < n; fila++) {
    for (int j = 0; j < n; j++) {
        double suma = 0.0;
        for (int k = 0; k < n; k++) {
            suma += matrizA[fila * n + k] * matrizB[k * n + j];
        }
        resultado[fila * n + j] = suma;
    }
}
```

`parallel for` reparte las filas del ciclo externo entre los hilos, y `omp_set_num_threads(P)` define cuántos trabajadores se usan. Como cada hilo escribe únicamente en las filas de `resultado` que le tocaron, no hace falta ninguna directiva adicional de sincronización para proteger la escritura.

## 4. Manejo de condiciones de carrera y balance de carga

### Condiciones de carrera
No se necesita `atomic`, `critical` ni `reduction`. Dos hilos nunca escriben la misma fila de `resultado`, `matrizA` y `matrizB` son de solo lectura, y las variables `j`, `k` y `suma` se declaran dentro del ciclo, por lo que cada hilo tiene su propia copia privada. El checksum final se calcula después del `parallel for`, cuando la barrera implícita ya garantiza que toda la matriz está completa.

### Desbalance de carga y Scheduling
Elegimos `schedule(static)` porque todas las filas cuestan exactamente lo mismo: cada una implica n² operaciones sin importar su posición. Al no existir filas "más pesadas" que otras, repartirlas en bloques fijos desde el inicio es lo más eficiente y evita el overhead de reasignar trabajo dinámicamente.

## 5. Resultados y Métricas

### Análisis del algoritmo secuencial vs. paralelo
El algoritmo secuencial hace O(n³) operaciones sin ninguna posibilidad de paralelismo. Al repartir las n filas del resultado entre P hilos, cada uno hace aproximadamente n²·(n/P) operaciones independientes, sin sincronización durante el cálculo. A diferencia del histograma, aquí el trabajo por hilo es mucho mayor que el overhead de crear los hilos, por lo que la paralelización sí produce una mejora real y sostenida — aunque no lineal, porque el ancho de banda de memoria y la heterogeneidad de núcleos limitan la ganancia a partir de cierto número de hilos.

## 6. Pruebas de ejecución y métricas individuales

### Pruebas de corrida

- Melisa Mendizabal: METRICAS_MELISA.md
- Kevin Villagrán: METRICAS_KEVIN.md
- Anggie Quezada: METRICAS_ANGGIE.md

## 7. Compilar
```bash
make all
```

Genera:
- bin/matrices_secuencial
- bin/matrices_paralelo

### Ejecutar versión secuencial (ejemplo fijo 3x3)
```bash
make run_mat_sec
```

### Ejecutar versión paralela
```bash
make run_mat_par N=1000 P=8
# o
./bin/matrices_paralelo 1000 8
```

### Ejecutar prueba de escalabilidad
```bash
make bench_mat N=1000
```

### Ejecutar varias corridas por configuración (para métricas)
```bash
make bench_mat_reps N=1000 REPS=5
```