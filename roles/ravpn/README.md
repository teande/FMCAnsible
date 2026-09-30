# Remote-access VPN role

`cisco.fmcansible.ravpn` configures one remote-access VPN policy and its IPv4
pool, group policy, default dynamic access policy, and connection profiles.
It reads each created object back and checks key fields. `state: absent`
removes only resources bearing the role's ownership marker. `state: inspect`
discovers the target and prerequisites without changing FMC.

FTD 7.3 or later is required. The target must be connected and managed. The
role uses existing security zone, Secure Client image, IKEv2 policy, certificate
enrollment, and AD or local realms. It does not create an AD connection,
certificate, package, or local user. Configure and validate these separately.
The RAVPN policy uses the existing IKEv2 policy's algorithms; select one that
meets your organization's security requirements.

`state: present` creates the FMC configuration; `deploy: true` additionally
assigns the policy to `target_device` and deploys that FTD. Use
`state: absent` to unassign and remove the role-owned configuration.

| `ravpn` field | Required for `present` or `inspect` | Meaning |
| --- | --- | --- |
| `name`, `target_device` | Yes | Unique policy name and exact FTD name. |
| `state` | No | `inspect` (read-only), `present` (default), or `absent`. |
| `deploy` | No | `false` (default). When true, requires a clean target baseline and deploys only that FTD. |
| `domain_uuid` | If multiple domains | FMC domain UUID. |
| `access_zone` | Yes | Existing routed security zone for VPN termination. |
| `secure_client.name`, `secure_client.os` | Yes | Existing client image and `WINDOWS`, `MAC`, or `LINUX`. |
| `ikev2_policy`, `certificate` | Yes | Existing policy and certificate enrollment names. |
| `pool.range`, `pool.mask` | Yes | IPv4 address range and netmask for clients. |
| `group_policy.default_domain` | Yes | DNS suffix for clients. |
| `group_policy.banner` | No | Default `Authorized access only`. |
| `group_policy.simultaneous_logins` | No | Default `2`. |
| `group_policy.vpn_idle_timeout` | No | Minutes; default `30`. |
| `group_policy.mtu` | No | Default `1406`. |
| `profiles` | Yes | One or more unique names, `authentication: ad` or `local`, exact existing realm name, optional alias. |

Only full-tunnel IPv4 address assignment is currently supported. Split-tunnel
network lists, DHCP assignment, SAML, secondary authentication, and custom DAP
rules are not part of this role. A local-auth profile is not deployed unless
FMC returns its `localRealmServer` binding on read-back. These constraints
avoid silently creating a configuration that the role cannot verify.

`deploy: true` also checks the Secure Client license and enrolled certificate
before writing, and refuses an FTD with unrelated pending changes. No
`ignoreWarning` or `forceDeploy` override is exposed. This role verifies FMC
configuration and deployment state, not client sign-in or dataplane traffic.

See [the runnable example](../../samples/fmc_configuration/ravpn/README.md).
