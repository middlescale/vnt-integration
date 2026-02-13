# vnt-integration

This repo can live alongside the vnt and vnts repos, or contain them as subdirectories.

```
parent/
  vnt-integration/
  vnt/
  vnts/
```

Or:

```
vnt-integration/
  vnt/
  vnts/
```

Local run (uses ./vnt and ./vnts by default, or sibling dirs if present):

```
sudo -v
./scripts/run-integration.sh
```

The smoke test runs one container and starts one vnts process plus two vnt clients in it.
It uses `vnt-cli --list` to discover peer virtual IPs and verifies ping reachability.

Or use docker compose (single container):

```
docker compose up
```

You can also override paths:

```
VNT_DIR=../vnt VNTS_DIR=../vnts ./scripts/run-integration.sh
```

For docker compose with sibling repos:

```
VNT_DIR=../vnt VNTS_DIR=../vnts docker compose up
```
