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

Or use docker compose:

```
docker compose up
```

You can also override paths:

```
VNT_DIR=../vnt VNTS_DIR=../vnts ./scripts/run-integration.sh
```
