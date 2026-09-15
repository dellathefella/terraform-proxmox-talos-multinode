# etcd Disaster Recovery

For the happy-path upgrade procedure see [upgrade.md](upgrade.md). This document
covers **quorum loss** — the scenario where you've lost enough control plane
nodes that etcd can no longer commit.

## Symptoms

- `kubectl` hangs or returns `etcdserver: unavailable`
- `talosctl etcd members --nodes <cp>` shows fewer than a quorum of members
- Bootstrap never completes on a fresh control plane

## Decision tree

| Survivors (of 3 CPs) | Action |
| --- | --- |
| 2 of 3 | etcd still has quorum. Rebuild the lost CP node; it rejoins automatically. |
| 1 of 3 | **Restore from snapshot** (below), then rebuild the other two CPs. |
| 0 of 3 | Restore from snapshot onto one node, then join the other two. |

## Restore from S3 snapshot

Requires a snapshot from the backup CronJob (`kubernetes/etcd-backup-cronjob.yaml`)
or a manual `talosctl etcd backup`.

```sh
# 1. On the surviving (or first rebuilt) CP node, list available snapshots
talosctl --nodes <cp-ip> etcd backup ls s3://<bucket>/talos --region <region>

# 2. Restore. This wipes the current etcd data on the target node and
#    re-initializes the cluster from the snapshot.
talosctl --nodes <cp-ip> etcd restore s3://<bucket>/talos/<snapshot-name> \
  --region <region> \
  --restore-from-time="<timestamp>"   # optional: point-in-time

# 3. Reboot the control plane so etcd comes up on the restored data
talosctl reboot --nodes <cp-ip-1>,<cp-ip-2>,<cp-ip-3>

# 4. Verify
talosctl --nodes <cp-ip> etcd members
kubectl get nodes
```

## Rebuilding the lost control plane nodes

After restore, the rebuilt CP VMs (fresh Talos images) join the restored etcd
automatically once their machine config is applied — Terraform handles this if
you replaced the VMs; otherwise:

```sh
tofu apply -replace='module.talos.talos_machine_configuration_apply.control_plane["<name>"]'
```

## If you have no snapshot

- 2-of-3 survivors: you're fine, just rebuild the third.
- 1-of-3 with no snapshot: the data on the survivor is unrecoverable as a
  cluster. Back up what you can from Longhorn volumes (they survive independently
  of etcd) and rebuild the cluster, restoring workloads from Longhorn backups.

## Prevention checklist

- [ ] Backup CronJob deployed and **tested** (a backup you've never restored is a rumor)
- [ ] Snapshots go to different failure domain than the cluster (S3/PBS, not local)
- [ ] Nightly restore verification job (restore into a scratch namespace/VM)
- [ ] 3 CPs on 3 distinct PVE nodes (enforced by `control_plane_node_spread` check)
