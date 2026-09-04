# The MeshBench apt repository

Served from this repository at `https://meshbench.github.io/apt`. The pool and
the index are written by `publish-apt.yml` in
[MeshBench/meshbench](https://github.com/MeshBench/meshbench) when a release is
published; an edit made here by hand is overwritten by the next one.

```
curl -fsSL https://meshbench.github.io/apt/meshbench.gpg \
  | sudo tee /usr/share/keyrings/meshbench.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/meshbench.gpg] \
  https://meshbench.github.io/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/meshbench.list

sudo apt update && sudo apt install meshbench
```

`meshbench` is the application on its own. `meshbench-bundled` carries the QEMU
and Renode emulators with it, and the two conflict, so a machine has exactly one
and can swap without uninstalling first.

`meshbench.gpg` is the public half of the signing key, dearmoured, which is the
form `signed-by=` wants. Its fingerprint is

    503C C0C1 A132 97F1 B143  3E1A F0AC 901F 2454 7735

Old versions stay in the pool on purpose: a repository that drops what it
replaced breaks anybody pinning a version.
