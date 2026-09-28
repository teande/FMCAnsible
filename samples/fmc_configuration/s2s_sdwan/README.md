# SD-WAN site-to-site VPN example

This example invokes the `cisco.fmcansible.s2s_vpn` role once to configure one
cdFMC `AUTO_VPN` topology with a borrowed-IP hub
DVTI and an automatically generated spoke SVTI. It is adapted from the live
S2S integration test. The target FTDs must run version 7.3 or later. This
example configures FMC and, when requested, deploys the configuration; it does
not test dataplane traffic or configure BGP.

## Dependencies

### Already present in FMC or the environment

| Dependency | Why it is needed |
| --- | --- |
| cdFMC tenant, domain, and API token | The inventory uses the collection's `httpapi` connection. |
| Two distinct registered and managed FTDs, version 7.3+ | One hub and one spoke are required. |
| Enabled, named, routed source interfaces on both FTDs | The hub DVTI and generated spoke SVTI use these interfaces. |
| Reachable underlay addresses and routing | FMC can save the configuration without tunnel reachability. |
| FMC supplied IKEv2/IPsec defaults | This example uses the policies and proposals supplied by FMC. Review their algorithms against your security policy before deployment. |
| Permission to configure devices and deploy | Required only for the actions selected by the playbook. |

### Created or changed by this example

| Resource | Operation |
| --- | --- |
| Spoke IPv4 tunnel address pool | Create and read back. |
| Routed security zone for the spoke SVTI | Create and read back. |
| Hub loopback and DVTI borrowing its address | Create and read back. |
| `AUTO_VPN` S2S topology | Create and read back. |
| Topology IPsec settings | Disable reverse-route injection on the answer-only hub. |
| Hub and spoke endpoints | Create and read back. FMC generates the spoke SVTI. |
| Generated spoke SVTI | Discover and read back. |
| Device deployment | Only when `s2s_vpn.deploy: true`. |

An AD realm, RAVPN policy, and Secure Client package are not dependencies for
site-to-site SD-WAN. Policy-based and manual route-based S2S examples will be
added separately.

## Run

[`site.yml`](site.yml) is the playbook. Its `roles` entry invokes
`cisco.fmcansible.s2s_vpn`; the `s2s_vpn` mapping in
[`vars.example.yml`](vars.example.yml) supplies its inputs. The inventory
connects to cdFMC, not to either FTD directly.

From the collection checkout, set `FMCANSIBLE_CDFMC_URL` and
`FMCANSIBLE_CDFMC_TOKEN` in your shell from a secret store, then make a
private copy of `vars.example.yml` with your device/interface names and
addresses outside the repository, for example `/tmp/private-sdwan.yml`. Build
and install this branch into an isolated collection path so
Ansible does not load the published 1.1.1 package, which lacks the role. The
local artifact still reports version 1.1.1 because this branch is unreleased;
do not publish it. Do not commit the token or private variables file. The
example inventory enables HTTPS certificate validation.

```sh
ansible-galaxy collection build . --output-path /tmp/fmcansible-role-build
ansible-galaxy collection install \
  /tmp/fmcansible-role-build/cisco-fmcansible-1.1.1.tar.gz \
  -p /tmp/fmcansible-role-collections --force
export ANSIBLE_COLLECTIONS_PATH=/tmp/fmcansible-role-collections:$HOME/.ansible/collections
ansible-playbook -i samples/fmc_configuration/s2s_sdwan/inventory.example.yml \
  samples/fmc_configuration/s2s_sdwan/discover.yml
ansible-playbook -i samples/fmc_configuration/s2s_sdwan/inventory.example.yml \
  samples/fmc_configuration/s2s_sdwan/site.yml -e @/tmp/private-sdwan.yml
```

`inventory.example.yml` reads `FMCANSIBLE_CDFMC_URL` and
`FMCANSIBLE_CDFMC_TOKEN` from the process environment. `discover.yml` lists
managed devices and physical interface names without changing FMC.
The sample variables default to `s2s_vpn.state: inspect`, which checks
prerequisites and ownership without changing FMC. If `deploy: true`, inspection
also checks for pre-existing pending changes on the selected devices. Change
the state to `present` only when ready to create the VPN.

Set `s2s_vpn.state: absent` in the variables file to remove the topology and
the resources owned by this example. The example checks ownership using its
description marker before deleting named resources. cdFMC may omit security
zone descriptions from GET responses; this zone is instead named
`<s2s_vpn.name>-zone` and is managed as part of that topology. Choose a
unique VPN name and do not reuse its derived zone name for other purposes.
`deploy` defaults to
`false`; enabling it can also deploy other pending changes on the same FTDs,
so start from a clean deployment baseline.

The input names are stable across runs. A second `present` run reads the same
resources back and does not recreate them. The VPN object name must be unique
in the FMC domain. A name collision with a resource that lacks this example's
ownership marker fails before it is changed, except for the derived zone
where cdFMC does not preserve that marker.
