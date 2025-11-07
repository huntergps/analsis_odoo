#!/bin/bash
#
# Script: odoo_config_parser.sh
# Descripcion: Libreria para leer configuracion de Odoo desde archivos .conf
# Repositorio: https://github.com/tu-usuario/odoo-tools
# Version: 2.0
#

# Colores para output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# Funcion para obtener valor de configuracion
get_odoo_config() {
    local config_file="$1"
    local key="$2"
    local value=$(grep "^${key}\s*=" "$config_file" | head -1 | cut -d"=" -f2- | xargs)
    echo "$value"
}

# Funcion para listar todos los archivos de configuracion
list_odoo_configs() {
    local odoo_dir="${1:-/opt/odoo}"
    
    local configs=()
    
    # Buscar en ubicaciones comunes
    local search_paths=(
        "${odoo_dir}/conf/*.conf"
        "${odoo_dir}/*.conf"
        "/etc/odoo/*.conf"
        "/etc/odoo-server.conf"
    )
    
    for pattern in "${search_paths[@]}"; do
        for config in $pattern; do
            if [ -f "$config" ]; then
                configs+=("$config")
            fi
        done
    done
    
    # Eliminar duplicados
    printf "%s\n" "${configs[@]}" | sort -u
}

# Funcion para seleccionar configuracion interactivamente
select_odoo_config() {
    local odoo_dir="${1:-/opt/odoo}"
    
    # Obtener lista de configuraciones
    local configs=($(list_odoo_configs "$odoo_dir"))
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo -e "${RED}ERROR: No se encontraron archivos de configuracion en $odoo_dir${NC}" >&2
        return 1
    fi
    
    if [ ${#configs[@]} -eq 1 ]; then
        echo "${configs[0]}"
        return 0
    fi
    
    # Multiples configuraciones - mostrar menu
    echo -e "${BLUE}Se encontraron multiples configuraciones:${NC}" >&2
    echo "" >&2
    
    local i=1
    for config in "${configs[@]}"; do
        local db_name=$(get_odoo_config "$config" "db_name")
        local db_port=$(get_odoo_config "$config" "db_port")
        local http_port=$(get_odoo_config "$config" "http_port")
        
        echo -e "${GREEN}[$i]${NC} $config" >&2
        [ -n "$db_name" ] && echo "    Database: $db_name" >&2
        [ -n "$http_port" ] && echo "    HTTP Port: $http_port" >&2
        echo "" >&2
        
        ((i++))
    done
    
    # Pedir seleccion
    echo -n -e "${YELLOW}Seleccione configuracion [1-${#configs[@]}]: ${NC}" >&2
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#configs[@]}" ]; then
        echo "${configs[$((selection-1))]}"
        return 0
    else
        echo -e "${RED}Seleccion invalida${NC}" >&2
        return 1
    fi
}

# Funcion para detectar archivo de configuracion (auto o seleccion)
detect_odoo_config() {
    local odoo_dir="${1:-/opt/odoo}"
    local interactive="${2:-true}"
    
    local configs=($(list_odoo_configs "$odoo_dir"))
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo -e "${RED}ERROR: No se encontraron archivos de configuracion${NC}" >&2
        return 1
    fi
    
    if [ ${#configs[@]} -eq 1 ]; then
        echo "${configs[0]}"
        return 0
    fi
    
    # Multiples configuraciones
    if [ "$interactive" = "true" ]; then
        select_odoo_config "$odoo_dir"
    else
        # Modo no interactivo - devolver el primero
        echo "${configs[0]}"
    fi
}

# Funcion para parsear configuracion y exportar variables
parse_odoo_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}ERROR: Config file not found: $config_file${NC}" >&2
        return 1
    fi
    
    # Exportar variables
    export ODOO_CONFIG_FILE="$config_file"
    export ODOO_DB_NAME=$(get_odoo_config "$config_file" "db_name")
    export ODOO_DB_USER=$(get_odoo_config "$config_file" "db_user")
    export ODOO_DB_PASSWORD=$(get_odoo_config "$config_file" "db_password")
    export ODOO_DB_HOST=$(get_odoo_config "$config_file" "db_host")
    export ODOO_DB_PORT=$(get_odoo_config "$config_file" "db_port")
    export ODOO_DATA_DIR=$(get_odoo_config "$config_file" "data_dir")
    export ODOO_LOGFILE=$(get_odoo_config "$config_file" "logfile")
    export ODOO_HTTP_PORT=$(get_odoo_config "$config_file" "http_port")
    export ODOO_WORKERS=$(get_odoo_config "$config_file" "workers")
    
    # Valores por defecto
    : ${ODOO_DB_HOST:=localhost}
    : ${ODOO_DB_PORT:=5432}
    : ${ODOO_DB_USER:=odoo}
    : ${ODOO_HTTP_PORT:=8069}
    
    # Derivar directorios
    if [ -n "$ODOO_DATA_DIR" ] && [ -n "$ODOO_DB_NAME" ]; then
        export ODOO_FILESTORE="${ODOO_DATA_DIR}/filestore/${ODOO_DB_NAME}"
    fi
    
    if [ -n "$ODOO_LOGFILE" ]; then
        export ODOO_LOG_DIR=$(dirname "$ODOO_LOGFILE")
    fi
    
    return 0
}

# Funcion para validar configuracion
validate_odoo_config() {
    local errors=0
    
    if [ -z "$ODOO_DB_NAME" ]; then
        echo -e "${RED}ERROR: db_name not found in config${NC}" >&2
        errors=$((errors + 1))
    fi
    
    if [ -z "$ODOO_DB_PASSWORD" ]; then
        echo -e "${YELLOW}WARNING: db_password not found in config${NC}" >&2
    fi
    
    if [ -z "$ODOO_DATA_DIR" ]; then
        echo -e "${RED}ERROR: data_dir not found in config${NC}" >&2
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Funcion para mostrar configuracion
show_odoo_config() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Configuracion de Odoo              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Config File:${NC}       $ODOO_CONFIG_FILE"
    echo -e "${GREEN}Database Name:${NC}     $ODOO_DB_NAME"
    echo -e "${GREEN}Database User:${NC}     $ODOO_DB_USER"
    echo -e "${GREEN}Database Host:${NC}     $ODOO_DB_HOST"
    echo -e "${GREEN}Database Port:${NC}     $ODOO_DB_PORT"
    echo -e "${GREEN}HTTP Port:${NC}         $ODOO_HTTP_PORT"
    echo -e "${GREEN}Workers:${NC}           ${ODOO_WORKERS:-N/A}"
    echo -e "${GREEN}Data Directory:${NC}    $ODOO_DATA_DIR"
    echo -e "${GREEN}Filestore:${NC}         $ODOO_FILESTORE"
    echo -e "${GREEN}Log Directory:${NC}     $ODOO_LOG_DIR"
    echo ""
}
