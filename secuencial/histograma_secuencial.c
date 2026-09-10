#include <stdio.h>
#include <stdlib.h>
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

    clock_t inicio = clock();

    // PRIMER CICLO 
  
    float Max = arreglo[0];
    float Min = arreglo[0];
    for (int i = 1; i < N; i++) {
        float dato = arreglo[i];
        if (dato > Max) Max = dato;
        if (dato < Min) Min = dato;
    }


   
    double anchoRango = (Max - Min) / NUM_BINS;

    // SEGUNDO CICLO 
    for (int i = 0; i < N; i++) {
        float dato = arreglo[i];
        int indice = (int)((dato - Min) / anchoRango);

        // Validación: evitar que el valor justo en Max se salga del arreglo
        if (indice >= NUM_BINS) indice = NUM_BINS - 1;
        if (indice < 0) indice = 0;

        histograma[indice]++;
    }


    clock_t fin = clock();
    double tiempo = (double)(fin - inicio) / CLOCKS_PER_SEC;


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
