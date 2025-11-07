# Scripts Reutilizables para Cualquier Servidor Odoo

## Parser de Configuracion

Se ha creado `odoo_config_parser.sh` que permite leer automaticamente la configuracion de Odoo desde el archivo .conf

### Uso del Parser

```bash
# 1. Incluir el parser en tu script
source /ruta/a/odoo_config_parser.sh

# 2. Detectar automaticamente el archivo de configuracion
CONFIG_FILE=$(detect_odoo_config "/opt/odoo")

# 3. Parsear la configuracion
parse_odoo_config "$CONFIG_FILE"

# 4. Usar las variables exportadas
echo "Base de datos: $ODOO_DB_NAME"
echo "Usuario: $ODOO_DB_USER"
echo "Password: $ODOO_DB_PASSWORD"
echo "Host: $ODOO_DB_HOST"
echo "Data dir: $ODOO_DATA_DIR"
echo "Filestore: $ODOO_FILESTORE"
```

### Variables Exportadas

El parser exporta automaticamente:
- `ODOO_DB_NAME` - Nombre de la base de datos
- `ODOO_DB_USER` - Usuario de PostgreSQL
- `ODOO_DB_PASSWORD` - Contraseña de PostgreSQL
- `ODOO_DB_HOST` - Host de PostgreSQL (default: localhost)
- `ODOO_DB_PORT` - Puerto de PostgreSQL (default: 5432)
- `ODOO_DATA_DIR` - Directorio de datos de Odoo
- `ODOO_FILESTORE` - Ruta al filestore (data_dir/filestore/db_name)
- `ODOO_LOG_DIR` - Directorio de logs

## Adaptando los Scripts Existentes

### Ejemplo: Adaptar vacuum_selective.sh

```bash
#!/bin/bash
# vacuum_selective_reutilizable.sh

# 1. Parametros
ODOO_DIR="${1:-/opt/odoo}"
CONFIG_FILE="${2}"

# 2. Cargar parser
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/odoo_config_parser.sh"

# 3. Detectar/usar config
if [ -z "$CONFIG_FILE" ]; then
    CONFIG_FILE=$(detect_odoo_config "$ODOO_DIR")
fi

# 4. Parsear
parse_odoo_config "$CONFIG_FILE"
validate_odoo_config || exit 1

# 5. Usar variables en lugar de valores hardcodeados
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h $ODOO_DB_HOST -p $ODOO_DB_PORT \
    -d $ODOO_DB_NAME -U $ODOO_DB_USER -c "VACUUM FULL VERBOSE account_move_line;"
```

### Ejemplo: Script con Argumentos

```bash
#!/bin/bash

show_help() {
    cat << EOF
Uso: $0 [OPCIONES]

OPCIONES:
    -d, --odoo-dir DIR    Directorio de Odoo (default: /opt/odoo)
    -c, --config FILE     Archivo de configuracion
    -h, --help            Muestra ayuda
EOF
}

# Valores por defecto
ODOO_DIR="/opt/odoo"
CONFIG_FILE=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--odoo-dir) ODOO_DIR="$2"; shift 2 ;;
        -c|--config) CONFIG_FILE="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Opcion invalida: $1"; exit 1 ;;
    esac
done

# Cargar y usar configuracion
source "$(dirname $0)/odoo_config_parser.sh"
[ -z "$CONFIG_FILE" ] && CONFIG_FILE=$(detect_odoo_config "$ODOO_DIR")
parse_odoo_config "$CONFIG_FILE"
```

## Uso en Diferentes Servidores

### Servidor 1: Instalacion estandar
```bash
./vacuum_selective.sh -d /opt/odoo
# Detecta automaticamente: /opt/odoo/conf/odoo.conf
```

### Servidor 2: Multiple instancias
```bash
./vacuum_selective.sh -d /opt/odoo -c /opt/odoo/conf/odoo_produccion.conf
./vacuum_selective.sh -d /opt/odoo -c /opt/odoo/conf/odoo_desarrollo.conf
```

### Servidor 3: Instalacion personalizada
```bash
./vacuum_selective.sh -d /home/odoo/odoo-14 -c /etc/odoo/odoo.conf
```

## Ventajas

1. **No mas credenciales hardcodeadas** - Lee del archivo .conf
2. **Reutilizable** - Funciona en cualquier servidor
3. **Flexible** - Soporta instalaciones personalizadas
4. **Mantenible** - Cambios en un solo lugar
5. **Seguro** - Credenciales solo en archivo de configuracion

## Migracion de Scripts Existentes

Para migrar un script existente:

1. Agregar al inicio:
```bash
source "$(dirname $0)/odoo_config_parser.sh"
CONFIG_FILE=$(detect_odoo_config "/opt/odoo")
parse_odoo_config "$CONFIG_FILE"
```

2. Reemplazar valores hardcodeados:
- `ferreteria2020` → `$ODOO_DB_NAME`
- `D9j75xHJXpYpDsDRHoGsYNbbqwGmCNi6` → `$ODOO_DB_PASSWORD`
- `odoo` → `$ODOO_DB_USER`
- `localhost` → `$ODOO_DB_HOST`
- `/opt/odoo/data/filestore/ferreteria2020` → `$ODOO_FILESTORE`

3. Agregar opcion de ayuda con -h

## Ejemplo Completo

Ver `odoo_config_parser.sh` para la implementacion completa.

Crear nuevo script llamado `mi_script_reutilizable.sh`:

```bash
#!/bin/bash
source "$(dirname $0)/odoo_config_parser.sh"

# Parametros
ODOO_DIR="${1:-/opt/odoo}"

# Auto-detectar y parsear
CONFIG_FILE=$(detect_odoo_config "$ODOO_DIR")
parse_odoo_config "$CONFIG_FILE"
validate_odoo_config || exit 1

# Mostrar configuracion
show_odoo_config

# Usar variables
echo "Conectando a: $ODOO_DB_NAME en $ODOO_DB_HOST"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h $ODOO_DB_HOST -p $ODOO_DB_PORT \
    -d $ODOO_DB_NAME -U $ODOO_DB_USER -c "SELECT version();"
```

## Testing

Para probar el parser:

```bash
# Test basico
source /opt/odoo/libs/odoo_config_parser.sh
CONFIG_FILE=$(detect_odoo_config "/opt/odoo")
parse_odoo_config "$CONFIG_FILE"
show_odoo_config

# Test con validacion
validate_odoo_config && echo "OK" || echo "ERROR"
```

