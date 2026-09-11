CC = gcc
CFLAGS = -Wall -Wextra -O3
OPENMP = -fopenmp

# Directorios
SEC_DIR = secuencial
PAR_DIR = paralelo
BINS_DIR = bin

# Parametros por defecto para matrices: make run_mat_par N=1000 P=8
N = 1000
P = 8

# Targets
all: $(BINS_DIR) \
     $(BINS_DIR)/histograma_secuencial $(BINS_DIR)/histograma_paralelo \
     $(BINS_DIR)/matrices_secuencial $(BINS_DIR)/matrices_paralelo

$(BINS_DIR):
	mkdir -p $(BINS_DIR)

# ---------- Histograma ----------

# Compilar versión secuencial
$(BINS_DIR)/histograma_secuencial: $(SEC_DIR)/histograma_secuencial.c
	$(CC) $(CFLAGS) -o $@ $^

# Compilar versión paralela
$(BINS_DIR)/histograma_paralelo: $(PAR_DIR)/histograma_paralelo.c
	$(CC) $(CFLAGS) $(OPENMP) -o $@ $^

# Ejecutar secuencial
run_sec: $(BINS_DIR)/histograma_secuencial
	./$(BINS_DIR)/histograma_secuencial

# Ejecutar paralelo
run_par: $(BINS_DIR)/histograma_paralelo
	./$(BINS_DIR)/histograma_paralelo

# Ejecutar ambas y medir tiempo
bench: $(BINS_DIR)/histograma_secuencial $(BINS_DIR)/histograma_paralelo
	@echo "=== Secuencial ==="
	@time ./$(BINS_DIR)/histograma_secuencial
	@echo "\n=== Paralelo ==="
	@time ./$(BINS_DIR)/histograma_paralelo

# Repetir varias corridas con un numero de hilos fijo (para tabla de METRICAS)
# make bench_hist REPS=5 THREADS=4
REPS = 5
THREADS = 4

bench_hist: $(BINS_DIR)/histograma_secuencial $(BINS_DIR)/histograma_paralelo
	@echo "=== Secuencial ($(REPS) corridas) ==="
	@for i in $$(seq 1 $(REPS)); do \
		printf "Run %s: " $$i; \
		./$(BINS_DIR)/histograma_secuencial | grep "Tiempo"; \
	done
	@echo ""
	@echo "=== Paralelo con $(THREADS) hilos ($(REPS) corridas) ==="
	@for i in $$(seq 1 $(REPS)); do \
		printf "Run %s: " $$i; \
		OMP_NUM_THREADS=$(THREADS) ./$(BINS_DIR)/histograma_paralelo | grep "Tiempo"; \
	done

# Escalabilidad: mismo N con distinto numero de hilos (como bench_mat)
# make bench_hist_threads REPS=3
bench_hist_threads: $(BINS_DIR)/histograma_paralelo
	@echo "=== Histograma: escalabilidad ($(REPS) corridas por config) ==="
	@for t in 1 2 4 8; do \
		echo "-- $$t hilo(s) --"; \
		for i in $$(seq 1 $(REPS)); do \
			printf "Run %s: " $$i; \
			OMP_NUM_THREADS=$$t ./$(BINS_DIR)/histograma_paralelo | grep "Tiempo"; \
		done; \
		echo ""; \
	done

# ---------- Matrices ----------

# Compilar versión secuencial
$(BINS_DIR)/matrices_secuencial: $(SEC_DIR)/matrices_secuencial.c
	$(CC) $(CFLAGS) -o $@ $^

# Compilar versión paralela
$(BINS_DIR)/matrices_paralelo: $(PAR_DIR)/matrices_paralelo.c
	$(CC) $(CFLAGS) $(OPENMP) -o $@ $^

# Ejecutar secuencial
run_mat_sec: $(BINS_DIR)/matrices_secuencial
	./$(BINS_DIR)/matrices_secuencial

# Ejecutar paralelo con N y P (make run_mat_par N=1000 P=8)
run_mat_par: $(BINS_DIR)/matrices_paralelo
	./$(BINS_DIR)/matrices_paralelo $(N) $(P)

# Escalabilidad: mismo N con distinto numero de trabajadores
bench_mat: $(BINS_DIR)/matrices_paralelo
	@echo "=== Matrices N=$(N): escalabilidad ==="
	@for p in 1 2 4 8 16; do \
		./$(BINS_DIR)/matrices_paralelo $(N) $$p | grep -E "trabajadores|Checksum|Tiempo"; \
		echo ""; \
	done

# Repetir varias corridas con distintos P (para tabla de METRICAS)
# make bench_mat_reps N=1000 REPS=5
bench_mat_reps: $(BINS_DIR)/matrices_paralelo
	@echo "=== Matrices N=$(N): escalabilidad ($(REPS) corridas por config) ==="
	@for p in 1 2 4 8; do \
		echo "-- P=$$p --"; \
		for i in $$(seq 1 $(REPS)); do \
			printf "Run %s: " $$i; \
			./$(BINS_DIR)/matrices_paralelo $(N) $$p | grep "Tiempo"; \
		done; \
		echo ""; \
	done

# Limpiar
clean:
	rm -rf $(BINS_DIR)

.PHONY: all run_sec run_par bench bench_hist bench_hist_threads run_mat_sec run_mat_par bench_mat bench_mat_reps clean