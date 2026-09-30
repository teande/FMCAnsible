# s2s_vpn role

Configure one site-to-site VPN per invocation. `mode: sdwan` creates an
`AUTO_VPN` topology with a borrowed-IP hub DVTI and FMC-generated spoke SVTI.
`mode: route_based` creates a point-to-point topology with two explicit static
VTIs borrowing loopback addresses. Policy-based mode is not supported yet.
The target FTDs must run version 7.3 or later. This role is not in the
published 1.1.1 collection; use this feature branch until it is released.

## SD-WAN playbook example

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

## Manual route-based example

The playbook invocation is the same; set `mode: route_based` and supply
loopback and static VTI identifiers on **both** endpoints. The role requires
exact names of existing IKEv2 and IPsec proposal objects:

```yaml
- name: Configure one manual route-based VPN
  hosts: cdfmc
  connection: httpapi
  gather_facts: false
  roles:
    - role: cisco.fmcansible.s2s_vpn
      vars:
        s2s_vpn:
          mode: route_based
          name: example-route-based
          state: inspect
          deploy: false
          crypto:
            ikev2_policy: AES-GCM-NULL-SHA-LATEST
            ipsec_proposal: AES-GCM
          hub:
            device: hub-ftd
            source_interface: outside
            loopback:
              id: 90
              ifname: route-hub-lo
              address: 169.254.90.1
              netmask: 255.255.255.252
            tunnel:
              id: 90
              ifname: route-hub-vti
          spoke:
            device: spoke-ftd
            source_interface: outside
            loopback:
              id: 91
              ifname: route-spoke-lo
              address: 169.254.90.2
              netmask: 255.255.255.252
            tunnel:
              id: 91
              ifname: route-spoke-vti
```

Replace the example crypto names with objects present in your FMC domain.
See the [route-based sample](../../samples/fmc_configuration/s2s_route_based/README.md)
for an inventory, private variable file, and commands. This mode uses
automatic pre-shared keys, IKEv2, IPsec tunnel mode, and disables
reverse-route injection. It preserves FMC's other IPsec defaults.

| Input | Default | Meaning |
| --- | --- | --- |
| `s2s_vpn.mode` | `sdwan` | `sdwan` or `route_based`. |
| `s2s_vpn.name` | Required | Unique topology name; the zone is named `<name>-zone`. |
| `s2s_vpn.domain_uuid` | Sole FMC domain | Required only when FMC has multiple domains. |
| `s2s_vpn.state` | `present` | `inspect`, `present`, or `absent`. |
| `s2s_vpn.deploy` | `false` | Deploy only when the selected FTDs have no pre-existing pending changes. |
| `s2s_vpn.hub` | Required | Managed hub FTD, routed source interface, and loopback/tunnel identifiers. |
| `s2s_vpn.spoke` | Required | Managed spoke FTD and routed source interface; route-based mode also requires loopback/tunnel identifiers. |
| `s2s_vpn.spoke_pool` | SD-WAN only | IPv4 tunnel pool name, range, and mask. |
| `s2s_vpn.crypto` | Route-based `present` only | Exact existing IKEv2 policy and IPsec proposal names. |

SD-WAN uses the FMC-provided IKEv2/IPsec defaults and disables reverse-route
injection for the answer-only hub. Review FMC's crypto defaults before
deployment. Neither mode configures BGP or tests traffic. The role checks device
version and interface prerequisites, refuses ambiguous or conflicting named
resources, and GET-verifies objects after creation and deletion. If an
assertion fails, its message identifies the relevant `s2s_vpn` field or FMC
resource.

The cdFMC API may omit security-zone descriptions even after creation or
update. The role therefore owns the exact `<name>-zone` zone name and requires
it to be routed. Use a unique topology name and do not reuse that zone name.

See the [SD-WAN example](../../samples/fmc_configuration/s2s_sdwan/README.md)
for inventory and discovery commands.
