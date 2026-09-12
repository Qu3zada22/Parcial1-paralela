# Histograma Masivo - Documentación Técnica
[Enlace al repo](https://github.com/Qu3zada22/Parcial1-paralela)

## Problema: Histograma Masivo  

## 1. Contexto y Datos
Se tiene una lista gigante de temperaturas representadas como números con decimales y se quiere organizarlas en 100 grupos para contar cuántas caen en cada uno, sin saber de antemano cuál es el valor mínimo o máximo.

### Datos de prueba
- Tamaño de la muestra (N): 10,000,000 elementos (float), un tamaño suficiente para medir con estabilidad el tiempo de cómputo y comparar el costo real de usar OpenMP.
- Origen: Generados de forma pseudoaleatoria simulando lecturas de sensores en un rango de 0 a 100.
- Estructura en memoria: Un arreglo unidimensional contiguo (float), lo que facilita un buen uso de la caché del procesador al recorrerlo secuencialmente.



## 2. Solución Secuencial

### Algoritmo
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

## 3. Estrategia de Paralelización

Para evaluar si el programa puede acelerarse, dividimos el trabajo entre varios hilos usando OpenMP con un enfoque de paralelismo de datos puro: partir el arreglo en bloques y que cada hilo procese su parte.

### ¿Qué directivas usamos y por qué?

**a. Búsqueda de mínimo y máximo**
```
#pragma omp parallel for reduction(min:Min) reduction(max:Max)
```
Como todos los hilos necesitan actualizar las mismas variables de mínimo y máximo, usar una cláusula de reducción le dice a OpenMP que cada hilo mantenga una copia local y al final combine los resultados de forma segura. Con esto evitamos condiciones de carrera sin necesidad de poner locks pesados dentro del ciclo.

**b. Para construir el Histograma**

``` 
#pragma omp parallel for schedule(static)
#pragma omp atomic
```
Cada hilo calcula en qué bin cae cada temperatura de forma independiente. Sin embargo, como varios hilos podrían intentar actualizar el mismo contador del histograma al mismo tiempo, usamos #pragma omp atomic para garantizar que la operación de incremento (++) sea atómica a nivel de hardware y no se pierdan datos.




## 4. Manejo de condiciones de carrera y balance de carga

### Condiciones de carrera: 
Quedaron cubiertas con reduction en el primer ciclo y atomic en el segundo. Si no las hubiéramos puesto, tendríamos race conditions clásicas donde los hilos sobreescriben resultados ajenos (en el min/max) o pierden sumas de conteo (en los bins).

### Desbalance de carga y Scheduling: 
Elegimos schedule(static) porque clasificar una temperatura y sumarla al bin toma prácticamente el mismo tiempo para cualquier elemento del arreglo. No hay tareas más pesadas que otras, así que dividir el trabajo en bloques estáticos iguales desde el inicio es lo más eficiente y evita gastar ciclos de CPU decidiendo quién hace qué.


## 5. Resultados y Métricas

### Análisis del algoritmo secuencial vs. paralelo

El algoritmo secuencial original recorre el arreglo dos veces: una para hallar los límites y otra para clasificar, por lo que su costo es $O(2N) = O(N)$. La versión paralela conserva el orden $O(N)$ y reparte elementos entre los núcleos, pero eso no garantiza una reducción de tiempo.

En las métricas del equipo, el histograma paralelo fue más lento que el secuencial en las máquinas medidas. El segundo recorrido actualiza solo 100 bins compartidos; aunque `atomic` evita perder conteos, también serializa los incrementos cuando varios hilos caen en el mismo bin. El overhead de crear y coordinar hilos, junto con esa contención, supera el beneficio de repartir el recorrido. Por ello, para esta implementación y tamaño de datos, la recomendación es mantener la versión secuencial; una alternativa para mejorar el paralelo sería usar histogramas locales por hilo y combinarlos al final.

## 6. Pruebas de ejecución y métricas individuales

### Pruebas de corrida

- Melisa Mendizabal: METRICAS_MELISA.md
- Anggie Quezada: METRICAS_ANGGIE.md
- Kevin Villagrán: METRICAS_KEVIN.md


## 7. Compilar
```bash
make all
```

Genera:
- bin/histograma_secuencial
- bin/histograma_paralelo

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


