# Scripts de Optimizacion de Base de Datos Odoo

## Scripts Disponibles

### 1. vacuum_full_database.sh
Ejecuta VACUUM FULL completo en toda la base de datos

- **Tiempo estimado:** 2-4 horas  
- **Reduccion esperada:** 2-4 GB  
- **Log:** /opt/odoo/logs/vacuum_full_YYYYMMDD_HHMMSS.log

### 2. vacuum_selective.sh (RECOMENDADO)
Ejecuta VACUUM FULL solo en las 5 tablas mas grandes

- **Tiempo estimado:** 1.5-2 horas  
- **Reduccion esperada:** 1.5-3 GB (80% del beneficio)  
- **Log:** /opt/odoo/logs/vacuum_selective_YYYYMMDD_HHMMSS.log

---

## Ejecucion Remota con Screen (RECOMENDADO)

### ¿Por que usar screen?
- La sesion SSH puede desconectarse sin interrumpir el proceso
- Puedes reconectarte y ver el progreso en cualquier momento
- El proceso continua ejecutandose aunque cierres la terminal

### Paso a Paso:

#### 1. Conectarse al servidor
```bash
ssh root@csolish.galapagos.tech
```

#### 2. Detener Odoo
```bash
systemctl stop odoo
systemctl status odoo  # Verificar que este detenido
```

#### 3. Iniciar screen con nombre descriptivo
```bash
# Para vacuum selectivo (recomendado)
screen -S vacuum_odoo

# O para vacuum completo
screen -S vacuum_full_odoo
```

#### 4. Ejecutar el script dentro de screen
```bash
# Opcion A: Vacuum selectivo (mas rapido)
/opt/odoo/libs/vacuum_selective.sh

# Opcion B: Vacuum completo
/opt/odoo/libs/vacuum_full_database.sh
```

El script mostrara el progreso en pantalla en tiempo real con:
- Timestamps de cada operacion
- Tamano de cada tabla antes y despues
- Tiempo transcurrido
- Colores para identificar INFO/SUCCESS/WARNING/ERROR

#### 5. Desconectarse de screen (sin detener el proceso)
```
Presionar: Ctrl+A y luego D
```
Veras el mensaje: "[detached from XXXXX.vacuum_odoo]"

El proceso SIGUE EJECUTANDOSE en segundo plano.

#### 6. Reconectarse a la sesion screen
```bash
# Listar sesiones activas
screen -ls

# Reconectar a la sesion
screen -r vacuum_odoo
```

#### 7. Cuando el script termine
El script mostrara:
```
=========================================
           RESUMEN FINAL                 
=========================================
INFO: Tamaño ANTES:  28 GB
INFO: Tamaño DESPUÉS: 24 GB
INFO: Tiempo total:  01:45:32
SUCCESS: Proceso completado exitosamente

IMPORTANTE: Recuerde reiniciar Odoo con: systemctl start odoo
=========================================
```

#### 8. Salir de screen y reiniciar Odoo
```bash
# Salir de screen
exit

# Reiniciar Odoo
systemctl start odoo
systemctl status odoo  # Verificar que este corriendo

# Probar acceso web
curl -I http://localhost:8069
```

---

## Ejecucion Local (Sin screen)

Si estas en el servidor directamente:

```bash
# 1. Detener Odoo
systemctl stop odoo

# 2. Ejecutar script
/opt/odoo/libs/vacuum_selective.sh

# 3. Esperar...

# 4. Reiniciar Odoo
systemctl start odoo
```

**ADVERTENCIA:** Si la terminal se cierra, el proceso se DETENDRA.

---

## Monitoreo Durante la Ejecucion

### Opcion 1: Dentro de screen
Veras el progreso directamente en pantalla

### Opcion 2: Desde otra terminal (sin entrar a screen)
```bash
# Ver log en tiempo real
tail -f /opt/odoo/logs/vacuum_selective_*.log

# Ver ultima linea cada 5 segundos
watch -n 5 "tail -20 /opt/odoo/logs/vacuum_selective_*.log"

# Ver procesos postgres activos
watch -n 10 "ps aux | grep postgres | grep VACUUM"
```

---

## Comandos Utiles de Screen

```bash
# Listar todas las sesiones
screen -ls

# Crear nueva sesion con nombre
screen -S nombre_sesion

# Reconectar a sesion
screen -r nombre_sesion

# Desconectar sin cerrar (dentro de screen)
Ctrl+A y luego D

# Matar una sesion (si algo salio mal)
screen -X -S nombre_sesion quit

# Ver ayuda de screen
man screen
```

---

## Verificar Resultados

```bash
# Tamano actual de la BD
PGPASSWORD="D9j75xHJXpYpDsDRHoGsYNbbqwGmCNi6" psql -h localhost -d ferreteria2020 -U odoo -c "SELECT pg_size_pretty(pg_database_size(ferreteria2020));"

# Espacio en disco
df -h /

# Ver todos los logs de vacuum
ls -lh /opt/odoo/logs/vacuum_*.log
```

---

## Programacion Recomendada

**Cuando ejecutar:**
- Domingos a las 2-4 AM
- Fines de semana
- Dias festivos
- Mantenimiento programado

**Frecuencia:**
- Vacuum selectivo: Mensual
- Vacuum completo: Trimestral

---

## Troubleshooting

### Screen no esta instalado
```bash
apt-get update
apt-get install -y screen
```

### No puedo reconectar a screen
```bash
# Listar sesiones
screen -ls

# Si dice "Attached", desconectar primero
screen -d vacuum_odoo

# Luego reconectar
screen -r vacuum_odoo
```

### El proceso fallo
```bash
# Ver el log completo
less /opt/odoo/logs/vacuum_selective_*.log

# Buscar errores
grep -i error /opt/odoo/logs/vacuum_selective_*.log
```

### Olvidaste reiniciar Odoo
```bash
systemctl start odoo
systemctl status odoo
```

---

## Resumen Rapido

```bash
# FORMA CORRECTA (con screen)
ssh root@csolish.galapagos.tech
systemctl stop odoo
screen -S vacuum_odoo
/opt/odoo/libs/vacuum_selective.sh
# [Ctrl+A, D para desconectar]
# ... esperar 1.5-2 horas ...
screen -r vacuum_odoo  # Reconectar
exit  # Cuando termine
systemctl start odoo
```

**Ubicacion scripts:** /opt/odoo/libs/
**Ubicacion logs:** /opt/odoo/logs/

---

Creado: 2025-11-06
Ultima actualizacion: 2025-11-06

---

## Script de Analisis de Base de Datos

### analisis_odoo.sh

Genera un informe completo de analisis de la base de datos y filestore.

**Caracteristicas:**
- Analisis de tamaño de base de datos y tablas
- Estadisticas de attachments por modelo
- Distribucion por tipo de archivo
- Deteccion de bloat (espacio desperdiciado)
- Identificacion de directorios anomalos
- Analisis por año de creacion
- Recomendaciones de optimizacion

**Tiempo de ejecucion:** 2-5 minutos  
**No requiere detener Odoo**

**Uso:**
```bash
# Ejecutar desde el servidor
/opt/odoo/libs/analisis_odoo.sh

# Ver el reporte generado
ls -lh /opt/odoo/reports/
cat /opt/odoo/reports/analisis_odoo_*.txt
```

**Reportes generados en:** /opt/odoo/reports/

**Cuandoejecutar:**
- Antes de hacer VACUUM (para decidir que limpiar)
- Mensualmente para monitoreo
- Despues de VACUUM (para ver resultados)
- Cuando el backup sea muy grande

**El reporte incluye:**
1. Tamaño total de BD
2. Top 10 tablas mas grandes
3. Conteo de registros por tabla
4. Estimacion de bloat
5. Attachments por modelo
6. Distribucion por tipo de archivo (PDF, XML, etc)
7. Archivos por año
8. Tamano de filestore en disco
9. Directorios anomalos
10. Conclusiones y recomendaciones

