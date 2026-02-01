///|
priv enum Block {
  Air
  Grass
  Dirt
  Stone
  Sand
  Water
  Wood
  Leaves
  Bedrock
  Planks
  Brick
  Cobblestone
  Gravel
  Clay
  Snow
} derive(Eq)

///|
priv enum Biome {
  Ocean
  Plains
  Forest
  Hills
  Mountains
  Desert
  Mesa
  River
  Snow
  Karst
} derive(Eq)

///|
priv struct ColumnInfo {
  height : Int
  biome : Biome
  ridge : Double
  moist : Double
}

///|
priv struct Chunk {
  blocks : Array[Block]
}

///|
priv struct World {
  chunk_size : Int
  height : Int
  section_height : Int
  sea_level : Int
  chunks : @hashmap.HashMap[String, Chunk]
}

///|
fn World::new(height : Int, chunk_size : Int, section_height : Int) -> World {
  let sea_level = height / 2
  {
    chunk_size,
    height,
    section_height,
    sea_level,
    chunks: @hashmap.new(capacity=64),
  }
}

///|
fn chunk_key(cx : Int, cz : Int) -> String {
  "\{cx},\{cz}"
}

///|
fn chunk_key_3(cx : Int, cy : Int, cz : Int) -> String {
  "\{cx},\{cy},\{cz}"
}

///|
fn div_floor(a : Int, b : Int) -> Int {
  let mut q = a / b
  let r = a % b
  if r != 0 && (r > 0) != (b > 0) {
    q = q - 1
  }
  q
}

///|
fn mod_floor(a : Int, b : Int) -> Int {
  a - div_floor(a, b) * b
}

///|
fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

///|
fn smoothstep(t : Double) -> Double {
  t * t * (3.0 - 2.0 * t)
}

///|
fn clamp01(v : Double) -> Double {
  if v < 0.0 {
    0.0
  } else if v > 1.0 {
    1.0
  } else {
    v
  }
}

///|
fn hash2(x : Int, z : Int) -> Double {
  let mut n = x * 374761393 + z * 668265263 + 0x9E3779B9
  n = (n ^ (n >> 13)) * 1274126177
  n = n ^ (n >> 16)
  let v = n & 0x7fffffff
  v.to_double() / 2147483647.0
}

///|
fn value_noise(x : Double, z : Double) -> Double {
  let x0 = x.floor().to_int()
  let z0 = z.floor().to_int()
  let x1 = x0 + 1
  let z1 = z0 + 1
  let fx = x - x0.to_double()
  let fz = z - z0.to_double()
  let u = smoothstep(fx)
  let v = smoothstep(fz)
  let n00 = hash2(x0, z0)
  let n10 = hash2(x1, z0)
  let n01 = hash2(x0, z1)
  let n11 = hash2(x1, z1)
  let nx0 = lerp(n00, n10, u)
  let nx1 = lerp(n01, n11, u)
  lerp(nx0, nx1, v)
}

///|
fn fbm(x : Double, z : Double) -> Double {
  let mut sum = 0.0
  let mut amp = 1.0
  let mut freq = 1.0
  let mut norm = 0.0
  for i = 0; i < 4; i = i + 1 {
    sum = sum + value_noise(x * freq, z * freq) * amp
    norm = norm + amp
    amp = amp * 0.5
    freq = freq * 2.0
  }
  sum / norm
}

///|
fn ridged(x : Double, z : Double) -> Double {
  let n = fbm(x, z)
  let r = 1.0 - (2.0 * n - 1.0).abs()
  r * r
}

///|
fn warp_coords(x : Double, z : Double) -> (Double, Double) {
  let warp_x = fbm(x * 0.0015, z * 0.0015)
  let warp_z = fbm(x * 0.0015 + 17.3, z * 0.0015 - 11.7)
  let wx = x + (warp_x - 0.5) * 48.0
  let wz = z + (warp_z - 0.5) * 48.0
  (wx, wz)
}

///|
fn terrace(height : Double, step : Double) -> Double {
  let base = (height / step).floor() * step
  let frac = height - base
  base + frac * 0.2
}

///|
fn biome_from(
  temp : Double,
  moist : Double,
  ridge : Double,
  land : Double,
) -> Biome {
  if land < 0.16 {
    Biome::Ocean
  } else if temp > 0.7 && moist < 0.34 {
    if ridge > 0.55 {
      Biome::Mesa
    } else {
      Biome::Desert
    }
  } else if ridge > 0.62 {
    Biome::Hills
  } else if moist > 0.62 {
    Biome::Forest
  } else {
    Biome::Plains
  }
}

///|
fn tree_peak(gx : Int, gz : Int, radius : Int) -> (Bool, Double) {
  let noise = hash2(gx, gz)
  for dz = -radius; dz <= radius; dz = dz + 1 {
    for dx = -radius; dx <= radius; dx = dx + 1 {
      if dx == 0 && dz == 0 {
        continue
      }
      let other = hash2(gx + dx, gz + dz)
      if other >= noise {
        return (false, noise)
      }
    }
  }
  (true, noise)
}

///|
fn World::chunk_index(self : World, lx : Int, y : Int, lz : Int) -> Int {
  lx + self.chunk_size * (y + self.section_height * lz)
}

///|
fn World::chunk_blocks(
  self : World,
  cx : Int,
  cy : Int,
  cz : Int,
) -> Array[Block] {
  let key = chunk_key_3(cx, cy, cz)
  match self.chunks.get(key) {
    Some(chunk) => chunk.blocks
    None => {
      let chunk = generate_chunk_section(self, cx, cy, cz)
      self.chunks.set(key, chunk)
      chunk.blocks
    }
  }
}

///|
fn World::get(self : World, x : Int, y : Int, z : Int) -> Block {
  if y < 0 {
    Block::Bedrock
  } else if y >= self.height {
    Block::Air
  } else {
    let cx = div_floor(x, self.chunk_size)
    let cz = div_floor(z, self.chunk_size)
    let cy = div_floor(y, self.section_height)
    let lx = mod_floor(x, self.chunk_size)
    let lz = mod_floor(z, self.chunk_size)
    let ly = mod_floor(y, self.section_height)
    let blocks = self.chunk_blocks(cx, cy, cz)
    blocks[self.chunk_index(lx, ly, lz)]
  }
}

///|
fn block_is_air(block : Block) -> Bool {
  match block {
    Block::Air => true
    _ => false
  }
}

///|
fn block_is_transparent(block : Block) -> Bool {
  match block {
    Block::Water => true
    _ => false
  }
}

///|
fn block_is_cutout(block : Block) -> Bool {
  match block {
    Block::Leaves => true
    _ => false
  }
}

///|
fn block_is_see_through(block : Block) -> Bool {
  block_is_transparent(block) || block_is_cutout(block)
}

///|
fn block_is_water(block : Block) -> Bool {
  match block {
    Block::Water => true
    _ => false
  }
}

///|
fn block_is_solid(block : Block) -> Bool {
  match block {
    Block::Air => false
    Block::Water => false
    _ => true
  }
}

///|
fn block_is_replaceable(block : Block) -> Bool {
  match block {
    Block::Air => true
    Block::Water => true
    _ => false
  }
}

///|

///|
fn World::set(self : World, x : Int, y : Int, z : Int, block : Block) -> Bool {
  if y <= 0 || y >= self.height {
    false
  } else {
    let cx = div_floor(x, self.chunk_size)
    let cz = div_floor(z, self.chunk_size)
    let cy = div_floor(y, self.section_height)
    let lx = mod_floor(x, self.chunk_size)
    let lz = mod_floor(z, self.chunk_size)
    let ly = mod_floor(y, self.section_height)
    let blocks = self.chunk_blocks(cx, cy, cz)
    blocks[self.chunk_index(lx, ly, lz)] = block
    true
  }
}

///|
fn World::get_range(
  self : World,
  x : Int,
  y : Int,
  z : Int,
  y_min : Int,
  y_max : Int,
) -> Block {
  if y < y_min || y >= y_max {
    Block::Air
  } else {
    self.get(x, y, z)
  }
}

///|
fn World::column_info(self : World, x : Int, z : Int) -> ColumnInfo {
  let fx = x.to_double()
  let fz = z.to_double()
  let (wx, wz) = warp_coords(fx, fz)
  let continent = fbm(wx * 0.0011, wz * 0.0011)
  let continentalness = continent * 2.0 - 1.0
  let land = clamp01((continentalness + 0.2) / 0.55)
  let hills = fbm(wx * 0.018, wz * 0.018)
  let detail = fbm(wx * 0.085, wz * 0.085)
  let ridge = ridged(wx * 0.0065, wz * 0.0065)
  let peaks = ridged(wx * 0.012, wz * 0.012)
  let mega = ridged(wx * 0.0008 + 2.5, wz * 0.0008 - 5.4)
  let mega_mask = clamp01((mega - 0.6) / 0.25)
  let mountain_chain = ridged(wx * 0.0019 + 7.4, wz * 0.0019 - 3.1)
  let chain_mask = clamp01((mountain_chain - 0.45) / 0.4)
  let cliff = ridged(wx * 0.02, wz * 0.02)
  let cliff_mask = clamp01((cliff - 0.72) / 0.22)
  let cliff_strength = cliff_mask * cliff_mask
  let coast = clamp01((0.42 - land) / 0.24)
  let coast_noise = fbm(wx * 0.022 + 19.2, wz * 0.022 - 7.1)
  let coast_cliff = clamp01((coast_noise - 0.72) / 0.2) * coast
  let raw_scale = self.height.to_double() / 384.0
  let relief_scale = if raw_scale < 2.0 { raw_scale } else { 2.0 }
  let detail_scale = if raw_scale < 1.0 { raw_scale } else { 1.0 }
  let temp = fbm(wx * 0.0015 + 5.2, wz * 0.0015 - 9.7)
  let moist = fbm(wx * 0.0018 - 7.3, wz * 0.0018 + 2.4)
  let karst_noise = fbm(wx * 0.008 + 21.4, wz * 0.008 - 17.2)
  let karst_mask = clamp01((karst_noise - 0.55) / 0.25)
  let basin_noise = fbm(wx * 0.00085 - 14.1, wz * 0.00085 + 9.2)
  let basin_mask = clamp01((0.38 - basin_noise) / 0.2)
  let river_noise = fbm(wx * 0.002 + 12.4, wz * 0.002 - 8.2)
  let river_shape = 1.0 - (river_noise * 2.0 - 1.0).abs()
  let river_mask = clamp01((river_shape - 0.78) / 0.12)
  let mut biome = biome_from(temp, moist, ridge, land)
  let sea = self.sea_level.to_double()
  let macro_noise = fbm(wx * 0.00012 + 6.7, wz * 0.00012 - 8.9)
  let macro_shift = (macro_noise * 2.0 - 1.0) * (self.height.to_double() * 0.08)
  let base_ocean = sea - 32.0 * relief_scale + macro_shift * 0.4
  let base_land = sea - 6.0 * relief_scale + macro_shift
  let land_height = base_land +
    (continent - 0.5) * 18.0 * relief_scale +
    (hills - 0.5) * 10.0 * detail_scale +
    (detail - 0.5) * 2.5 * detail_scale
  let mut height = lerp(base_ocean, land_height, land)
  height = height +
    chain_mask * 26.0 * relief_scale +
    chain_mask * peaks * 18.0 * relief_scale
  height = height +
    mega_mask * 60.0 * relief_scale +
    mega_mask * peaks * 24.0 * relief_scale
  height = height +
    ridge * 8.0 * detail_scale +
    cliff_strength * 6.0 * detail_scale
  height = height - basin_mask * 14.0 * relief_scale
  if karst_mask > 0.45 && land > 0.3 {
    height = terrace(height + karst_mask * 6.0 * detail_scale, 2.8)
    let sink = fbm(wx * 0.05 + 3.1, wz * 0.05 - 6.7)
    if sink > 0.74 {
      height = height - (sink - 0.74) * 12.0 * karst_mask * detail_scale
    }
  }
  if river_mask > 0.0 && land > 0.22 {
    let river_depth = river_mask *
      (8.0 + (1.0 - chain_mask) * 4.0) *
      detail_scale
    height = height - river_depth
  }
  match biome {
    Biome::Ocean => height = height - (8.0 + land * 5.0) * relief_scale
    Biome::Mesa => {
      height = height +
        ridge * 6.0 * detail_scale +
        (hills - 0.5) * 3.0 * detail_scale
      height = terrace(height, 4.0)
    }
    Biome::Desert =>
      height = height +
        (hills - 0.5) * 3.0 * detail_scale +
        (detail - 0.5) * 1.2 * detail_scale
    Biome::Forest =>
      height = height +
        (hills - 0.5) * 4.5 * detail_scale +
        (detail - 0.5) * 2.0 * detail_scale
    Biome::Plains => height = lerp(height, sea + 5.0 * relief_scale, 0.75)
    Biome::Hills =>
      height = height +
        ridge * 6.0 * detail_scale +
        (hills - 0.5) * 3.0 * detail_scale
    Biome::Mountains =>
      height = height + ridge * 12.0 * relief_scale + peaks * 8.0 * relief_scale
    Biome::River => height = height
    Biome::Snow => height = height
    Biome::Karst => height = height
  }
  if land > 0.2 && river_mask > 0.55 && ridge < 0.7 {
    biome = Biome::River
  }
  if chain_mask > 0.55 && land > 0.3 {
    biome = Biome::Mountains
  }
  if mega_mask > 0.55 && land > 0.3 {
    biome = Biome::Mountains
  }
  if karst_mask > 0.68 && land > 0.32 && temp > 0.4 && temp < 0.75 {
    biome = Biome::Karst
  }
  if height > sea + 46.0 * relief_scale {
    biome = Biome::Snow
  }
  if coast > 0.0 {
    let beach_height = sea + 2.0 * relief_scale
    height = lerp(height, beach_height, coast * 0.7)
    if coast_cliff > 0.35 {
      height = height + coast_cliff * 6.0 * relief_scale
    }
  }
  let lake = fbm(wx * 0.01 + 13.7, wz * 0.01 - 4.4)
  if land > 0.2 && lake > 0.76 {
    height = height - (lake - 0.76) * 14.0 * detail_scale
  }
  let mut h = height.floor().to_int()
  if h < 4 {
    h = 4
  } else if h > self.height - 3 {
    h = self.height - 3
  }
  { height: h, biome, ridge, moist }
}

///|
fn World::height_at(self : World, x : Int, z : Int) -> Int {
  self.column_info(x, z).height
}

///|
fn surface_blocks(
  world : World,
  gx : Int,
  gz : Int,
  info : ColumnInfo,
) -> (Block, Block) {
  let h = info.height
  let biome = info.biome
  let ridge = info.ridge
  let moist = info.moist
  let raw_scale = world.height.to_double() / 384.0
  let relief_scale = if raw_scale < 2.0 { raw_scale } else { 2.0 }
  let scaled30 = (30.0 * relief_scale).to_int()
  let scaled28 = (28.0 * relief_scale).to_int()
  let scaled48 = (48.0 * relief_scale).to_int()
  let mut top_block = match biome {
    Biome::Ocean => Block::Sand
    Biome::Desert => Block::Sand
    Biome::Mesa => Block::Sand
    Biome::Mountains => Block::Stone
    Biome::Hills => Block::Grass
    Biome::Forest => Block::Grass
    Biome::Plains => Block::Grass
    Biome::River => Block::Sand
    Biome::Snow => Block::Snow
    Biome::Karst => Block::Stone
  }
  let mut mid_block = match biome {
    Biome::Ocean => Block::Sand
    Biome::Desert => Block::Sand
    Biome::Mesa => Block::Sand
    Biome::Mountains => Block::Stone
    Biome::Hills => Block::Dirt
    Biome::Forest => Block::Dirt
    Biome::Plains => Block::Dirt
    Biome::River => Block::Clay
    Biome::Snow => Block::Stone
    Biome::Karst => Block::Stone
  }
  let is_shore = h <= world.sea_level + 1
  if is_shore {
    top_block = Block::Sand
    mid_block = Block::Sand
  }
  let sea = world.sea_level
  if biome == Biome::Mountains {
    if h > sea + scaled30 {
      top_block = Block::Stone
      mid_block = Block::Stone
    } else {
      top_block = Block::Grass
      mid_block = Block::Dirt
    }
  }
  if biome != Biome::Snow && ridge > 0.88 && h > sea + scaled28 {
    top_block = Block::Stone
    mid_block = Block::Stone
  }
  let snow_line = sea + scaled48
  if h >= snow_line {
    top_block = Block::Snow
    mid_block = Block::Stone
  }
  let surface_noise = fbm(
    gx.to_double() * 0.06 + 2.1,
    gz.to_double() * 0.06 - 3.7,
  )
  let is_stony = match top_block {
    Block::Stone => true
    _ => false
  }
  let allow_soil = biome != Biome::Snow && h > world.sea_level + 2
  if is_stony && allow_soil {
    let karst_limit = if biome == Biome::Karst { 0.62 } else { 0.45 }
    if surface_noise > karst_limit && moist > 0.3 {
      top_block = Block::Grass
      mid_block = Block::Dirt
    } else if surface_noise > 0.38 {
      top_block = Block::Dirt
      mid_block = Block::Dirt
    }
  }
  (top_block, mid_block)
}

///|
fn bedrock_height(world : World, gx : Int, gz : Int, info : ColumnInfo) -> Int {
  let (wx, wz) = warp_coords(gx.to_double(), gz.to_double())
  let plate = fbm(wx * 0.0006 + 11.7, wz * 0.0006 - 4.2)
  let plate_shift = (plate - 0.5) * 80.0
  let sea = world.sea_level.to_double()
  let base_floor = sea - 140.0 + plate_shift
  let depth_limit = 120.0
  let surface = info.height.to_double()
  let mut bedrock = base_floor
  let max_floor = surface - depth_limit
  if max_floor > bedrock {
    bedrock = max_floor
  }
  let mut y = bedrock.floor().to_int()
  let max_allowed = info.height - 5
  if y > max_allowed {
    y = max_allowed
  }
  if y < 0 {
    y = 0
  }
  y
}

///|
fn generate_chunk_section(world : World, cx : Int, cy : Int, cz : Int) -> Chunk {
  let total = world.chunk_size * world.section_height * world.chunk_size
  let blocks = Array::make(total, Block::Air)
  let y0 = cy * world.section_height
  let mut y1 = y0 + world.section_height
  if y1 > world.height {
    y1 = world.height
  }
  for lz = 0; lz < world.chunk_size; lz = lz + 1 {
    for lx = 0; lx < world.chunk_size; lx = lx + 1 {
      let gx = cx * world.chunk_size + lx
      let gz = cz * world.chunk_size + lz
      let info = world.column_info(gx, gz)
      let h = info.height
      let biome = info.biome
      let ridge = info.ridge
      let moist = info.moist
      let (top_block, mid_block) = surface_blocks(world, gx, gz, info)
      let bedrock_y = bedrock_height(world, gx, gz, info)
      for y = y0; y < y1; y = y + 1 {
        let ly = y - y0
        let idx = world.chunk_index(lx, ly, lz)
        if y <= bedrock_y {
          blocks[idx] = Block::Bedrock
        } else if y < h - 4 {
          blocks[idx] = Block::Stone
        } else if y < h - 1 {
          blocks[idx] = mid_block
        } else if y < h {
          blocks[idx] = top_block
        } else if y < world.sea_level {
          blocks[idx] = Block::Water
        }
      }
      if h > world.sea_level + 1 {
        let forest = fbm(
          gx.to_double() * 0.01 + 2.7,
          gz.to_double() * 0.01 - 4.1,
        )
        let radius_bias = if forest > 0.65 {
          -1
        } else if forest < 0.35 {
          1
        } else {
          0
        }
        let tree_radius = match biome {
          Biome::Forest => 2
          Biome::Plains => 3
          Biome::Hills => 3
          Biome::Mountains => 4
          Biome::Ocean => 4
          Biome::Desert => 4
          Biome::Mesa => 4
          Biome::River => 4
          Biome::Snow => 4
          Biome::Karst => 4
        }
        let tree_radius = if tree_radius + radius_bias < 2 {
          2
        } else {
          tree_radius + radius_bias
        }
        let (is_peak, tree_noise) = tree_peak(gx, gz, tree_radius)
        let mut tree_threshold = match biome {
          Biome::Ocean => 1.2
          Biome::Forest => 0.7
          Biome::Plains => 0.78
          Biome::Hills => 0.8
          Biome::Mountains => 0.88
          Biome::Desert => 1.1
          Biome::Mesa => 1.05
          Biome::River => 1.2
          Biome::Snow => 1.2
          Biome::Karst => 1.0
        }
        let density_boost = (forest - 0.5) * 0.16
        tree_threshold = tree_threshold - moist * 0.08 - density_boost
        let can_tree = match top_block {
          Block::Grass => true
          _ => false
        }
        if can_tree &&
          is_peak &&
          ridge < 0.75 &&
          tree_noise > tree_threshold &&
          lx >= 2 &&
          lz >= 2 &&
          lx <= world.chunk_size - 3 &&
          lz <= world.chunk_size - 3 {
          let trunk = 3 + (tree_noise * 4.0 + moist * 2.0).to_int()
          for t = 0; t < trunk; t = t + 1 {
            let y = h + t
            if y >= y0 && y < y1 {
              let idx = world.chunk_index(lx, y - y0, lz)
              blocks[idx] = Block::Wood
            }
          }
          let leaf_start = h + trunk - 2
          for dy = -2; dy <= 1; dy = dy + 1 {
            for dz = -2; dz <= 2; dz = dz + 1 {
              for dx = -2; dx <= 2; dx = dx + 1 {
                let dist = dx * dx + dz * dz + dy * dy
                if dist <= 6 {
                  let y = leaf_start + dy
                  let lx2 = lx + dx
                  let lz2 = lz + dz
                  if y >= y0 &&
                    y < y1 &&
                    lx2 >= 0 &&
                    lx2 < world.chunk_size &&
                    lz2 >= 0 &&
                    lz2 < world.chunk_size {
                    let idx = world.chunk_index(lx2, y - y0, lz2)
                    if block_is_air(blocks[idx]) {
                      blocks[idx] = Block::Leaves
                    }
                  }
                }
              }
            }
          }
          let top_y = h + trunk
          for dz = -1; dz <= 1; dz = dz + 1 {
            for dx = -1; dx <= 1; dx = dx + 1 {
              let dist = dx * dx + dz * dz
              if dist <= 2 {
                let lx2 = lx + dx
                let lz2 = lz + dz
                let y = top_y
                if y >= y0 &&
                  y < y1 &&
                  lx2 >= 0 &&
                  lx2 < world.chunk_size &&
                  lz2 >= 0 &&
                  lz2 < world.chunk_size {
                  let idx = world.chunk_index(lx2, y - y0, lz2)
                  if block_is_air(blocks[idx]) {
                    blocks[idx] = Block::Leaves
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  { blocks, }
}

///|
priv struct RayHit {
  x : Int
  y : Int
  z : Int
  prev_x : Int
  prev_y : Int
  prev_z : Int
}

///|
fn raycast(
  world : World,
  origin : Vec3,
  dir : Vec3,
  max_dist : Double,
) -> RayHit? {
  let dir_n = dir.normalize()
  if dir_n.length() <= 0.000001 {
    return None
  }
  let mut x = origin.x.floor().to_int()
  let mut y = origin.y.floor().to_int()
  let mut z = origin.z.floor().to_int()
  let start_block = world.get(x, y, z)
  if !block_is_air(start_block) && !block_is_replaceable(start_block) {
    return Some({ x, y, z, prev_x: x, prev_y: y, prev_z: z })
  }
  let step_x = if dir_n.x > 0.0 { 1 } else if dir_n.x < 0.0 { -1 } else { 0 }
  let step_y = if dir_n.y > 0.0 { 1 } else if dir_n.y < 0.0 { -1 } else { 0 }
  let step_z = if dir_n.z > 0.0 { 1 } else if dir_n.z < 0.0 { -1 } else { 0 }
  let mut t_max_x = if step_x != 0 {
    let next = if step_x > 0 { (x + 1).to_double() } else { x.to_double() }
    (next - origin.x) / dir_n.x
  } else {
    1.0e9
  }
  let mut t_max_y = if step_y != 0 {
    let next = if step_y > 0 { (y + 1).to_double() } else { y.to_double() }
    (next - origin.y) / dir_n.y
  } else {
    1.0e9
  }
  let mut t_max_z = if step_z != 0 {
    let next = if step_z > 0 { (z + 1).to_double() } else { z.to_double() }
    (next - origin.z) / dir_n.z
  } else {
    1.0e9
  }
  let t_delta_x = if step_x != 0 { 1.0 / dir_n.x.abs() } else { 1.0e9 }
  let t_delta_y = if step_y != 0 { 1.0 / dir_n.y.abs() } else { 1.0e9 }
  let t_delta_z = if step_z != 0 { 1.0 / dir_n.z.abs() } else { 1.0e9 }
  let mut prev_x = x
  let mut prev_y = y
  let mut prev_z = z
  let mut t = 0.0
  while t <= max_dist {
    if t_max_x < t_max_y {
      if t_max_x < t_max_z {
        prev_x = x
        prev_y = y
        prev_z = z
        x = x + step_x
        t = t_max_x
        t_max_x = t_max_x + t_delta_x
      } else {
        prev_x = x
        prev_y = y
        prev_z = z
        z = z + step_z
        t = t_max_z
        t_max_z = t_max_z + t_delta_z
      }
    } else if t_max_y < t_max_z {
      prev_x = x
      prev_y = y
      prev_z = z
      y = y + step_y
      t = t_max_y
      t_max_y = t_max_y + t_delta_y
    } else {
      prev_x = x
      prev_y = y
      prev_z = z
      z = z + step_z
      t = t_max_z
      t_max_z = t_max_z + t_delta_z
    }
    if !block_is_air(world.get(x, y, z)) {
      return Some({ x, y, z, prev_x, prev_y, prev_z })
    }
  }
  None
}

///|
fn raycast_solid(
  world : World,
  origin : Vec3,
  dir : Vec3,
  max_dist : Double,
) -> RayHit? {
  let dir_n = dir.normalize()
  if dir_n.length() <= 0.000001 {
    return None
  }
  let mut x = origin.x.floor().to_int()
  let mut y = origin.y.floor().to_int()
  let mut z = origin.z.floor().to_int()
  let start_block = world.get(x, y, z)
  if !block_is_air(start_block) && !block_is_replaceable(start_block) {
    return Some({ x, y, z, prev_x: x, prev_y: y, prev_z: z })
  }
  let step_x = if dir_n.x > 0.0 { 1 } else if dir_n.x < 0.0 { -1 } else { 0 }
  let step_y = if dir_n.y > 0.0 { 1 } else if dir_n.y < 0.0 { -1 } else { 0 }
  let step_z = if dir_n.z > 0.0 { 1 } else if dir_n.z < 0.0 { -1 } else { 0 }
  let mut t_max_x = if step_x != 0 {
    let next = if step_x > 0 { (x + 1).to_double() } else { x.to_double() }
    (next - origin.x) / dir_n.x
  } else {
    1.0e9
  }
  let mut t_max_y = if step_y != 0 {
    let next = if step_y > 0 { (y + 1).to_double() } else { y.to_double() }
    (next - origin.y) / dir_n.y
  } else {
    1.0e9
  }
  let mut t_max_z = if step_z != 0 {
    let next = if step_z > 0 { (z + 1).to_double() } else { z.to_double() }
    (next - origin.z) / dir_n.z
  } else {
    1.0e9
  }
  let t_delta_x = if step_x != 0 { 1.0 / dir_n.x.abs() } else { 1.0e9 }
  let t_delta_y = if step_y != 0 { 1.0 / dir_n.y.abs() } else { 1.0e9 }
  let t_delta_z = if step_z != 0 { 1.0 / dir_n.z.abs() } else { 1.0e9 }
  let mut prev_x = x
  let mut prev_y = y
  let mut prev_z = z
  let mut t = 0.0
  while t <= max_dist {
    if t_max_x < t_max_y {
      if t_max_x < t_max_z {
        prev_x = x
        prev_y = y
        prev_z = z
        x = x + step_x
        t = t_max_x
        t_max_x = t_max_x + t_delta_x
      } else {
        prev_x = x
        prev_y = y
        prev_z = z
        z = z + step_z
        t = t_max_z
        t_max_z = t_max_z + t_delta_z
      }
    } else if t_max_y < t_max_z {
      prev_x = x
      prev_y = y
      prev_z = z
      y = y + step_y
      t = t_max_y
      t_max_y = t_max_y + t_delta_y
    } else {
      prev_x = x
      prev_y = y
      prev_z = z
      z = z + step_z
      t = t_max_z
      t_max_z = t_max_z + t_delta_z
    }
    let block = world.get(x, y, z)
    if !block_is_air(block) && !block_is_replaceable(block) {
      return Some({ x, y, z, prev_x, prev_y, prev_z })
    }
  }
  None
}
