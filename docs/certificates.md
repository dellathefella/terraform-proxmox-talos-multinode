# Certificate Lifecycle

Talos manages all cluster certificates via the machine secrets
(`talos_machine_secrets` in this module). Key facts and procedures:

## Lifetimes

| Certificate | TTL |
| --- | --- |
| Talos / Kubernetes CA | **825 days** (fixed by Talos, not configurable) |
| talosconfig admin client cert | inherits the CA's `NotAfter` → **825 days** |
| Serving / API certs (kubelet, apiserver, etcd) | ~1 year, auto-rotated by Talos well before expiry |

Serving certificates **auto-rotate** — you rarely need to act.

> **A 10-year self-signed cert is not achievable through this module.** Talos
> hardcodes the CA validity at 825 days and exposes no override in
> `talos_machine_secrets` or the machine config. The provider's *ephemeral*
> `talos_client_configuration` has a `crt_ttl` knob, but (a) the data source
> this module uses has no such knob, and (b) even a 10-year leaf is capped by the
> CA's `NotAfter` during X.509 chain validation.
>
> Practical options:
> - Rotate the CA roughly every 2 years (`talosctl rotate-ca`).
> - Import your own long-lived CA via
>   `tofu import 'module.talos.talos_machine_secrets.cluster_machine_secret' ./secrets.yaml`
>   (manual, one-time, not managed by this module).

## Inspecting expiry

```sh
# API server serving cert
echo | openssl s_client -connect <cluster_api_endpoint>:6443 2>/dev/null \
  | openssl x509 -noout -dates -subject

# CA cert used by your talosconfig (written to ./talosconfig at apply time)
grep -A100 'ca:' ./talosconfig | base64 -d \
  | openssl x509 -noout -dates
```

Set a calendar reminder **~6 months before CA expiry**.

## Rotating the CA

CA rotation is a Talos-supported but disruptive procedure:

1. Generate new secrets: `talos_machine_secrets` with `on_destroy` protection
   removed, or use `talosctl gen` to create a new CA and re-issue identities.
2. Follow the official procedure:
   https://www.talos.dev/latest/guides/etcd-ca-rotation/ (etcd CA) and the
   Kubernetes CA rotation guide for the kube CA.
3. Re-issue kubeconfig/talosconfig to all consumers.

**Do not** simply replace `talos_machine_secrets` in state — every existing
certificate becomes invalid and the cluster will not recover without a restore.

## Monitoring recommendation

Add an alert for `apiserver_client_certificate_expiration_seconds` (exposed by
kube-apiserver) and for the Talos `CertificateStatus` resource:

```sh
talosctl get certificates --nodes <ip>
```

Alert when any certificate is < 30 days from expiry.
