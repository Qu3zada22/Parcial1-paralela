#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>

#define N 10000000      
#define NUM_BINS 100

int main() {
   
    float *arreglo = malloc(N * sizeof(float));
    long *histograma = calloc(NUM_BINS, sizeof(long));

    if (arreglo == NULL || histograma == NULL) {
        printf("Error al reservar memoria\n");
        return 1;
    }


    srand(42);
    for (int j = 0; j < N; j++) {
        arreglo[j] = ((float)rand() / RAND_MAX) * 100.0f;
    }

    double inicio = omp_get_wtime();

    // PRIMER CICLO 
    // Encontrar Min y Max recorriendo todo el arreglo
    float Max = arreglo[0];
    float Min = arreglo[0];
    
    #pragma omp parallel for reduction(max:Max) reduction(min:Min)
    for (int i = 1; i < N; i++) {
        float dato = arreglo[i];
        if (dato > Max) Max = dato;
        if (dato < Min) Min = dato;
    }
    // FIN PRIMER CICLO ----

    // Calcular ancho de rango
    double anchoRango = (Max - Min) / NUM_BINS;

    // ---- SEGUNDO CICLO (construcción del histograma - PARALELIZADO) ----
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < N; i++) {
        float dato = arreglo[i];
        int indice = (int)((dato - Min) / anchoRango);

        // Validación: evitar que el valor justo en Max se salga del arreglo
        if (indice >= NUM_BINS) indice = NUM_BINS - 1;
        if (indice < 0) indice = 0;

        #pragma omp atomic
        histograma[indice]++;
    }
    // ---- FIN SEGUNDO CICLO ----

    double fin = omp_get_wtime();
    double tiempo = fin - inicio;

    // Mostrar histograma (frecuencia)
    long total = 0;
    printf("Min encontrado: %.4f | Max encontrado: %.4f\n\n", Min, Max);
    for (int b = 0; b < NUM_BINS; b++) {
        printf("Bin %3d [%.2f - %.2f): %ld mediciones\n",
               b, Min + b * anchoRango, Min + (b + 1) * anchoRango, histograma[b]);
        total += histograma[b];
    }
    printf("\nTotal clasificado: %ld (deberia ser %d)\n", total, N);
    printf("\nTiempo de ejecución: %.6f segundos\n", tiempo);

    free(arreglo);
    free(histograma);
    return 0;
}
