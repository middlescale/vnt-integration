# vnt-integration

This repo is expected to live alongside the `vnt` and `vnts` repos.

```
parent/
  vnt-integration/
  vnt/
  vnts/
```

Local run (uses sibling `../vnt` and `../vnts` by default):

```
sudo -v
./scripts/run-integration.sh
```

The smoke test runs one container and starts one vnts process plus two vnt clients in it.
It uses `vnt-cli --list` to discover peer virtual IPs and verifies ping reachability.

Use docker compose (multi-container: builder + vnts + 2 clients):

```
docker compose run --rm builder
docker compose up -d vnts client1 client2
```

You can also override paths:

```
VNT_DIR=../vnt VNTS_DIR=../vnts ./scripts/run-integration.sh
```

For docker compose with sibling repos:

```
VNT_DIR=../vnt VNTS_DIR=../vnts docker compose run --rm builder
VNT_DIR=../vnt VNTS_DIR=../vnts docker compose up -d vnts client1 client2
```

Then you can verify connectivity from host:

```
docker compose exec -T client1 /workspace/bin/vnt-cli --list
docker compose exec -T client2 /workspace/bin/vnt-cli --list
docker compose down -v
```
