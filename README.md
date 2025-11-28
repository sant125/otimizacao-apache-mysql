# Otimizações Apache + PHP-FPM + MySQL

Documentação e scripts para otimização de servidores web LAMP.

## Conteúdo

- **OTIMIZACOES.md** - Documentação completa de todas as otimizações aplicadas
- **reverter-otimizacoes.sh** - Script para reverter todas as otimizações

## Servidor Aplicado

- **IP:** 54.173.247.211
- **Sites:** hsgroupbrazil.com.br, servmanindustrial.com.br, multitecengenharia.com.br
- **Data:** 2025-11-28
- **SO:** Ubuntu 24.04.3 LTS
- **RAM:** 1.9GB

## Otimizações Aplicadas

1. ✅ PHP-FPM otimizado (pm=dynamic, 50 workers)
2. ✅ OPcache habilitado (256MB, 10k files)
3. ✅ Apache MPM Event (migrado de prefork)
4. ✅ HTTP/2 habilitado
5. ✅ Compressão Gzip + Brotli
6. ✅ Cache de navegador (1 ano imagens, 1 mês CSS/JS)
7. ✅ Módulos Apache limpos
8. ✅ MySQL local desabilitado (+412MB RAM)

## Ganhos Estimados

- 📈 **30-50%** mais rápido
- 💾 **50-70%** menos banda (compressão)
- 🚀 **3-5x** mais requisições simultâneas
- 🧠 **+412MB RAM** disponível
- ⚡ HTTP/2, OPcache, Compressão ativos

## Como Usar

### Ver documentação completa:
```bash
cat OTIMIZACOES.md
```

### Reverter otimizações:
```bash
chmod +x reverter-otimizacoes.sh
sudo ./reverter-otimizacoes.sh
```

## Backups Criados

Todos os arquivos originais foram salvos:
- `/etc/php/8.3/fpm/pool.d/www.conf.bak`
- `/etc/php/8.3/fpm/php.ini.bak`
- `/etc/apache2/sites-enabled/hsgroup.com.br-le-ssl.conf.bak`
- `/etc/mysql/mysql.conf.d/mysqld.cnf.bak`

## Acesso ao Servidor

```bash
ssh -i /root/trampo/wh1op09.pem wh1op09@54.173.247.211
```

## Verificar Status

```bash
# PHP-FPM
systemctl status php8.3-fpm

# Apache
systemctl status apache2
apache2ctl -V | grep MPM

# HTTP/2
curl -I --http2 https://hsgroupbrazil.com.br | grep HTTP

# Compressão
curl -H "Accept-Encoding: gzip" -I https://hsgroupbrazil.com.br | grep -i content-encoding

# RAM
free -h
```

## Suporte

Para dúvidas ou problemas, consulte o arquivo `OTIMIZACOES.md` seção "Troubleshooting".
