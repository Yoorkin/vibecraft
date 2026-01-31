///|
priv struct Camera {
  mut position : Vec3
  mut yaw : Double
  mut pitch : Double
  mut vel_y : Double
}

///|
priv struct Game {
  renderer : Renderer
  world : World
  chunk_size : Int
  view_distance : Int
  mut current_cx : Int
  mut current_cz : Int
  mut visible_index : @hashmap.HashMap[String, Int]
  mut slot_coords : Array[(Int, Int)]
  mut dirty_chunks : Array[(Int, Int)]
  mut chunk_queue : Array[(Int, Int)]
  mut chunk_queue_cursor : Int
  mut queued_index : @hashmap.HashMap[String, Bool]
  chunk_build_budget : Int
  mut initial_loading : Bool
  mut initial_total : Int
  mut initial_built : Int
  camera : Camera
  mut player_height : Double
  mut last_time : Double
  mut last_w_down : Bool
  mut last_w_tap : Double
  mut sprint_latch : Bool
  mut selected_block : Block
  mut selected_slot : Int
  mut particles : Array[Particle]
  mut rng_state : Int
}

///|
priv struct Particle {
  position : Vec3
  velocity : Vec3
  life : Double
  size : Double
  color : Vec3
  tile_x : Int
  tile_y : Int
}

///|
fn find_spawn(world : World) -> Vec3 {
  let sea = world.sea_level
  let max_radius = 256
  let mut best_x = 0
  let mut best_z = 0
  let mut best_h = -9999
  for r = 0; r <= max_radius; r = r + 1 {
    let start = -r
    let end = r
    for z = start; z <= end; z = z + 1 {
      for x = start; x <= end; x = x + 1 {
        let h = world.height_at(x, z)
        if h > best_h {
          best_h = h
          best_x = x
          best_z = z
        }
        if h > sea + 1 {
          let y = h.to_double() + 2.0
          return vec3(x.to_double(), y, z.to_double())
        }
      }
    }
  }
  let safe_h = if best_h > sea + 1 { best_h } else { sea + 2 }
  vec3(best_x.to_double(), safe_h.to_double() + 2.0, best_z.to_double())
}

///|
fn init_game() -> Unit {
  let canvas = dom_create_canvas()
  input_init(canvas)
  let renderer = renderer_init(canvas)
  let world = World::new(96, 16)
  let chunk_size = 16
  let view_distance = 10
  let visible_capacity = (2 * view_distance + 1) * (2 * view_distance + 1) * 2 +
    1
  let spawn_pos = find_spawn(world)
  let spawn_x = spawn_pos.x.floor().to_int()
  let spawn_z = spawn_pos.z.floor().to_int()
  let camera = { position: spawn_pos, yaw: -1.2, pitch: -0.4, vel_y: 0.0 }
  let current_cx = div_floor(spawn_x, chunk_size)
  let current_cz = div_floor(spawn_z, chunk_size)
  let game = {
    renderer,
    world,
    chunk_size,
    view_distance,
    current_cx,
    current_cz,
    visible_index: @hashmap.new(capacity=visible_capacity),
    slot_coords: [],
    dirty_chunks: [],
    chunk_queue: [],
    chunk_queue_cursor: 0,
    queued_index: @hashmap.new(capacity=visible_capacity),
    chunk_build_budget: 4,
    initial_loading: true,
    initial_total: 0,
    initial_built: 0,
    camera,
    player_height: standing_height(),
    last_time: dom_now_ms(),
    last_w_down: false,
    last_w_tap: 0.0,
    sprint_latch: false,
    selected_block: Block::Dirt,
    selected_slot: 1,
    particles: [],
    rng_state: 1337,
  }
  refresh_visible_chunks(game)
  dom_set_hotbar(game.selected_slot)
  ignore(dom_request_animation_frame(t => game_frame(game, t)))
}

///|
fn game_frame(game : Game, time : Double) -> Unit {
  let raw_dt = (time - game.last_time) / 1000.0
  let dt = clamp(raw_dt, 0.0, 0.05)
  game.last_time = time
  let dims = dom_resize_canvas(game.renderer.canvas)
  game.renderer.resize(dims[0], dims[1])
  update_camera(game, dt, time)
  update_hotbar(game)
  handle_block_edit(game)
  update_particles(game, dt)
  upload_particles(game)
  process_chunk_queue(game)
  flush_dirty_chunks(game)
  let aspect = if game.renderer.height > 0 {
    game.renderer.width.to_double() / game.renderer.height.to_double()
  } else {
    1.0
  }
  let far_plane = (game.view_distance * game.chunk_size).to_double() * 3.0
  let projection = mat4_perspective(1.0, aspect, 0.1, far_plane)
  let front = camera_front(game.camera)
  let view = mat4_look_at(
    game.camera.position,
    game.camera.position.add(front),
    vec3(0.0, 1.0, 0.0),
  )
  let vp = mat4_mul(projection, view)
  let underwater = player_eye_in_water(game.world, game.camera.position)
  let tint = if underwater {
    vec3(0.08, 0.2, 0.35)
  } else {
    vec3(0.0, 0.0, 0.0)
  }
  let tint_strength = if underwater { 0.45 } else { 0.0 }
  game.renderer.draw(vp, tint, tint_strength)
  ignore(dom_request_animation_frame(t => game_frame(game, t)))
}

///|
fn update_camera(game : Game, dt : Double, now : Double) -> Unit {
  let sensitivity = 0.002
  let dx = input_mouse_dx()
  let dy = input_mouse_dy()
  game.camera.yaw = game.camera.yaw + dx * sensitivity
  game.camera.pitch = clamp(game.camera.pitch - dy * sensitivity, -1.55, 1.55)
  let mut direction = vec3(0.0, 0.0, 0.0)
  let yaw = game.camera.yaw
  let forward_flat = vec3(@math.cos(yaw), 0.0, @math.sin(yaw)).normalize()
  let right = forward_flat.cross(vec3(0.0, 1.0, 0.0)).normalize()
  let w_down = input_key("KeyW")
  if w_down {
    direction = direction.add(forward_flat)
  }
  if input_key("KeyS") {
    direction = direction.sub(forward_flat)
  }
  if input_key("KeyA") {
    direction = direction.sub(right)
  }
  if input_key("KeyD") {
    direction = direction.add(right)
  }
  if w_down && !game.last_w_down {
    if now - game.last_w_tap < 260.0 {
      game.sprint_latch = true
    }
    game.last_w_tap = now
  }
  if !w_down {
    game.sprint_latch = false
  }
  game.last_w_down = w_down
  let mut pos = game.camera.position
  let sneaking = input_key("ShiftLeft") || input_key("ShiftRight")
  let sprinting = !sneaking &&
    (input_key("ControlLeft") || input_key("ControlRight") || game.sprint_latch)
  let target_height = if sneaking {
    sneaking_height()
  } else {
    standing_height()
  }
  if target_height != game.player_height {
    let delta = game.player_height - target_height
    let candidate = vec3(pos.x, pos.y - delta, pos.z)
    if position_free(game.world, candidate, target_height) {
      pos = candidate
      game.player_height = target_height
    }
  }
  let mut on_ground = player_on_ground(game.world, pos, game.player_height)
  let mut in_water = player_in_water(game.world, pos, game.player_height)
  if direction.length() > 0.0 {
    let base_speed = 5.2
    let sprint_speed = 7.6
    let sneak_speed = 2.6
    let water_speed = 2.8
    let speed = if sneaking {
      sneak_speed
    } else if sprinting {
      sprint_speed
    } else if in_water {
      water_speed
    } else {
      base_speed
    }
    let air_control = if on_ground { 1.0 } else { 0.7 }
    let velocity = direction.normalize().mul(speed * air_control * dt)
    let next_x = vec3(pos.x + velocity.x, pos.y, pos.z)
    if position_free(game.world, next_x, game.player_height) {
      if !sneaking ||
        !on_ground ||
        player_on_ground(game.world, next_x, game.player_height) {
        pos = next_x
      }
    }
    let next_z = vec3(pos.x, pos.y, pos.z + velocity.z)
    if position_free(game.world, next_z, game.player_height) {
      if !sneaking ||
        !on_ground ||
        player_on_ground(game.world, next_z, game.player_height) {
        pos = next_z
      }
    }
  }
  on_ground = player_on_ground(game.world, pos, game.player_height)
  in_water = player_in_water(game.world, pos, game.player_height)
  if on_ground && game.camera.vel_y < 0.0 {
    game.camera.vel_y = 0.0
  }
  if in_water {
    let gravity = 6.0
    let swim_speed = 3.0
    if input_key("Space") {
      game.camera.vel_y = swim_speed
    } else if sneaking {
      game.camera.vel_y = -swim_speed
    } else {
      game.camera.vel_y = game.camera.vel_y - gravity * dt
    }
    game.camera.vel_y = game.camera.vel_y * 0.85
    if game.camera.vel_y < -3.0 {
      game.camera.vel_y = -3.0
    }
  } else {
    let gravity = 24.0
    let jump_speed = 8.0
    if on_ground && input_key("Space") {
      game.camera.vel_y = jump_speed
      on_ground = false
    } else if !on_ground {
      let mut g = gravity
      if game.camera.vel_y > 0.0 && !input_key("Space") {
        g = gravity * 1.6
      }
      game.camera.vel_y = game.camera.vel_y - g * dt
    }
  }
  let next_y = vec3(pos.x, pos.y + game.camera.vel_y * dt, pos.z)
  if position_free(game.world, next_y, game.player_height) {
    pos = next_y
  } else {
    if game.camera.vel_y < 0.0 {
      let mut probe = pos
      let step = -0.05
      let mut candidate = vec3(probe.x, probe.y + step, probe.z)
      while position_free(game.world, candidate, game.player_height) {
        probe = candidate
        candidate = vec3(probe.x, probe.y + step, probe.z)
      }
      pos = probe
      on_ground = true
    }
    game.camera.vel_y = 0.0
  }
  game.camera.position = clamp_position(game.world, pos, game.player_height)
  let block_x = game.camera.position.x.floor().to_int()
  let block_z = game.camera.position.z.floor().to_int()
  let cx = div_floor(block_x, game.chunk_size)
  let cz = div_floor(block_z, game.chunk_size)
  if cx != game.current_cx || cz != game.current_cz {
    game.current_cx = cx
    game.current_cz = cz
    refresh_visible_chunks(game)
  }
}

///|
fn handle_block_edit(game : Game) -> Unit {
  let max_dist = 8.0
  let origin = game.camera.position
  let dir = camera_front(game.camera)
  let hit_place = raycast(game.world, origin, dir, max_dist)
  let hit_break = raycast_solid(game.world, origin, dir, max_dist)
  match hit_break {
    Some(hit) =>
      if input_consume_click(0) {
        let broken = game.world.get(hit.x, hit.y, hit.z)
        if !block_is_replaceable(broken) {
          if game.world.set(hit.x, hit.y, hit.z, Block::Air) {
            mark_block_dirty(game, hit.x, hit.z)
            spawn_break_particles(game, hit.x, hit.y, hit.z, broken)
          }
        }
      }
    None => ()
  }
  match hit_place {
    Some(hit) =>
      if input_consume_click(2) {
        let target = game.world.get(hit.x, hit.y, hit.z)
        let place_x = if block_is_replaceable(target) {
          hit.x
        } else {
          hit.prev_x
        }
        let place_y = if block_is_replaceable(target) {
          hit.y
        } else {
          hit.prev_y
        }
        let place_z = if block_is_replaceable(target) {
          hit.z
        } else {
          hit.prev_z
        }
        if block_is_replaceable(game.world.get(place_x, place_y, place_z)) &&
          !block_overlaps_player(
            game.camera,
            place_x,
            place_y,
            place_z,
            game.player_height,
          ) {
          if game.world.set(place_x, place_y, place_z, game.selected_block) {
            mark_block_dirty(game, place_x, place_z)
          }
        }
      }
    None => ()
  }
}

///|
fn update_hotbar(game : Game) -> Unit {
  if input_key("Digit1") {
    set_hotbar(game, 0, Block::Grass)
  }
  if input_key("Digit2") {
    set_hotbar(game, 1, Block::Dirt)
  }
  if input_key("Digit3") {
    set_hotbar(game, 2, Block::Stone)
  }
  if input_key("Digit4") {
    set_hotbar(game, 3, Block::Sand)
  }
  if input_key("Digit5") {
    set_hotbar(game, 4, Block::Wood)
  }
  if input_key("Digit6") {
    set_hotbar(game, 5, Block::Brick)
  }
  if input_key("Digit7") {
    set_hotbar(game, 6, Block::Planks)
  }
  if input_key("Digit8") {
    set_hotbar(game, 7, Block::Leaves)
  }
  if input_key("Digit9") {
    set_hotbar(game, 8, Block::Cobblestone)
  }
  if input_key("Digit0") {
    set_hotbar(game, 9, Block::Gravel)
  }
  if input_key("Minus") {
    set_hotbar(game, 10, Block::Clay)
  }
  if input_key("Equal") {
    set_hotbar(game, 11, Block::Snow)
  }
}

///|
fn rand_next(game : Game) -> Double {
  let mut state = game.rng_state
  state = state * 1103515245 + 12345
  game.rng_state = state
  let v = (state >> 1) & 0x7fffffff
  v.to_double() / 2147483647.0
}

///|
fn spawn_break_particles(
  game : Game,
  x : Int,
  y : Int,
  z : Int,
  block : Block,
) -> Unit {
  if block_is_air(block) {
    return
  }
  let (tx, ty) = particle_tile(block)
  let base_color = block_particle_color(block)
  let origin = vec3(
    x.to_double() + 0.5,
    y.to_double() + 0.5,
    z.to_double() + 0.5,
  )
  for i = 0; i < 18; i = i + 1 {
    let rx = rand_next(game) * 2.0 - 1.0
    let ry = rand_next(game) * 1.2
    let rz = rand_next(game) * 2.0 - 1.0
    let velocity = vec3(rx, ry + 0.6, rz).mul(3.0)
    let life = 0.6 + rand_next(game) * 0.4
    let size = 0.08 + rand_next(game) * 0.05
    game.particles.push({
      position: origin,
      velocity,
      life,
      size,
      color: base_color,
      tile_x: tx,
      tile_y: ty,
    })
  }
}

///|
fn update_particles(game : Game, dt : Double) -> Unit {
  if game.particles.length() == 0 {
    return
  }
  let alive : Array[Particle] = []
  for i = 0; i < game.particles.length(); i = i + 1 {
    let p = game.particles[i]
    let velocity = p.velocity.add(vec3(0.0, -12.0 * dt, 0.0))
    let position = p.position.add(velocity.mul(dt))
    let life = p.life - dt
    if life > 0.0 {
      alive.push({
        position,
        velocity,
        life,
        size: p.size,
        color: p.color,
        tile_x: p.tile_x,
        tile_y: p.tile_y,
      })
    }
  }
  game.particles = alive
}

///|
fn upload_particles(game : Game) -> Unit {
  if game.particles.length() == 0 {
    game.renderer.clear_particles()
    return
  }
  let front = camera_front(game.camera)
  let right = front.cross(vec3(0.0, 1.0, 0.0)).normalize()
  let up = right.cross(front).normalize()
  let positions : Array[Double] = []
  let colors : Array[Double] = []
  let uvs : Array[Double] = []
  for i = 0; i < game.particles.length(); i = i + 1 {
    let p = game.particles[i]
    let r = right.mul(p.size)
    let u = up.mul(p.size)
    let c = p.position
    let p0 = c.sub(r).sub(u)
    let p1 = c.add(r).sub(u)
    let p2 = c.add(r).add(u)
    let p3 = c.sub(r).add(u)
    let (u0, v0, u1, v1) = particle_uv(p.tile_x, p.tile_y)
    push_particle_quad(
      positions,
      colors,
      uvs,
      p0,
      p1,
      p2,
      p3,
      p.color,
      u0,
      v0,
      u1,
      v1,
    )
  }
  let mesh = { positions, colors, uvs, vertex_count: positions.length() / 3 }
  game.renderer.upload_particles(mesh)
}

///|
fn push_particle_quad(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  p0 : Vec3,
  p1 : Vec3,
  p2 : Vec3,
  p3 : Vec3,
  color : Vec3,
  u0 : Double,
  v0 : Double,
  u1 : Double,
  v1 : Double,
) -> Unit {
  push_particle_vertex(positions, colors, uvs, p0, color, u0, v0)
  push_particle_vertex(positions, colors, uvs, p1, color, u1, v0)
  push_particle_vertex(positions, colors, uvs, p2, color, u1, v1)
  push_particle_vertex(positions, colors, uvs, p0, color, u0, v0)
  push_particle_vertex(positions, colors, uvs, p2, color, u1, v1)
  push_particle_vertex(positions, colors, uvs, p3, color, u0, v1)
}

///|
fn push_particle_vertex(
  positions : Array[Double],
  colors : Array[Double],
  uvs : Array[Double],
  p : Vec3,
  color : Vec3,
  u : Double,
  v : Double,
) -> Unit {
  positions.push(p.x)
  positions.push(p.y)
  positions.push(p.z)
  colors.push(color.x)
  colors.push(color.y)
  colors.push(color.z)
  uvs.push(u)
  uvs.push(v)
}

///|
fn particle_uv(tile_x : Int, tile_y : Int) -> (Double, Double, Double, Double) {
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
fn particle_tile(block : Block) -> (Int, Int) {
  match block {
    Block::Grass => (0, 0)
    Block::Dirt => (2, 0)
    Block::Stone => (3, 0)
    Block::Sand => (0, 1)
    Block::Water => (1, 1)
    Block::Wood => (2, 1)
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
fn block_particle_color(block : Block) -> Vec3 {
  match block {
    Block::Grass => vec3(0.8, 1.0, 0.8)
    Block::Dirt => vec3(0.9, 0.75, 0.6)
    Block::Stone => vec3(0.9, 0.9, 0.9)
    Block::Sand => vec3(1.0, 0.95, 0.8)
    Block::Water => vec3(0.8, 0.9, 1.0)
    Block::Wood => vec3(0.9, 0.8, 0.6)
    Block::Leaves => vec3(0.8, 1.0, 0.8)
    Block::Bedrock => vec3(0.7, 0.7, 0.7)
    Block::Planks => vec3(1.0, 0.9, 0.75)
    Block::Brick => vec3(1.0, 0.75, 0.75)
    Block::Cobblestone => vec3(0.85, 0.85, 0.85)
    Block::Gravel => vec3(0.8, 0.78, 0.75)
    Block::Clay => vec3(0.85, 0.88, 0.95)
    Block::Snow => vec3(0.95, 0.97, 1.0)
    Block::Air => vec3(1.0, 1.0, 1.0)
  }
}

///|
fn set_hotbar(game : Game, slot : Int, block : Block) -> Unit {
  if game.selected_slot != slot {
    game.selected_slot = slot
    game.selected_block = block
    dom_set_hotbar(slot)
  }
}

///|

///|
fn visible_coords_ring(cx : Int, cz : Int, dist : Int) -> Array[(Int, Int)] {
  let coords : Array[(Int, Int)] = []
  coords.push((cx, cz))
  for r = 1; r <= dist; r = r + 1 {
    let x0 = cx - r
    let x1 = cx + r
    let z0 = cz - r
    let z1 = cz + r
    for x = x0; x <= x1; x = x + 1 {
      coords.push((x, z0))
      coords.push((x, z1))
    }
    if z1 - z0 > 1 {
      for z = z0 + 1; z <= z1 - 1; z = z + 1 {
        coords.push((x0, z))
        coords.push((x1, z))
      }
    }
  }
  coords
}

///|
fn empty_mesh() -> Mesh {
  { positions: [], colors: [], uvs: [], vertex_count: 0 }
}

///|
fn empty_chunk_mesh() -> ChunkMesh {
  { solid: empty_mesh(), cutout: empty_mesh(), trans: empty_mesh() }
}

///|
fn enqueue_chunk(game : Game, cx : Int, cz : Int) -> Unit {
  let key = chunk_key(cx, cz)
  match game.queued_index.get(key) {
    Some(_) => ()
    None => {
      game.queued_index.set(key, true)
      game.chunk_queue.push((cx, cz))
    }
  }
}

///|
fn process_chunk_queue(game : Game) -> Unit {
  let mut built = 0
  let budget = game.chunk_build_budget
  while built < budget && game.chunk_queue_cursor < game.chunk_queue.length() {
    let (cx, cz) = game.chunk_queue[game.chunk_queue_cursor]
    game.chunk_queue_cursor = game.chunk_queue_cursor + 1
    let key = chunk_key(cx, cz)
    match game.visible_index.get(key) {
      Some(idx) => {
        let mesh = build_chunk_mesh(game.world, cx, cz, game.chunk_size)
        game.renderer.update_chunk(idx, mesh)
      }
      None => ()
    }
    game.queued_index.remove(key)
    if game.initial_loading {
      game.initial_built = game.initial_built + 1
      if game.initial_total > 0 {
        let progress = game.initial_built.to_double() /
          game.initial_total.to_double()
        if progress >= 1.0 {
          game.initial_loading = false
          dom_set_loading(1.0)
        } else {
          dom_set_loading(progress)
        }
      } else {
        game.initial_loading = false
        dom_set_loading(1.0)
      }
    }
    built = built + 1
  }
  if game.chunk_queue_cursor >= game.chunk_queue.length() {
    game.chunk_queue = []
    game.chunk_queue_cursor = 0
    game.queued_index = @hashmap.new(
      capacity=game.visible_index.length() * 2 + 1,
    )
  }
}

///|
fn refresh_visible_chunks(game : Game) -> Unit {
  let coords = visible_coords_ring(
    game.current_cx,
    game.current_cz,
    game.view_distance,
  )
  if game.slot_coords.length() == 0 {
    let meshes : Array[ChunkMesh] = []
    for i = 0; i < coords.length(); i = i + 1 {
      meshes.push(empty_chunk_mesh())
    }
    game.renderer.upload_chunk_meshes(meshes)
    game.visible_index = @hashmap.new(capacity=coords.length() * 2 + 1)
    for i = 0; i < coords.length(); i = i + 1 {
      let (cx, cz) = coords[i]
      let key = chunk_key(cx, cz)
      game.visible_index.set(key, i)
    }
    game.slot_coords = coords
    game.dirty_chunks = []
    game.chunk_queue = []
    game.chunk_queue_cursor = 0
    game.queued_index = @hashmap.new(capacity=coords.length() * 2 + 1)
    game.initial_loading = true
    game.initial_total = coords.length()
    game.initial_built = 0
    dom_set_loading(0.0)
    for i = 0; i < coords.length(); i = i + 1 {
      let (cx, cz) = coords[i]
      enqueue_chunk(game, cx, cz)
    }
    return
  }
  let visible_set = @hashmap.new(capacity=coords.length() * 2 + 1)
  for i = 0; i < coords.length(); i = i + 1 {
    let (cx, cz) = coords[i]
    visible_set.set(chunk_key(cx, cz), true)
  }
  let pending_queue : Array[(Int, Int)] = []
  for i = game.chunk_queue_cursor; i < game.chunk_queue.length(); i = i + 1 {
    let (cx, cz) = game.chunk_queue[i]
    let key = chunk_key(cx, cz)
    if visible_set.contains(key) {
      pending_queue.push((cx, cz))
    }
  }
  game.chunk_queue = pending_queue
  game.chunk_queue_cursor = 0
  game.queued_index = @hashmap.new(capacity=coords.length() * 2 + 1)
  for i = 0; i < game.chunk_queue.length(); i = i + 1 {
    let (cx, cz) = game.chunk_queue[i]
    game.queued_index.set(chunk_key(cx, cz), true)
  }
  let next_index = @hashmap.new(capacity=coords.length() * 2 + 1)
  let used = Array::make(game.slot_coords.length(), false)
  let pending : Array[(Int, Int)] = []
  for i = 0; i < coords.length(); i = i + 1 {
    let (cx, cz) = coords[i]
    let key = chunk_key(cx, cz)
    match game.visible_index.get(key) {
      Some(idx) => {
        next_index.set(key, idx)
        used[idx] = true
      }
      None => pending.push((cx, cz))
    }
  }
  let free_slots : Array[Int] = []
  for i = 0; i < used.length(); i = i + 1 {
    if !used[i] {
      free_slots.push(i)
    }
  }
  let mut cursor = 0
  for i = 0; i < pending.length(); i = i + 1 {
    if cursor >= free_slots.length() {
      break
    }
    let idx = free_slots[cursor]
    cursor = cursor + 1
    let (cx, cz) = pending[i]
    game.renderer.update_chunk(idx, empty_chunk_mesh())
    game.slot_coords[idx] = (cx, cz)
    let key = chunk_key(cx, cz)
    next_index.set(key, idx)
    enqueue_chunk(game, cx, cz)
  }
  game.visible_index = next_index
}

///|
fn flush_dirty_chunks(game : Game) -> Unit {
  if game.dirty_chunks.length() == 0 {
    return
  }
  for i = 0; i < game.dirty_chunks.length(); i = i + 1 {
    let (cx, cz) = game.dirty_chunks[i]
    let key = chunk_key(cx, cz)
    match game.visible_index.get(key) {
      Some(idx) => {
        let mesh = build_chunk_mesh(game.world, cx, cz, game.chunk_size)
        game.renderer.update_chunk(idx, mesh)
      }
      None => ()
    }
  }
  game.dirty_chunks = []
}

///|
fn mark_block_dirty(game : Game, x : Int, z : Int) -> Unit {
  let cx = div_floor(x, game.chunk_size)
  let cz = div_floor(z, game.chunk_size)
  let lx = mod_floor(x, game.chunk_size)
  let lz = mod_floor(z, game.chunk_size)
  mark_chunk_dirty(game, cx, cz)
  if lx == 0 {
    mark_chunk_dirty(game, cx - 1, cz)
  } else if lx == game.chunk_size - 1 {
    mark_chunk_dirty(game, cx + 1, cz)
  }
  if lz == 0 {
    mark_chunk_dirty(game, cx, cz - 1)
  } else if lz == game.chunk_size - 1 {
    mark_chunk_dirty(game, cx, cz + 1)
  }
}

///|
fn mark_chunk_dirty(game : Game, cx : Int, cz : Int) -> Unit {
  for i = 0; i < game.dirty_chunks.length(); i = i + 1 {
    if game.dirty_chunks[i].0 == cx && game.dirty_chunks[i].1 == cz {
      return
    }
  }
  game.dirty_chunks.push((cx, cz))
}

///|
fn camera_front(camera : Camera) -> Vec3 {
  let cp = @math.cos(camera.pitch)
  let sp = @math.sin(camera.pitch)
  let cy = @math.cos(camera.yaw)
  let sy = @math.sin(camera.yaw)
  vec3(cp * cy, sp, cp * sy).normalize()
}

///|
fn player_radius() -> Double {
  0.3
}

///|
fn standing_height() -> Double {
  1.6
}

///|
fn sneaking_height() -> Double {
  1.2
}

///|
fn player_on_ground(world : World, pos : Vec3, height : Double) -> Bool {
  let probe = vec3(pos.x, pos.y - 0.05, pos.z)
  !position_free(world, probe, height)
}

///|
fn player_in_water(world : World, pos : Vec3, height : Double) -> Bool {
  let radius = player_radius()
  let ix0 = (pos.x - radius).floor().to_int()
  let ix1 = (pos.x + radius).floor().to_int()
  let iz0 = (pos.z - radius).floor().to_int()
  let iz1 = (pos.z + radius).floor().to_int()
  let iy0 = (pos.y - height).floor().to_int()
  let iy1 = pos.y.floor().to_int()
  let mut y = iy0
  while y <= iy1 {
    if block_is_water(world.get(ix0, y, iz0)) ||
      block_is_water(world.get(ix0, y, iz1)) ||
      block_is_water(world.get(ix1, y, iz0)) ||
      block_is_water(world.get(ix1, y, iz1)) {
      return true
    }
    y = y + 1
  }
  false
}

///|
fn player_eye_in_water(world : World, pos : Vec3) -> Bool {
  let ix = pos.x.floor().to_int()
  let iz = pos.z.floor().to_int()
  let iy = pos.y.floor().to_int()
  block_is_water(world.get(ix, iy, iz))
}

///|
fn position_free(world : World, pos : Vec3, height : Double) -> Bool {
  let radius = player_radius()
  let ix0 = (pos.x - radius).floor().to_int()
  let ix1 = (pos.x + radius).floor().to_int()
  let iz0 = (pos.z - radius).floor().to_int()
  let iz1 = (pos.z + radius).floor().to_int()
  let iy0 = (pos.y - height).floor().to_int()
  let iy1 = pos.y.floor().to_int()
  let mut y = iy0
  while y <= iy1 {
    let layer_ok = !block_is_solid(world.get(ix0, y, iz0)) &&
      !block_is_solid(world.get(ix0, y, iz1)) &&
      !block_is_solid(world.get(ix1, y, iz0)) &&
      !block_is_solid(world.get(ix1, y, iz1))
    if !layer_ok {
      return false
    }
    y = y + 1
  }
  true
}

///|
fn clamp_position(world : World, pos : Vec3, height : Double) -> Vec3 {
  let min_y = height
  let max_y = (world.height - 1).to_double() + 0.8
  vec3(pos.x, clamp(pos.y, min_y, max_y), pos.z)
}

///|
fn block_overlaps_player(
  camera : Camera,
  x : Int,
  y : Int,
  z : Int,
  height : Double,
) -> Bool {
  let radius = player_radius()
  let min_x = camera.position.x - radius
  let max_x = camera.position.x + radius
  let min_y = camera.position.y - height
  let max_y = camera.position.y
  let min_z = camera.position.z - radius
  let max_z = camera.position.z + radius
  let bx0 = x.to_double()
  let by0 = y.to_double()
  let bz0 = z.to_double()
  let bx1 = bx0 + 1.0
  let by1 = by0 + 1.0
  let bz1 = bz0 + 1.0
  !(max_x <= bx0 ||
  min_x >= bx1 ||
  max_y <= by0 ||
  min_y >= by1 ||
  max_z <= bz0 ||
  min_z >= bz1)
}
