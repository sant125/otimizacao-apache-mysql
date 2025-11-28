# Otimizações Apache + PHP-FPM + MySQL

Documentação completa das otimizações aplicadas no servidor `54.173.247.211` (hsgroupbrazil.com.br)

**Data:** 2025-11-28
**Servidor:** Ubuntu 24.04.3 LTS
**RAM:** 1.9GB
**Aplicações:** WordPress (RDS) + Sites custom

---

## Índice

1. [PHP-FPM Otimizado](#1-php-fpm-otimizado)
2. [OPcache Habilitado](#2-opcache-habilitado)
3. [Apache MPM Event](#3-apache-mpm-event)
4. [HTTP/2 Habilitado](#4-http2-habilitado)
5. [Compressão Gzip + Brotli](#5-compressão-gzip--brotli)
6. [Cache de Navegador](#6-cache-de-navegador)
7. [Módulos Apache Limpos](#7-módulos-apache-limpos)
8. [MySQL Local Desabilitado](#8-mysql-local-desabilitado)
9. [Como Reverter Tudo](#como-reverter-tudo)

---

## 1. PHP-FPM Otimizado

### O que foi alterado:
**Arquivo:** `/etc/php/8.3/fpm/pool.d/www.conf`

```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 15
pm.max_requests = 500
pm.process_idle_timeout = 10s
```

### Benefícios:
- Melhor gerenciamento de memória
- Processos reciclados para evitar memory leaks
- Timeout de idle reduzido

### Como reverter:
```bash
# Restaurar backup
sudo cp /etc/php/8.3/fpm/pool.d/www.conf.bak /etc/php/8.3/fpm/pool.d/www.conf
sudo systemctl restart php8.3-fpm
```

### Como verificar:
```bash
# Ver configuração atual
grep -E "^(pm =|pm.max_children|pm.start_servers)" /etc/php/8.3/fpm/pool.d/www.conf

# Ver processos ativos
ps aux | grep php-fpm | wc -l

# Ver status
curl http://localhost/status
```

---

## 2. OPcache Habilitado

### O que foi alterado:
**Arquivo:** `/etc/php/8.3/fpm/php.ini`

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
```

### Benefícios:
- Cache de bytecode PHP (muito mais rápido)
- Reduz parsing de arquivos PHP
- 256MB dedicados ao cache

### Como reverter:
```bash
# Restaurar backup
sudo cp /etc/php/8.3/fpm/php.ini.bak /etc/php/8.3/fpm/php.ini
sudo systemctl restart php8.3-fpm
```

### Como limpar cache:
```bash
# Limpar OPcache
sudo systemctl reload php8.3-fpm

# Via PHP
php -r "opcache_reset();"
```

### Como verificar:
```bash
# Verificar se está habilitado
php -i | grep opcache.enable

# Ver estatísticas (criar arquivo info.php)
echo "<?php phpinfo();" | sudo tee /var/www/hsgroupbrazil.com.br/opcache-info.php
# Acessar: https://hsgroupbrazil.com.br/opcache-info.php
```

---

## 3. Apache MPM Event

### O que foi alterado:
**Mudança:** `mpm_prefork` → `mpm_event`
**Arquivo:** `/etc/apache2/mods-available/mpm_event.conf`

```apache
<IfModule mpm_event_module>
    ServerLimit             16
    StartServers            3
    MinSpareThreads         25
    MaxSpareThreads         75
    ThreadLimit             64
    ThreadsPerChild         25
    MaxRequestWorkers       400
    MaxConnectionsPerChild  10000
</IfModule>
```

### Benefícios:
- Thread-based ao invés de process-based
- 3-5x mais conexões simultâneas
- Menor uso de memória por conexão
- Compatível com PHP-FPM

### Como reverter:
```bash
# Voltar para prefork
sudo a2dismod mpm_event
sudo a2enmod mpm_prefork php8.3
sudo systemctl restart apache2
```

### Como verificar:
```bash
# Ver MPM ativo
apache2ctl -V | grep MPM

# Ver threads/processos
ps aux | grep apache2
```

---

## 4. HTTP/2 Habilitado

### O que foi alterado:
**Módulo habilitado:** `http2`
**Arquivo:** `/etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf`

```apache
<VirtualHost *:443>
    Protocols h2 h2c http/1.1
    ...
</VirtualHost>
```

### Benefícios:
- Multiplexing (múltiplas requisições em 1 conexão)
- Header compression
- Server push
- Muito mais rápido que HTTP/1.1

### Como reverter:
```bash
# Desabilitar HTTP/2
sudo a2dismod http2

# Remover do VirtualHost
sudo sed -i '/Protocols h2/d' /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf

sudo systemctl restart apache2
```

### Como verificar:
```bash
# Testar HTTP/2
curl -I --http2 https://hsgroupbrazil.com.br | grep HTTP

# Ou no navegador (F12 → Network → Protocol)
```

---

## 5. Compressão Gzip + Brotli

### O que foi alterado:
**Módulos habilitados:** `deflate`, `brotli`
**Arquivo:** `/etc/apache2/mods-enabled/deflate.conf`

```apache
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css
    AddOutputFilterByType DEFLATE text/javascript application/javascript application/x-javascript
    AddOutputFilterByType DEFLATE application/json application/xml application/rss+xml
    AddOutputFilterByType DEFLATE application/xhtml+xml application/atom+xml
    AddOutputFilterByType DEFLATE image/svg+xml
    AddOutputFilterByType DEFLATE font/truetype font/opentype application/font-woff application/font-woff2

    DeflateCompressionLevel 6

    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html
</IfModule>
```

### Benefícios:
- Redução de 50-70% no tamanho dos arquivos
- Economia de banda
- Carregamento mais rápido

### Como reverter:
```bash
# Desabilitar compressão
sudo a2dismod deflate brotli
sudo systemctl restart apache2
```

### Como verificar:
```bash
# Verificar se está comprimindo
curl -H "Accept-Encoding: gzip" -I https://hsgroupbrazil.com.br | grep -i "content-encoding"

# Deve retornar: Content-Encoding: gzip
```

---

## 6. Cache de Navegador

### O que foi alterado:
**Módulos habilitados:** `expires`, `headers`
**Arquivo:** `/etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf`

```apache
# Browser Caching
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    ExpiresByType application/pdf "access plus 1 month"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
    ExpiresByType font/ttf "access plus 1 year"
    ExpiresByType font/otf "access plus 1 year"
</IfModule>

# Cache-Control Headers
<IfModule mod_headers.c>
    <FilesMatch "\.(jpg|jpeg|png|gif|webp|svg|ico)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
    <FilesMatch "\.(css|js)$">
        Header set Cache-Control "max-age=2592000, public"
    </FilesMatch>
    <FilesMatch "\.(woff|woff2|ttf|otf|eot)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
</IfModule>
```

### Benefícios:
- Imagens em cache por 1 ano
- CSS/JS em cache por 1 mês
- Menos requisições ao servidor
- Carregamento instantâneo em visitas recorrentes

### Como limpar cache (forçar atualização):
```bash
# Opção 1: Adicionar query string aos arquivos
# style.css?v=2 (no código HTML)

# Opção 2: Desabilitar temporariamente
sudo a2dismod expires
sudo systemctl reload apache2

# Reabilitar depois
sudo a2enmod expires
sudo systemctl reload apache2
```

### Como verificar:
```bash
# Verificar headers de cache
curl -I https://hsgroupbrazil.com.br/wp-content/themes/tema/style.css | grep -i cache

# Deve retornar: Cache-Control: max-age=...
```

---

## 7. Módulos Apache Limpos

### O que foi desabilitado:
```bash
autoindex    # Listagem de diretórios
status       # Página de status do Apache
negotiation  # Content negotiation
```

### Benefícios:
- Menos memória usada
- Menos superfície de ataque
- Startup mais rápido

### Como reverter:
```bash
# Reabilitar módulos
sudo a2enmod autoindex status negotiation
sudo systemctl restart apache2
```

### Como verificar módulos ativos:
```bash
# Listar todos os módulos
apachectl -M | sort

# Contar módulos
apachectl -M | wc -l
```

---

## 8. MySQL Local Desabilitado

### O que foi feito:
- MySQL local **parado** e **desabilitado**
- Todos os sites usam **RDS** (`db-2.wh1.com.br`)
- **+412MB RAM** liberados

### Sites verificados:
- `hsgroupbrazil.com.br` → RDS ✓
- `servmanindustrial.com.br` → RDS ✓
- `multitecengenharia.com.br` → Sem DB (site estático)

### Como reverter:
```bash
# Reabilitar MySQL local
sudo systemctl enable mysql
sudo systemctl start mysql

# Verificar
sudo systemctl status mysql

# Restaurar otimizações (se necessário)
sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf.bak /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql
```

### Como verificar:
```bash
# Ver status
systemctl status mysql

# Ver RAM usada (se ativo)
ps aux | grep mysql | grep -v grep | awk '{sum+=$6} END {print "MySQL: " sum/1024 " MB"}'

# Ver bancos (se ativo)
sudo mysql -e "SHOW DATABASES;"
```

### Se precisar usar MySQL local no futuro:
```bash
# 1. Reabilitar
sudo systemctl enable mysql
sudo systemctl start mysql

# 2. Criar banco
sudo mysql -e "CREATE DATABASE nome_db;"
sudo mysql -e "CREATE USER 'user'@'localhost' IDENTIFIED BY 'senha';"
sudo mysql -e "GRANT ALL ON nome_db.* TO 'user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 3. Importar dados
sudo mysql nome_db < backup.sql
```

---

## Como Reverter TUDO

### Script completo para reverter todas as otimizações:

```bash
#!/bin/bash
# reverter-otimizacoes.sh

echo "=== Revertendo otimizações ==="

# 1. PHP-FPM
echo "Revertendo PHP-FPM..."
sudo cp /etc/php/8.3/fpm/pool.d/www.conf.bak /etc/php/8.3/fpm/pool.d/www.conf 2>/dev/null
sudo cp /etc/php/8.3/fpm/php.ini.bak /etc/php/8.3/fpm/php.ini 2>/dev/null
sudo systemctl restart php8.3-fpm

# 2. Apache MPM (voltar para prefork)
echo "Revertendo para MPM prefork..."
sudo a2dismod mpm_event
sudo a2enmod mpm_prefork php8.3
sudo a2dismod http2

# 3. Remover HTTP/2 do VirtualHost
echo "Removendo HTTP/2..."
sudo cp /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf.bak2 /etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf 2>/dev/null

# 4. Desabilitar compressão
echo "Desabilitando compressão..."
sudo a2dismod deflate brotli 2>/dev/null

# 5. Desabilitar cache
echo "Desabilitando cache..."
sudo a2dismod expires

# 6. Reabilitar módulos originais
echo "Reabilitando módulos..."
sudo a2enmod autoindex status negotiation 2>/dev/null

# 7. Reabilitar MySQL local
echo "Reabilitando MySQL..."
sudo systemctl enable mysql
sudo systemctl start mysql

# 8. Reiniciar Apache
echo "Reiniciando Apache..."
sudo systemctl restart apache2

echo "=== Reversão completa ==="
echo "Status dos serviços:"
echo "PHP-FPM: $(systemctl is-active php8.3-fpm)"
echo "Apache: $(systemctl is-active apache2)"
echo "MySQL: $(systemctl is-active mysql)"
```

### Como usar:
```bash
# Salvar script
nano /root/reverter-otimizacoes.sh

# Dar permissão
chmod +x /root/reverter-otimizacoes.sh

# Executar
sudo /root/reverter-otimizacoes.sh
```

---

## Backups Criados

Todos os arquivos originais foram salvos com extensão `.bak`:

```
/etc/php/8.3/fpm/pool.d/www.conf.bak
/etc/php/8.3/fpm/php.ini.bak
/etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf.bak
/etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf.bak2
/etc/mysql/mysql.conf.d/mysqld.cnf.bak
```

---

## Monitoramento e Testes

### Verificar performance:
```bash
# Apache status
apache2ctl -V
apachectl -M

# PHP-FPM status
sudo systemctl status php8.3-fpm

# RAM livre
free -h

# Processos PHP
ps aux | grep php-fpm | wc -l

# Processos Apache
ps aux | grep apache2 | wc -l
```

### Testar compressão:
```bash
curl -H "Accept-Encoding: gzip" -I https://hsgroupbrazil.com.br
```

### Testar HTTP/2:
```bash
curl -I --http2 https://hsgroupbrazil.com.br
```

### Teste de carga (opcional):
```bash
# Instalar Apache Bench
sudo apt install apache2-utils -y

# Teste simples (100 requisições, 10 simultâneas)
ab -n 100 -c 10 https://hsgroupbrazil.com.br/

# Teste pesado (1000 requisições, 50 simultâneas)
ab -n 1000 -c 50 https://hsgroupbrazil.com.br/
```

### PageSpeed Insights:
- https://pagespeed.web.dev/
- Testar: https://hsgroupbrazil.com.br

### GTmetrix:
- https://gtmetrix.com/
- Testar performance e otimizações

---

## Ganhos Totais Estimados

| Métrica | Antes | Depois | Ganho |
|---------|-------|--------|-------|
| **Velocidade** | Baseline | +30-50% | 📈 |
| **Banda** | 100% | 30-50% | 💾 -50-70% |
| **Requisições simultâneas** | ~50 | 200-400 | 🚀 3-5x |
| **RAM livre** | ~400MB | ~820MB | 🧠 +412MB |
| **HTTP/2** | ❌ | ✅ | ⚡ Ativo |
| **OPcache** | ❌ | ✅ | ⚡ Ativo |
| **Compressão** | ❌ | ✅ Gzip+Brotli | ⚡ Ativo |

---

## Ajustes Finos (Opcional)

### Se o servidor tiver mais RAM (4GB+):
```bash
# Aumentar PHP-FPM
pm.max_children = 100
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 30

# Aumentar OPcache
opcache.memory_consumption=512
```

### Se o servidor tiver menos RAM (1GB):
```bash
# Reduzir PHP-FPM
pm.max_children = 25
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 8

# Reduzir Apache
MaxRequestWorkers = 200
```

---

## Troubleshooting

### Apache não inicia:
```bash
# Ver erros
sudo systemctl status apache2
sudo journalctl -u apache2 -n 50

# Testar config
sudo apachectl configtest
```

### PHP-FPM não inicia:
```bash
# Ver erros
sudo systemctl status php8.3-fpm
sudo journalctl -u php8.3-fpm -n 50

# Testar config
sudo php-fpm8.3 -t
```

### Site lento mesmo com otimizações:
```bash
# Verificar logs
sudo tail -f /var/log/apache2/hsgroupbrazil.com.br-ssl-error.log

# Verificar slow queries (se MySQL local ativo)
sudo tail -f /var/log/mysql/slow-query.log

# Verificar plugins WordPress
# Desabilitar plugins no wp-admin e testar
```

### Limpar cache completamente:
```bash
# OPcache
sudo systemctl reload php8.3-fpm

# Apache
sudo systemctl reload apache2

# Browser (Ctrl+Shift+R no navegador)
```

---

## Contato e Suporte

**Servidor:** 54.173.247.211
**Sites:** hsgroupbrazil.com.br, servmanindustrial.com.br, multitecengenharia.com.br
**Data das otimizações:** 2025-11-28
**Aplicado por:** Claude Code

**Documentação completa em:**
- `/root/trampo/otimizacao-apache-mysql/`

---

## Changelog

### 2025-11-28
- ✅ PHP-FPM otimizado (pm=dynamic, 50 workers)
- ✅ OPcache habilitado (256MB)
- ✅ Apache MPM Event (migrado de prefork)
- ✅ HTTP/2 habilitado
- ✅ Compressão Gzip + Brotli
- ✅ Cache de navegador (1 ano imagens, 1 mês CSS/JS)
- ✅ Módulos Apache limpos (removidos: autoindex, status, negotiation)
- ✅ MySQL local desabilitado (+412MB RAM)
- ✅ Content Security Policy corrigido (reCAPTCHA)

---

**Fim da documentação**
