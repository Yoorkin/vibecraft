///|
extern "js" fn dom_create_canvas() -> JsValue =
  #| () => {
  #|   const canvas = document.createElement("canvas");
  #|   canvas.style.width = "100%";
  #|   canvas.style.height = "100%";
  #|   canvas.style.display = "block";
  #|   canvas.style.cursor = "crosshair";
  #|   document.body.style.margin = "0";
  #|   document.body.style.overflow = "hidden";
  #|   document.body.appendChild(canvas);
  #|   return canvas;
  #| }

///|
extern "js" fn dom_resize_canvas(canvas : JsValue) -> Array[Int] =
  #| (canvas) => {
  #|   const dpr = window.devicePixelRatio || 1;
  #|   const w = window.innerWidth || 800;
  #|   const h = window.innerHeight || 600;
  #|   const width = Math.floor(w * dpr);
  #|   const height = Math.floor(h * dpr);
  #|   if (canvas.width !== width || canvas.height !== height) {
  #|     canvas.width = width;
  #|     canvas.height = height;
  #|     canvas.style.width = w + "px";
  #|     canvas.style.height = h + "px";
  #|   }
  #|   return [canvas.width, canvas.height];
  #| }

///|
extern "js" fn dom_request_animation_frame(cb : (Double) -> Unit) -> Int =
  #| (cb) => window.requestAnimationFrame(cb)

///|
extern "js" fn dom_now_ms() -> Double =
  #| () => (performance && performance.now) ? performance.now() : Date.now()

///|
extern "js" fn input_init(canvas : JsValue) -> Unit =
  #| (canvas) => {
  #|   const state = {
  #|     keys: Object.create(null),
  #|     buttons: Object.create(null),
  #|     clicks: Object.create(null),
  #|     dx: 0,
  #|     dy: 0,
  #|   };
  #|   window.__moonbit_input = state;
  #|   window.addEventListener("keydown", (e) => { state.keys[e.code] = true; });
  #|   window.addEventListener("keyup", (e) => { state.keys[e.code] = false; });
  #|   window.addEventListener("blur", () => {
  #|     state.keys = Object.create(null);
  #|     state.buttons = Object.create(null);
  #|     state.clicks = Object.create(null);
  #|   });
  #|   canvas.addEventListener("mousedown", (e) => {
  #|     if (document.pointerLockElement !== canvas) {
  #|       canvas.requestPointerLock();
  #|     }
  #|     state.buttons[e.button] = true;
  #|     state.clicks[e.button] = true;
  #|   });
  #|   window.addEventListener("mouseup", (e) => { state.buttons[e.button] = false; });
  #|   window.addEventListener("mousemove", (e) => {
  #|     if (document.pointerLockElement === canvas) {
  #|       state.dx += e.movementX || 0;
  #|       state.dy += e.movementY || 0;
  #|     }
  #|   });
  #|   window.addEventListener("contextmenu", (e) => e.preventDefault());
  #| }

///|
extern "js" fn input_key(code : String) -> Bool =
  #| (code) => {
  #|   const s = window.__moonbit_input;
  #|   return !!(s && s.keys && s.keys[code]);
  #| }

///|
extern "js" fn input_consume_click(button : Int) -> Bool =
  #| (button) => {
  #|   const s = window.__moonbit_input;
  #|   if (!s || !s.clicks) return false;
  #|   const v = !!s.clicks[button];
  #|   s.clicks[button] = false;
  #|   return v;
  #| }

///|
extern "js" fn input_mouse_dx() -> Double =
  #| () => {
  #|   const s = window.__moonbit_input;
  #|   if (!s) return 0;
  #|   const v = s.dx || 0;
  #|   s.dx = 0;
  #|   return v;
  #| }

///|
extern "js" fn input_mouse_dy() -> Double =
  #| () => {
  #|   const s = window.__moonbit_input;
  #|   if (!s) return 0;
  #|   const v = s.dy || 0;
  #|   s.dy = 0;
  #|   return v;
  #| }

///|
extern "js" fn dom_set_hotbar(selected : Int) -> Unit =
  #| (selected) => {
  #|   const bar = document.getElementById("hotbar");
  #|   if (!bar) return;
  #|   const slots = bar.querySelectorAll(".slot");
  #|   for (let i = 0; i < slots.length; i++) {
  #|     if (i === selected) {
  #|       slots[i].classList.add("active");
  #|     } else {
  #|       slots[i].classList.remove("active");
  #|     }
  #|   }
  #| }

///|
extern "js" fn dom_create_atlas() -> JsValue =
  #| () => {
  #|   const tile = 16;
  #|   const cols = 4;
  #|   const rows = 4;
  #|   const canvas = document.createElement("canvas");
  #|   canvas.width = tile * cols;
  #|   canvas.height = tile * rows;
  #|   const ctx = canvas.getContext("2d");
  #|   ctx.imageSmoothingEnabled = false;
  #|   function hash(x, y, seed) {
  #|     let n = Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(seed, 1442695041);
  #|     n = (n ^ (n >>> 13)) >>> 0;
  #|     n = Math.imul(n, 1274126177);
  #|     n = (n ^ (n >>> 16)) >>> 0;
  #|     return n / 4294967295;
  #|   }
  #|   function smoothstep(t) {
  #|     return t * t * (3 - 2 * t);
  #|   }
  #|   function valueNoise(x, y, seed) {
  #|     const x0 = Math.floor(x);
  #|     const y0 = Math.floor(y);
  #|     const x1 = x0 + 1;
  #|     const y1 = y0 + 1;
  #|     const fx = x - x0;
  #|     const fy = y - y0;
  #|     const u = smoothstep(fx);
  #|     const v = smoothstep(fy);
  #|     const n00 = hash(x0, y0, seed);
  #|     const n10 = hash(x1, y0, seed);
  #|     const n01 = hash(x0, y1, seed);
  #|     const n11 = hash(x1, y1, seed);
  #|     const nx0 = n00 + (n10 - n00) * u;
  #|     const nx1 = n01 + (n11 - n01) * u;
  #|     return nx0 + (nx1 - nx0) * v;
  #|   }
  #|   function fbm(x, y, seed) {
  #|     let sum = 0;
  #|     let amp = 1;
  #|     let freq = 1;
  #|     let norm = 0;
  #|     for (let i = 0; i < 3; i++) {
  #|       sum += valueNoise(x * freq, y * freq, seed + i * 17) * amp;
  #|       norm += amp;
  #|       amp *= 0.5;
  #|       freq *= 2;
  #|     }
  #|     return sum / norm;
  #|   }
  #|   function pick(colors, r) {
  #|     return colors[Math.floor(r * colors.length)];
  #|   }
  #|   function fillTile(tx, ty, color) {
  #|     const x = tx * tile;
  #|     const y = ty * tile;
  #|     ctx.fillStyle = color;
  #|     ctx.fillRect(x, y, tile, tile);
  #|   }
  #|   function blockNoise(tx, ty, colors, seed, block) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     const n = colors.length;
  #|     for (let y = 0; y < tile; y++) {
  #|       for (let x = 0; x < tile; x++) {
  #|         const r = hash(x + x0, y + y0, seed);
  #|         const idx = Math.min(n - 1, Math.floor(r * n));
  #|         ctx.fillStyle = colors[idx];
  #|         ctx.fillRect(x0 + x, y0 + y, 1, 1);
  #|       }
  #|     }
  #|   }
  #|   function blockNoiseAlpha(tx, ty, colors, seed, block) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     const n = colors.length;
  #|     for (let y = 0; y < tile; y++) {
  #|       for (let x = 0; x < tile; x++) {
  #|         const r = hash(x + x0, y + y0, seed);
  #|         const idx = Math.min(n - 1, Math.floor(r * n));
  #|         ctx.fillStyle = colors[idx];
  #|         ctx.fillRect(x0 + x, y0 + y, 1, 1);
  #|       }
  #|     }
  #|   }
  #|   function speckle(tx, ty, color, seed, rate) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     for (let y = 0; y < tile; y++) {
  #|       for (let x = 0; x < tile; x++) {
  #|         if (hash(x + x0, y + y0, seed) > rate) {
  #|           ctx.fillStyle = color;
  #|           ctx.fillRect(x0 + x, y0 + y, 1, 1);
  #|         }
  #|       }
  #|     }
  #|   }
  #|   function grassTop(tx, ty) {
  #|     const greens = ["#5ca142", "#6aad4d", "#4f9b3c", "#73b957"];
  #|     blockNoise(tx, ty, greens, 11, 1);
  #|     speckle(tx, ty, "#76c65b", 37, 0.985);
  #|   }
  #|   function grassSide(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     const grassColors = ["#5ca142", "#6aad4d", "#4f9b3c", "#73b957"];
  #|     const dirtColors = ["#8b6b4b", "#7a5c3c", "#946f53", "#6e5236"];
  #|     const block = 1;
  #|     for (let by = 0; by < tile; by += block) {
  #|       for (let bx = 0; bx < tile; bx += block) {
  #|         const isGrass = by < 4;
  #|         const colors = isGrass ? grassColors : dirtColors;
  #|         const seed = isGrass ? 19 : 23;
  #|         ctx.fillStyle = pick(colors, hash(bx + x0, by + y0, seed));
  #|         ctx.fillRect(x0 + bx, y0 + by, block, block);
  #|       }
  #|     }
  #|     ctx.fillStyle = "rgba(0,0,0,0.22)";
  #|     ctx.fillRect(x0, y0 + 3, tile, 1);
  #|   }
  #|   function woodTop(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     const cx = x0 + tile / 2;
  #|     const cy = y0 + tile / 2;
  #|     for (let y = 0; y < tile; y++) {
  #|       for (let x = 0; x < tile; x++) {
  #|         const dx = x0 + x - cx;
  #|         const dy = y0 + y - cy;
  #|         const dist = Math.sqrt(dx * dx + dy * dy);
  #|         const ring = (Math.floor(dist + 0.5) % 2) === 0;
  #|         let use = ring ? "#c79a5a" : "#b0814b";
  #|         if (hash(x + x0, y + y0, 31) > 0.96) {
  #|           use = "#8d5f33";
  #|         }
  #|         ctx.fillStyle = use;
  #|         ctx.fillRect(x0 + x, y0 + y, 1, 1);
  #|       }
  #|     }
  #|   }
  #|   function woodSide(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     for (let x = 0; x < tile; x++) {
  #|       const jitter = Math.floor(hash(x + x0, y0, 29) * 2);
  #|       const band = ((x + jitter) % 6) < 3;
  #|       ctx.fillStyle = band ? "#a8743f" : "#c28b52";
  #|       ctx.fillRect(x0 + x, y0, 1, tile);
  #|     }
  #|   }
  #|   function leavesTile(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     const leafColors = ["#3f9142", "#2f7b34", "#4fa551", "#2a6a2f"];
  #|     const block = 1;
  #|     for (let by = 0; by < tile; by += block) {
  #|       for (let bx = 0; bx < tile; bx += block) {
  #|         const r = hash(bx + x0, by + y0, 41);
  #|         if (r > 0.86) {
  #|           ctx.clearRect(x0 + bx, y0 + by, block, block);
  #|           continue;
  #|         }
  #|         ctx.fillStyle = pick(leafColors, r * 0.9);
  #|         ctx.fillRect(x0 + bx, y0 + by, block, block);
  #|       }
  #|     }
  #|   }
  #|   function planks(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     for (let y = 0; y < tile; y++) {
  #|       const band = Math.floor(y / 4) % 2 === 0;
  #|       ctx.fillStyle = band ? "#c59257" : "#b8824c";
  #|       ctx.fillRect(x0, y0 + y, tile, 1);
  #|     }
  #|     ctx.fillStyle = "#9c6b3e";
  #|     for (let y = 0; y < tile; y += 4) {
  #|       ctx.fillRect(x0, y0 + y, tile, 1);
  #|     }
  #|     ctx.fillStyle = "#8b5b33";
  #|     ctx.fillRect(x0 + 7, y0, 1, tile);
  #|     if (hash(x0, y0, 83) > 0.6) {
  #|       ctx.fillStyle = "#7a4d2c";
  #|       ctx.fillRect(x0 + 11, y0 + 6, 2, 2);
  #|     }
  #|   }
  #|   function brick(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     ctx.fillStyle = "#7a2e25";
  #|     ctx.fillRect(x0, y0, tile, tile);
  #|     const brickW = 6;
  #|     const brickH = 4;
  #|     for (let y = 0; y < tile; y += brickH) {
  #|       const offset = (Math.floor(y / brickH) % 2) * 3;
  #|       for (let x = -offset; x < tile; x += brickW) {
  #|         const bx = x0 + x + 1;
  #|         const by = y0 + y + 1;
  #|         ctx.fillStyle = "#b85743";
  #|         ctx.fillRect(bx, by, brickW - 2, brickH - 2);
  #|         ctx.fillStyle = "#9a4637";
  #|         ctx.fillRect(bx, by, brickW - 2, 1);
  #|       }
  #|     }
  #|   }
  #|   function stone(tx, ty) {
  #|     blockNoise(tx, ty, ["#8c8c8c", "#868686", "#7f7f7f", "#909090"], 17, 1);
  #|     speckle(tx, ty, "#9a9a9a", 73, 0.995);
  #|   }
  #|   function bedrock(tx, ty) {
  #|     blockNoise(tx, ty, ["#3a3a3a", "#2b2b2b", "#4a4a4a", "#1f1f1f"], 3, 1);
  #|     speckle(tx, ty, "#101010", 59, 0.97);
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     ctx.fillStyle = "rgba(0,0,0,0.35)";
  #|     for (let i = 0; i < 3; i++) {
  #|       const y = Math.floor(hash(i, 9, 59) * tile);
  #|       ctx.fillRect(x0, y0 + y, tile, 1);
  #|     }
  #|   }
  #|   function water(tx, ty) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     const grad = ctx.createLinearGradient(0, y0, 0, y0 + tile);
  #|     grad.addColorStop(0, "rgba(70,140,220,0.65)");
  #|     grad.addColorStop(1, "rgba(50,110,190,0.65)");
  #|     ctx.fillStyle = grad;
  #|     ctx.fillRect(x0, y0, tile, tile);
  #|     blockNoiseAlpha(
  #|       tx,
  #|       ty,
  #|       ["rgba(70,140,220,0.5)", "rgba(55,120,205,0.5)", "rgba(85,155,235,0.45)"],
  #|       5,
  #|       2,
  #|     );
  #|     ctx.fillStyle = "rgba(120,180,245,0.25)";
  #|     for (let y = 0; y < tile; y += 4) {
  #|       ctx.fillRect(x0, y0 + y, tile, 1);
  #|     }
  #|   }
  #|   function cobble(tx, ty) {
  #|     blockNoise(tx, ty, ["#8a8a8a", "#7a7a7a", "#909090", "#6f6f6f"], 27, 1);
  #|     speckle(tx, ty, "#5f5f5f", 81, 0.996);
  #|   }
  #|   function gravel(tx, ty) {
  #|     blockNoise(tx, ty, ["#8c8a86", "#7f7c77", "#8f8c88", "#6f6c68"], 33, 1);
  #|     speckle(tx, ty, "#5f5d59", 35, 0.987);
  #|   }
  #|   function clay(tx, ty) {
  #|     blockNoise(tx, ty, ["#8b95a7", "#7e8899", "#9aa4b6", "#768091"], 39, 1);
  #|     speckle(tx, ty, "rgba(255,255,255,0.18)", 41, 0.995);
  #|   }
  #|   function snow(tx, ty) {
  #|     blockNoise(tx, ty, ["#f2f6fb", "#e7edf6", "#f7fbff", "#dde5ee"], 45, 1);
  #|     speckle(tx, ty, "#cfd7e0", 47, 0.992);
  #|   }
  #|   // Tiles (tx, ty)
  #|   grassTop(0, 0); // grass top
  #|   grassSide(1, 0); // grass side
  #|   blockNoise(2, 0, ["#7b4c22", "#6b3f1d", "#8a5329", "#5c3518"], 13, 1); // dirt
  #|   stone(3, 0); // stone
  #|   blockNoise(0, 1, ["#d8c06a", "#c8b25f", "#e1c979", "#bfa64f"], 7, 1); // sand
  #|   water(1, 1); // water
  #|   woodTop(2, 1); // wood top
  #|   woodSide(3, 1); // wood side
  #|   leavesTile(0, 2); // leaves
  #|   bedrock(1, 2); // bedrock
  #|   planks(2, 2); // planks
  #|   brick(3, 2); // brick
  #|   cobble(0, 3); // cobblestone
  #|   gravel(1, 3); // gravel
  #|   clay(2, 3); // clay
  #|   snow(3, 3); // snow
  #|   window.__atlas = canvas;
  #|   return canvas;
  #| }
