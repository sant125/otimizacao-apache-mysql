# Diagnóstico

## Ver se travou por falta de memória

```bash
# Ver se OOM Killer matou processos
sudo dmesg -T | grep -i 'killed process' | tail -20

# Ver erros do sistema
sudo journalctl -p err -S '3 days ago' | tail -50
```

## Logs

```bash
# MySQL
sudo tail -100 /var/log/mysql/error.log

# Apache
sudo tail -100 /var/log/apache2/error.log
```

## Status atual

```bash
# Memória
free -h
ps aux --sort=-%mem | head -10

# Swap
sudo swapon --show

# Disco
df -h
```

## Script rápido

```bash
cat > /tmp/check.sh <<'EOF'
#!/bin/bash
echo "=== Memória ==="
free -h
echo ""
echo "=== Swap ==="
sudo swapon --show
echo ""
echo "=== Disco ==="
df -h /
echo ""
echo "=== Top 5 processos ==="
ps aux --sort=-%mem | head -6
echo ""
echo "=== OOM recente? ==="
sudo dmesg -T | grep -i 'killed process' | tail -3
EOF
chmod +x /tmp/check.sh
/tmp/check.sh
```
