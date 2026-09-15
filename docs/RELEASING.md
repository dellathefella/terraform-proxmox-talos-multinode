# Releasing

This module is consumed via git tags. To publish a release:

```sh
# 1. Make sure CI is green on main.
git checkout main && git pull

# 2. Tag a semver version (bump per semver; breaking variable changes = major).
git tag -a v1.1.0 -m "v1.1.0: <summary of changes>"
git push origin v1.1.0
```

The `release.yml` workflow creates a GitHub release with auto-generated notes.

Consumers can then pin:

```hcl
module "talos" {
  source = "git::https://github.com/dellathefella/terraform-proxmox-talos-multinode.git?ref=v1.1.0"
}
```

Renovate will open PRs to bump consumer pins when new tags appear.

## Breaking changes checklist

- [ ] Variable renames documented in README migration section
- [ ] `tofu state mv` commands provided for any resource address changes
- [ ] Major version bumped
- [ ] `tofu test` updated to cover the new behavior
