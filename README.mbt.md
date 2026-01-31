# WebCubes Mini MC

A tiny Minecraft-like demo built with MoonBit (JS backend) + WebGL.

## Run

```bash
moon check --deny-warn
moon build --target js
python3 -m http.server 8000
```

Then open `http://localhost:8000/index.html`.

Or just run:

```bash
./run-js.sh
```

## Controls

- Click to lock pointer
- WASD to move
- Space to jump
- Shift or Ctrl to sprint
- Left click: break block
- Right click: place block
- 1-8: select block
