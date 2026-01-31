///|
priv struct Mesh {
  positions : Array[Double]
  colors : Array[Double]
  uvs : Array[Double]
  vertex_count : Int
}

///|
priv struct ChunkMesh {
  solid : Mesh
  cutout : Mesh
  trans : Mesh
}

///|
fn build_mesh_range(
  world : World,
  x_start : Int,
  x_end : Int,
  z_start : Int,
  z_end : Int,
) -> ChunkMesh {
  let solid_positions : Array[Double] = []
  let solid_colors : Array[Double] = []
  let solid_uvs : Array[Double] = []
  let cutout_positions : Array[Double] = []
  let cutout_colors : Array[Double] = []
  let cutout_uvs : Array[Double] = []
  let trans_positions : Array[Double] = []
  let trans_colors : Array[Double] = []
  let trans_uvs : Array[Double] = []
  for z = z_start; z < z_end; z = z + 1 {
    for y = 0; y < world.height; y = y + 1 {
      for x = x_start; x < x_end; x = x + 1 {
        let block = world.get(x, y, z)
        if !block_is_air(block) {
          let is_trans = block_is_transparent(block)
          let is_cutout = block_is_cutout(block)
          let positions = if is_trans {
            trans_positions
          } else if is_cutout {
            cutout_positions
          } else {
            solid_positions
          }
          let colors = if is_trans {
            trans_colors
          } else if is_cutout {
            cutout_colors
          } else {
            solid_colors
          }
          let uvs = if is_trans {
            trans_uvs
          } else if is_cutout {
            cutout_uvs
          } else {
            solid_uvs
          }
          let east = world.get(x + 1, y, z)
          if face_visible(block, east) {
            append_face_east(positions, colors, uvs, x, y, z, block)
          }
          let west = world.get(x - 1, y, z)
          if face_visible(block, west) {
            append_face_west(positions, colors, uvs, x, y, z, block)
          }
          let up = world.get(x, y + 1, z)
          if face_visible(block, up) {
            append_face_up(positions, colors, uvs, x, y, z, block)
          }
          let down = world.get(x, y - 1, z)
          if face_visible(block, down) {
            append_face_down(positions, colors, uvs, x, y, z, block)
          }
          let south = world.get(x, y, z + 1)
          if face_visible(block, south) {
            append_face_south(positions, colors, uvs, x, y, z, block)
          }
          let north = world.get(x, y, z - 1)
          if face_visible(block, north) {
            append_face_north(positions, colors, uvs, x, y, z, block)
          }
        }
      }
    }
  }
  let solid = {
    positions: solid_positions,
    colors: solid_colors,
    uvs: solid_uvs,
    vertex_count: solid_positions.length() / 3,
  }
  let cutout = {
    positions: cutout_positions,
    colors: cutout_colors,
    uvs: cutout_uvs,
    vertex_count: cutout_positions.length() / 3,
  }
  let trans = {
    positions: trans_positions,
    colors: trans_colors,
    uvs: trans_uvs,
    vertex_count: trans_positions.length() / 3,
  }
  { solid, cutout, trans }
}

///|
fn build_chunk_mesh(
  world : World,
  cx : Int,
  cz : Int,
  chunk_size : Int,
) -> ChunkMesh {
  let x_start = cx * chunk_size
  let z_start = cz * chunk_size
  build_mesh_range(
    world,
    x_start,
    x_start + chunk_size,
    z_start,
    z_start + chunk_size,
  )
}

///|
fn build_chunk_surface_mesh(
  world : World,
  cx : Int,
  cz : Int,
  chunk_size : Int,
) -> ChunkMesh {
  let solid_positions : Array[Double] = []
  let solid_colors : Array[Double] = []
  let solid_uvs : Array[Double] = []
  let trans_positions : Array[Double] = []
  let trans_colors : Array[Double] = []
  let trans_uvs : Array[Double] = []
  let total = chunk_size * chunk_size
  let heights = Array::make(total, 0)
  let blocks = Array::make(total, Block::Air)
  for z = 0; z < chunk_size; z = z + 1 {
    for x = 0; x < chunk_size; x = x + 1 {
      let gx = cx * chunk_size + x
      let gz = cz * chunk_size + z
      let info = world.column_info(gx, gz)
      let h = info.height
      let (top_block, _) = surface_blocks(world, gx, gz, info)
      let idx = x + z * chunk_size
      if h <= world.sea_level {
        heights[idx] = world.sea_level
        blocks[idx] = Block::Water
      } else {
        heights[idx] = h
        blocks[idx] = top_block
      }
    }
  }
  let used = Array::make(total, false)
  for z = 0; z < chunk_size; z = z + 1 {
    for x = 0; x < chunk_size; x = x + 1 {
      let idx = x + z * chunk_size
      if used[idx] {
        continue
      }
      let block = blocks[idx]
      if block_is_air(block) {
        continue
      }
      let height = heights[idx]
      let mut w = 1
      while x + w < chunk_size {
        let idx2 = x + w + z * chunk_size
        if used[idx2] || blocks[idx2] != block || heights[idx2] != height {
          break
        }
        w = w + 1
      }
      let mut d = 1
      while z + d < chunk_size {
        let mut ok = true
        for dx = 0; dx < w; dx = dx + 1 {
          let idx2 = x + dx + (z + d) * chunk_size
          if used[idx2] || blocks[idx2] != block || heights[idx2] != height {
            ok = false
            break
          }
        }
        if !ok {
          break
        }
        d = d + 1
      }
      for dz = 0; dz < d; dz = dz + 1 {
        for dx = 0; dx < w; dx = dx + 1 {
          used[x + dx + (z + dz) * chunk_size] = true
        }
      }
      let x0 = (cx * chunk_size + x).to_double()
      let x1 = (cx * chunk_size + x + w).to_double()
      let z0 = (cz * chunk_size + z).to_double()
      let z1 = (cz * chunk_size + z + d).to_double()
      let y = height.to_double()
      if block_is_transparent(block) {
        append_face_up_rect(
          trans_positions, trans_colors, trans_uvs, x0, x1, z0, z1, y, block,
        )
      } else {
        append_face_up_rect(
          solid_positions, solid_colors, solid_uvs, x0, x1, z0, z1, y, block,
        )
      }
    }
  }
  let solid = {
    positions: solid_positions,
    colors: solid_colors,
    uvs: solid_uvs,
    vertex_count: solid_positions.length() / 3,
  }
  let cutout = { positions: [], colors: [], uvs: [], vertex_count: 0 }
  let trans = {
    positions: trans_positions,
    colors: trans_colors,
    uvs: trans_uvs,
    vertex_count: trans_positions.length() / 3,
  }
  { solid, cutout, trans }
}

///|
fn face_visible(block : Block, neighbor : Block) -> Bool {
  if block_is_air(block) {
    false
  } else if block_is_transparent(block) {
    block_is_air(neighbor)
  } else if block_is_cutout(block) {
    !block_is_cutout(neighbor)
  } else {
    block_is_air(neighbor) || block_is_see_through(neighbor)
  }
}

///|
fn face_shade(face : Int) -> Double {
  match face {
    0 => 0.85
    1 => 0.85
    2 => 1.0
    3 => 0.5
    4 => 0.8
    5 => 0.8
    _ => 1.0
  }
}

///|
fn block_tint(block : Block, face : Int) -> Vec3 {
  let shade = face_shade(face)
  match block {
    Block::Air => vec3(0.0, 0.0, 0.0)
    _ => vec3(shade, shade, shade)
  }
}

///|
fn tile_for_face(block : Block, face : Int) -> (Int, Int) {
  match block {
    Block::Grass =>
      if face == 2 {
        (0, 0)
      } else if face == 3 {
        (2, 0)
      } else {
        (1, 0)
      }
    Block::Dirt => (2, 0)
    Block::Stone => (3, 0)
    Block::Sand => (0, 1)
    Block::Water => (1, 1)
    Block::Wood => if face == 2 || face == 3 { (2, 1) } else { (3, 1) }
    Block::Leaves => (0, 2)
    Block::Bedrock => (1, 2)
    Block::Planks => (2, 2)
    Block::Brick => (3, 2)
    Block::Cobblestone => (0, 3)
    Block::Gravel => (1, 3)
    Block::Clay => (2, 3)
    Block::Snow => (3, 3)
    Block::Air => (0, 0)
  }
}

///|
fn push_vertex_uv(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Double,
  y : Double,
  z : Double,
  color : Vec3,
  u : Double,
  v : Double,
) -> Unit {
  positions.push(x)
  positions.push(y)
  positions.push(z)
  colors.push(color.x)
  colors.push(color.y)
  colors.push(color.z)
  uvs.push(u)
  uvs.push(v)
}

///|
fn push_quad(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x0 : Double,
  y0 : Double,
  z0 : Double,
  x1 : Double,
  y1 : Double,
  z1 : Double,
  x2 : Double,
  y2 : Double,
  z2 : Double,
  x3 : Double,
  y3 : Double,
  z3 : Double,
  color : Vec3,
  u0 : Double,
  v0 : Double,
  u1 : Double,
  v1 : Double,
) -> Unit {
  push_vertex_uv(positions, colors, uvs, x0, y0, z0, color, u0, v0)
  push_vertex_uv(positions, colors, uvs, x1, y1, z1, color, u1, v0)
  push_vertex_uv(positions, colors, uvs, x2, y2, z2, color, u1, v1)
  push_vertex_uv(positions, colors, uvs, x0, y0, z0, color, u0, v0)
  push_vertex_uv(positions, colors, uvs, x2, y2, z2, color, u1, v1)
  push_vertex_uv(positions, colors, uvs, x3, y3, z3, color, u0, v1)
}

///|
fn tile_uv(tile_x : Int, tile_y : Int) -> (Double, Double, Double, Double) {
  let cols = 4.0
  let rows = 4.0
  let du = 1.0 / cols
  let dv = 1.0 / rows
  let u0 = tile_x.to_double() * du
  let v1 = 1.0 - tile_y.to_double() * dv
  let v0 = v1 - dv
  (u0, v0, u0 + du, v1)
}

///|
fn append_face_east(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  let c = block_tint(block, 0)
  let (tx, ty) = tile_for_face(block, 0)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  let x0 = x.to_double() + 1.0
  let y0 = y.to_double()
  let y1 = y.to_double() + 1.0
  let z0 = z.to_double()
  let z1 = z.to_double() + 1.0
  push_quad(
    positions, colors, uvs, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, c, u0,
    v0, u1, v1,
  )
}

///|
fn append_face_west(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  let c = block_tint(block, 1)
  let (tx, ty) = tile_for_face(block, 1)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  let x0 = x.to_double()
  let y0 = y.to_double()
  let y1 = y.to_double() + 1.0
  let z0 = z.to_double()
  let z1 = z.to_double() + 1.0
  push_quad(
    positions, colors, uvs, x0, y0, z1, x0, y0, z0, x0, y1, z0, x0, y1, z1, c, u0,
    v0, u1, v1,
  )
}

///|
fn append_face_up(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  let c = block_tint(block, 2)
  let (tx, ty) = tile_for_face(block, 2)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  let x0 = x.to_double()
  let x1 = x.to_double() + 1.0
  let y1 = y.to_double() + 1.0
  let z0 = z.to_double()
  let z1 = z.to_double() + 1.0
  push_quad(
    positions, colors, uvs, x0, y1, z0, x0, y1, z1, x1, y1, z1, x1, y1, z0, c, u0,
    v0, u1, v1,
  )
}

///|
fn append_face_up_rect(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x0 : Double,
  x1 : Double,
  z0 : Double,
  z1 : Double,
  y : Double,
  block : Block,
) -> Unit {
  let c = block_tint(block, 2)
  let (tx, ty) = tile_for_face(block, 2)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  push_quad(
    positions, colors, uvs, x0, y, z0, x0, y, z1, x1, y, z1, x1, y, z0, c, u0, v0,
    u1, v1,
  )
}

///|
fn append_face_down(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  let c = block_tint(block, 3)
  let (tx, ty) = tile_for_face(block, 3)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  let x0 = x.to_double()
  let x1 = x.to_double() + 1.0
  let y0 = y.to_double()
  let z0 = z.to_double()
  let z1 = z.to_double() + 1.0
  push_quad(
    positions, colors, uvs, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, c, u0,
    v0, u1, v1,
  )
}

///|
fn append_face_south(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  let c = block_tint(block, 4)
  let (tx, ty) = tile_for_face(block, 4)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  let x0 = x.to_double()
  let x1 = x.to_double() + 1.0
  let y0 = y.to_double()
  let y1 = y.to_double() + 1.0
  let z1 = z.to_double() + 1.0
  push_quad(
    positions, colors, uvs, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, c, u0,
    v0, u1, v1,
  )
}

///|
fn append_face_north(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  let c = block_tint(block, 5)
  let (tx, ty) = tile_for_face(block, 5)
  let (u0, v0, u1, v1) = tile_uv(tx, ty)
  let x0 = x.to_double()
  let x1 = x.to_double() + 1.0
  let y0 = y.to_double()
  let y1 = y.to_double() + 1.0
  let z0 = z.to_double()
  push_quad(
    positions, colors, uvs, x1, y0, z0, x0, y0, z0, x0, y1, z0, x1, y1, z0, c, u0,
    v0, u1, v1,
  )
}
