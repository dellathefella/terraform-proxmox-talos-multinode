# VIP Failover Drill (HA load balancer)

Run this quarterly to prove the HA pair actually fails over. Takes ~5 minutes.

## Prerequisites

- `lb_ha_enabled = true` with the secondary LB on a separate PVE node
- A client that uses the VIP (`lb_vip`) as the kubeconfig/Talos endpoint
- Two terminals

## Drill steps

### 1. Baseline — confirm the VIP is on the primary

```sh
# On the primary LB LXC
ip -4 addr show eth0 | grep <lb_vip>     # should be present
# On the secondary LB LXC
ip -4 addr show eth0 | grep <lb_vip>     # should be absent
```

### 2. Start a continuous probe from a client

```sh
# 1 request/second against the API through the VIP
while true; do curl -sk -o /dev/null -w "%{http_code} %{time_total}s\n" https://<lb_vip>:6443/version; sleep 1; done
```

Note the baseline latency.

### 3. Kill nginx on the primary (simulates LB process crash)

```sh
# On the primary LB
systemctl stop nginx
```

**Expected:** probe fails for ≤ 3s (track script: 3 checks × 1s + failover),
then recovers at the same latency via the secondary.

```sh
# Verify VIP moved
ip -4 addr show eth0 | grep <lb_vip>     # now on the SECONDARY
```

### 4. Restore the primary

```sh
systemctl start nginx
```

**Expected:** VIP preempts back to the primary within ~1s (higher priority).
Probe should not drop during preemption (nginx is already up before the VIP moves).

### 5. Node-level failover (optional, more disruptive)

Shut down the entire primary PVE node:

```sh
# primary PVE node
shutdown -h now
```

**Expected:** VIP on secondary within ~3s; cluster API stays available
(etcd still has quorum from the other CP nodes).

## Pass criteria

| Check | Target |
| --- | --- |
| API unavailable window during nginx crash | < 5s |
| API unavailable during node loss | < 5s |
| kubectl / talosctl recover without intervention | Yes |
| VIP preempts back cleanly | Yes, no duplicate-IP warnings in `journalctl -u keepalived` |

## If it fails

- VIP didn't move: check `journalctl -u keepalived` on both LBs — usually a
  VRRP auth mismatch or the unicast peer blocked by the PVE firewall
  (the `vrrp` rule must be present when `lb_firewall_enabled = true`).
- VIP moved but API stayed down: secondary's nginx config drifted — re-run
  `tofu apply` and check the `talos_nginx_config` triggers.
- Duplicate IP: both sides think they're master — check for asymmetric
  firewall rules dropping VRRP adverts.
