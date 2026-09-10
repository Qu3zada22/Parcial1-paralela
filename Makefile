CC = gcc-16
CFLAGS = -Wall -Wextra -O3
OPENMP = -fopenmp

# Directorios
SEC_DIR = secuencial
PAR_DIR = paralelo
BINS_DIR = bin

# Targets
all: $(BINS_DIR) $(BINS_DIR)/histograma_secuencial $(BINS_DIR)/histograma_paralelo

$(BINS_DIR):
	mkdir -p $(BINS_DIR)

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

# Limpiar
clean:
	rm -rf $(BINS_DIR)

.PHONY: all run_sec run_par bench clean
