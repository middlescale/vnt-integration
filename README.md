# vnt-integration

This repo is intended to live alongside the vnt and vnts repos in the same parent directory:

```
parent/
  vnt-integration/
  vnt/
  vnts/
```

Local run (uses sibling repos by default):

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
