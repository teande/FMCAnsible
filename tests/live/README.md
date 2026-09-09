# FMCAnsible Live Tests

These playbooks are acceptance tests for real FMC targets. They are intentionally
separate from unit and sanity tests because they create and delete configuration
on a live manager.

## Branching

Keep this live-test framework on a separate branch from urgent product fixes.
The refresh-token and dependency work should stay focused; live lab automation,
Jenkins orchestration, and customer template generation should be reviewed as a
separate change.

## Inventory

Only example inventories live in this repository:

- `inventories/onprem.example.yml`
- `inventories/cdfmc.example.yml`

Real inventories and secrets should be provided by Jenkins credentials or an
internal private repo.

Every run must set a unique identifier:

```bash
export FMCANSIBLE_RUN_ID="manual-$(date +%Y%m%d-%H%M%S)"
```

The identifier becomes part of every created resource name. Jenkins must use a
value derived from `BUILD_NUMBER` and the checked-out commit.

## Targets

The same test shape is used for:

- on-prem FMC
- cdFMC

For cdFMC, use an API token issued by Security Cloud Control (SCC) and point
`CDFMC_HOST` at the cdFMC API host. SCC is the control plane that issues the
token; it is not a separate FMCAnsible configuration target.

Each platform has internal feature gates in `vars/feature_matrix.yml`. A missing
API operation should become an explicit test skip or limitation rather than an
unexplained failure.

## Recommended Jenkins Flow

Run these stages after the offline collection gates pass:

```bash
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/00_preflight.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/01_cleanup_stale.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/10_objects_single.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/11_objects_bulk.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/20_access_policy.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/21_access_rules_ips_file_malware.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/22_access_policy_advanced_settings.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/30_ravpn_create_delete.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/31_s2s_vpn_create_delete.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/32_s2s_topology_api_support.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/40_routing_api_support.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/41_interface_configuration.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/50_platform_settings.yml
ansible-playbook -i /opt/fmcansible-lab/inventories/onprem.yml tests/live/playbooks/99_cleanup.yml
```

Use separate Jenkins stages and parameters for VPN, deployment, cdFMC, and
long-running token refresh tests.

## API Concurrency

FMC returns HTTP `429` when fixed REST API concurrency or rate limits are
exceeded. The explicit `Too Many Writes` response is:

```text
Parallel add/update/delete operations are blocked. Please retry the request.
```

The FMC 10.0 GA lab returned this response when two different FTD registration
requests were submitted together. Device registration, unregistration, policy
assignment, deployment, and cleanup must therefore be serialized at the FMC
level, even when the operations target different devices.

The Jenkins pipeline must hold a shared lock for the complete live-test run.
Playbooks must keep writes synchronous, avoid `async` with `poll: 0`, and wait
for any task returned by a `202 Accepted` response to complete. If multiple
inventory hosts can reach the same FMC, use `serial: 1` or task-level
`throttle: 1`. Other automation and UI changes are outside Ansible's scheduler,
so the lab also needs an operational rule that Jenkins owns the FMC during a
run.

Do not add an unconditional retry for all `429` responses. The same status code
also covers request-rate and connection limits, and replaying an ambiguous
non-idempotent `POST` can create duplicate configuration. Before retrying,
confirm the response is the explicit concurrency rejection or use GET/read-back
to prove that FMC did not accept the earlier write.

See Cisco's
[FMC 10.0 REST API rate-limiting documentation](https://www.cisco.com/c/en/us/td/docs/security/firepower/10-0/API/REST/firepower_management_center_rest_api_quick_start_guide_10_0/Objects_In_The_REST_API.html).

The `site_cdfmc.yml` suite runs the same object, access-policy, access-rule,
advanced-setting, and Platform Settings CRUD tests as the on-prem suite. VPN
mutation remains platform-gated until dedicated cloud lab variables and live
qualification are available.

Set `fmcansible_run_vpn_tests=true` through a Jenkins extra-vars file to enable
the RA VPN and S2S workflows. The example defaults read the non-secret topology
selectors from these environment variables:

```text
FMCANSIBLE_RAVPN_ACCESS_ZONE_NAME
FMCANSIBLE_RAVPN_ANYCONNECT_PACKAGE_NAME
FMCANSIBLE_RAVPN_CLIENT_OS
FMCANSIBLE_RAVPN_IKEV2_POLICY_NAME
FMCANSIBLE_S2S_DEVICE_A
FMCANSIBLE_S2S_DEVICE_B
FMCANSIBLE_S2S_INTERFACE_A
FMCANSIBLE_S2S_INTERFACE_B
FMCANSIBLE_S2S_TOPOLOGY_TYPE
FMCANSIBLE_S2S_IKEV2_POLICY_NAME
FMCANSIBLE_S2S_IPSEC_PROPOSAL_NAME
FMCANSIBLE_ROUTING_TEST_DEVICE
FMCANSIBLE_ROUTING_PEER_HOST
FMCANSIBLE_ROUTING_PEER_USERNAME
FMCANSIBLE_ROUTING_PEER_INTERFACE
FMCANSIBLE_ROUTING_PEER_IPV4
FMCANSIBLE_ROUTING_FTD_IPV4
FMCANSIBLE_ROUTING_TRANSIT_NETWORK
FMCANSIBLE_ROUTING_PEER_IPV6
FMCANSIBLE_ROUTING_FTD_IPV6
FMCANSIBLE_ROUTING_IPV6_PREFIX
FMCANSIBLE_ROUTING_FTD_SECONDARY_IPV4
FMCANSIBLE_INTERFACE_TEST_DEVICE
FMCANSIBLE_INTERFACE_TEST_NAME
```

The RA VPN test creates and verifies a self-signed certificate enrollment,
IPv4 address pool, dynamic access policy, group policy, RA VPN policy, address
assignment setting, and connection profile. It intentionally requires an
existing outside security zone and a preloaded Cisco Secure Client package.
The package API uses `multipart/form-data`; `fmc_configuration` only sends JSON
request bodies, so the collection cannot upload the package as part of this
test.

The complete policy-based S2S workflow supports point-to-point, hub-and-spoke,
and full-mesh topologies. Point-to-point requires two `PEER` endpoints.
Hub-and-spoke requires one `HUB` and at least two `SPOKE` endpoints. Full mesh
requires at least three `PEER` endpoints. The test creates one protected network
per endpoint, configures IKEv2 automatic pre-shared-key authentication and an
explicit IPsec proposal, verifies every endpoint, and deletes everything in an
`always` block. FMC requires each selected interface to be enabled, named, and
in routed mode.

`32_s2s_topology_api_support.yml` separately probes all topology shells declared
by the API: the three policy-based variants, route-based point-to-point and
hub-and-spoke, SD-WAN `AUTO_VPN`, Umbrella `SASE_TUNNEL`, and Secure Access
`SSE_TUNNEL`. Shell acceptance does not prove endpoint support, licensing,
deployment, or traffic. An API can accept an `AUTO_VPN` shell before applying
an SD-WAN license gate later in the workflow.
Complete route-based testing still requires VTI creation and attachment.

`40_routing_api_support.yml` is a non-mutating runtime check for ECMP, IPv4 and
IPv6 static routes, EIGRP, BGP address families and neighbors, OSPFv2 policies
and interfaces, and OSPFv3 policies, interfaces, and neighbors. The FMC 10.0 GA
and cdFMC schemas declare CRUD for all of them. This read-only probe does not
replace later routing create/update/delete, adjacency, route-table, deployment,
and traffic tests.

`41_interface_configuration.yml` performs transactional field tests on one
explicitly selected, disabled CI interface. It sends the complete writable
interface representation, verifies read-back, restores the original
configuration after every field, and verifies the final state. It covers mode,
MTU, SGT propagation, NVE-only, priority, path monitoring, and hardware
settings. Hardware settings are platform-dependent and are skipped when the API
does not return a hardware block. An HTTP success is not sufficient: a field is
reported as `accepted_not_persisted` when the read-back differs.

`21_access_rules_ips_file_malware.yml` creates a Mandatory category, uses
`upsertAccessRule` for a singular rule, uses `createMultipleAccessRule` for a
bulk rule, and reads both rules back. It asserts source and destination network
groups, source and destination security zones, intrusion policy, file policy,
and malware file-rule references. Network-group references use the
API-returned `NetworkGroup` type. FMC has been observed to accept
`NetworkObjectGroup` while silently discarding that reference, so a changed
result without GET-back verification is not sufficient.

`22_access_policy_advanced_settings.yml` creates an isolated access policy,
probes application logging, EVE, inheritance, policy logging, and security
intelligence setting families, then updates and reads back the application log
format. The captured cdFMC schema additionally declares AI Defense settings;
the captured FMC 10.0 schema does not. A failed optional probe is retained in
the capability report rather than converted into a successful test.

FMC 10.0 also declares the application-logging field
`sendToSysLogConfigFromPlatformSetting`; the captured cdFMC schema does not.
The live request and read-back assertion include that field only for on-prem
FMC so cdFMC is not given an unsupported property that it silently discards.

FMCAnsible discovers operations from the legacy `fmc.json` document. For the
application logging endpoint that document uses
`getAllAccessPolicyAdvancedLoggingSetting`; the newer OAS3 document uses
`getAllAccessPolicyApplicationLoggingSettingModel`. The path and logical
resource are the same, but playbooks must use the operation ID exposed by the
collection's discovery document.

`50_platform_settings.yml` creates an isolated FTD Platform Settings policy and
probes login banner, DNS, external authentication, HTTP/ICMP/SSH access,
NetFlow, NTP, SNMP, syslog, and trusted-DNS configuration families. It updates
and reads back a login banner, then deletes the entire policy. API declaration
and successful GET probing do not qualify device assignment or deployment.

## From Acceptance Test To Customer Sample

Use live acceptance playbooks as the implementation reference for new files in
`samples/`, but do not copy them verbatim. A customer sample should retain:

- the exact API operation, data model, and path/query parameters
- prerequisite discovery rather than hard-coded UUIDs
- read-back assertions where FMC can silently omit invalid references
- a documented minimum FMC or cdFMC API version

CI-only run prefixes, capability-probe loops, destructive stale cleanup, and
Jenkins-specific variables should remain under `tests/live/`. Promote a use
case to `samples/` only after create, read-back, idempotency where applicable,
delete, and zero-residue checks pass on every platform claimed by the sample.

The on-prem preflight retrieves the FMC version. Development runs warn when GA
enforcement is disabled. Release runs must set
`fmcansible_enforce_ga_version=true` and provide
`fmcansible_allowed_fmc_versions` from private lab variables.

## Live Lab Requirements

Run these tests only against isolated, non-production managers and devices.
Each target needs dedicated managed FTDs suitable for the workflow being
tested. Routing adjacency tests also need the required data interfaces and a
reachable Linux/FRR peer. VPN topology tests need enough dedicated endpoints
for the selected topology.

Keep hostnames, VM IDs, IP addresses, hypervisor details, network layout, real
inventories, and secrets in Jenkins or another private configuration store.

## Naming And Cleanup

Every created resource uses a unique prefix:

```text
ci-fmcansible-${BUILD_NUMBER}-${GIT_COMMIT_SHORT}
```

Every destructive playbook must use `block`/`always` cleanup. A first-stage stale
cleanup playbook removes old `ci-fmcansible-*` resources before a run starts.
The cleanup playbook removes host objects, access rules and policies, file and
malware policies, network groups, security zones, Platform Settings policies,
RA VPNs and their supporting objects, and S2S VPNs and their protected
networks. It then re-queries FMC to prove all prefixed resources are absent.

The FMC 10.0 runtime API exposes the RA VPN and S2S create/delete operations
used here. The live API specification, rather than an old checked-in generated
document, is the authority for each run. A Jenkins lock must serialize jobs
against a shared FMC/FTD lab because stale cleanup deliberately owns the full
`ci-fmcansible-*` namespace.
