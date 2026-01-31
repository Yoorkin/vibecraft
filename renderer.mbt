///|
priv struct Renderer {
  canvas : JsValue
  gl : WebGL
  program : WebGLProgram
  loc_pos : Int
  loc_color : Int
  loc_uv : Int
  loc_vp : WebGLUniformLocation
  loc_tex : WebGLUniformLocation
  loc_tint : WebGLUniformLocation
  loc_tint_strength : WebGLUniformLocation
  texture : WebGLTexture
  particle_buffer_pos : WebGLBuffer
  particle_buffer_color : WebGLBuffer
  particle_buffer_uv : WebGLBuffer
  mut particle_vertex_count : Int
  mut chunks : Array[RenderChunk]
  mut width : Int
  mut height : Int
}

///|
priv struct RenderChunk {
  buffer_pos : WebGLBuffer
  buffer_color : WebGLBuffer
  buffer_uv : WebGLBuffer
  vertex_count : Int
  buffer_pos_cutout : WebGLBuffer
  buffer_color_cutout : WebGLBuffer
  buffer_uv_cutout : WebGLBuffer
  vertex_count_cutout : Int
  buffer_pos_trans : WebGLBuffer
  buffer_color_trans : WebGLBuffer
  buffer_uv_trans : WebGLBuffer
  vertex_count_trans : Int
}

///|
fn renderer_init(canvas : JsValue) -> Renderer {
  let gl = gl_create_context(canvas)
  let vs = compile_shader(gl, gl_vertex_shader, vertex_shader_source())
  let fs = compile_shader(gl, gl_fragment_shader, fragment_shader_source())
  let program = link_program(gl, vs, fs)
  let loc_pos = gl_get_attrib_location(gl, program, "a_pos")
  let loc_color = gl_get_attrib_location(gl, program, "a_color")
  let loc_uv = gl_get_attrib_location(gl, program, "a_uv")
  let loc_vp = gl_get_uniform_location(gl, program, "u_vp")
  let loc_tex = gl_get_uniform_location(gl, program, "u_tex")
  let loc_tint = gl_get_uniform_location(gl, program, "u_tint")
  let loc_tint_strength = gl_get_uniform_location(
    gl, program, "u_tint_strength",
  )
  let texture = gl_create_texture(gl)
  let atlas = dom_create_atlas()
  gl_active_texture(gl, gl_texture0)
  gl_bind_texture(gl, gl_texture_2d, texture)
  gl_pixel_storei(gl, gl_unpack_flip_y_webgl, 1)
  let ok = gl_tex_image_2d_canvas(
    gl, gl_texture_2d, 0, gl_rgba, gl_rgba, gl_unsigned_byte, atlas,
  )
  if !ok {
    js_error("Failed to upload texture atlas")
  }
  gl_tex_parameteri(gl, gl_texture_2d, gl_texture_min_filter, gl_nearest)
  gl_tex_parameteri(gl, gl_texture_2d, gl_texture_mag_filter, gl_nearest)
  gl_tex_parameteri(gl, gl_texture_2d, gl_texture_wrap_s, gl_clamp_to_edge)
  gl_tex_parameteri(gl, gl_texture_2d, gl_texture_wrap_t, gl_clamp_to_edge)
  gl_enable(gl, gl_depth_test)
  gl_enable(gl, gl_blend)
  gl_blend_func(gl, gl_src_alpha, gl_one_minus_src_alpha)
  gl_clear_color(gl, 0.52, 0.75, 0.95, 1.0)
  gl_use_program(gl, program)
  gl_uniform1i(gl, loc_tex, 0)
  gl_uniform3f(gl, loc_tint, 0.0, 0.0, 0.0)
  gl_uniform1f(gl, loc_tint_strength, 0.0)
  let particle_buffer_pos = gl_create_buffer(gl)
  let particle_buffer_color = gl_create_buffer(gl)
  let particle_buffer_uv = gl_create_buffer(gl)
  {
    canvas,
    gl,
    program,
    loc_pos,
    loc_color,
    loc_uv,
    loc_vp,
    loc_tex,
    loc_tint,
    loc_tint_strength,
    texture,
    particle_buffer_pos,
    particle_buffer_color,
    particle_buffer_uv,
    particle_vertex_count: 0,
    chunks: [],
    width: 0,
    height: 0,
  }
}

///|
fn Renderer::resize(self : Renderer, width : Int, height : Int) -> Unit {
  if width != self.width || height != self.height {
    self.width = width
    self.height = height
    gl_viewport(self.gl, 0, 0, width, height)
  }
}

///|
fn Renderer::upload_chunk_meshes(
  self : Renderer,
  meshes : Array[ChunkMesh],
) -> Unit {
  self.chunks = []
  for i = 0; i < meshes.length(); i = i + 1 {
    let mesh = meshes[i]
    let solid = mesh.solid
    let cutout = mesh.cutout
    let trans = mesh.trans
    let buffer_pos = gl_create_buffer(self.gl)
    let buffer_color = gl_create_buffer(self.gl)
    let buffer_uv = gl_create_buffer(self.gl)
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_pos)
    gl_buffer_data_f32(
      self.gl,
      gl_array_buffer,
      solid.positions,
      gl_static_draw,
    )
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_color)
    gl_buffer_data_f32(self.gl, gl_array_buffer, solid.colors, gl_static_draw)
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_uv)
    gl_buffer_data_f32(self.gl, gl_array_buffer, solid.uvs, gl_static_draw)
    let buffer_pos_cutout = gl_create_buffer(self.gl)
    let buffer_color_cutout = gl_create_buffer(self.gl)
    let buffer_uv_cutout = gl_create_buffer(self.gl)
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_pos_cutout)
    gl_buffer_data_f32(
      self.gl,
      gl_array_buffer,
      cutout.positions,
      gl_static_draw,
    )
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_color_cutout)
    gl_buffer_data_f32(self.gl, gl_array_buffer, cutout.colors, gl_static_draw)
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_uv_cutout)
    gl_buffer_data_f32(self.gl, gl_array_buffer, cutout.uvs, gl_static_draw)
    let buffer_pos_trans = gl_create_buffer(self.gl)
    let buffer_color_trans = gl_create_buffer(self.gl)
    let buffer_uv_trans = gl_create_buffer(self.gl)
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_pos_trans)
    gl_buffer_data_f32(
      self.gl,
      gl_array_buffer,
      trans.positions,
      gl_static_draw,
    )
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_color_trans)
    gl_buffer_data_f32(self.gl, gl_array_buffer, trans.colors, gl_static_draw)
    gl_bind_buffer(self.gl, gl_array_buffer, buffer_uv_trans)
    gl_buffer_data_f32(self.gl, gl_array_buffer, trans.uvs, gl_static_draw)
    self.chunks.push({
      buffer_pos,
      buffer_color,
      buffer_uv,
      vertex_count: solid.vertex_count,
      buffer_pos_cutout,
      buffer_color_cutout,
      buffer_uv_cutout,
      vertex_count_cutout: cutout.vertex_count,
      buffer_pos_trans,
      buffer_color_trans,
      buffer_uv_trans,
      vertex_count_trans: trans.vertex_count,
    })
  }
}

///|
fn Renderer::update_chunk(
  self : Renderer,
  index : Int,
  mesh : ChunkMesh,
) -> Unit {
  if index < 0 || index >= self.chunks.length() {
    return
  }
  let chunk = self.chunks[index]
  let solid = mesh.solid
  let cutout = mesh.cutout
  let trans = mesh.trans
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_pos)
  gl_buffer_data_f32(self.gl, gl_array_buffer, solid.positions, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_color)
  gl_buffer_data_f32(self.gl, gl_array_buffer, solid.colors, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_uv)
  gl_buffer_data_f32(self.gl, gl_array_buffer, solid.uvs, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_pos_cutout)
  gl_buffer_data_f32(self.gl, gl_array_buffer, cutout.positions, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_color_cutout)
  gl_buffer_data_f32(self.gl, gl_array_buffer, cutout.colors, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_uv_cutout)
  gl_buffer_data_f32(self.gl, gl_array_buffer, cutout.uvs, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_pos_trans)
  gl_buffer_data_f32(self.gl, gl_array_buffer, trans.positions, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_color_trans)
  gl_buffer_data_f32(self.gl, gl_array_buffer, trans.colors, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_uv_trans)
  gl_buffer_data_f32(self.gl, gl_array_buffer, trans.uvs, gl_static_draw)
  self.chunks[index] = {
    buffer_pos: chunk.buffer_pos,
    buffer_color: chunk.buffer_color,
    buffer_uv: chunk.buffer_uv,
    vertex_count: solid.vertex_count,
    buffer_pos_cutout: chunk.buffer_pos_cutout,
    buffer_color_cutout: chunk.buffer_color_cutout,
    buffer_uv_cutout: chunk.buffer_uv_cutout,
    vertex_count_cutout: cutout.vertex_count,
    buffer_pos_trans: chunk.buffer_pos_trans,
    buffer_color_trans: chunk.buffer_color_trans,
    buffer_uv_trans: chunk.buffer_uv_trans,
    vertex_count_trans: trans.vertex_count,
  }
}

///|
fn Renderer::upload_particles(self : Renderer, mesh : Mesh) -> Unit {
  gl_bind_buffer(self.gl, gl_array_buffer, self.particle_buffer_pos)
  gl_buffer_data_f32(self.gl, gl_array_buffer, mesh.positions, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, self.particle_buffer_color)
  gl_buffer_data_f32(self.gl, gl_array_buffer, mesh.colors, gl_static_draw)
  gl_bind_buffer(self.gl, gl_array_buffer, self.particle_buffer_uv)
  gl_buffer_data_f32(self.gl, gl_array_buffer, mesh.uvs, gl_static_draw)
  self.particle_vertex_count = mesh.vertex_count
}

///|
fn Renderer::clear_particles(self : Renderer) -> Unit {
  self.particle_vertex_count = 0
}

///|
fn Renderer::draw(
  self : Renderer,
  vp : Array[Double],
  tint : Vec3,
  tint_strength : Double,
) -> Unit {
  if tint_strength > 0.0 {
    gl_clear_color(self.gl, 0.05, 0.12, 0.22, 1.0)
  } else {
    gl_clear_color(self.gl, 0.52, 0.75, 0.95, 1.0)
  }
  gl_clear(self.gl, gl_color_buffer_bit | gl_depth_buffer_bit)
  gl_use_program(self.gl, self.program)
  gl_uniform_matrix4fv(self.gl, self.loc_vp, false, vp)
  gl_active_texture(self.gl, gl_texture0)
  gl_bind_texture(self.gl, gl_texture_2d, self.texture)
  gl_uniform1i(self.gl, self.loc_tex, 0)
  gl_uniform3f(self.gl, self.loc_tint, tint.x, tint.y, tint.z)
  gl_uniform1f(self.gl, self.loc_tint_strength, tint_strength)
  gl_enable_vertex_attrib_array(self.gl, self.loc_pos)
  gl_enable_vertex_attrib_array(self.gl, self.loc_color)
  gl_enable_vertex_attrib_array(self.gl, self.loc_uv)
  gl_depth_mask(self.gl, true)
  gl_depth_func(self.gl, gl_less)
  for i = 0; i < self.chunks.length(); i = i + 1 {
    let chunk = self.chunks[i]
    if chunk.vertex_count > 0 {
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_pos)
      gl_vertex_attrib_pointer(self.gl, self.loc_pos, 3, gl_float, false, 0, 0)
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_color)
      gl_vertex_attrib_pointer(
        self.gl,
        self.loc_color,
        3,
        gl_float,
        false,
        0,
        0,
      )
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_uv)
      gl_vertex_attrib_pointer(self.gl, self.loc_uv, 2, gl_float, false, 0, 0)
      gl_draw_arrays(self.gl, gl_triangles, 0, chunk.vertex_count)
    }
  }
  for i = 0; i < self.chunks.length(); i = i + 1 {
    let chunk = self.chunks[i]
    if chunk.vertex_count_cutout > 0 {
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_pos_cutout)
      gl_vertex_attrib_pointer(self.gl, self.loc_pos, 3, gl_float, false, 0, 0)
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_color_cutout)
      gl_vertex_attrib_pointer(
        self.gl,
        self.loc_color,
        3,
        gl_float,
        false,
        0,
        0,
      )
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_uv_cutout)
      gl_vertex_attrib_pointer(self.gl, self.loc_uv, 2, gl_float, false, 0, 0)
      gl_draw_arrays(self.gl, gl_triangles, 0, chunk.vertex_count_cutout)
    }
  }
  gl_depth_mask(self.gl, false)
  gl_depth_func(self.gl, gl_lequal)
  for i = 0; i < self.chunks.length(); i = i + 1 {
    let chunk = self.chunks[i]
    if chunk.vertex_count_trans > 0 {
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_pos_trans)
      gl_vertex_attrib_pointer(self.gl, self.loc_pos, 3, gl_float, false, 0, 0)
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_color_trans)
      gl_vertex_attrib_pointer(
        self.gl,
        self.loc_color,
        3,
        gl_float,
        false,
        0,
        0,
      )
      gl_bind_buffer(self.gl, gl_array_buffer, chunk.buffer_uv_trans)
      gl_vertex_attrib_pointer(self.gl, self.loc_uv, 2, gl_float, false, 0, 0)
      gl_draw_arrays(self.gl, gl_triangles, 0, chunk.vertex_count_trans)
    }
  }
  if self.particle_vertex_count > 0 {
    gl_bind_buffer(self.gl, gl_array_buffer, self.particle_buffer_pos)
    gl_vertex_attrib_pointer(self.gl, self.loc_pos, 3, gl_float, false, 0, 0)
    gl_bind_buffer(self.gl, gl_array_buffer, self.particle_buffer_color)
    gl_vertex_attrib_pointer(self.gl, self.loc_color, 3, gl_float, false, 0, 0)
    gl_bind_buffer(self.gl, gl_array_buffer, self.particle_buffer_uv)
    gl_vertex_attrib_pointer(self.gl, self.loc_uv, 2, gl_float, false, 0, 0)
    gl_draw_arrays(self.gl, gl_triangles, 0, self.particle_vertex_count)
  }
  gl_depth_mask(self.gl, true)
  gl_depth_func(self.gl, gl_less)
}

///|
fn compile_shader(
  gl : WebGL,
  shader_type : Int,
  source : String,
) -> WebGLShader {
  let shader = gl_create_shader(gl, shader_type)
  gl_shader_source(gl, shader, source)
  gl_compile_shader(gl, shader)
  if !gl_get_shader_parameter(gl, shader, gl_compile_status) {
    let log = gl_get_shader_info_log(gl, shader)
    js_error("Shader compile error:\\n\{log}")
  }
  shader
}

///|
fn link_program(gl : WebGL, vs : WebGLShader, fs : WebGLShader) -> WebGLProgram {
  let program = gl_create_program(gl)
  gl_attach_shader(gl, program, vs)
  gl_attach_shader(gl, program, fs)
  gl_link_program(gl, program)
  if !gl_get_program_parameter(gl, program, gl_link_status) {
    let log = gl_get_program_info_log(gl, program)
    js_error("Program link error:\\n\{log}")
  }
  program
}

///|
fn vertex_shader_source() -> String {
  let src : String =
    #|attribute vec3 a_pos;
    #|attribute vec3 a_color;
    #|attribute vec2 a_uv;
    #|uniform mat4 u_vp;
    #|varying vec3 v_color;
    #|varying vec2 v_uv;
    #|void main() {
    #|  gl_Position = u_vp * vec4(a_pos, 1.0);
    #|  v_color = a_color;
    #|  v_uv = a_uv;
    #|}
  src
}

///|
fn fragment_shader_source() -> String {
  let src : String =
    #|precision mediump float;
    #|varying vec3 v_color;
    #|varying vec2 v_uv;
    #|uniform sampler2D u_tex;
    #|uniform vec3 u_tint;
    #|uniform float u_tint_strength;
    #|void main() {
    #|  vec4 tex = texture2D(u_tex, v_uv);
    #|  if (tex.a < 0.1) discard;
    #|  vec3 base = tex.rgb * v_color;
    #|  vec3 mixed = mix(base, u_tint, u_tint_strength);
    #|  gl_FragColor = vec4(mixed, tex.a);
    #|}
  src
}
