# Remote-access VPN example

This example invokes `cisco.fmcansible.ravpn` once. It defaults to
`state: inspect` and `deploy: false`; it does not change FMC until the inputs
are replaced with real prerequisite names and `state: present` is set.

Set `FMCANSIBLE_FMC_HOST`, `FMCANSIBLE_FMC_USER`, and
`FMCANSIBLE_FMC_PASSWORD` from a secret store. Use the FMC hostname without
`https://` in `FMCANSIBLE_FMC_HOST`. Copy `vars.example.yml` to a private
location outside the repository and update the target, realm, and prerequisite
names. Do not commit credentials or private variable files.

From a collection checkout installed into an isolated collection path:

```sh
ansible-playbook -i samples/fmc_configuration/ravpn/inventory.example.yml \
  samples/fmc_configuration/ravpn/site.yml \
  -e @/path/to/private-ravpn.yml
```

The address pool, group policy, DAP, policy, and profiles are owned by the role.
The security zone, Secure Client package, IKEv2 policy, certificate, and AD or
local realm must already exist. Run `state: present` with `deploy: false` to
inspect created configuration, then use `deploy: true` after confirming the
target's deployment baseline. Run `state: absent` to remove role-owned
resources. See [role inputs](../../../roles/ravpn/README.md) for restrictions.
