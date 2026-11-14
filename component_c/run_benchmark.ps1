# ==============================================================================
# Polyglot Persistence Capstone — Component C Benchmark Runner (PowerShell)
# ==============================================================================
$ErrorActionPreference = "Stop"

$Container = "advdb-postgres"
$DbUser = "student"
$DbName = "advdb"

Write-Host "=== Component C: Performance & Tuning Study Benchmark ===" -ForegroundColor Cyan

# Check container
$running = docker ps -q -f "name=$Container"
if (-not $running) {
    Write-Error "Container $Container is not running. Please run: docker compose --profile sql up -d"
    exit 1
}

Write-Host "--- Step 1: Running EXPLAIN (ANALYZE, BUFFERS) Before Tuning ---" -ForegroundColor Yellow
Get-Content component_c/01_explain_before_tuning.sql | docker exec -i $Container psql -U $DbUser -d $DbName | Tee-Object -FilePath component_c/results_before_tuning.txt

Write-Host "--- Step 2: Applying B-Tree and GIN Indexes ---" -ForegroundColor Yellow
Get-Content component_c/02_apply_indexes.sql | docker exec -i $Container psql -U $DbUser -d $DbName | Tee-Object -FilePath component_c/results_indexing.txt

Write-Host "--- Step 3: Running EXPLAIN (ANALYZE, BUFFERS) After Tuning ---" -ForegroundColor Yellow
Get-Content component_c/03_explain_after_tuning.sql | docker exec -i $Container psql -U $DbUser -d $DbName | Tee-Object -FilePath component_c/results_after_tuning.txt

Write-Host "--- Step 4: Measuring Storage and Write Overhead Trade-Offs ---" -ForegroundColor Yellow
Get-Content component_c/04_tradeoff_benchmarks.sql | docker exec -i $Container psql -U $DbUser -d $DbName | Tee-Object -FilePath component_c/results_tradeoffs.txt

Write-Host "=== Benchmark Complete! Results recorded in component_c/ ===" -ForegroundColor Green
