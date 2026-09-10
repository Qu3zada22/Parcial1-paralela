# Multiplicación de Matrices Densas - Documentación Técnica

**Autor:** Kevin Villagrán  
**Problema:** Multiplicación de Matrices Densas  
**Lenguaje:** C  
**Paralelización:** OpenMP  

---

## 1. Descripción del Problema

### Contexto

Se tienen dos matrices cuadradas, `A` y `B`, y se desea calcular una tercera
matriz `C` mediante la operación `C = A × B`. Cada elemento `C[fila][j]` se
obtiene multiplicando los elementos correspondientes de una fila de `A` y una
columna de `B`, y sumando esos productos.

El diagrama plantea matrices de `1M × 1M` para representar una carga masiva. En
la implementación, el tamaño se recibe mediante `n` y su valor predeterminado
es `1000`, lo que permite ajustar el problema a la memoria disponible.

### Entrada

- Dimensión `n` de las matrices; por defecto, `N_DEFAULT = 1000`
- Número opcional de trabajadores `P`
- Matrices `A` y `B` de tipo `double`
- Valores pseudoaleatorios entre 0 y 9, generados con semilla `42`

### Salida

- Matriz resultante `C = A × B`
- Muestra de hasta `6 × 6` elementos de `C`
- Checksum de todos los elementos calculados
- Tiempo de ejecución de la multiplicación

---

## 2. Solución Secuencial

### Algoritmo

```text
1. Recorrer cada fila de A
2. Para cada fila, recorrer cada columna de B
3. Inicializar suma = 0
4. Recorrer k desde 0 hasta n - 1
5. Acumular A[fila][k] × B[k][j] en suma
6. Guardar suma en C[fila][j]
```

La operación principal se expresa con tres ciclos anidados:

```c
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

### Complejidad

- **Tiempo:** `O(n³)`, porque se realizan tres recorridos anidados
- **Espacio:** `O(n²)`, correspondiente a las tres matrices
- **Operaciones aproximadas:** `2n³`, contando multiplicaciones y sumas

---

## 3. Flujo Representado en el Diagrama

El diagrama divide el proceso en dos partes: la coordinación general y el
trabajo que realiza cada trabajador.

### Coordinación general

```text
Inicio
  ↓
Declarar A, B y C; C comienza con valores en 0
  ↓
Definir el número de trabajadores P
  ↓
Asignar a cada trabajador un conjunto de filas
  ↓
Crear los P trabajadores
  ↓
Esperar a que todos terminen
  ↓
Fin
```

### Flujo de cada trabajador

```text
Inicio Trabajador
  ↓
Tomar una fila asignada
  ↓
Para cada columna j
  ↓
suma = 0
  ↓
Para cada posición k
  ↓
suma += A[fila][k] × B[k][j]
  ↓
C[fila][j] = suma
  ↓
Continuar con la siguiente columna y la siguiente fila asignada
  ↓
Fin Trabajador
```

En el código no se crean los trabajadores manualmente. OpenMP realiza esa
tarea, distribuye las filas y espera a que todos terminen mediante la barrera
implícita del `parallel for`.

---

## 4. Estrategia de Paralelización

### Tipo de Descomposición

Se utiliza **paralelismo de datos por filas**. Cada trabajador recibe un bloque
de filas de `C` y utiliza las mismas filas de `A` para calcularlas. La matriz
`B` es compartida y únicamente se consulta.

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

### Correspondencia con el diagrama

- `omp_set_num_threads(P)` define el número solicitado de trabajadores.
- `parallel for` crea el equipo de trabajadores y paraleliza el ciclo de filas.
- `schedule(static)` reparte las filas en bloques de tamaño similar.
- Cada trabajador ejecuta localmente los ciclos de columnas `j` y productos `k`.
- La barrera implícita espera a todos antes de medir el tiempo final.

---

## 5. Análisis de Colisiones (Race Conditions)

| Variable | Uso | Protección necesaria |
|----------|-----|----------------------|
| `matrizA` | Compartida, solo lectura | Ninguna |
| `matrizB` | Compartida, solo lectura | Ninguna |
| `resultado` | Compartida, escritura por filas distintas | Ninguna |
| `fila` | Índice privado del `parallel for` | Administrada por OpenMP |
| `j`, `k`, `suma` | Declaradas dentro de cada iteración | Privadas para cada trabajador |

No se necesita `atomic`, `critical` ni `reduction` durante la multiplicación.
Dos trabajadores no escriben la misma fila de `resultado`, por lo que no existe
una colisión entre sus asignaciones.

El checksum se calcula después del `parallel for`. Para ese momento, la barrera
implícita garantiza que toda la matriz resultante ya fue completada.

---

## 6. Decisiones de Diseño

### ¿Por qué paralelizar por filas?

1. **Independencia:** cada fila de `C` puede calcularse sin depender de otra.
2. **Carga uniforme:** todas las filas requieren aproximadamente el mismo trabajo.
3. **Reparto simple:** `schedule(static)` evita el costo de reasignar trabajo.
4. **Escrituras separadas:** cada trabajador modifica una región distinta de `C`.
5. **Buena granularidad:** una fila contiene `n²` operaciones aproximadas.

### Memoria dinámica

Las matrices se almacenan como arreglos lineales reservados con `malloc` y
`calloc`. El elemento de la fila `i` y columna `j` se accede mediante
`i * n + j`. Esto permite elegir `n` durante la ejecución sin usar arreglos de
tamaño fijo en la pila.

### Validación mediante checksum

La suma de todos los elementos de `C` permite comprobar que distintas
configuraciones de trabajadores producen el mismo resultado. No sustituye una
comparación elemento por elemento, pero ayuda a detectar cambios en el cálculo.

---

## 7. Compilación y Ejecución

### Compilar

```bash
make all
```

Genera:

- `bin/matrices_secuencial`
- `bin/matrices_paralelo`

### Ejecutar la versión secuencial incluida

```bash
make run_mat_sec
```

Esta versión usa el ejemplo fijo de `3 × 3` definido en
`secuencial/matrices_secuencial.c`.

### Ejecutar la versión paralela

```bash
make run_mat_par N=1000 P=8
```

También puede ejecutarse directamente:

```bash
./bin/matrices_paralelo 1000 8
```

### Ejecutar la prueba de escalabilidad

```bash
make bench_mat N=1000
```

El objetivo `bench_mat` ejecuta el programa con `1`, `2`, `4`, `8` y `16`
trabajadores.

---

## 8. Resultados Esperados

### Validez funcional

- La matriz `C` contiene el producto de `A` y `B`.
- El resultado debe conservar el mismo checksum al cambiar `P`.
- Con `N=1000` y semilla `42`, las mediciones registradas obtuvieron un checksum
  de `20,224,732,496`.

### Desempeño

- La carga `O(n³)` ofrece suficiente trabajo para aprovechar varios núcleos.
- El rendimiento mejora mientras existan núcleos y ancho de banda disponibles.
- Agregar más trabajadores no garantiza una mejora indefinida.

Los tiempos, el speedup y la eficiencia medidos se encuentran en
`docs/METRICAS_KEVIN.md`.

---

## Referencias

- OpenMP: https://www.openmp.org/
- OpenMP Worksharing-Loop Construct: https://www.openmp.org/spec-html/5.0/openmpsu41.html
- Documentación de métricas del proyecto: `docs/METRICAS_KEVIN.md`
