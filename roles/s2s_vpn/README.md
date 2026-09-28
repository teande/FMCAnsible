# s2s_vpn role

Configure one site-to-site VPN per invocation. `mode: sdwan` is implemented;
policy-based and manual route-based modes are planned but not yet supported.
The target FTDs must run version 7.3 or later. This role is not in the
published 1.1.1 collection; use this feature branch until it is released.

## Playbook example

In an Ansible collection, `roles/s2s_vpn/tasks/main.yml` is the role's entry
point. You do not call that task file directly. Add the fully qualified role
name under `roles` in a playbook and pass one `s2s_vpn` mapping:

```yaml
- name: Configure one site-to-site VPN
  hosts: cdfmc
  connection: httpapi
  gather_facts: false
  roles:
    - role: cisco.fmcansible.s2s_vpn
      vars:
        s2s_vpn:
          mode: sdwan
          name: example-sdwan
          state: inspect
          deploy: false
          hub:
            device: hub-ftd
            source_interface: outside
            loopback:
              id: 94
              ifname: sdwan-hub-lo
              address: 198.18.94.1
              netmask: 255.255.255.255
            tunnel:
              id: 94
              ifname: sdwan-hub-dvti
          spoke:
            device: spoke-ftd
            source_interface: outside
          spoke_pool:
            name: example-sdwan-tunnel-pool
            range: 198.18.94.10-198.18.94.50
            mask: 255.255.255.0
```

Replace device and interface names with those discovered from your FMC. Run
with `state: inspect` first to validate prerequisites without changing FMC;
then use `state: present` to create the VPN. `deploy: false` leaves changes
pending. Set `deploy: true` only after reviewing other pending changes on the
selected FTDs. Use `state: absent` to remove resources owned by this role.
The [sample directory](../../samples/fmc_configuration/s2s_sdwan/README.md)
has a separate inventory, variables file, and commands for this workflow.

| Input | Default | Meaning |
| --- | --- | --- |
| `s2s_vpn.mode` | `sdwan` | VPN topology mode. Only `sdwan` is supported now. |
| `s2s_vpn.name` | Required | Unique topology name; the zone is named `<name>-zone`. |
| `s2s_vpn.domain_uuid` | Sole FMC domain | Required only when FMC has multiple domains. |
| `s2s_vpn.state` | `present` | `inspect`, `present`, or `absent`. |
| `s2s_vpn.deploy` | `false` | Deploy only when the selected FTDs have no pre-existing pending changes. |
| `s2s_vpn.hub` | Required | Managed hub FTD, routed source interface, loopback, and DVTI identifiers. |
| `s2s_vpn.spoke` | Required | Managed spoke FTD and routed source interface. |
| `s2s_vpn.spoke_pool` | Required | IPv4 tunnel pool name, range, and mask. |

The role uses the FMC-provided IKEv2/IPsec defaults and disables reverse-route
injection for the answer-only hub. Review FMC's crypto defaults before
deployment. It does not configure BGP or test traffic. The role checks device
version and interface prerequisites, refuses ambiguous or conflicting named
resources, and GET-verifies objects after creation and deletion. If an
assertion fails, its message identifies the relevant `s2s_vpn` field or FMC
resource.

The cdFMC API may omit security-zone descriptions even after creation or
update. The role therefore owns the exact `<name>-zone` zone name and requires
it to be routed. Use a unique topology name and do not reuse that zone name.

See the [SD-WAN example](../../samples/fmc_configuration/s2s_sdwan/README.md)
for inventory and discovery commands.
