# Manual route-based site-to-site VPN example

This playbook invokes `cisco.fmcansible.s2s_vpn` once with
`mode: route_based`. It configures a point-to-point IKEv2 topology between
two managed FTDs. Each endpoint gets a loopback and a static VTI borrowing
that loopback's IPv4 address. It configures FMC and optionally deploys; it
does not add BGP, static routes, or dataplane traffic tests.

## Prerequisites

- Two distinct connected FTDs on version 7.3 or later, each with an enabled,
  named, routed physical source interface and reachable underlay addressing.
- Existing IKEv2 policy and IKEv2 IPsec proposal. Set their exact names in
  `s2s_vpn.crypto`; the role does not create or select cryptography silently.
- A cdFMC API token supplied by a secret store. The example inventory reads
  `FMCANSIBLE_CDFMC_URL` and `FMCANSIBLE_CDFMC_TOKEN` from the environment and
  validates the HTTPS certificate.
- Unique topology name, zone name (`<name>-zone`), loopback IDs, and tunnel
  IDs. Reserve these resources for this role.

The role creates the routed zone, both loopbacks and static VTIs, the
point-to-point topology, IKE/IPsec settings, and two peer endpoints. It
reads every resource back. A repeated `present` run should make no changes.
`absent` removes only resources matching the role's ownership marker and
the exact derived zone name; cdFMC may omit security-zone descriptions.

## Run

From the feature-branch collection checkout, build and install into an
isolated path. The local artifact still reports version 1.1.1 because this
branch is unreleased; do not publish it. Put a private copy of
[`vars.example.yml`](vars.example.yml) outside the repo, such as
`/tmp/private-route-based.yml`, and replace the example device names,
interfaces, addresses, IDs, and crypto object names.

```sh
ansible-galaxy collection build . --output-path /tmp/fmcansible-role-build
ansible-galaxy collection install \
  /tmp/fmcansible-role-build/cisco-fmcansible-1.1.1.tar.gz \
  -p /tmp/fmcansible-role-collections --force
export ANSIBLE_COLLECTIONS_PATH=/tmp/fmcansible-role-collections:$HOME/.ansible/collections
ansible-playbook -i samples/fmc_configuration/s2s_route_based/inventory.example.yml \
  samples/fmc_configuration/s2s_route_based/site.yml \
  -e @/tmp/private-route-based.yml
```

Start with `state: inspect` to check ownership and device prerequisites
without changing FMC. Set `state: present` to create the VPN. `deploy`
defaults to `false`; enable it only when both FTDs have no unrelated pending
changes. Set `state: absent` to remove the resources. The role refuses
ambiguous matches or unowned resources instead of replacing them.
