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
  mut chunk_queue_surface : Array[(Int, Int)]
  mut chunk_queue_surface_cursor : Int
  mut queued_surface : @hashmap.HashMap[String, Bool]
  mut chunk_queue_detail : Array[(Int, Int)]
  mut chunk_queue_detail_cursor : Int
  mut queued_detail : @hashmap.HashMap[String, Bool]
  chunk_build_budget : Int
  chunk_time_budget_ms : Double
  mut initial_loading : Bool
  mut initial_total : Int
  mut initial_built : Int
  detail_distance : Int
  camera : Camera
  mut player_height : Double
  mut last_time : Double
  mut last_w_down : Bool
  mut last_w_tap : Double
  mut sprint_latch : Bool
  mut selected_block : Block
  mut selected_slot : Int
  mut slot_detail : Array[Bool]
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
  let random_radius = 4096.0
  let tries = 4000
  for i = 0; i < tries; i = i + 1 {
    let rx = (hash2(i * 37 + 11, i * 17 - 5) * 2.0 - 1.0) * random_radius
    let rz = (hash2(i * 29 - 23, i * 41 + 9) * 2.0 - 1.0) * random_radius
    let x = rx.floor().to_int()
    let z = rz.floor().to_int()
    let h = world.height_at(x, z)
    if h > sea + 1 {
      let y = h.to_double() + 2.0
      return vec3(x.to_double(), y, z.to_double())
    }
  }
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
fn random_spawn(game : Game) -> Vec3 {
  let sea = game.world.sea_level
  let radius = 768.0
  let tries = 200
  for i = 0; i < tries; i = i + 1 {
    let rx = (rand_next(game) * 2.0 - 1.0) * radius
    let rz = (rand_next(game) * 2.0 - 1.0) * radius
    let x = rx.floor().to_int()
    let z = rz.floor().to_int()
    let h = game.world.height_at(x, z)
    if h > sea + 1 {
      let pos = vec3(
        x.to_double() + 0.5,
        h.to_double() + 2.0,
        z.to_double() + 0.5,
      )
      if position_free(game.world, pos, standing_height()) {
        return pos
      }
    }
  }
  find_spawn(game.world)
}

///|
fn init_game() -> Unit {
  let canvas = dom_create_canvas()
  input_init(canvas)
  dom_init_fly_toggle()
  dom_init_random_teleport()
  dom_init_command_input()
  let renderer = renderer_init(canvas)
  let world = World::new(2000, 16, 32)
  let chunk_size = 16
  let view_distance = 20
  let detail_distance = if view_distance > 6 {
    view_distance / 2
  } else {
    view_distance
  }
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
    chunk_queue_surface: [],
    chunk_queue_surface_cursor: 0,
    queued_surface: @hashmap.new(capacity=visible_capacity),
    chunk_queue_detail: [],
    chunk_queue_detail_cursor: 0,
    queued_detail: @hashmap.new(capacity=visible_capacity),
    chunk_build_budget: 2,
    chunk_time_budget_ms: 5.0,
    initial_loading: true,
    initial_total: 0,
    initial_built: 0,
    detail_distance,
    camera,
    player_height: standing_height(),
    last_time: dom_now_ms(),
    last_w_down: false,
    last_w_tap: 0.0,
    sprint_latch: false,
    selected_block: Block::Dirt,
    selected_slot: 1,
    slot_detail: [],
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
  let fly_mode = input_fly_enabled()
  let fly_speed_mul = 3.0
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
  let cmd = input_consume_command()
  if cmd.length() > 0 {
    let code = cmd[0]
    if code == 1 && cmd.length() >= 4 {
      let x = cmd[1]
      let y = cmd[2]
      let z = cmd[3]
      pos = vec3(x.to_double() + 0.5, y.to_double() + 2.0, z.to_double() + 0.5)
      game.camera.vel_y = 0.0
      game.player_height = standing_height()
    } else if code == 2 && cmd.length() >= 3 {
      let x = cmd[1]
      let z = cmd[2]
      let h = game.world.height_at(x, z)
      pos = vec3(x.to_double() + 0.5, h.to_double() + 2.0, z.to_double() + 0.5)
      game.camera.vel_y = 0.0
      game.player_height = standing_height()
    } else if code == 3 && cmd.length() >= 3 {
      let yaw_deg = cmd[1]
      let pitch_deg = cmd[2]
      game.camera.yaw = yaw_deg.to_double() * @math.PI / 180.0
      game.camera.pitch = clamp(
        pitch_deg.to_double() * @math.PI / 180.0,
        -1.55,
        1.55,
      )
    }
  }
  if input_consume_teleport() {
    pos = random_spawn(game)
    game.camera.vel_y = 0.0
    game.player_height = standing_height()
  }
  let sneak_key = input_key("ShiftLeft") || input_key("ShiftRight")
  let sneaking = if fly_mode { false } else { sneak_key }
  let sprinting = !sneak_key &&
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
  if fly_mode {
    in_water = false
  }
  if direction.length() > 0.0 {
    let base_speed = if fly_mode { 11.0 * fly_speed_mul } else { 5.2 }
    let sprint_speed = if fly_mode { 17.0 * fly_speed_mul } else { 7.6 }
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
    let air_control = if fly_mode || on_ground { 1.0 } else { 0.7 }
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
  if fly_mode {
    in_water = false
  }
  if on_ground && game.camera.vel_y < 0.0 {
    game.camera.vel_y = 0.0
  }
  if fly_mode {
    let mut vertical = 0.0
    if input_key("Space") {
      vertical = vertical + 1.0
    }
    if sneak_key {
      vertical = vertical - 1.0
    }
    if vertical != 0.0 {
      let fly_speed = if sprinting { 12.0 } else { 8.5 }
      let next_y = vec3(
        pos.x,
        pos.y + vertical * fly_speed * fly_speed_mul * dt,
        pos.z,
      )
      if position_free(game.world, next_y, game.player_height) {
        pos = next_y
      }
    }
    game.camera.vel_y = 0.0
  } else if in_water {
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
fn in_detail_range(game : Game, cx : Int, cz : Int) -> Bool {
  let dx = (cx - game.current_cx).abs()
  let dz = (cz - game.current_cz).abs()
  dx <= game.detail_distance && dz <= game.detail_distance
}

///|
fn clamp_int(v : Int, min_val : Int, max_val : Int) -> Int {
  if v < min_val {
    min_val
  } else if v > max_val {
    max_val
  } else {
    v
  }
}

///|
fn detail_y_bounds(game : Game) -> (Int, Int) {
  let center = game.camera.position.y.floor().to_int()
  let range = game.world.section_height * 3
  let y0 = clamp_int(center - range, 0, game.world.height)
  let mut y1 = clamp_int(center + range, 0, game.world.height)
  if y1 <= y0 {
    y1 = clamp_int(y0 + 1, 0, game.world.height)
  }
  (y0, y1)
}

///|
fn chunk_terrain_bounds(game : Game, cx : Int, cz : Int) -> (Int, Int) {
  let mut min_h = game.world.height
  let mut max_h = 0
  let x0 = cx * game.chunk_size
  let z0 = cz * game.chunk_size
  for dz = -1; dz <= game.chunk_size; dz = dz + 1 {
    let gz = z0 + dz
    for dx = -1; dx <= game.chunk_size; dx = dx + 1 {
      let gx = x0 + dx
      let h = game.world.column_info(gx, gz).height
      if h < min_h {
        min_h = h
      }
      if h > max_h {
        max_h = h
      }
    }
  }
  if max_h < game.world.sea_level {
    max_h = game.world.sea_level
  }
  let margin = 4
  let y0 = clamp_int(min_h - margin, 0, game.world.height)
  let mut y1 = clamp_int(max_h + margin, 0, game.world.height)
  if y1 <= y0 {
    y1 = clamp_int(y0 + 1, 0, game.world.height)
  }
  (y0, y1)
}

///|
fn chunk_detail_bounds(game : Game, cx : Int, cz : Int) -> (Int, Int) {
  let (cam0, cam1) = detail_y_bounds(game)
  let (t0, t1) = chunk_terrain_bounds(game, cx, cz)
  let y0 = if t0 < cam0 { t0 } else { cam0 }
  let y1 = if t1 > cam1 { t1 } else { cam1 }
  (y0, y1)
}

///|
fn build_chunk_keep_set(
  game : Game,
  coords : Array[(Int, Int)],
) -> @hashmap.HashMap[String, Bool] {
  let cache_dist = game.detail_distance + 1
  let keep = @hashmap.new(capacity=coords.length() * 6 + 1)
  for i = 0; i < coords.length(); i = i + 1 {
    let (cx, cz) = coords[i]
    let dx = (cx - game.current_cx).abs()
    let dz = (cz - game.current_cz).abs()
    if dx <= cache_dist && dz <= cache_dist {
      let (y0, y1) = chunk_detail_bounds(game, cx, cz)
      let cy0 = div_floor(y0, game.world.section_height)
      let cy1 = div_floor(y1 - 1, game.world.section_height)
      let mut cy = cy0
      while cy <= cy1 {
        keep.set(chunk_key_3(cx, cy, cz), true)
        cy = cy + 1
      }
    }
  }
  keep
}

///|
fn build_height_keep_set(
  game : Game,
  coords : Array[(Int, Int)],
) -> @hashmap.HashMap[String, Bool] {
  let cache_dist = game.detail_distance + 1
  let keep = @hashmap.new(capacity=coords.length() + 1)
  for i = 0; i < coords.length(); i = i + 1 {
    let (cx, cz) = coords[i]
    let dx = (cx - game.current_cx).abs()
    let dz = (cz - game.current_cz).abs()
    if dx <= cache_dist && dz <= cache_dist {
      keep.set(chunk_key(cx, cz), true)
    }
  }
  keep
}

///|
fn enqueue_surface(game : Game, cx : Int, cz : Int) -> Unit {
  let key = chunk_key(cx, cz)
  match game.queued_surface.get(key) {
    Some(_) => ()
    None => {
      game.queued_surface.set(key, true)
      game.chunk_queue_surface.push((cx, cz))
    }
  }
}

///|
fn enqueue_detail(game : Game, cx : Int, cz : Int) -> Unit {
  let key = chunk_key(cx, cz)
  match game.queued_detail.get(key) {
    Some(_) => ()
    None => {
      game.queued_detail.set(key, true)
      game.chunk_queue_detail.push((cx, cz))
    }
  }
}

///|
fn process_chunk_queue(game : Game) -> Unit {
  let mut built = 0
  let budget = game.chunk_build_budget
  let start = dom_now_ms()
  while built < budget {
    let mut did_work = false
    if game.chunk_queue_surface_cursor < game.chunk_queue_surface.length() {
      let (cx, cz) = game.chunk_queue_surface[game.chunk_queue_surface_cursor]
      game.chunk_queue_surface_cursor = game.chunk_queue_surface_cursor + 1
      let key = chunk_key(cx, cz)
      match game.visible_index.get(key) {
        Some(idx) => {
          let mesh = build_chunk_surface_mesh(
            game.world,
            cx,
            cz,
            game.chunk_size,
          )
          game.renderer.update_chunk(idx, mesh)
          if idx >= 0 && idx < game.slot_detail.length() {
            game.slot_detail[idx] = false
          }
        }
        None => ()
      }
      game.queued_surface.remove(key)
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
      did_work = true
    } else if game.chunk_queue_detail_cursor < game.chunk_queue_detail.length() {
      let (cx, cz) = game.chunk_queue_detail[game.chunk_queue_detail_cursor]
      game.chunk_queue_detail_cursor = game.chunk_queue_detail_cursor + 1
      let key = chunk_key(cx, cz)
      match game.visible_index.get(key) {
        Some(idx) => {
          let (y0, y1) = chunk_detail_bounds(game, cx, cz)
          let mesh = build_chunk_mesh(
            game.world,
            cx,
            cz,
            game.chunk_size,
            y0,
            y1,
          )
          game.renderer.update_chunk(idx, mesh)
          if idx >= 0 && idx < game.slot_detail.length() {
            game.slot_detail[idx] = true
          }
        }
        None => ()
      }
      game.queued_detail.remove(key)
      did_work = true
    }
    if !did_work {
      break
    }
    built = built + 1
    if dom_now_ms() - start >= game.chunk_time_budget_ms {
      break
    }
  }
  if game.chunk_queue_surface_cursor >= game.chunk_queue_surface.length() {
    game.chunk_queue_surface = []
    game.chunk_queue_surface_cursor = 0
    game.queued_surface = @hashmap.new(
      capacity=game.visible_index.length() * 2 + 1,
    )
  }
  if game.chunk_queue_detail_cursor >= game.chunk_queue_detail.length() {
    game.chunk_queue_detail = []
    game.chunk_queue_detail_cursor = 0
    game.queued_detail = @hashmap.new(
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
    game.slot_detail = Array::make(coords.length(), false)
    game.dirty_chunks = []
    game.chunk_queue_surface = []
    game.chunk_queue_surface_cursor = 0
    game.queued_surface = @hashmap.new(capacity=coords.length() * 2 + 1)
    game.chunk_queue_detail = []
    game.chunk_queue_detail_cursor = 0
    game.queued_detail = @hashmap.new(capacity=coords.length() * 2 + 1)
    game.initial_loading = true
    game.initial_total = coords.length()
    game.initial_built = 0
    dom_set_loading(0.0)
    for i = 0; i < coords.length(); i = i + 1 {
      let (cx, cz) = coords[i]
      enqueue_surface(game, cx, cz)
      if in_detail_range(game, cx, cz) {
        enqueue_detail(game, cx, cz)
      }
    }
    let keep = build_chunk_keep_set(game, coords)
    let keep_height = build_height_keep_set(game, coords)
    game.world.prune_chunks(keep)
    game.world.prune_height_cache(keep_height)
    return
  }
  let visible_set = @hashmap.new(capacity=coords.length() * 2 + 1)
  for i = 0; i < coords.length(); i = i + 1 {
    let (cx, cz) = coords[i]
    visible_set.set(chunk_key(cx, cz), true)
  }
  let pending_surface : Array[(Int, Int)] = []
  for i = game.chunk_queue_surface_cursor
      i < game.chunk_queue_surface.length()
      i = i + 1 {
    let (cx, cz) = game.chunk_queue_surface[i]
    let key = chunk_key(cx, cz)
    if visible_set.contains(key) {
      pending_surface.push((cx, cz))
    }
  }
  game.chunk_queue_surface = pending_surface
  game.chunk_queue_surface_cursor = 0
  game.queued_surface = @hashmap.new(capacity=coords.length() * 2 + 1)
  for i = 0; i < game.chunk_queue_surface.length(); i = i + 1 {
    let (cx, cz) = game.chunk_queue_surface[i]
    game.queued_surface.set(chunk_key(cx, cz), true)
  }
  let pending_detail : Array[(Int, Int)] = []
  for i = game.chunk_queue_detail_cursor
      i < game.chunk_queue_detail.length()
      i = i + 1 {
    let (cx, cz) = game.chunk_queue_detail[i]
    let key = chunk_key(cx, cz)
    if visible_set.contains(key) {
      pending_detail.push((cx, cz))
    }
  }
  game.chunk_queue_detail = pending_detail
  game.chunk_queue_detail_cursor = 0
  game.queued_detail = @hashmap.new(capacity=coords.length() * 2 + 1)
  for i = 0; i < game.chunk_queue_detail.length(); i = i + 1 {
    let (cx, cz) = game.chunk_queue_detail[i]
    game.queued_detail.set(chunk_key(cx, cz), true)
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
    if idx >= 0 && idx < game.slot_detail.length() {
      game.slot_detail[idx] = false
    }
    let key = chunk_key(cx, cz)
    next_index.set(key, idx)
    enqueue_surface(game, cx, cz)
    if in_detail_range(game, cx, cz) {
      enqueue_detail(game, cx, cz)
    }
  }
  game.visible_index = next_index
  for i = 0; i < coords.length(); i = i + 1 {
    let (cx, cz) = coords[i]
    let key = chunk_key(cx, cz)
    match game.visible_index.get(key) {
      Some(idx) => {
        let want_detail = in_detail_range(game, cx, cz)
        if want_detail && !game.slot_detail[idx] {
          enqueue_detail(game, cx, cz)
        } else if !want_detail && game.slot_detail[idx] {
          enqueue_surface(game, cx, cz)
        }
      }
      None => ()
    }
  }
  let keep = build_chunk_keep_set(game, coords)
  let keep_height = build_height_keep_set(game, coords)
  game.world.prune_chunks(keep)
  game.world.prune_height_cache(keep_height)
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
      Some(idx) =>
        if in_detail_range(game, cx, cz) {
          let (y0, y1) = chunk_detail_bounds(game, cx, cz)
          let mesh = build_chunk_mesh(
            game.world,
            cx,
            cz,
            game.chunk_size,
            y0,
            y1,
          )
          game.renderer.update_chunk(idx, mesh)
          if idx >= 0 && idx < game.slot_detail.length() {
            game.slot_detail[idx] = true
          }
        } else {
          let mesh = build_chunk_surface_mesh(
            game.world,
            cx,
            cz,
            game.chunk_size,
          )
          game.renderer.update_chunk(idx, mesh)
          if idx >= 0 && idx < game.slot_detail.length() {
            game.slot_detail[idx] = false
          }
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
