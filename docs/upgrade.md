# Talos & Kubernetes Upgrade Runbook

This module gates upgrades with `data.talos_cluster_health`, so a failed upgrade
surfaces as a stuck/failed `terraform apply` rather than a silently broken cluster.

## Before you start

1. **Back up etcd** — see `kubernetes/etcd-backup-cronjob.yaml` or run manually:
   ```sh
   talosctl etcd backup s3://<bucket>/manual-$(date -u +%Y%m%dT%H%M%SZ) --nodes <cp-ip>
   ```
2. Check the Talos upgrade path: Talos supports skipping at most **one** minor
   version (e.g. 1.12 → 1.14 is OK, 1.11 → 1.14 is not).
3. Verify the target version exists on Image Factory:
   `https://factory.talos.dev/versions`

## Upgrade sequence

Bump `talos_version` in your tfvars, then apply. The new disk image is downloaded
per node. Then upgrade nodes one at a time (never all at once):

```sh
# 1. Cordon + drain the node
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# 2. Upgrade in place (uses the installer image for your schematic)
talosctl upgrade --nodes <node-ip> \
  --image factory.talos.dev/installer/<schematic_id>:<new-version> \
  --on-reboot=reboot

# 3. Wait for the node to rejoin and be Ready
kubectl wait --for=condition=Ready node/<node> --timeout=10m

# 4. Uncordon and move on
kubectl uncordon <node>
```

Order: workers → control planes (one CP at a time, etcd health between each):

```sh
talosctl etcd health --nodes <cp-ip>
```

## If an upgrade fails

- `talosctl rollback --nodes <node>` reboots into the previous OS partition.
- Full etcd restore (last resort, cluster-wide):
  ```sh
  talosctl etcd restore s3://<bucket>/<snapshot> --restore-from-time=... --nodes <all-cp-ips>
  ```
  Then re-apply machine configs and reboot the control plane.

## Kubernetes version

The Kubernetes version is tied to the Talos version (each Talos release ships a
specific kube). Upgrading Talos upgrades Kubernetes — check the
[Talos support matrix](https://www.talos.dev/latest/support-scope/) for the
kube version that ships with your target.
