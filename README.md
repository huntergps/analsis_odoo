# 🔧 Herramientas de Análisis y Optimización para Odoo

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Odoo](https://img.shields.io/badge/Odoo-13.0+-purple.svg)](https://www.odoo.com)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

Conjunto de scripts profesionales para analizar, optimizar y mantener instalaciones de Odoo en producción. Compatible con Odoo 13.0+.

## 📋 Tabla de Contenidos

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Scripts Disponibles](#scripts-disponibles)
- [Guía de Uso](#guía-de-uso)
  - [1. Análisis de Base de Datos](#1-análisis-de-base-de-datos)
  - [2. Optimización con VACUUM](#2-optimización-con-vacuum)
  - [3. Limpieza de Archivos Huérfanos](#3-limpieza-de-archivos-huérfanos)
- [Configuración Avanzada](#configuración-avanzada)
- [Troubleshooting](#troubleshooting)
- [Contribuir](#contribuir)
- [Licencia](#licencia)

## ✨ Características

- **✅ Totalmente Parametrizado**: Sin credenciales hardcodeadas
- **✅ Multi-Instancia**: Soporta múltiples instancias Odoo en el mismo servidor
- **✅ Auto-Detección**: Encuentra automáticamente archivos de configuración
- **✅ Selector Interactivo**: Menú para elegir entre múltiples configuraciones
- **✅ Seguridad**: Modo dry-run para pruebas sin riesgo
- **✅ Reportes Detallados**: Logs y reportes en formato legible
- **✅ Screen Support**: Soporte para ejecución remota persistente

## 📦 Requisitos

- Odoo 13.0 o superior
- PostgreSQL 10+
- Bash 4.0+
- Acceso SSH al servidor (para instalación remota)
- Permisos de lectura en archivos de configuración de Odoo

## 🚀 Instalación

### Instalación Rápida

```bash
cd /opt/odoo/libs
git clone https://github.com/huntergps/analsis_odoo.git odoo-tools
cd odoo-tools
chmod +x *.sh
```

### Verificar Instalación

```bash
./analisis_odoo.sh -h
```

## 🛠 Scripts Disponibles

| Script | Descripción | Tiempo Estimado | Downtime |
|--------|-------------|-----------------|----------|
| `analisis_odoo.sh` | Genera informe completo de BD y filestore | 2-5 min | ❌ No |
| `vacuum_selective.sh` | VACUUM FULL en tablas principales (top 5) | 1.5-2 hrs | ✅ Sí |
| `vacuum_full_database.sh` | VACUUM FULL en toda la base de datos | 2-4 hrs | ✅ Sí |
| `cleanup_orphan_files.sh` | Limpia archivos huérfanos de ir_attachment | 5-15 min | ❌ No |
| `odoo_config_parser.sh` | Librería para parsear configs (usado por otros scripts) | - | - |

## 📖 Guía de Uso

### 1. Análisis de Base de Datos

El script `analisis_odoo.sh` genera un informe completo sin necesidad de detener Odoo.

#### Uso Básico

```bash
# Auto-detecta configuración (muestra menú si hay múltiples)
./analisis_odoo.sh

# Especificar directorio de Odoo
./analisis_odoo.sh -d /opt/odoo

# Usar archivo de configuración específico
./analisis_odoo.sh -c /opt/odoo/conf/odoo_produccion.conf
```

#### Ejemplo de Salida

```
========================================
INFORME DE ANALISIS - ODOO DATABASE & FILESTORE
========================================

Fecha: 2025-11-06 23:00:00
Base de datos: ferreteria2020
Tamaño total BD: 17 GB
Total attachments: 892,074 archivos
Filestore: 18 GB

Top 5 Tablas Más Grandes:
1. account_move_line    - 6.2 GB
2. account_move         - 3.8 GB
3. stock_move           - 2.1 GB
4. ir_attachment        - 405 MB
5. stock_move_line      - 1.9 GB
```

#### ¿Qué Analiza?

- ✅ Tamaño de base de datos PostgreSQL
- ✅ Top 10 tablas más grandes (datos + índices)
- ✅ Bloat estimado (espacio desperdiciado)
- ✅ Distribución de attachments por modelo, tipo y año
- ✅ Análisis de filestore en disco
- ✅ Archivos huérfanos y anomalías
- ✅ Recomendaciones de optimización

#### Reportes Generados

Los reportes se guardan en:
```
/opt/odoo/reports/analisis_odoo_YYYYMMDD_HHMMSS.txt
```

---

### 2. Optimización con VACUUM

Los scripts de VACUUM liberan espacio eliminando tuplas muertas y reorganizando datos.

> ⚠️ **IMPORTANTE**: Requiere detener Odoo antes de ejecutar

#### 2.1 VACUUM Selectivo (Recomendado)

Procesa solo las 5 tablas más grandes. **Más rápido y suficiente en la mayoría de casos**.

```bash
# 1. Detener Odoo
systemctl stop odoo

# 2. Ejecutar VACUUM selectivo
./vacuum_selective.sh

# 3. Reiniciar Odoo
systemctl start odoo
```

**Tablas procesadas:**
- `account_move_line`
- `account_move`
- `stock_move`
- `ir_attachment`
- `stock_move_line`

**Tiempo estimado:** 1.5 - 2 horas

#### 2.2 VACUUM Completo

Procesa toda la base de datos. Usar solo si es necesario.

```bash
systemctl stop odoo
./vacuum_full_database.sh
systemctl start odoo
```

**Tiempo estimado:** 2 - 4 horas

#### 2.3 Ejecución Remota con Screen

Para ejecutar de forma segura en sesiones SSH remotas:

```bash
# 1. Detener Odoo
systemctl stop odoo

# 2. Iniciar sesión screen
screen -S vacuum_odoo

# 3. Ejecutar VACUUM
./vacuum_selective.sh

# 4. Desconectar screen (Ctrl+A, luego D)
# El proceso seguirá corriendo aunque cierres SSH

# 5. Reconectar a la sesión más tarde
screen -r vacuum_odoo

# 6. Cuando termine, reiniciar Odoo
systemctl start odoo
```

#### Comandos Útiles de Screen

| Comando | Descripción |
|---------|-------------|
| `screen -S nombre` | Crear sesión con nombre |
| `Ctrl+A, D` | Desconectar de sesión (detach) |
| `screen -ls` | Listar sesiones activas |
| `screen -r nombre` | Reconectar a sesión |
| `screen -X -S nombre quit` | Cerrar sesión |

#### Espacio Recuperable

Típicamente puedes recuperar:
- **2-4 GB** en bases de datos de producción activas
- **10-20%** del tamaño total en BDs sin mantenimiento reciente
- **Más rendimiento** en queries gracias a índices reorganizados

---

### 3. Limpieza de Archivos Huérfanos

El script `cleanup_orphan_files.sh` elimina registros en `ir_attachment` que apuntan a archivos que no existen físicamente.

> ✅ **SEGURO**: No requiere detener Odoo

#### 3.1 Modo Dry-Run (Recomendado Primero)

```bash
# Ver qué se limpiaría SIN hacer cambios
./cleanup_orphan_files.sh --dry-run
```

**Salida ejemplo:**
```
========================================
  LIMPIEZA DE ARCHIVOS HUÉRFANOS
========================================

Base de datos: ferreteria2020
Filestore: /opt/odoo/data/filestore/ferreteria2020

MODO DRY-RUN: No se harán cambios reales

Registros huérfanos en BD: 1,247
Espacio potencial a recuperar: ~850 MB

Ejecute sin --dry-run para realizar los cambios
```

#### 3.2 Ejecución Real

```bash
# Ejecutar limpieza
./cleanup_orphan_files.sh

# O con config específico
./cleanup_orphan_files.sh -c /opt/odoo/conf/odoo.conf
```

El script pedirá confirmación antes de eliminar:
```
¿Desea eliminar estos 1,247 registros de la BD? (s/n)
```

#### ¿Qué Limpia?

1. **Registros en BD sin archivo físico**
   - Registros en `ir_attachment` que apuntan a archivos que no existen
   - Reduce tamaño de la BD
   - Evita errores 404 en attachments

2. **Reportes Detallados**
   - Lista de registros encontrados
   - IDs, nombres y modelos afectados
   - Estimación de espacio recuperable

#### Cuándo Ejecutar

✅ **Ejecuta este script si:**
- Has restaurado backups y archivos no se copiaron completamente
- Has movido filestore manualmente
- Tienes errores de attachments faltantes en logs
- El análisis muestra diferencia entre BD y filestore

#### Archivos Generados

```
/opt/odoo/reports/orphan_cleanup_YYYYMMDD_HHMMSS.txt  # Reporte
/opt/odoo/logs/cleanup_orphans_YYYYMMDD_HHMMSS.log    # Log detallado
```

---

## ⚙️ Configuración Avanzada

### Múltiples Instancias Odoo

Si tienes varias instancias en el mismo servidor:

```bash
# El script mostrará un menú interactivo
./analisis_odoo.sh

# Salida:
# Se encontraron múltiples configuraciones:
# [1] /opt/odoo/conf/odoo_empresa1.conf (Database: empresa1)
# [2] /opt/odoo/conf/odoo_empresa2.conf (Database: empresa2)
# [3] /opt/odoo/conf/odoo_test.conf (Database: test_db)
# Seleccione configuración [1-3]:
```

### Variables de Entorno Exportadas

El parser exporta estas variables que puedes usar en tus propios scripts:

```bash
ODOO_CONFIG_FILE       # Ruta al archivo de config
ODOO_DB_NAME           # Nombre de la BD
ODOO_DB_USER           # Usuario PostgreSQL
ODOO_DB_PASSWORD       # Contraseña BD
ODOO_DB_HOST           # Host BD (default: localhost)
ODOO_DB_PORT           # Puerto BD (default: 5432)
ODOO_DATA_DIR          # Directorio data_dir
ODOO_FILESTORE         # Ruta al filestore
ODOO_LOG_DIR           # Directorio de logs
ODOO_HTTP_PORT         # Puerto HTTP de Odoo
```

### Crear Tu Propio Script

```bash
#!/bin/bash
# mi_script.sh

# Cargar el parser
source /opt/odoo/libs/odoo-tools/odoo_config_parser.sh

# Auto-detectar y cargar config
auto_detect_config "/opt/odoo"

# Usar las variables
echo "Procesando BD: $ODOO_DB_NAME"
PGPASSWORD="$ODOO_DB_PASSWORD" psql -h "$ODOO_DB_HOST" \
  -p "$ODOO_DB_PORT" -d "$ODOO_DB_NAME" -U "$ODOO_DB_USER" \
  -c "SELECT COUNT(*) FROM res_partner;"
```

---

## 🔍 Troubleshooting

### Error: "No se pudo cargar la configuración"

**Causa:** No se encuentra el archivo de configuración de Odoo

**Solución:**
```bash
# Especificar la ruta manualmente
./analisis_odoo.sh -c /ruta/completa/a/odoo.conf

# O verificar que existe
ls -la /opt/odoo/conf/*.conf
```

### Error: "psql: invalid port number: False"

**Causa:** El archivo de config tiene `db_port = False`

**Solución:** Ya está corregido en la última versión. Actualiza:
```bash
cd /opt/odoo/libs/odoo-tools
git pull origin main
```

### VACUUM parece colgado

**Normal.** VACUUM es un proceso largo. Verifica progreso:

```bash
# En otra terminal SSH
psql -U odoo -d ferreteria2020 -c "
SELECT pid, state, query
FROM pg_stat_activity
WHERE query LIKE '%VACUUM%';
"
```

### Recuperar sesión Screen perdida

```bash
# Listar sesiones activas
screen -ls

# Reconectar
screen -r [nombre_o_id]
```

---

## 📊 Casos de Uso Reales

### Caso 1: Análisis Mensual

```bash
#!/bin/bash
# cron_analisis.sh - Ejecutar mensualmente via cron

cd /opt/odoo/libs/odoo-tools
./analisis_odoo.sh -c /opt/odoo/conf/odoo.conf

# Enviar reporte por email (opcional)
LATEST_REPORT=$(ls -t /opt/odoo/reports/analisis_odoo_*.txt | head -1)
mail -s "Reporte Odoo $(date +%Y-%m)" admin@empresa.com < "$LATEST_REPORT"
```

### Caso 2: Mantenimiento Trimestral

```bash
# 1. Análisis pre-mantenimiento
./analisis_odoo.sh > /tmp/pre_maintenance.txt

# 2. Detener Odoo
systemctl stop odoo

# 3. Backup
sudo -u postgres pg_dump ferreteria2020 > /backup/pre_vacuum_$(date +%Y%m%d).sql

# 4. VACUUM selectivo
screen -S vacuum -dm ./vacuum_selective.sh

# 5. Monitorear (desde otra terminal)
screen -r vacuum

# 6. Cuando termine, reiniciar
systemctl start odoo

# 7. Análisis post-mantenimiento
./analisis_odoo.sh > /tmp/post_maintenance.txt

# 8. Comparar
diff /tmp/pre_maintenance.txt /tmp/post_maintenance.txt
```

### Caso 3: Limpieza Post-Migración

```bash
# Después de migrar desde otro servidor

# 1. Verificar integridad
./analisis_odoo.sh --dry-run

# 2. Limpiar huérfanos
./cleanup_orphan_files.sh --dry-run  # Revisar primero
./cleanup_orphan_files.sh            # Ejecutar

# 3. Optimizar
systemctl stop odoo
./vacuum_selective.sh
systemctl start odoo

# 4. Verificar mejora
./analisis_odoo.sh
```

---

## 📁 Estructura del Repositorio

```
odoo-tools/
├── analisis_odoo.sh              # Script de análisis completo
├── vacuum_selective.sh            # VACUUM rápido (5 tablas)
├── vacuum_full_database.sh        # VACUUM completo
├── cleanup_orphan_files.sh        # Limpieza de huérfanos
├── odoo_config_parser.sh          # Librería parser de configs
├── README.md                      # Este archivo
├── LICENSE                        # Licencia MIT
├── .gitignore                     # Archivos ignorados
└── GITHUB_SYNC_INSTRUCTIONS.md    # Instrucciones de sincronización
```

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas!

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/MiFeature`)
3. Commit tus cambios (`git commit -m 'Add: Mi nuevo feature'`)
4. Push a la rama (`git push origin feature/MiFeature`)
5. Abre un Pull Request

### Guías de Contribución

- Usa shellcheck para validar scripts
- Documenta nuevas funciones
- Agrega ejemplos de uso
- Mantén compatibilidad con Odoo 13.0+

---

## 📝 Changelog

### v2.1.0 (2025-11-06)
- ✨ Agregado `cleanup_orphan_files.sh` para limpieza de huérfanos
- 🐛 Fix: Manejo de `db_port = False` en configs
- 📚 Documentación unificada en README principal
- ✅ Testeado en producción con 892K attachments

### v2.0.0 (2025-11-06)
- ✨ Agregada función `auto_detect_config()`
- ✨ Soporte para múltiples instancias con selector interactivo
- 🔄 Scripts totalmente parametrizados (sin hardcoded)
- 📚 Documentación completa

### v1.0.0 (2025-11-05)
- 🎉 Release inicial
- ✨ Scripts de análisis y VACUUM
- 📚 Documentación básica

---

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

## 👤 Autor

**Hunter GPS**
- GitHub: [@huntergps](https://github.com/huntergps)
- Repositorio: [analsis_odoo](https://github.com/huntergps/analsis_odoo)

---

## 🙏 Agradecimientos

- Comunidad de Odoo
- PostgreSQL Documentation
- Bash Best Practices Community

---

## 📞 Soporte

¿Encontraste un bug? ¿Tienes una sugerencia?

- 🐛 [Reportar un Issue](https://github.com/huntergps/analsis_odoo/issues)
- 💡 [Solicitar un Feature](https://github.com/huntergps/analsis_odoo/issues/new)
- 📧 Email: hunter@galapagos.tech

---

**⭐ Si este proyecto te ayudó, dale una estrella en GitHub!**

---

## 🔗 Enlaces Útiles

- [Documentación Oficial de Odoo](https://www.odoo.com/documentation/)
- [PostgreSQL VACUUM Documentation](https://www.postgresql.org/docs/current/sql-vacuum.html)
- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Screen User Manual](https://www.gnu.org/software/screen/manual/)
