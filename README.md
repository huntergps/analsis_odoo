# Odoo Tools - Database & Filestore Optimization Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-green.svg)
![PostgreSQL](https://img.shields.io/badge/postgresql-9.6%2B-blue.svg)

Coleccion de scripts bash para optimizar, analizar y mantener bases de datos e instalaciones de Odoo en cualquier servidor.

## Caracteristicas

✅ **100% Reutilizable** - Funciona en cualquier instalacion de Odoo  
✅ **Auto-deteccion** - Encuentra automaticamente archivos de configuracion  
✅ **Selector Multiple** - Soporta multiples instancias en un mismo servidor  
✅ **Sin Credenciales Hardcodeadas** - Lee desde archivos .conf  
✅ **Logs Detallados** - Timestamps, colores, progreso  
✅ **Screen Compatible** - Ejecuta remotamente sin riesgo de desconexion  

## Scripts Incluidos

| Script | Descripcion | Tiempo | Impacto |
|--------|-------------|--------|---------|
| `analisis_odoo.sh` | Genera informe completo de BD y filestore | 2-5 min | Sin downtime |
| `vacuum_selective.sh` | VACUUM FULL en tablas principales | 1.5-2 hrs | Requiere detener Odoo |
| `vacuum_full_database.sh` | VACUUM FULL completo | 2-4 hrs | Requiere detener Odoo |
| `odoo_config_parser.sh` | Libreria para parsear configs | - | Libreria |

## Instalacion

### Opcion 1: Clonar desde GitHub

bash
cd /opt/odoo/libs
git clone https://github.com/tu-usuario/odoo-tools.git
cd odoo-tools
chmod +x *.sh


### Opcion 2: Descarga Manual

bash
cd /opt/odoo/libs
mkdir odoo-tools
cd odoo-tools
# Descargar scripts individualmente


## Uso Rapido

### Analizar Base de Datos (Sin detener Odoo)

bash
cd /opt/odoo/libs/odoo-tools
./analisis_odoo.sh

# Con multiples configuraciones, se mostrara un menu:
# [1] /opt/odoo/conf/odoo_produccion.conf (Database: prod_db)
# [2] /opt/odoo/conf/odoo_desarrollo.conf (Database: dev_db)
# Seleccione configuracion [1-2]:


### VACUUM Selectivo (Recomendado)

bash
# 1. Detener Odoo
systemctl stop odoo

# 2. Iniciar screen
screen -S vacuum_odoo

# 3. Ejecutar script
cd /opt/odoo/libs/odoo-tools
./vacuum_selective.sh

# 4. Desconectar de screen (Ctrl+A, D)
# 5. Reconectar mas tarde: screen -r vacuum_odoo


## Parametros

Todos los scripts aceptan:

bash
./script.sh [opciones]

Opciones:
  -d, --odoo-dir DIR     Directorio de Odoo (default: /opt/odoo)
  -c, --config FILE      Archivo de configuracion especifico
  -h, --help             Mostrar ayuda


### Ejemplos

bash
# Instalacion estandar (auto-detecta config)
./analisis_odoo.sh

# Directorio personalizado
./analisis_odoo.sh -d /home/odoo/odoo-16

# Config especifica (multiples instancias)
./vacuum_selective.sh -c /opt/odoo/conf/odoo_produccion.conf

# Instalacion no estandar
./analisis_odoo.sh -d /var/lib/odoo -c /etc/odoo/odoo.conf


## Reportes Generados

### Analisis de Base de Datos

El script `analisis_odoo.sh` genera un reporte detallado en:
- `/opt/odoo/reports/analisis_odoo_YYYYMMDD_HHMMSS.txt`

**Incluye:**
- Tamaño total de base de datos
- Top 10 tablas mas grandes
- Conteo de registros por tabla
- Estimacion de bloat (espacio desperdiciado)
- Attachments por modelo y año
- Distribucion por tipo de archivo (PDF, XML, etc.)
- Directorios anomalos en filestore
- Recomendaciones de optimizacion

### VACUUM Logs

Los scripts de VACUUM generan logs en:
- `/opt/odoo/logs/vacuum_selective_YYYYMMDD_HHMMSS.log`
- `/opt/odoo/logs/vacuum_full_YYYYMMDD_HHMMSS.log`

**Incluyen:**
- Timestamps de cada operacion
- Tamaños antes/despues por tabla
- Tiempo de ejecucion
- Resumen final

## Configuracion Auto-detectada

El parser de configuracion busca archivos `.conf` en:
- `${ODOO_DIR}/conf/*.conf`
- `${ODOO_DIR}/*.conf`
- `/etc/odoo/*.conf`
- `/etc/odoo-server.conf`

### Variables Exportadas

bash
ODOO_CONFIG_FILE      # Archivo de configuracion usado
ODOO_DB_NAME          # Nombre de la base de datos
ODOO_DB_USER          # Usuario PostgreSQL
ODOO_DB_PASSWORD      # Contraseña
ODOO_DB_HOST          # Host (default: localhost)
ODOO_DB_PORT          # Puerto (default: 5432)
ODOO_DATA_DIR         # Directorio de datos
ODOO_FILESTORE        # Ruta al filestore
ODOO_LOG_DIR          # Directorio de logs
ODOO_HTTP_PORT        # Puerto HTTP
ODOO_WORKERS          # Numero de workers


## Estructura del Proyecto

odoo-tools/
├── README.md                      # Este archivo
├── README_VACUUM.md               # Guia detallada de VACUUM
├── README_REUTILIZABLE.md         # Guia de desarrollo
├── odoo_config_parser.sh          # Libreria de parseo
├── analisis_odoo.sh               # Script de analisis
├── vacuum_selective.sh            # VACUUM selectivo
├── vacuum_full_database.sh        # VACUUM completo
└── .gitignore                     # Archivos a ignorar


## Casos de Uso

### Caso 1: Backup muy grande

bash
# 1. Analizar para identificar el problema
./analisis_odoo.sh

# 2. Revisar el reporte
cat /opt/odoo/reports/analisis_odoo_*.txt

# 3. Ejecutar VACUUM si hay bloat
./vacuum_selective.sh


### Caso 2: Base de datos lenta

bash
# 1. Analizar bloat
./analisis_odoo.sh

# 2. Si hay >10% bloat, ejecutar VACUUM
systemctl stop odoo
screen -S vacuum
./vacuum_selective.sh
# Ctrl+A, D
systemctl start odoo


### Caso 3: Multiples instancias

bash
# Analizar instancia de produccion
./analisis_odoo.sh -c /opt/odoo/conf/odoo_prod.conf

# Analizar instancia de desarrollo
./analisis_odoo.sh -c /opt/odoo/conf/odoo_dev.conf


## Requisitos

- Bash >= 4.0
- PostgreSQL >= 9.6
- Odoo >= 10.0
- `screen` (opcional, para ejecucion remota)
- Permisos de root o sudo

## Instalacion de Dependencias

bash
# Ubuntu/Debian
apt-get install -y screen postgresql-client

# RHEL/CentOS
yum install -y screen postgresql


## Seguridad

⚠️ **IMPORTANTE:**
- Los scripts leen credenciales desde archivos `.conf`
- NO se almacenan credenciales en los scripts
- Proteger adecuadamente los archivos `.conf` (chmod 600)
- Revisar logs antes de compartirlos (pueden contener info sensible)

## Contribuir

Las contribuciones son bienvenidas!

1. Fork el repositorio
2. Crear branch de feature (`git checkout -b feature/nueva-funcion`)
3. Commit cambios (`git commit -am "Agregar nueva funcion"`)
4. Push al branch (`git push origin feature/nueva-funcion`)
5. Crear Pull Request

## Changelog

### v2.0.0 (2025-11-06)
- Parser de configuracion mejorado
- Selector de multiples configuraciones
- Auto-deteccion de instalaciones
- Organizacion en subdirectorio github-ready

### v1.0.0 (2025-11-06)
- Scripts iniciales de VACUUM y analisis
- Logs detallados con timestamps
- Soporte para screen

## Licencia

MIT License - Ver LICENSE file para detalles

## Autor

Creado para optimizar bases de datos Odoo en produccion

## Soporte

Para reportar bugs o solicitar features:
- Crear un issue en GitHub
- Email: support@example.com

## Agradecimientos

- Comunidad de Odoo
- PostgreSQL Documentation
- Bash Best Practices

---

**⭐ Si este proyecto te ayudo, dale una estrella en GitHub!**
