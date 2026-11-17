#!/bin/bash

# ==============================================================================
# SCRIPT DE AUDITORÍA AUTOMÁTICA - SMR (SERVIDORES WEB APACHE2) [0 - 100 PTS]
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_SCORE=0
MAX_SCORE=100

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        AUDITORÍA AUTOMÁTICA DE SERVIDORES WEB (SMR - APACHE2)        ${NC}"
echo -e "${BLUE}======================================================================${NC}\n"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Este script debe ejecutarse como root (usa sudo ./smr_web_checker.sh).${NC}"
  exit 1
fi

pass_check() {
    local points=$1
    local msg=$2
    echo -e " [${GREEN}OK - +${points} pts${NC}] $msg"
    TOTAL_SCORE=$((TOTAL_SCORE + points))
}

fail_check() {
    local msg=$1
    echo -e " [${RED}FAIL - 0 pts${NC}] $msg"
}

# ------------------------------------------------------------------------------
# LOGRO 1: Cortafuegos UFW (10 pts)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}--- [LOGRO 1] Comprobando Cortafuegos (UFW) ---${NC}"
if ufw status | grep -q "Status: active"; then
    pass_check 4 "El cortafuegos UFW está activo."
    
    if ufw status | grep -E "(80|80/tcp|WWW|Apache)" | grep -q "ALLOW"; then
        pass_check 3 "UFW permite el puerto 80 (HTTP)."
    else
        fail_check "Puerto 80 (HTTP) no abierto en UFW."
    fi
    
    if ufw status | grep -E "(443|443/tcp|WWW Full|Apache Secure)" | grep -q "ALLOW"; then
        pass_check 3 "UFW permite el puerto 443 (HTTPS)."
    else
        fail_check "Puerto 443 (HTTPS) no abierto en UFW."
    fi
else
    fail_check "El cortafuegos UFW está desactivado."
fi

# ------------------------------------------------------------------------------
# LOGRO 2: Instalación y Estado de Apache2 (12 pts)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- [LOGRO 2] Verificando Instalación y Estado de Apache2 ---${NC}"
if dpkg -l | grep -q apache2; then
    pass_check 4 "El paquete apache2 está instalado."
else
    fail_check "apache2 no está instalado."
fi

if systemctl is-active --quiet apache2; then
    pass_check 4 "El servicio apache2 está activo y en ejecución."
else
    fail_check "El servicio apache2 NO está activo."
fi

if systemctl is-enabled --quiet apache2; then
    pass_check 4 "El servicio apache2 está habilitado en el arranque."
else
    fail_check "El servicio apache2 NO está habilitado (enabled)."
fi

# ------------------------------------------------------------------------------
# LOGRO 3: Estructura de Directorios y Permisos POSIX (15 pts)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- [LOGRO 3] Comprobando Permisos y Directorios ---${NC}"
if [ -d "/var/www/empresa/public_html" ] && [ -d "/var/www/tienda/public_html" ]; then
    pass_check 5 "Existen las estructuras de directorios para empresa y tienda."
else
    fail_check "Faltan las estructuras de directorios en /var/www/."
fi

if [ -f "/var/www/empresa/public_html/index.html" ] && [ -f "/var/www/tienda/public_html/index.html" ]; then
    pass_check 5 "Existen los archivos index.html identificativos en ambos sitios."
else
    fail_check "Falta algún archivo index.html en empresa o tienda."
fi

OWNER_EMPRESA=$(stat -c '%U:%G' /var/www/empresa/public_html 2>/dev/null)
OWNER_TIENDA=$(stat -c '%U:%G' /var/www/tienda/public_html 2>/dev/null)
if [ "$OWNER_EMPRESA" = "www-data:www-data" ] && [ "$OWNER_TIENDA" = "www-data:www-data" ]; then
    pass_check 5 "El propietario de ambos directorios web es www-data:www-data."
else
    fail_check "El propietario no es www-data:www-data (Empresa: $OWNER_EMPRESA | Tienda: $OWNER_TIENDA)."
fi

# ------------------------------------------------------------------------------
# LOGRO 4: VirtualHosts y Directivas de Directorio (25 pts)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- [LOGRO 4] Verificando Sitios Virtuales y Directivas ---${NC}"
CONF_EMP="/etc/apache2/sites-available/empresa.conf"
CONF_TIE="/etc/apache2/sites-available/tienda.conf"

if [ -f "$CONF_EMP" ] && [ -f "$CONF_TIE" ]; then
    pass_check 3 "Existen los ficheros empresa.conf y tienda.conf en sites-available."
else
    fail_check "Falta empresa.conf o tienda.conf en /etc/apache2/sites-available/."
fi

if [ -f "$CONF_EMP" ] && [ -f "$CONF_TIE" ] && \
   grep -Eq "ServerName[[:space:]]+www\.empresa\.local" "$CONF_EMP" && \
   grep -Eq "DocumentRoot[[:space:]]+/var/www/empresa/public_html" "$CONF_EMP" && \
   grep -Eq "ServerName[[:space:]]+www\.tienda\.local" "$CONF_TIE" && \
   grep -Eq "DocumentRoot[[:space:]]+/var/www/tienda/public_html" "$CONF_TIE"; then
    pass_check 4 "ServerName y DocumentRoot configurados correctamente en ambos sitios."
else
    fail_check "Falta o es incorrecto ServerName o DocumentRoot en empresa.conf o tienda.conf."
fi

if [ -f "$CONF_EMP" ] && [ -f "$CONF_TIE" ] && \
   grep -qi "<Directory" "$CONF_EMP" && grep -qi "Require all granted" "$CONF_EMP" && \
   grep -qi "<Directory" "$CONF_TIE" && grep -qi "Require all granted" "$CONF_TIE"; then
    pass_check 3 "Bloque <Directory> y acceso público (Require all granted) configurados."
else
    fail_check "Falta bloque <Directory> o directiva 'Require all granted' en alguno de los sitios."
fi

if [ -f "$CONF_EMP" ] && [ -f "$CONF_TIE" ] && \
   grep -q "\-Indexes" "$CONF_EMP" && grep -q "+FollowSymLinks" "$CONF_EMP" && \
   grep -q "\-Indexes" "$CONF_TIE" && grep -q "+FollowSymLinks" "$CONF_TIE"; then
    pass_check 3 "Directivas de seguridad (-Indexes) y enlaces (+FollowSymLinks) configuradas."
else
    fail_check "Falta '-Indexes' o '+FollowSymLinks' en empresa.conf o tienda.conf."
fi

if [ -L "/etc/apache2/sites-enabled/empresa.conf" ] && [ -L "/etc/apache2/sites-enabled/tienda.conf" ]; then
    pass_check 7 "Los VirtualHosts empresa.conf y tienda.conf están habilitados en sites-enabled."
else
    fail_check "Los VirtualHosts empresa.conf y/o tienda.conf no están habilitados (a2ensite)."
fi

if [ ! -e "/etc/apache2/sites-enabled/000-default.conf" ]; then
    pass_check 5 "El sitio por defecto 000-default.conf ha sido desactivado."
else
    fail_check "El sitio por defecto (000-default.conf) sigue activo."
fi

# ------------------------------------------------------------------------------
# LOGRO 5: Módulos y Código Server-Side (PHP) vs Client-Side (JS) (12 pts)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- [LOGRO 5] Comprobando PHP (Servidor) y JavaScript (Cliente) ---${NC}"
if dpkg -l | grep -q libapache2-mod-php || dpkg -l | grep -q php; then
    pass_check 4 "Módulo PHP instalado en el servidor."
else
    fail_check "PHP no está instalado."
fi

if [ -f "/var/www/empresa/public_html/info.php" ] && grep -q "phpinfo" /var/www/empresa/public_html/info.php; then
    pass_check 4 "Archivo info.php con ejecución de servidor localizado en empresa."
else
    fail_check "No existe info.php o no contiene código PHP válido."
fi

JS_FILE="/var/www/empresa/public_html/test.html"
if [ -f "$JS_FILE" ] && grep -qi "<script>" "$JS_FILE"; then
    pass_check 4 "Archivo test.html con código JavaScript (<script>) para cliente localizado."
else
    fail_check "Falta test.html en /var/www/empresa/public_html o no contiene etiqueta <script>."
fi

# ------------------------------------------------------------------------------
# LOGRO 6: HTTPS y SSL con certificados padrepoveda2026 (16 pts)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- [LOGRO 6] Verificando SSL/HTTPS y Certificados padrepoveda2026 ---${NC}"
if apache2ctl -M 2>/dev/null | grep -q ssl_module; then
    pass_check 4 "El módulo mod_ssl está cargado en Apache."
else
    fail_check "El módulo mod_ssl no está activo."
fi

CERT_FILE="/etc/ssl/certs/padrepoveda2026.crt"
KEY_FILE="/etc/ssl/private/padrepoveda2026.key"
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    pass_check 4 "Existen el certificado ($CERT_FILE) y la clave privada ($KEY_FILE)."
else
    fail_check "Faltan los ficheros padrepoveda2026.crt o padrepoveda2026.key en /etc/ssl/."
fi

SSL_CONF_AVAIL="/etc/apache2/sites-available/empresa-ssl.conf"
SSL_CONF_ENAB="/etc/apache2/sites-enabled/empresa-ssl.conf"
if [ -f "$SSL_CONF_AVAIL" ] && [ -L "$SSL_CONF_ENAB" ]; then
    pass_check 4 "El sitio seguro empresa-ssl.conf existe en sites-available y está habilitado."
else
    fail_check "Falta empresa-ssl.conf en sites-available o no está habilitado en sites-enabled."
fi

if [ -f "$SSL_CONF_ENAB" ] && grep -q "443" "$SSL_CONF_ENAB" && \
   grep -q "padrepoveda2026.crt" "$SSL_CONF_ENAB" && grep -q "padrepoveda2026.key" "$SSL_CONF_ENAB"; then
    pass_check 4 "empresa-ssl.conf escucha en el puerto 443 y apunta a padrepoveda2026."
else
    fail_check "empresa-ssl.conf no está configurado con puerto 443 y los certificados padrepoveda2026."
fi

# ------------------------------------------------------------------------------
# LOGRO 8: Fichero de Auditoría (10 pts)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}--- [LOGRO 8] Comprobando Fichero de Auditoría ---${NC}"
AUDIT_FILE="/var/www/empresa/public_html/audit.txt"

if [ -f "$AUDIT_FILE" ] && grep -q "AUDIT_WEB_OK" "$AUDIT_FILE"; then
    pass_check 5 "Existe audit.txt y contiene la cadena AUDIT_WEB_OK."
else
    fail_check "Falta audit.txt o no contiene AUDIT_WEB_OK."
fi

if [ "$(stat -c '%U' "$AUDIT_FILE" 2>/dev/null)" = "www-data" ]; then
    pass_check 5 "El propietario de audit.txt es www-data."
else
    fail_check "El propietario de audit.txt no es www-data."
fi

# ------------------------------------------------------------------------------
# RESULTADO FINAL
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}======================================================================${NC}"
if [ "$TOTAL_SCORE" -ge 90 ]; then
    echo -e " PUNTUACIÓN FINAL: ${GREEN}${TOTAL_SCORE} / ${MAX_SCORE} pts${NC} - ¡EXCELENTE!"
elif [ "$TOTAL_SCORE" -ge 50 ]; then
    echo -e " PUNTUACIÓN FINAL: ${YELLOW}${TOTAL_SCORE} / ${MAX_SCORE} pts${NC} - SUPERADO"
else
    echo -e " PUNTUACIÓN FINAL: ${RED}${TOTAL_SCORE} / ${MAX_SCORE} pts${NC} - NO SUPERADO"
fi
echo -e "${BLUE}======================================================================${NC}\n"