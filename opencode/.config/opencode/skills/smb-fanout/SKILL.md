---
name: smb-fanout
description: Use when diagnosing or optimizing SMB/CIFS share throughput with rotating DNS A records, multiple NAS IPs, PowerScale/clustered storage, Windows SMB connections, or multi-IP fanout design.
---

# SMB Fanout

Use this skill for SMB/CIFS shares where one hostname resolves to multiple backend IPs and throughput may improve by spreading work across those IPs.

## Goals

- Determine whether DNS returns multiple usable SMB targets.
- Compare hostname, single-IP, and multi-IP throughput.
- Keep logical paths stable while using IP paths only for access.
- Avoid duplicate scanning or duplicate file indexing.

## Discovery

Collect rotating DNS A records with system DNS:

```powershell
1..100 | ForEach-Object {
  try { (Resolve-DnsName -Name "HOSTNAME" -Type A -ErrorAction Stop).IPAddress } catch {}
} | Sort-Object -Unique
```

Check IPv6 only if needed:

```powershell
Resolve-DnsName -Name "HOSTNAME" -Type AAAA
```

Check SMB reachability:

```powershell
Test-NetConnection -ComputerName "IP" -Port 445 -InformationLevel Detailed
```

Inspect active SMB TCP sessions:

```powershell
Get-NetTCPConnection -RemotePort 445 -State Established | Sort-Object RemoteAddress,LocalPort
```

SMB cmdlets may require elevated permissions:

```powershell
Get-SmbConnection
Get-SmbMultichannelConnection
Get-SmbClientConfiguration
```

## Benchmark Pattern

Use read-only tests first.

Compare the same fixed file list across:

1. Hostname only.
2. Single explicit IP.
3. Multiple explicit IPs.
4. Same-IP parallel workers versus multi-IP parallel workers.

Interpretation:

- Multi-IP faster than same-IP means NAS/IP fanout helps.
- Same-IP and multi-IP similar means bottleneck is likely client, VPN, uplink, disk, or protocol overhead.
- Hostname slower than explicit IPs means client resolution/session behavior is not spreading load.

## Safe Path Rule

Separate logical paths from access paths.

Store and report logical paths:

```text
\\hostname\share\path\file.pdf
```

Use access paths only for SMB operations:

```text
\\172.18.56.45\share\path\file.pdf
```

This keeps database keys, logs, and user-facing paths stable while spreading network I/O.

## Fanout Design

Do not scan the same logical directory on every IP. That duplicates work.

Use a logical work queue:

```text
dirQueue: logical directories
fileQueue: logical files
accessRoots: IP-backed UNC roots
```

For each SMB operation:

1. Pop one logical directory or file.
2. Pick the next IP root, or the least-busy IP root.
3. Convert logical path to access path.
4. Run `ReadDir`, `Stat`, or read operation against the access path.
5. Emit or store only the logical path.

This spreads per-directory and per-file operations across all targets without duplicate traversal.

## Worker Strategy

Use separate pools:

- Directory workers for `ReadDir` discovery.
- File workers for `Stat`, reads, hashing, parsing, or indexing.
- Single batched DB writer when persisting results.

If directory breadth is small, some directory workers will idle. File workers can still saturate the share once files are discovered.

Pick IP per operation, not permanently per worker. This avoids one worker or hot directory pinning to one NAS IP.

## Limits

Metadata-heavy workloads may not saturate raw bandwidth. They may saturate SMB operation latency instead.

Full bandwidth usually requires byte reads, hashing, copying, parsing, or large-file reads. For large files, consider chunked reads only if the protocol/client code supports safe range reads.

## Safety

- Prefer read-only tests unless user explicitly approves writes.
- Do not use DNS fanout across unrelated servers unless share consistency, locks, and namespace coherence are guaranteed.
- Be careful with hidden/admin shares such as `DHEC_EXITRECS$`; preserve exact share names and escaping.
- Do not store IP-based UNC paths in durable indexes unless the user explicitly wants physical-node paths.

## Output

Report:

- Resolved IP count and list.
- Port 445 reachability summary.
- Benchmark comparison: hostname, single IP, multi-IP.
- Active TCP session distribution if checked.
- Conclusion: helps, does not help, or inconclusive.
- Next safe tuning step.
