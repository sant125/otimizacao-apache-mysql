#!/bin/bash
# Script para reverter todas as otimizações aplicadas
# Data: 2025-11-28
# Servidor: 54.173.247.211 (hsgroupbrazil.com.br)

set -e

echo "=============================================="
echo "  Revertendo Otimizações Apache/PHP/MySQL"
echo "=============================================="
echo ""

# Confirmar
read -p "Tem certeza que deseja reverter TODAS as otimizações? (sim/não): " confirm
if [ "$confirm" != "sim" ]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo "[1/8] Revertendo PHP-FPM..."
if [ -f /etc/php/8.3/fpm/pool.d/www.conf.bak ]; then
    cp /etc/php/8.3/fpm/pool.d/www.conf.bak /etc/php/8.3/fpm/pool.d/www.conf
    echo "  ✓ PHP-FPM pool.d revertido"
else
    echo "  ⚠ Backup não encontrado"
fi

echo ""
echo "[2/8] Revertendo OPcache..."
if [ -f /etc/php/8.3/fpm/php.ini.bak ]; then
    cp /etc/php/8.3/fpm/php.ini.bak /etc/php/8.3/fpm/php.ini
    echo "  ✓ OPcache revertido"
else
    echo "  ⚠ Backup não encontrado"
fi

echo ""
echo "[3/8] Reiniciando PHP-FPM..."
systemctl restart php8.3-fpm
echo "  ✓ PHP-FPM reiniciado"

echo ""
echo "[4/8] Revertendo Apache para MPM prefork..."
a2dismod mpm_event 2>/dev/null || true
a2enmod mpm_prefork
a2enmod php8.3
echo "  ✓ MPM prefork reativado"

echo ""
echo "[5/8] Desabilitando HTTP/2..."
a2dismod http2 2>/dev/null || true
if [ -f /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf.bak2 ]; then
    cp /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf.bak2 /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf
    echo "  ✓ VirtualHost revertido"
else
    # Remover linha do Protocols manualmente
    sed -i '/Protocols h2/d' /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf 2>/dev/null || true
    echo "  ✓ HTTP/2 removido do VirtualHost"
fi

echo ""
echo "[6/8] Desabilitando otimizações de compressão e cache..."
a2dismod deflate 2>/dev/null || true
a2dismod brotli 2>/dev/null || true
a2dismod expires 2>/dev/null || true
echo "  ✓ Compressão e cache desabilitados"

echo ""
echo "[7/8] Reabilitando módulos originais..."
a2enmod autoindex 2>/dev/null || true
a2enmod status 2>/dev/null || true
a2enmod negotiation 2>/dev/null || true
echo "  ✓ Módulos originais reabilitados"

echo ""
echo "[8/8] Reabilitando MySQL local..."
systemctl enable mysql 2>/dev/null || true
systemctl start mysql 2>/dev/null || true
if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf.bak ]; then
    cp /etc/mysql/mysql.conf.d/mysqld.cnf.bak /etc/mysql/mysql.conf.d/mysqld.cnf
fi
rm -f /etc/mysql/mysql.conf.d/99-optimization.cnf 2>/dev/null || true
echo "  ✓ MySQL local reabilitado"

echo ""
echo "Reiniciando Apache..."
apachectl configtest
systemctl restart apache2
echo "  ✓ Apache reiniciado"

echo ""
echo "=============================================="
echo "  Reversão completa!"
echo "=============================================="
echo ""
echo "Status dos serviços:"
echo "  PHP-FPM: $(systemctl is-active php8.3-fpm)"
echo "  Apache:  $(systemctl is-active apache2)"
echo "  MySQL:   $(systemctl is-active mysql)"
echo ""
echo "Configuração revertida para o estado original."
echo ""
