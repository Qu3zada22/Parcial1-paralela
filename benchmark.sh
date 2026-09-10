#!/bin/bash

# Script de benchmark para medir speedup y eficiencia
# Uso: ./benchmark.sh [numero_ejecuciones] [num_threads]

NUM_RUNS=${1:-5}
NUM_THREADS=${2:-8}

echo "=========================================="
echo "Benchmark: Histograma Paralelo"
echo "=========================================="
echo "Número de ejecuciones: $NUM_RUNS"
echo "Número de threads (para paralelo): $NUM_THREADS"
echo ""

# Arreglos para guardar tiempos
declare -a SEC_TIMES
declare -a PAR_TIMES

# Ejecutar versión secuencial múltiples veces
echo "Ejecutando versión SECUENCIAL ($NUM_RUNS veces)..."
for ((i=1; i<=NUM_RUNS; i++)); do
    output=$(./bin/histograma_secuencial 2>/dev/null | grep "Tiempo de ejecución:" | awk '{print $(NF-1)}')
    SEC_TIMES[$i]=$output
    echo "  Run $i: $output segundos"
done

echo ""

# Ejecutar versión paralela múltiples veces
echo "Ejecutando versión PARALELA ($NUM_RUNS veces, $NUM_THREADS threads)..."
export OMP_NUM_THREADS=$NUM_THREADS
for ((i=1; i<=NUM_RUNS; i++)); do
    output=$(./bin/histograma_paralelo 2>/dev/null | grep "Tiempo de ejecución:" | awk '{print $(NF-1)}')
    PAR_TIMES[$i]=$output
    echo "  Run $i: $output segundos"
done

echo ""
echo "=========================================="
echo "RESULTADOS"
echo "=========================================="

# Calcular promedios con awk
SEC_AVG=$(printf '%s\n' "${SEC_TIMES[@]}" | awk '{sum+=$1; count++} END {if (count>0) printf "%.6f", sum/count}')
PAR_AVG=$(printf '%s\n' "${PAR_TIMES[@]}" | awk '{sum+=$1; count++} END {if (count>0) printf "%.6f", sum/count}')

# Calcular speedup y eficiencia solo si PAR_AVG no es cero
if [ -z "$PAR_AVG" ] || [ "$PAR_AVG" == "0" ]; then
    echo "Error: No se pudieron medir los tiempos. Verifica que los binarios existan."
    exit 1
fi

SPEEDUP=$(echo "scale=6; $SEC_AVG / $PAR_AVG" | bc -l)
EFICIENCIA=$(echo "scale=6; $SPEEDUP / $NUM_THREADS" | bc -l)

echo "Tiempo promedio SECUENCIAL: $SEC_AVG segundos"
echo "Tiempo promedio PARALELO:   $PAR_AVG segundos"
echo "Speedup (S/P):              $SPEEDUP"
echo "Eficiencia (S/P/T):         $EFICIENCIA"
echo "=========================================="
