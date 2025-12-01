# Otimização Apache + MySQL - Ubuntu

Guia rápido de otimização por tamanho de máquina.

---

## Escolha sua máquina:

| Máquina | Config |
|---------|--------|
| **1v1** (1GB RAM) | [configs/1v1.md](configs/1v1.md) |
| **1v2** (2GB RAM) | [configs/1v2.md](configs/1v2.md) |
| **2v2** (2GB RAM) | [configs/2v2.md](configs/2v2.md) |
| **2v4** (4GB RAM) | [configs/2v4.md](configs/2v4.md) |
| **2v8** (8GB RAM) | [configs/2v8.md](configs/2v8.md) |

---

## Resumo

| Config | 1v1 | 1v2/2v2 | 2v4 | 2v8 |
|--------|-----|---------|-----|-----|
| Swap | 2GB | 2GB | 4GB | 4GB |
| MySQL Buffer | 256M | 512M | 1G | 2G |
| MySQL Connections | 30 | 40 | 50 | 100 |
| Apache Workers | 20 | 30 | 50 | 100 |

---

## Diagnóstico rápido

```bash
# Ver se houve OOM (memória esgotada)
sudo dmesg -T | grep -i 'killed process'

# Ver uso atual
free -h
sudo swapon --show
df -h

# Ver logs de erro
sudo tail -100 /var/log/mysql/error.log
sudo tail -100 /var/log/apache2/error.log
```

Mais detalhes: [diagnostico.md](diagnostico.md)
