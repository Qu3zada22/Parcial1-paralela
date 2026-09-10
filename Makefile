CC = gcc-16
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

# Limpiar
clean:
	rm -rf $(BINS_DIR)

.PHONY: all run_sec run_par bench run_mat_sec run_mat_par bench_mat clean
