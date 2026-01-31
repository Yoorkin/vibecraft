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
  #|   const prev = window.__moonbit_input;
  #|   const state = {
  #|     keys: Object.create(null),
  #|     buttons: Object.create(null),
  #|     clicks: Object.create(null),
  #|     dx: 0,
  #|     dy: 0,
  #|     fly: prev && typeof prev.fly === "boolean" ? prev.fly : false,
  #|     teleport: false,
  #|     cmds: prev && Array.isArray(prev.cmds) ? prev.cmds : [],
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
  #|   const btn = document.getElementById("fly-toggle");
  #|   if (btn) {
  #|     btn.textContent = state.fly ? "Fly: On" : "Fly: Off";
  #|     btn.classList.toggle("active", !!state.fly);
  #|   }
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
extern "js" fn input_fly_enabled() -> Bool =
  #| () => {
  #|   const s = window.__moonbit_input;
  #|   return !!(s && s.fly);
  #| }

///|
extern "js" fn input_consume_teleport() -> Bool =
  #| () => {
  #|   const s = window.__moonbit_input;
  #|   if (!s) return false;
  #|   const v = !!s.teleport;
  #|   s.teleport = false;
  #|   return v;
  #| }

///|
extern "js" fn input_consume_command() -> Array[Int] =
  #| () => {
  #|   const s = window.__moonbit_input;
  #|   if (!s || !Array.isArray(s.cmds) || s.cmds.length === 0) return [];
  #|   return s.cmds.shift();
  #| }

///|
extern "js" fn dom_init_fly_toggle() -> Unit =
  #| () => {
  #|   const btn = document.getElementById("fly-toggle");
  #|   if (!btn) return;
  #|   const getState = () => {
  #|     let s = window.__moonbit_input;
  #|     if (!s) {
  #|       s = {
  #|         keys: Object.create(null),
  #|         buttons: Object.create(null),
  #|         clicks: Object.create(null),
  #|         dx: 0,
  #|         dy: 0,
  #|         fly: false,
  #|         teleport: false,
  #|         cmds: [],
  #|       };
  #|       window.__moonbit_input = s;
  #|     }
  #|     if (typeof s.fly !== "boolean") s.fly = false;
  #|     return s;
  #|   };
  #|   const update = (s) => {
  #|     const on = !!s.fly;
  #|     btn.textContent = on ? "Fly: On" : "Fly: Off";
  #|     btn.classList.toggle("active", on);
  #|   };
  #|   update(getState());
  #|   btn.addEventListener("click", (e) => {
  #|     e.preventDefault();
  #|     const s = getState();
  #|     s.fly = !s.fly;
  #|     update(s);
  #|   });
  #| }

///|
extern "js" fn dom_init_random_teleport() -> Unit =
  #| () => {
  #|   const btn = document.getElementById("teleport-random");
  #|   if (!btn) return;
  #|   const getState = () => {
  #|     let s = window.__moonbit_input;
  #|     if (!s) {
  #|       s = {
  #|         keys: Object.create(null),
  #|         buttons: Object.create(null),
  #|         clicks: Object.create(null),
  #|         dx: 0,
  #|         dy: 0,
  #|         fly: false,
  #|         teleport: false,
  #|         cmds: [],
  #|       };
  #|       window.__moonbit_input = s;
  #|     }
  #|     if (typeof s.teleport !== "boolean") s.teleport = false;
  #|     return s;
  #|   };
  #|   btn.addEventListener("click", (e) => {
  #|     e.preventDefault();
  #|     const s = getState();
  #|     s.teleport = true;
  #|     btn.classList.add("active");
  #|     setTimeout(() => btn.classList.remove("active"), 120);
  #|   });
  #| }

///|
extern "js" fn dom_init_command_input() -> Unit =
  #| () => {
  #|   const input = document.getElementById("cmd-input");
  #|   const btn = document.getElementById("cmd-run");
  #|   if (!input || !btn) return;
  #|   const getState = () => {
  #|     let s = window.__moonbit_input;
  #|     if (!s) {
  #|       s = {
  #|         keys: Object.create(null),
  #|         buttons: Object.create(null),
  #|         clicks: Object.create(null),
  #|         dx: 0,
  #|         dy: 0,
  #|         fly: false,
  #|         teleport: false,
  #|         cmds: [],
  #|       };
  #|       window.__moonbit_input = s;
  #|     }
  #|     if (!Array.isArray(s.cmds)) s.cmds = [];
  #|     return s;
  #|   };
  #|   const parseInts = (parts) => {
  #|     const out = [];
  #|     for (let i = 0; i < parts.length; i++) {
  #|       const v = parseInt(parts[i], 10);
  #|       if (Number.isFinite(v)) out.push(v);
  #|     }
  #|     return out;
  #|   };
  #|   const submit = () => {
  #|     const text = input.value.trim();
  #|     if (!text) return;
  #|     const parts = text.split(/\s+/);
  #|     const cmd = parts[0].toLowerCase();
  #|     const nums = parseInts(parts.slice(1));
  #|     let payload = null;
  #|     if (cmd === "tp") {
  #|       if (nums.length >= 3) {
  #|         payload = [1, nums[0], nums[1], nums[2]];
  #|       } else if (nums.length >= 2) {
  #|         payload = [2, nums[0], nums[1]];
  #|       }
  #|     } else if (cmd === "look") {
  #|       if (nums.length >= 2) {
  #|         payload = [3, nums[0], nums[1]];
  #|       }
  #|     }
  #|     if (payload) {
  #|       const s = getState();
  #|       s.cmds.push(payload);
  #|       input.value = "";
  #|     }
  #|   };
  #|   btn.addEventListener("click", (e) => {
  #|     e.preventDefault();
  #|     submit();
  #|   });
  #|   input.addEventListener("keydown", (e) => {
  #|     if (e.key === "Enter") {
  #|       e.preventDefault();
  #|       submit();
  #|     }
  #|   });
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
extern "js" fn dom_set_loading(progress : Double) -> Unit =
  #| (progress) => {
  #|   const el = document.getElementById("loading");
  #|   if (!el) return;
  #|   const text = el.querySelector(".loading-text");
  #|   const fill = el.querySelector(".bar-fill");
  #|   const p = Math.max(0, Math.min(1, progress || 0));
  #|   if (p >= 1) {
  #|     el.style.display = "none";
  #|     return;
  #|   }
  #|   el.style.display = "flex";
  #|   const pct = Math.round(p * 100);
  #|   if (text) text.textContent = `Loading ${pct}%`;
  #|   if (fill) fill.style.width = `${pct}%`;
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
  #|   function rowsFrom(str) {
  #|     return str.trim().split("\n").map((line) => line.trim());
  #|   }
  #|   function drawTile(tx, ty, palette, rows) {
  #|     const x0 = tx * tile;
  #|     const y0 = ty * tile;
  #|     for (let y = 0; y < tile; y++) {
  #|       const row = rows[y];
  #|       for (let x = 0; x < tile; x++) {
  #|         const ch = row[x];
  #|         if (ch === ".") continue;
  #|         const color = palette[ch];
  #|         if (!color) continue;
  #|         ctx.fillStyle = color;
  #|         ctx.fillRect(x0 + x, y0 + y, 1, 1);
  #|       }
  #|     }
  #|   }
  #|   const grassPalette = {
  #|     a: "#5fb84a",
  #|     b: "#56aa42",
  #|     c: "#4a9637",
  #|     d: "#6ed05a",
  #|   };
  #|   const dirtPalette = {
  #|     "1": "#8a5a2b",
  #|     "2": "#7a4d24",
  #|     "3": "#9a6431",
  #|     "4": "#6d4420",
  #|   };
  #|   const stonePalette = {
  #|     a: "#8b8d90",
  #|     b: "#7c7e82",
  #|     c: "#9a9da1",
  #|     d: "#6f7175",
  #|   };
  #|   const sandPalette = {
  #|     a: "#d9c48a",
  #|     b: "#cfb87c",
  #|     c: "#e2cf95",
  #|     d: "#c4ad6f",
  #|   };
  #|   const waterPalette = {
  #|     a: "rgba(70,125,210,0.6)",
  #|     b: "rgba(58,110,195,0.6)",
  #|     c: "rgba(80,140,220,0.6)",
  #|     d: "rgba(95,155,235,0.45)",
  #|   };
  #|   const woodTopPalette = {
  #|     a: "#d0a36a",
  #|     b: "#c08a52",
  #|     c: "#a97443",
  #|     d: "#8c5e32",
  #|   };
  #|   const woodSidePalette = {
  #|     a: "#c79253",
  #|     b: "#b17b45",
  #|     c: "#9e6a39",
  #|     d: "#7f532c",
  #|   };
  #|   const leavesPalette = {
  #|     a: "#4aa34a",
  #|     b: "#3f8f3f",
  #|     c: "#5cb85c",
  #|     d: "#357a35",
  #|   };
  #|   const bedrockPalette = {
  #|     a: "#3b3b3b",
  #|     b: "#2f2f2f",
  #|     c: "#4a4a4a",
  #|     d: "#1f1f1f",
  #|   };
  #|   const planksPalette = {
  #|     a: "#cfa26a",
  #|     b: "#b9874f",
  #|     c: "#a07040",
  #|     d: "#8d5c33",
  #|   };
  #|   const brickPalette = {
  #|     a: "#b65a4a",
  #|     b: "#9e483b",
  #|     c: "#c76b58",
  #|     m: "#8a7b6f",
  #|   };
  #|   const cobblePalette = {
  #|     a: "#8d8d8d",
  #|     b: "#7a7a7a",
  #|     c: "#9c9c9c",
  #|     d: "#6a6a6a",
  #|   };
  #|   const gravelPalette = {
  #|     a: "#8a887f",
  #|     b: "#7a786f",
  #|     c: "#94928a",
  #|     d: "#6b6861",
  #|   };
  #|   const clayPalette = {
  #|     a: "#8a94a6",
  #|     b: "#7c8697",
  #|     c: "#9aa4b6",
  #|   };
  #|   const snowPalette = {
  #|     a: "#f7fbff",
  #|     b: "#e5edf6",
  #|     c: "#d7e0ea",
  #|   };
  #|   const grassTopRows = rowsFrom(`
  #|     abacbabcabacbabc
  #|     bacabdbcbacabdbc
  #|     acbbacabacbbacab
  #|     baccdbabbaccdbab
  #|     cbacbaccabacbacc
  #|     abacbabcabacbabc
  #|     bacabbacbacabbac
  #|     acbbacdaacbbacda
  #|     abacbabcabacbabc
  #|     bacabdbcbacabdbc
  #|     acbbacabacbbacab
  #|     baccdbabbaccdbab
  #|     cbacbaccabacbacc
  #|     abacbabcabacbabc
  #|     bacabbacbacabbac
  #|     acbbacdaacbbacda
  #|   `);
  #|   const dirtRows = rowsFrom(`
  #|     1213212312132123
  #|     2312213223122132
  #|     1322131213221312
  #|     2133122121331221
  #|     3213213332132133
  #|     1213212312132123
  #|     2131221321312213
  #|     1322132113221321
  #|     2213431222134312
  #|     3122132231221322
  #|     1213212312132123
  #|     2312213223122132
  #|     1322131213221312
  #|     2133122121331221
  #|     3213213332132133
  #|     1213212312132123
  #|   `);
  #|   const grassSideRows = grassTopRows.slice(0, 4).concat(dirtRows.slice(4));
  #|   const stoneRows = rowsFrom(`
  #|     abbcacbbabbcacbb
  #|     bbacabbcbbacabbc
  #|     cabbabdccabbabdc
  #|     abbdbcababbdbcab
  #|     bcabbabcbcabbabc
  #|     cabbcabbcabbcabb
  #|     abbcacbbabbcacbb
  #|     bbacabbcbbacabbc
  #|     cabbabdccabbabdc
  #|     abbdbcababbdbcab
  #|     bcabbabcbcabbabc
  #|     cabbcabbcabbcabb
  #|     abbcacbbabbcacbb
  #|     bbacabbcbbacabbc
  #|     cabbabdccabbabdc
  #|     abbdbcababbdbcab
  #|   `);
  #|   const sandRows = rowsFrom(`
  #|     aacbbacaaacbbaca
  #|     bcaaabcabcaaabca
  #|     caaabccacaaabcca
  #|     acbbacaaacbbacaa
  #|     bcaabcaabcaabcaa
  #|     aacbbacaaacbbaca
  #|     bcaaabcabcaaabca
  #|     caaabccacaaabcca
  #|     acbbacaaacbbacaa
  #|     bcaabcaabcaabcaa
  #|     aacbbacaaacbbaca
  #|     bcaaabcabcaaabca
  #|     caaabccacaaabcca
  #|     acbbacaaacbbacaa
  #|     bcaabcaabcaabcaa
  #|     aacbbacaaacbbaca
  #|   `);
  #|   const waterRows = rowsFrom(`
  #|     aabccbaaaabccbaa
  #|     abbccbcaabbccbca
  #|     bccabccbbccabccb
  #|     ccbaabccccbaabcc
  #|     abccbaababccbaab
  #|     bbccaabbbbccaabb
  #|     ccbbaaccccbbaacc
  #|     baccbbacbaccbbac
  #|     aabccbaaaabccbaa
  #|     abbccbcaabbccbca
  #|     bccabccbbccabccb
  #|     ccbaabccccbaabcc
  #|     abccbaababccbaab
  #|     bbccaabbbbccaabb
  #|     ccbbaaccccbbaacc
  #|     baccbbacbaccbbac
  #|   `);
  #|   const woodTopRows = rowsFrom(`
  #|     cccccccccccccccc
  #|     cbbbbbbbbbbbbbbc
  #|     cbaaaaaaaaaaaabc
  #|     cbabaaaaaaaababc
  #|     cbababaaaabababc
  #|     cbababddddbababc
  #|     cbababddddbababc
  #|     cbababddcdbababc
  #|     cbababdcdcbababc
  #|     cbababddcdbababc
  #|     cbababddddbababc
  #|     cbababaaaabababc
  #|     cbabaaaaaaaababc
  #|     cbaaaaaaaaaaaabc
  #|     cbbbbbbbbbbbbbbc
  #|     cccccccccccccccc
  #|   `);
  #|   const woodSideRows = rowsFrom(`
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaadabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbadaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaadabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|     aabbbbaaaabbbbaa
  #|   `);
  #|   const leavesRows = rowsFrom(`
  #|     aabac..bacabacaa
  #|     abbacabb..bacaba
  #|     bacab..abacabbac
  #|     acabbac..abacaba
  #|     baca..abbacabbac
  #|     abacabbac..abbac
  #|     bacabbac..abacaa
  #|     acaba..bacabbaca
  #|     aabac..bacabacaa
  #|     abbacabb..bacaba
  #|     bacab..abacabbac
  #|     acabbac..abacaba
  #|     baca..abbacabbac
  #|     abacabbac..abbac
  #|     bacabbac..abacaa
  #|     acaba..bacabbaca
  #|   `);
  #|   const bedrockRows = rowsFrom(`
  #|     abcbadbbabcbadbb
  #|     bbacbbdabbacbbda
  #|     cbabdbaccbabdbac
  #|     bacbabadbacbabad
  #|     abcbadbbabcbadbb
  #|     bbacbbdabbacbbda
  #|     cbabdbaccbabdbac
  #|     bacbabadbacbabad
  #|     abcbadbbabcbadbb
  #|     bbacbbdabbacbbda
  #|     cbabdbaccbabdbac
  #|     bacbabadbacbabad
  #|     abcbadbbabcbadbb
  #|     bbacbbdabbacbbda
  #|     cbabdbaccbabdbac
  #|     bacbabadbacbabad
  #|   `);
  #|   const planksRows = rowsFrom(`
  #|     cccccccccccccccc
  #|     aaabbaaabaaabbaa
  #|     aabbaaabbaaabbaa
  #|     aaabbaaabaaabbaa
  #|     cccccccccccccccc
  #|     aabbaaabbaaabbaa
  #|     aaabbaaadaaabbaa
  #|     aabbaaabbaaabbaa
  #|     cccccccccccccccc
  #|     aaabbaaabaaabbaa
  #|     aabbaaabbaaabbaa
  #|     aaabbaaabaaabbaa
  #|     cccccccccccccccc
  #|     aabbaaabbaaabbaa
  #|     aaabbaaabaaabbaa
  #|     aabbaaabbaaabbaa
  #|   `);
  #|   const brickRows = rowsFrom(`
  #|     mmmmmmmmmmmmmmmm
  #|     mcaamabamaacmbaa
  #|     mbacmcaamabamaac
  #|     mcaamabamaacmbaa
  #|     mmmmmmmmmmmmmmmm
  #|     camaabmcaamabama
  #|     bamcacmaabmcaamb
  #|     camaabmcaamabama
  #|     mmmmmmmmmmmmmmmm
  #|     mcaamabamaacmbaa
  #|     mbacmcaamabamaac
  #|     mcaamabamaacmbaa
  #|     mmmmmmmmmmmmmmmm
  #|     camaabmcaamabama
  #|     bamcacmaabmcaamb
  #|     camaabmcaamabama
  #|   `);
  #|   const cobbleRows = rowsFrom(`
  #|     abccabbbabccabbb
  #|     bccabbccbccabbcc
  #|     cabbccaacabbccaa
  #|     abbccabbabbccabb
  #|     bccabbbdbccabbbd
  #|     cabbccabcabbccab
  #|     abccabbbabccabbb
  #|     bccabbccbccabbcc
  #|     cabbccaacabbccaa
  #|     abbccabbabbccabb
  #|     bccabbbdbccabbbd
  #|     cabbccabcabbccab
  #|     abccabbbabccabbb
  #|     bccabbccbccabbcc
  #|     cabbccaacabbccaa
  #|     abbccabbabbccabb
  #|   `);
  #|   const gravelRows = rowsFrom(`
  #|     aabbccabaabbccab
  #|     bbacccbabbacccba
  #|     acbbacdcacbbacdc
  #|     bccababcbccababc
  #|     abbccabaabbccaba
  #|     ccbabccaccbabcca
  #|     bacbacbbbacbacbb
  #|     cabbacbccabbacbc
  #|     aabbccabaabbccab
  #|     bbacccbabbacccba
  #|     acbbacdcacbbacdc
  #|     bccababcbccababc
  #|     abbccabaabbccaba
  #|     ccbabccaccbabcca
  #|     bacbacbbbacbacbb
  #|     cabbacbccabbacbc
  #|   `);
  #|   const clayRows = rowsFrom(`
  #|     aabaccaaaabaccaa
  #|     baccaabbbaccaabb
  #|     accaaabbaccaaabb
  #|     caaabbaccaaabbac
  #|     aabaccaaaabaccaa
  #|     baccaabbbaccaabb
  #|     accaaabbaccaaabb
  #|     caaabbaccaaabbac
  #|     aabaccaaaabaccaa
  #|     baccaabbbaccaabb
  #|     accaaabbaccaaabb
  #|     caaabbaccaaabbac
  #|     aabaccaaaabaccaa
  #|     baccaabbbaccaabb
  #|     accaaabbaccaaabb
  #|     caaabbaccaaabbac
  #|   `);
  #|   const snowRows = rowsFrom(`
  #|     aaaaaaaaaaaaaaaa
  #|     aaabaaaaaaabaaaa
  #|     aabaaabaaabaaaba
  #|     aaaaacaaaaacaaaa
  #|     aaabaaaaaaabaaaa
  #|     aabaaabaaabaaaba
  #|     aaaaacaaaaacaaaa
  #|     aaabaaaaaaabaaaa
  #|     aabaaabaaabaaaba
  #|     aaaaacaaaaacaaaa
  #|     aaabaaaaaaabaaaa
  #|     aabaaabaaabaaaba
  #|     aaaaacaaaaacaaaa
  #|     aaabaaaaaaabaaaa
  #|     aabaaabaaabaaaba
  #|     aaaaaaaaaaaaaaaa
  #|   `);
  #|   const grassSidePalette = Object.assign({}, grassPalette, dirtPalette);
  #|   drawTile(0, 0, grassPalette, grassTopRows);
  #|   drawTile(1, 0, grassSidePalette, grassSideRows);
  #|   drawTile(2, 0, dirtPalette, dirtRows);
  #|   drawTile(3, 0, stonePalette, stoneRows);
  #|   drawTile(0, 1, sandPalette, sandRows);
  #|   drawTile(1, 1, waterPalette, waterRows);
  #|   drawTile(2, 1, woodTopPalette, woodTopRows);
  #|   drawTile(3, 1, woodSidePalette, woodSideRows);
  #|   drawTile(0, 2, leavesPalette, leavesRows);
  #|   drawTile(1, 2, bedrockPalette, bedrockRows);
  #|   drawTile(2, 2, planksPalette, planksRows);
  #|   drawTile(3, 2, brickPalette, brickRows);
  #|   drawTile(0, 3, cobblePalette, cobbleRows);
  #|   drawTile(1, 3, gravelPalette, gravelRows);
  #|   drawTile(2, 3, clayPalette, clayRows);
  #|   drawTile(3, 3, snowPalette, snowRows);
  #|   window.__atlas = canvas;
  #|   return canvas;
  #| }
