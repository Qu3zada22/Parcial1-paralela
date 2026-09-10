#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

#define N_DEFAULT 1000

int main(int argc, char *argv[]) {

    int n = (argc > 1) ? atoi(argv[1]) : N_DEFAULT;

    if (n <= 0) {
        printf("Error: N debe ser mayor que 0\n");
        return 1;
    }

    if (argc > 2) {
        int P = atoi(argv[2]);
        if (P <= 0) {
            printf("Error: P debe ser mayor que 0\n");
            return 1;
        }
        omp_set_num_threads(P);
    }

    double *matrizA   = malloc((size_t)n * n * sizeof(double));
    double *matrizB   = malloc((size_t)n * n * sizeof(double));
    double *resultado = calloc((size_t)n * n, sizeof(double));

    if (matrizA == NULL || matrizB == NULL || resultado == NULL) {
        printf("Error al reservar memoria\n");
        free(matrizA);
        free(matrizB);
        free(resultado);
        return 1;
    }

    srand(42);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            matrizA[i * n + j] = (double)(rand() % 10);
            matrizB[i * n + j] = (double)(rand() % 10);
        }
    }

    int trabajadores = omp_get_max_threads();
    printf("Multiplicacion de matrices %d x %d con %d trabajadores\n\n",
           n, n, trabajadores);

    double inicio = omp_get_wtime();

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

    double fin = omp_get_wtime();
    double tiempo = fin - inicio;

    double checksum = 0.0;
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            checksum += resultado[i * n + j];
        }
    }

    int muestra = (n < 6) ? n : 6;
    printf("Matriz resultado (C = A x B), esquina %dx%d:\n", muestra, muestra);
    for (int i = 0; i < muestra; i++) {
        for (int j = 0; j < muestra; j++) {
            printf("%8.0f", resultado[i * n + j]);
        }
        printf("%s\n", (muestra < n) ? "  ..." : "");
    }

    printf("\nChecksum: %.0f\n", checksum);
    printf("Tiempo de ejecucion: %.6f segundos\n", tiempo);

    free(matrizA);
    free(matrizB);
    free(resultado);

    return 0;
}
