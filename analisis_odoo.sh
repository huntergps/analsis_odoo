#!/bin/bash
#
# Script: analisis_odoo.sh
# Descripcion: Genera un informe completo de analisis de base de datos y filestore de Odoo
# Uso: ./analisis_odoo.sh [-d ODOO_DIR] [-c CONFIG_FILE]
# No requiere detener Odoo
#

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar el parser de configuración
source "${SCRIPT_DIR}/odoo_config_parser.sh"

# Valores por defecto
ODOO_DIR="/opt/odoo"
CONFIG_FILE=""

# Colores
GREEN="\\033[0;32m"
BLUE="\\033[0;34m"
YELLOW="\\033[1;33m"
RED="\\033[0;31m"
CYAN="\\033[0;36m"
NC="\\033[0m"

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

REPORT_DIR="${ODOO_DIR}/reports"
REPORT_FILE="${REPORT_DIR}/analisis_odoo_$(date +%Y%m%d_%H%M%S).txt"

# Crear directorio de reportes
mkdir -p "$REPORT_DIR"

# Funciones
print_header() {
    echo -e "${CYAN}========================================${NC}" | tee -a "$REPORT_FILE"
    echo -e "${CYAN}$1${NC}" | tee -a "$REPORT_FILE"
    echo -e "${CYAN}========================================${NC}" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

print_section() {
    echo -e "\\n${BLUE}## $1${NC}" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

print_info() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$REPORT_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$REPORT_FILE"
}

print_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$REPORT_FILE"
}

# Inicio del reporte
clear
print_header "INFORME DE ANALISIS - ODOO DATABASE & FILESTORE"
echo "Fecha: $(date +"%Y-%m-%d %H:%M:%S")" | tee -a "$REPORT_FILE"
echo "Servidor: $(hostname)" | tee -a "$REPORT_FILE"
echo "Base de datos: $ODOO_DB_NAME" | tee -a "$REPORT_FILE"
echo "Usuario DB: $ODOO_DB_USER" | tee -a "$REPORT_FILE"
echo "Host DB: $ODOO_DB_HOST:$ODOO_DB_PORT" | tee -a "$REPORT_FILE"
echo "Filestore: $ODOO_FILESTORE" | tee -a "$REPORT_FILE"
echo "Config: $ODOO_CONFIG_FILE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ==========================================
# 1. ANALISIS DE BASE DE DATOS
# ==========================================
print_section "1. ANALISIS DE BASE DE DATOS"

# Tamaño total
print_info "Obteniendo tamaño total de base de datos..."
DB_SIZE=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT pg_size_pretty(pg_database_size('$ODOO_DB_NAME'));" | xargs)
echo "Tamaño total: $DB_SIZE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Top 10 tablas más grandes
print_info "Top 10 tablas más grandes:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    schemaname || '.' || tablename as tabla,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as tamaño_total,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as tamaño_datos,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as tamaño_indices
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Conteo de registros en tablas principales
print_info "Conteo de registros en tablas principales:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    schemaname || '.' || relname as tabla,
    n_live_tup as registros_activos,
    n_dead_tup as registros_muertos,
    pg_size_pretty(pg_total_relation_size(relid)) as tamaño
FROM pg_stat_user_tables
WHERE relname IN (
    'account_move_line',
    'account_move',
    'ir_attachment',
    'sale_order_line',
    'stock_move',
    'stock_move_line',
    'stock_valuation_layer',
    'mail_message',
    'purchase_order_line'
)
ORDER BY n_live_tup DESC;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Bloat estimado (espacio desperdiciado)
print_info "Estimación de bloat (espacio desperdiciado) en tablas grandes:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    relname as tabla,
    n_dead_tup as filas_muertas,
    pg_size_pretty(pg_relation_size(relid)) as tamaño_actual,
    CASE 
        WHEN n_live_tup > 0 THEN 
            round((n_dead_tup::numeric / n_live_tup::numeric) * 100, 2)
        ELSE 0 
    END as porcentaje_bloat
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 10;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ==========================================
# 2. ANALISIS DE ATTACHMENTS (IR_ATTACHMENT)
# ==========================================
print_section "2. ANALISIS DE ATTACHMENTS"

# Total de attachments
print_info "Total de attachments en base de datos:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    COUNT(*) as total_attachments,
    COUNT(CASE WHEN store_fname IS NOT NULL THEN 1 END) as en_filestore,
    COUNT(CASE WHEN store_fname IS NULL THEN 1 END) as en_database,
    pg_size_pretty(SUM(file_size)) as tamaño_total
FROM ir_attachment;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Attachments por modelo
print_info "Distribución de attachments por modelo:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    COALESCE(res_model, '(sin modelo)') as modelo,
    COUNT(*) as cantidad,
    pg_size_pretty(SUM(file_size)) as tamaño_total,
    pg_size_pretty(AVG(file_size)) as tamaño_promedio
FROM ir_attachment
WHERE store_fname IS NOT NULL
GROUP BY res_model
ORDER BY SUM(file_size) DESC
LIMIT 15;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Attachments por tipo de archivo
print_info "Distribución por tipo de archivo (mimetype):"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    COALESCE(mimetype, '(desconocido)') as tipo,
    COUNT(*) as cantidad,
    pg_size_pretty(SUM(file_size)) as tamaño_total
FROM ir_attachment
WHERE store_fname IS NOT NULL
GROUP BY mimetype
ORDER BY SUM(file_size) DESC
LIMIT 10;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Attachments por año
print_info "Distribución de attachments por año de creación:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    EXTRACT(YEAR FROM create_date) as año,
    COUNT(*) as cantidad,
    pg_size_pretty(SUM(file_size)) as tamaño_total
FROM ir_attachment
WHERE store_fname IS NOT NULL
GROUP BY EXTRACT(YEAR FROM create_date)
ORDER BY año DESC;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ==========================================
# 3. ANALISIS DE FILESTORE (DISCO)
# ==========================================
print_section "3. ANALISIS DE FILESTORE EN DISCO"

if [ -d "$ODOO_FILESTORE" ]; then
    print_info "Tamaño del filestore en disco:"
    du -sh "$ODOO_FILESTORE" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    print_info "Conteo de archivos por tipo:"
    echo "Analizando archivos... (esto puede tomar unos minutos)" | tee -a "$REPORT_FILE"
    find "$ODOO_FILESTORE" -type f -exec file --mime-type {} + 2>/dev/null | \\
        cut -d: -f2 | sort | uniq -c | sort -rn | head -20 | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    print_info "Total de archivos en filestore:"
    TOTAL_FILES=$(find "$ODOO_FILESTORE" -type f | wc -l)
    echo "Total: $TOTAL_FILES archivos" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    print_info "Archivos/directorios más grandes:"
    du -h "$ODOO_FILESTORE" --max-depth=1 2>/dev/null | sort -rh | head -20 | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    # Buscar directorios anómalos
    print_warning "Verificando directorios anómalos..."
    ANOMALIES=$(ls -la "$ODOO_FILESTORE" 2>/dev/null | grep -v "^d.*\\s[0-9a-f][0-9a-f]$" | grep "^d" | grep -v "total" | grep -v "\\s\\.$" | grep -v "\\s\\.\\.$")
    if [ ! -z "$ANOMALIES" ]; then
        print_warning "Directorios no estándar encontrados:"
        echo "$ANOMALIES" | tee -a "$REPORT_FILE"
        echo "" | tee -a "$REPORT_FILE"
        
        # Detalles de directorios anómalos
        NON_HEX_DIRS=$(ls "$ODOO_FILESTORE" 2>/dev/null | grep -v "^[0-9a-f][0-9a-f]$")
        if [ ! -z "$NON_HEX_DIRS" ]; then
            echo "Tamaño de directorios anómalos:" | tee -a "$REPORT_FILE"
            for dir in $NON_HEX_DIRS; do
                if [ -d "$ODOO_FILESTORE/$dir" ]; then
                    du -sh "$ODOO_FILESTORE/$dir" 2>/dev/null | tee -a "$REPORT_FILE"
                elif [ -f "$ODOO_FILESTORE/$dir" ]; then
                    ls -lh "$ODOO_FILESTORE/$dir" | awk '{print $5, $9}' | tee -a "$REPORT_FILE"
                fi
            done
            echo "" | tee -a "$REPORT_FILE"
        fi
    else
        print_info "No se encontraron directorios anómalos"
        echo "" | tee -a "$REPORT_FILE"
    fi
    
else
    print_error "Filestore no encontrado en: $ODOO_FILESTORE"
    echo "" | tee -a "$REPORT_FILE"
fi

# ==========================================
# 4. ANALISIS DE FACTURAS (ACCOUNT_MOVE)
# ==========================================
print_section "4. ANALISIS DE FACTURAS Y DOCUMENTOS CONTABLES"

print_info "Distribución de asientos contables por año:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    EXTRACT(YEAR FROM create_date) as año,
    COUNT(*) as cantidad,
    COUNT(CASE WHEN state = 'posted' THEN 1 END) as publicadas,
    COUNT(CASE WHEN state = 'draft' THEN 1 END) as borradores
FROM account_move
GROUP BY EXTRACT(YEAR FROM create_date)
ORDER BY año DESC;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

print_info "Distribución por tipo de documento:"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -c "
SELECT 
    move_type as tipo,
    COUNT(*) as cantidad,
    pg_size_pretty(SUM(
        (SELECT SUM(att.file_size) 
         FROM ir_attachment att 
         WHERE att.res_model = 'account.move' AND att.res_id = account_move.id)
    )) as tamaño_attachments
FROM account_move
GROUP BY move_type
ORDER BY COUNT(*) DESC;
" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ==========================================
# 5. ANALISIS DE ESPACIO EN DISCO
# ==========================================
print_section "5. ANALISIS DE ESPACIO EN DISCO"

print_info "Uso de disco general:"
df -h / | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

print_info "Uso de disco por componente de Odoo:"
du -sh "$ODOO_DATA_DIR" 2>/dev/null | tee -a "$REPORT_FILE"
du -sh "${ODOO_DIR}/logs" 2>/dev/null | tee -a "$REPORT_FILE"
du -sh "${ODOO_DIR}/backups" 2>/dev/null | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Espacio usado por PostgreSQL
print_info "Espacio usado por PostgreSQL:"
du -sh /var/lib/postgresql 2>/dev/null | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ==========================================
# 6. CONCLUSIONES Y RECOMENDACIONES
# ==========================================
print_section "6. CONCLUSIONES Y RECOMENDACIONES"

# Calcular totales
TOTAL_DB_SIZE_RAW=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT pg_database_size('$ODOO_DB_NAME');" | xargs)
TOTAL_ATTACHMENTS=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT COUNT(*) FROM ir_attachment WHERE store_fname IS NOT NULL;" | xargs)
TOTAL_MOVES=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT COUNT(*) FROM account_move;" | xargs)

echo "RESUMEN EJECUTIVO:" | tee -a "$REPORT_FILE"
echo "==================" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "1. Base de datos: $DB_SIZE" | tee -a "$REPORT_FILE"
echo "2. Total de attachments: $TOTAL_ATTACHMENTS archivos" | tee -a "$REPORT_FILE"
echo "3. Total de asientos contables: $TOTAL_MOVES" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "RECOMENDACIONES:" | tee -a "$REPORT_FILE"
echo "================" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Verificar bloat
BLOAT_COUNT=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT COUNT(*) FROM pg_stat_user_tables WHERE n_dead_tup > 10000;" | xargs)
if [ "$BLOAT_COUNT" -gt 0 ]; then
    print_warning "Bloat detectado en $BLOAT_COUNT tablas - Ejecutar VACUUM recomendado"
else
    print_info "Nivel de bloat aceptable"
fi

# Verificar attachments antiguos
OLD_ATTACHMENTS=$(PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" -t -c "SELECT COUNT(*) FROM ir_attachment WHERE store_fname IS NOT NULL AND create_date < NOW() - INTERVAL '2 years';" | xargs)
if [ "$OLD_ATTACHMENTS" -gt 1000 ]; then
    print_warning "Encontrados $OLD_ATTACHMENTS attachments mayores a 2 años - Considerar archivado"
fi

# Verificar directorios anómalos
if [ ! -z "$NON_HEX_DIRS" ]; then
    print_warning "Directorios anómalos en filestore - Revisar y limpiar"
fi

print_info "Ejecutar ${SCRIPT_DIR}/vacuum_selective.sh para optimizar BD"
print_info "Programar limpieza mensual de logs y vacuum"

echo "" | tee -a "$REPORT_FILE"
print_header "FIN DEL INFORME"
echo "Reporte guardado en: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
