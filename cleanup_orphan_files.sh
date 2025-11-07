#!/bin/bash
#
# Script: cleanup_orphan_files.sh
# Descripción: Limpia archivos huérfanos en Odoo 13.0
# Uso: ./cleanup_orphan_files.sh [-d ODOO_DIR] [-c CONFIG_FILE] [--dry-run]
#

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar el parser de configuración
source "${SCRIPT_DIR}/odoo_config_parser.sh"

# Valores por defecto
ODOO_DIR="/opt/odoo"
CONFIG_FILE=""
DRY_RUN=false

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -d) ODOO_DIR="$2"; shift 2 ;;
        -c) CONFIG_FILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h)
            echo "Uso: $0 [-d ODOO_DIR] [-c CONFIG_FILE] [--dry-run]"
            echo ""
            echo "Opciones:"
            echo "  -d ODOO_DIR     Directorio de instalación de Odoo (default: /opt/odoo)"
            echo "  -c CONFIG_FILE  Archivo de configuración específico"
            echo "  --dry-run       Solo mostrar qué se haría sin ejecutar cambios"
            echo "  -h              Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 --dry-run                    # Ver qué se limpiaría"
            echo "  $0 -c /opt/odoo/conf/odoo.conf  # Ejecutar limpieza"
            exit 0
            ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
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
    echo -e "${RED}ERROR: No se pudo cargar la configuración de Odoo${NC}"
    exit 1
fi

LOG_DIR="${ODOO_DIR}/logs"
LOG_FILE="${LOG_DIR}/cleanup_orphans_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="${ODOO_DIR}/reports/orphan_cleanup_$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$LOG_DIR"
mkdir -p "${ODOO_DIR}/reports"

# Funciones
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

# Banner
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  LIMPIEZA DE ARCHIVOS HUÉRFANOS       ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
log_info "Base de datos: $ODOO_DB_NAME"
log_info "Filestore: $ODOO_FILESTORE"
log_info "Config: $ODOO_CONFIG_FILE"

if [ "$DRY_RUN" = true ]; then
    log_warning "MODO DRY-RUN: No se harán cambios reales"
fi
echo ""

# ==========================================
# 1. REGISTROS EN BD SIN ARCHIVO FÍSICO
# ==========================================
echo -e "${CYAN}Paso 1: Buscando registros en ir_attachment sin archivo físico...${NC}"

log_info "Verificando registros en base de datos..."

# Crear script temporal SQL
cat > /tmp/check_orphans.sql << 'EOSQL'
\o /tmp/orphan_records.txt
SELECT COUNT(*) as total_orphans
FROM ir_attachment att
WHERE att.store_fname IS NOT NULL
  AND att.type = 'binary'
  AND NOT EXISTS (
    SELECT 1 FROM pg_stat_file(
      CONCAT(:filestore_path, '/', substring(att.store_fname from 1 for 2), '/', att.store_fname)
    , true) WHERE size IS NOT NULL
  );
\o
EOSQL

# Ejecutar SQL con parámetros
ORPHAN_COUNT=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "
WITH orphan_check AS (
  SELECT id, name, store_fname, COALESCE(file_size, 0) as file_size, res_model, res_id
  FROM ir_attachment
  WHERE store_fname IS NOT NULL
    AND type = 'binary'
  LIMIT 10
)
SELECT COUNT(*) FROM orphan_check oc
WHERE NOT EXISTS (
  SELECT 1 FROM pg_stat_file('$ODOO_FILESTORE/' || substring(oc.store_fname from 1 for 2) || '/' || oc.store_fname, true)
  WHERE size IS NOT NULL
);
" 2>/dev/null | tr -d ' ' | grep -o '[0-9]*' | head -1)

# Si el método anterior falla, usar método alternativo
if [ -z "$ORPHAN_COUNT" ] || [ "$ORPHAN_COUNT" = "0" ]; then
    log_info "Usando método de verificación alternativo..."

    # Crear lista temporal de store_fname
    PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "
    SELECT id, store_fname, file_size FROM ir_attachment WHERE store_fname IS NOT NULL LIMIT 1000;
    " 2>/dev/null | while IFS='|' read -r id fname fsize; do
        id=$(echo "$id" | tr -d ' ')
        fname=$(echo "$fname" | tr -d ' ')

        if [ -n "$fname" ]; then
            hexdir=$(echo "$fname" | cut -c1-2)
            fullpath="$ODOO_FILESTORE/$hexdir/$fname"

            if [ ! -f "$fullpath" ]; then
                echo "$id|$fname|$fsize"
            fi
        fi
    done > /tmp/orphan_records_list.txt

    ORPHAN_COUNT=$(wc -l < /tmp/orphan_records_list.txt)
fi

log_info "Registros huérfanos en BD (sin archivo físico): ${ORPHAN_COUNT:-0}"

if [ "${ORPHAN_COUNT:-0}" -gt 0 ] && [ "$DRY_RUN" = false ]; then
    log_warning "Se encontraron $ORPHAN_COUNT registros sin archivo físico"
    echo "Primeros 20 registros:" >> "$REPORT_FILE"
    head -20 /tmp/orphan_records_list.txt >> "$REPORT_FILE"

    echo ""
    log_warning "¿Desea eliminar estos registros de la BD? (s/n)"
    read -r response
    if [[ "$response" =~ ^[SsYy]$ ]]; then
        # Eliminar en lotes
        while read line; do
            id=$(echo "$line" | cut -d'|' -f1)
            PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "DELETE FROM ir_attachment WHERE id = $id;" 2>/dev/null
        done < /tmp/orphan_records_list.txt

        log_success "Registros eliminados de la base de datos"
    else
        log_info "Operación cancelada"
    fi
fi

# Limpieza de archivos temporales
rm -f /tmp/check_orphans.sql /tmp/orphan_records.txt /tmp/orphan_records_list.txt

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}           RESUMEN FINAL                ${NC}"
echo -e "${CYAN}========================================${NC}"
log_info "Registros en BD sin archivo: ${ORPHAN_COUNT:-0}"
log_info "Reporte guardado en: $REPORT_FILE"
log_info "Log guardado en: $LOG_FILE"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_info "Ejecute sin --dry-run para realizar los cambios"
fi
