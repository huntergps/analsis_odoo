#\!/bin/bash
#
# Script: vacuum_full_database.sh
# Descripción: Ejecuta VACUUM FULL en la base de datos de Odoo para liberar espacio
# Uso: ./vacuum_full_database.sh [-d ODOO_DIR] [-c CONFIG_FILE]
# IMPORTANTE: Detener Odoo antes de ejecutar este script
#

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar el parser de configuración
source "${SCRIPT_DIR}/odoo_config_parser.sh"

# Valores por defecto
ODOO_DIR="/opt/odoo"
CONFIG_FILE=""

# Colores para output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

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
LOG_FILE="${LOG_DIR}/vacuum_full_$(date +%Y%m%d_%H%M%S).log"
ODOO_SERVICE="odoo"

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

# Función para medir tiempo
displaytime() {
    secs=${1:?}
    h=$(( secs / 3600 ))
    m=$(( ( secs / 60 ) % 60 ))
    s=$(( secs % 60 ))
    printf "%02d:%02d:%02d" $h $m $s
}

# Banner
echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "   VACUUM FULL - Base de Datos Odoo     " | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

log_info "Iniciando proceso de VACUUM FULL"
log_info "Base de datos: $ODOO_DB_NAME"
log_info "Usuario DB: $ODOO_DB_USER"
log_info "Host DB: $ODOO_DB_HOST:$ODOO_DB_PORT"
log_info "Config: $ODOO_CONFIG_FILE"
log_info "Log file: $LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Verificar espacio en disco
log_info "Verificando espacio en disco..."
df -h / | tee -a "$LOG_FILE"
DISK_AVAIL=$(df / | tail -1 | awk '{print $4}')
log_info "Espacio disponible: ${DISK_AVAIL}K"
echo "" | tee -a "$LOG_FILE"

# Verificar tamaño de BD antes
log_info "Obteniendo tamaño de base de datos ANTES del VACUUM..."
START_TIME=$(date +%s)
DB_SIZE_BEFORE=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT pg_size_pretty(pg_database_size('$ODOO_DB_NAME'));" | xargs)
log_info "Tamaño de BD ANTES: $DB_SIZE_BEFORE"
echo "" | tee -a "$LOG_FILE"

# Verificar si Odoo está corriendo
log_info "Verificando estado del servicio Odoo..."
if systemctl is-active --quiet $ODOO_SERVICE; then
    log_error "¡ODOO ESTÁ CORRIENDO\! Debe detener Odoo antes de ejecutar VACUUM FULL"
    log_error "Ejecute: systemctl stop odoo"
    exit 1
else
    log_success "Odoo está detenido. OK para continuar."
fi
echo "" | tee -a "$LOG_FILE"

# Confirmar ejecución
log_warning "Este proceso tomará aproximadamente 2-4 horas"
log_warning "La base de datos estará bloqueada durante todo el proceso"
echo "" | tee -a "$LOG_FILE"
read -p "¿Desea continuar? (s/n): " -n 1 -r
echo ""
if [[ \! $REPLY =~ ^[SsYy]$ ]]; then
    log_info "Operación cancelada por el usuario"
    exit 0
fi
echo "" | tee -a "$LOG_FILE"

# Obtener tamaños de tablas principales ANTES
log_info "Tamaños de tablas principales ANTES del VACUUM:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    relname as tabla, 
    pg_size_pretty(pg_total_relation_size(relid)) as tamaño
FROM pg_stat_user_tables 
WHERE relname IN ('account_move_line', 'account_move', 'ir_attachment', 'stock_move', 'stock_move_line')
ORDER BY pg_total_relation_size(relid) DESC;
" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Ejecutar VACUUM FULL
log_info "Iniciando VACUUM FULL VERBOSE..."
log_info "Este proceso puede tomar varias horas. Por favor espere..."
echo "" | tee -a "$LOG_FILE"

VACUUM_START=$(date +%s)

PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "VACUUM FULL VERBOSE;" 2>&1 | tee -a "$LOG_FILE"

VACUUM_STATUS=${PIPESTATUS[0]}
VACUUM_END=$(date +%s)
VACUUM_DURATION=$((VACUUM_END - VACUUM_START))

echo "" | tee -a "$LOG_FILE"

if [ $VACUUM_STATUS -eq 0 ]; then
    log_success "VACUUM FULL completado exitosamente"
    log_info "Tiempo de ejecución: $(displaytime $VACUUM_DURATION)"
else
    log_error "VACUUM FULL falló con código: $VACUUM_STATUS"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Obtener tamaño de BD después
log_info "Obteniendo tamaño de base de datos DESPUÉS del VACUUM..."
DB_SIZE_AFTER=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT pg_size_pretty(pg_database_size('$ODOO_DB_NAME'));" | xargs)
log_info "Tamaño de BD DESPUÉS: $DB_SIZE_AFTER"
echo "" | tee -a "$LOG_FILE"

# Obtener tamaños de tablas principales DESPUÉS
log_info "Tamaños de tablas principales DESPUÉS del VACUUM:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    relname as tabla, 
    pg_size_pretty(pg_total_relation_size(relid)) as tamaño
FROM pg_stat_user_tables 
WHERE relname IN ('account_move_line', 'account_move', 'ir_attachment', 'stock_move', 'stock_move_line')
ORDER BY pg_total_relation_size(relid) DESC;
" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Verificar espacio en disco después
log_info "Espacio en disco después del VACUUM:"
df -h / | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Resumen final
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "           RESUMEN FINAL                 " | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
log_info "Tamaño ANTES:  $DB_SIZE_BEFORE"
log_info "Tamaño DESPUÉS: $DB_SIZE_AFTER"
log_info "Tiempo total:  $(displaytime $TOTAL_DURATION)"
log_success "Proceso completado exitosamente"
echo "" | tee -a "$LOG_FILE"
log_warning "IMPORTANTE: Recuerde reiniciar Odoo con: systemctl start odoo"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
