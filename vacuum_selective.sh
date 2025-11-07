#\!/bin/bash
#
# Script: vacuum_selective.sh
# Descripción: Ejecuta VACUUM FULL solo en las tablas más grandes
# Uso: ./vacuum_selective.sh [-d ODOO_DIR] [-c CONFIG_FILE]
# Ventaja: Más rápido (1.5-2 horas vs 3-4 horas)
#

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar el parser de configuración
source "${SCRIPT_DIR}/odoo_config_parser.sh"

# Valores por defecto
ODOO_DIR="/opt/odoo"
CONFIG_FILE=""

# Procesar argumentos
while getopts "d:c:h" opt; do
    case $opt in
        d) ODOO_DIR="$OPTARG" ;;
        c) CONFIG_FILE="$OPTARG" ;;
        h)
            echo "Uso: $0 [-d ODOO_DIR] [-c CONFIG_FILE]"
            echo ""
            echo "Opciones:"
            echo "  -d ODOO_DIR     Directorio de instalación de Odoo (default: /opt/odoo)"
            echo "  -c CONFIG_FILE  Archivo de configuración específico"
            echo "  -h              Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0                          # Usa /opt/odoo y selecciona config"
            echo "  $0 -d /opt/odoo             # Especifica directorio Odoo"
            echo "  $0 -c /opt/odoo/conf/my.conf # Usa config específico"
            exit 0
            ;;
        \?)
            echo "Opción inválida: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Cargar configuración
if [ -n "$CONFIG_FILE" ]; then
    parse_odoo_config "$CONFIG_FILE"
else
    auto_detect_config "$ODOO_DIR"
fi

# Verificar que se cargó la configuración
if [ -z "$ODOO_DB_NAME" ]; then
    echo "ERROR: No se pudo cargar la configuración de Odoo"
    exit 1
fi

LOG_DIR="${ODOO_DIR}/logs"
LOG_FILE="${LOG_DIR}/vacuum_selective_$(date +%Y%m%d_%H%M%S).log"

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

# Tablas a procesar (las más grandes)
TABLES=(
    "account_move_line"
    "account_move"
    "stock_move"
    "ir_attachment"
    "stock_move_line"
)

log_info() {
    echo "[$(date '+ %Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$LOG_FILE"
}

displaytime() {
    secs=${1:?}
    h=$(( secs / 3600 ))
    m=$(( ( secs / 60 ) % 60 ))
    s=$(( secs % 60 ))
    printf "%02d:%02d:%02d" $h $m $s
}

echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "  VACUUM FULL SELECTIVO - Odoo DB        " | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
log_info "Base de datos: $ODOO_DB_NAME"
log_info "Usuario DB: $ODOO_DB_USER"
log_info "Host DB: $ODOO_DB_HOST:$ODOO_DB_PORT"
log_info "Config: $ODOO_CONFIG_FILE"
echo "" | tee -a "$LOG_FILE"

# Verificar si Odoo está detenido
if systemctl is-active --quiet odoo; then
    echo "ERROR: Odoo está corriendo. Ejecute: systemctl stop odoo" | tee -a "$LOG_FILE"
    exit 1
fi

log_info "Procesando ${#TABLES[@]} tablas principales..."
echo "" | tee -a "$LOG_FILE"

START_TOTAL=$(date +%s)

for table in "${TABLES[@]}"; do
    log_info "========================================"
    log_info "Procesando tabla: $table"
    
    # Tamaño antes
    SIZE_BEFORE=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT pg_size_pretty(pg_total_relation_size('$table'));" | xargs)
    log_info "Tamaño ANTES: $SIZE_BEFORE"
    
    # VACUUM FULL
    START_TIME=$(date +%s)
    log_info "Ejecutando VACUUM FULL en $table..."
    
    PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "VACUUM FULL VERBOSE $table;" 2>&1 | tee -a "$LOG_FILE"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Tamaño después
    SIZE_AFTER=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT pg_size_pretty(pg_total_relation_size('$table'));" | xargs)
    
    log_info "Tamaño DESPUÉS: $SIZE_AFTER"
    log_info "Tiempo: $(displaytime $DURATION)"
    log_info "Completado: $table"
    echo "" | tee -a "$LOG_FILE"
done

END_TOTAL=$(date +%s)
TOTAL_DURATION=$((END_TOTAL - START_TOTAL))

echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
log_info "PROCESO COMPLETADO"
log_info "Tiempo total: $(displaytime $TOTAL_DURATION)"
log_info "Recuerde reiniciar Odoo: systemctl start odoo"
echo "=========================================" | tee -a "$LOG_FILE"
