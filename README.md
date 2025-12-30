# Proxmox ZFS Snapshot Manager

Lightweight shell script to manage ZFS snapshots on Proxmox VE with configurable retention policies.

## Why This Tool?

In public sector and budget-conscious environments, we need enterprise-grade backup solutions without vendor lock-in. This script leverages native ZFS capabilities for:

- **Automated snapshot creation** (hourly/daily/weekly)
- **GFS-style rotation** (Grandfather-Father-Son retention)
- **Syslog integration** for audit trails
- **Zero external dependencies** (just bash and zfs)
- **Idempotent execution** (safe to run multiple times)

## Features

- ✅ Recursive snapshots for entire datasets
- ✅ Configurable retention policies (hourly, daily, weekly)
- ✅ Robust error handling and logging
- ✅ Dataset validation before operations
- ✅ Integration-ready for offsite replication (`zfs send/recv`)
- ✅ Prometheus metrics export (optional)

## Installation

### Prerequisites

- Proxmox VE 7.x or 8.x (Debian-based)
- ZFS storage pool configured
- Root access or sudo privileges

### Quick Start

Download the script
wget https://raw.githubusercontent.com/patrickbloem-it/proxmox-zfs-snapshot-manager/main/zfs-snapshot-manager.sh

Make it executable
chmod +x zfs-snapshot-manager.sh

Run manually
./zfs-snapshot-manager.sh rpool/data

Or install system-wide
sudo cp zfs-snapshot-manager.sh /usr/local/bin/

## Usage

### Basic Usage

Snapshot a single dataset
/usr/local/bin/zfs-snapshot-manager.sh rpool/data

Snapshot with custom retention (keep last 48 hourly)
RETENTION_HOURLY=48 /usr/local/bin/zfs-snapshot-manager.sh rpool/data

### Automated Execution (Cron)

Add to `/etc/crontab`:

Hourly snapshots at minute 5
5 * * * * root /usr/local/bin/zfs-snapshot-manager.sh rpool/data 2>&1 | logger -t zfs-snapshot

Daily snapshots at 02:00
0 2 * * * root /usr/local/bin/zfs-snapshot-manager.sh rpool/backups 2>&1 | logger -t zfs-snapshot


### Systemd Timer (Alternative)

For better control, use systemd timers:

Create service file
sudo nano /etc/systemd/system/zfs-snapshot@.service

Create timer file
sudo nano /etc/systemd/system/zfs-snapshot@.timer

Enable for specific dataset
sudo systemctl enable --now zfs-snapshot@rpool-data.timer


## Configuration

Edit the script header to customize:

RETENTION_HOURLY=24 # Keep last 24 hourly snapshots
RETENTION_DAILY=7 # Keep last 7 daily snapshots
LOG_FACILITY="local0" # Syslog facility


## Advanced: Offsite Replication

Combine with `zfs send/recv` for disaster recovery:

#!/bin/bash

Example: Replicate latest snapshot to remote NAS
DATASET="rpool/data"
REMOTE_HOST="backup-server.local"
REMOTE_POOL="backup/proxmox"

LATEST_SNAP=$(zfs list -H -t snapshot -o name -s creation | grep "${DATASET}@auto-hourly" | tail -1)

if [ -n "$LATEST_SNAP" ]; then
zfs send -R "$LATEST_SNAP" | ssh "$REMOTE_HOST" "zfs recv -F $REMOTE_POOL"
fi


### Metrics Export (Prometheus)

Expose snapshot count for monitoring:

Add to script or create wrapper
echo "zfs_snapshots_total{dataset="rpool/data"} $(zfs list -t snapshot | grep -c 'rpool/data@')" > /var/lib/node_exporter/zfs_snapshots.prom


## Compliance & Audit

All operations are logged to syslog (`local0` facility by default). Forward logs to your SIEM:

Example rsyslog configuration
local0.* @@siem-server.local:514

## Troubleshooting

### "Dataset not found"
Verify dataset exists: `zfs list -H -o name`

### Permission Denied
Run as root or add user to `zfs` permissions:
zfs allow -u username create,destroy,mount,snapshot rpool/data

### Snapshots Not Rotating
Check cron logs: `grep zfs-snapshot /var/log/syslog`

## Related Article

📖 Read the full write-up: [Cost-Effective Disaster Recovery on Dev.to](https://dev.to/patrickbloemit/cost-effective-disaster-recovery-managing-zfs-snapshots-on-proxmox-ve)

## License

MIT License - See [LICENSE](LICENSE) file

## Contributing

Contributions welcome! Please:
1. Test changes on non-production systems first
2. Follow existing code style (ShellCheck compliant)
3. Update documentation for new features

## Author

**Patrick Bloem**  

- 🔗 [LinkedIn](https://www.linkedin.com/in/patrick-bloem-it/)
- 💼 [Xing](https://www.xing.com/profile/Patrick_Bloem/)
- 🐙 [GitHub](https://github.com/patrickbloem-it)
- ✍️ [Dev.to](https://dev.to/patrickbloemit)

---

*Built for the public sector. Shared for everyone.*
