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

Local run (uses ./vnt and ./vnts by default):

```
sudo -v
./scripts/run-integration.sh
```

The smoke test runs three containers (vnts + 2 vnt clients). The vnt1 container uses
`vnt-cli --list` to discover the peer virtual IP and verifies ping reachability.

Or use docker compose:

```
docker compose up --abort-on-container-exit --exit-code-from vnt1
```

You can also override paths:

```
VNT_DIR=../vnt VNTS_DIR=../vnts ./scripts/run-integration.sh
```

For docker compose with sibling repos:

```
VNT_DIR=../vnt VNTS_DIR=../vnts docker compose up --abort-on-container-exit --exit-code-from vnt1
```
