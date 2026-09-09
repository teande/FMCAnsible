# Testing FMCAnsible

This collection must be tested from an Ansible collection source layout:

```text
ansible_collections/cisco/fmcansible
```

The repository root is not in that layout, so direct `ansible-test` commands from the clone root fail. Use the local wrapper instead:

```bash
scripts/ansible-test-local.sh sanity --color -v
scripts/ansible-test-local.sh units --requirements --color -v
```

For Docker-backed tests, which are recommended for CI:

```bash
scripts/ansible-test-local.sh sanity --docker --color -v
scripts/ansible-test-local.sh units --docker --requirements --color -v
```

Build the collection:

```bash
ansible-galaxy collection build --output-path dist
```

Run the dependency matrix against supported Ansible-core versions and `cisco.nxos`:

```bash
PYTHON_BIN=python3.12 scripts/dependency-matrix.sh
```

The default matrix is:

```text
2.17.14 2.18.18 2.19.11 2.20.7 2.21.2
```

## Regression Scope

Regression testing means proving that existing collection behavior still works after a fix. For this collection, the minimum regression gate is:

- `ansible-test sanity`
- `ansible-test units`
- collection build
- Galaxy importer check
- dependency install beside `cisco.nxos`
- representative `fmc_configuration` operations: `getAllDomain`, create/update/delete object, and `upsertHostObject`
- `fmc_facts` fact gathering
- classic FMC username/password auth
- cdFMC bearer-token auth
- long-running classic FMC playbook that crosses the access-token expiry window
