///|
#external
priv type WebGL

///|
#external
priv type WebGLProgram

///|
#external
priv type WebGLShader

///|
#external
priv type WebGLBuffer

///|
#external
priv type WebGLUniformLocation

///|
#external
priv type WebGLTexture

///|
let gl_color_buffer_bit : Int = 0x4000

///|
let gl_depth_buffer_bit : Int = 0x0100

///|
let gl_triangles : Int = 0x0004

///|
let gl_array_buffer : Int = 0x8892

///|
let gl_texture_2d : Int = 0x0DE1

///|
let gl_texture0 : Int = 0x84C0

///|
let gl_texture_min_filter : Int = 0x2801

///|
let gl_texture_mag_filter : Int = 0x2800

///|
let gl_texture_wrap_s : Int = 0x2802

///|
let gl_texture_wrap_t : Int = 0x2803

///|
let gl_nearest : Int = 0x2600

///|
let gl_clamp_to_edge : Int = 0x812F

///|
let gl_rgba : Int = 0x1908

///|
let gl_unsigned_byte : Int = 0x1401

///|
let gl_unpack_flip_y_webgl : Int = 0x9240

///|
let gl_static_draw : Int = 0x88E4

///|
let gl_float : Int = 0x1406

///|
let gl_depth_test : Int = 0x0B71

///|
let gl_blend : Int = 0x0BE2

///|
let gl_src_alpha : Int = 0x0302

///|
let gl_one_minus_src_alpha : Int = 0x0303

///|
let gl_less : Int = 0x0201

///|
let gl_lequal : Int = 0x0203

///|

///|
let gl_vertex_shader : Int = 0x8B31

///|
let gl_fragment_shader : Int = 0x8B30

///|
let gl_compile_status : Int = 0x8B81

///|
let gl_link_status : Int = 0x8B82

///|
extern "js" fn gl_create_context(canvas : JsValue) -> WebGL =
  #| (canvas) => canvas.getContext("webgl") || canvas.getContext("experimental-webgl")

///|
extern "js" fn gl_viewport(
  gl : WebGL,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Unit =
  #| (gl, x, y, w, h) => gl.viewport(x, y, w, h)

///|
extern "js" fn gl_clear_color(
  gl : WebGL,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Unit =
  #| (gl, r, g, b, a) => gl.clearColor(r, g, b, a)

///|
extern "js" fn gl_clear(gl : WebGL, mask : Int) -> Unit =
  #| (gl, mask) => gl.clear(mask)

///|
extern "js" fn gl_enable(gl : WebGL, cap : Int) -> Unit =
  #| (gl, cap) => gl.enable(cap)

///|
extern "js" fn gl_blend_func(gl : WebGL, src : Int, dst : Int) -> Unit =
  #| (gl, src, dst) => gl.blendFunc(src, dst)

///|
extern "js" fn gl_depth_mask(gl : WebGL, flag : Bool) -> Unit =
  #| (gl, flag) => gl.depthMask(flag)

///|
extern "js" fn gl_depth_func(gl : WebGL, func : Int) -> Unit =
  #| (gl, func) => gl.depthFunc(func)

///|

///|
extern "js" fn gl_create_shader(gl : WebGL, shader_type : Int) -> WebGLShader =
  #| (gl, t) => gl.createShader(t)

///|
extern "js" fn gl_shader_source(
  gl : WebGL,
  shader : WebGLShader,
  source : String,
) -> Unit =
  #| (gl, shader, source) => gl.shaderSource(shader, source)

///|
extern "js" fn gl_compile_shader(gl : WebGL, shader : WebGLShader) -> Unit =
  #| (gl, shader) => gl.compileShader(shader)

///|
extern "js" fn gl_get_shader_parameter(
  gl : WebGL,
  shader : WebGLShader,
  pname : Int,
) -> Bool =
  #| (gl, shader, pname) => !!gl.getShaderParameter(shader, pname)

///|
extern "js" fn gl_get_shader_info_log(
  gl : WebGL,
  shader : WebGLShader,
) -> String =
  #| (gl, shader) => gl.getShaderInfoLog(shader) || ""

///|
extern "js" fn gl_create_program(gl : WebGL) -> WebGLProgram =
  #| (gl) => gl.createProgram()

///|
extern "js" fn gl_attach_shader(
  gl : WebGL,
  program : WebGLProgram,
  shader : WebGLShader,
) -> Unit =
  #| (gl, program, shader) => gl.attachShader(program, shader)

///|
extern "js" fn gl_link_program(gl : WebGL, program : WebGLProgram) -> Unit =
  #| (gl, program) => gl.linkProgram(program)

///|
extern "js" fn gl_get_program_parameter(
  gl : WebGL,
  program : WebGLProgram,
  pname : Int,
) -> Bool =
  #| (gl, program, pname) => !!gl.getProgramParameter(program, pname)

///|
extern "js" fn gl_get_program_info_log(
  gl : WebGL,
  program : WebGLProgram,
) -> String =
  #| (gl, program) => gl.getProgramInfoLog(program) || ""

///|
extern "js" fn gl_use_program(gl : WebGL, program : WebGLProgram) -> Unit =
  #| (gl, program) => gl.useProgram(program)

///|
extern "js" fn gl_get_attrib_location(
  gl : WebGL,
  program : WebGLProgram,
  name : String,
) -> Int =
  #| (gl, program, name) => gl.getAttribLocation(program, name)

///|
extern "js" fn gl_get_uniform_location(
  gl : WebGL,
  program : WebGLProgram,
  name : String,
) -> WebGLUniformLocation =
  #| (gl, program, name) => gl.getUniformLocation(program, name)

///|
extern "js" fn gl_uniform1i(
  gl : WebGL,
  location : WebGLUniformLocation,
  value : Int,
) -> Unit =
  #| (gl, location, value) => gl.uniform1i(location, value)

///|
extern "js" fn gl_uniform1f(
  gl : WebGL,
  location : WebGLUniformLocation,
  value : Double,
) -> Unit =
  #| (gl, location, value) => gl.uniform1f(location, value)

///|
extern "js" fn gl_uniform3f(
  gl : WebGL,
  location : WebGLUniformLocation,
  x : Double,
  y : Double,
  z : Double,
) -> Unit =
  #| (gl, location, x, y, z) => gl.uniform3f(location, x, y, z)

///|
extern "js" fn gl_uniform_matrix4fv(
  gl : WebGL,
  location : WebGLUniformLocation,
  transpose : Bool,
  data : Array[Double],
) -> Unit =
  #| (gl, location, transpose, data) => gl.uniformMatrix4fv(location, transpose, new Float32Array(data))

///|
extern "js" fn gl_create_buffer(gl : WebGL) -> WebGLBuffer =
  #| (gl) => gl.createBuffer()

///|
extern "js" fn gl_create_texture(gl : WebGL) -> WebGLTexture =
  #| (gl) => gl.createTexture()

///|
extern "js" fn gl_active_texture(gl : WebGL, texture : Int) -> Unit =
  #| (gl, texture) => gl.activeTexture(texture)

///|
extern "js" fn gl_bind_texture(
  gl : WebGL,
  target : Int,
  texture : WebGLTexture,
) -> Unit =
  #| (gl, target, texture) => gl.bindTexture(target, texture)

///|
extern "js" fn gl_tex_parameteri(
  gl : WebGL,
  target : Int,
  pname : Int,
  param : Int,
) -> Unit =
  #| (gl, target, pname, param) => gl.texParameteri(target, pname, param)

///|
extern "js" fn gl_tex_image_2d_canvas(
  gl : WebGL,
  target : Int,
  level : Int,
  internal_format : Int,
  format : Int,
  data_type : Int,
  canvas : JsValue,
) -> Bool =
  #| (gl, target, level, internalFormat, format, type, canvas) => {
  #|   try {
  #|     gl.texImage2D(target, level, internalFormat, format, type, canvas);
  #|     return true;
  #|   } catch (e) {
  #|     console.error("texImage2D failed", e);
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn gl_pixel_storei(gl : WebGL, pname : Int, param : Int) -> Unit =
  #| (gl, pname, param) => gl.pixelStorei(pname, param)

///|
extern "js" fn gl_bind_buffer(
  gl : WebGL,
  target : Int,
  buffer : WebGLBuffer,
) -> Unit =
  #| (gl, target, buffer) => gl.bindBuffer(target, buffer)

///|
extern "js" fn gl_buffer_data_f32(
  gl : WebGL,
  target : Int,
  data : Array[Double],
  usage : Int,
) -> Unit =
  #| (gl, target, data, usage) => gl.bufferData(target, new Float32Array(data), usage)

///|
extern "js" fn gl_vertex_attrib_pointer(
  gl : WebGL,
  index : Int,
  size : Int,
  ty : Int,
  normalized : Bool,
  stride : Int,
  offset : Int,
) -> Unit =
  #| (gl, index, size, ty, normalized, stride, offset) => gl.vertexAttribPointer(index, size, ty, normalized, stride, offset)

///|
extern "js" fn gl_enable_vertex_attrib_array(gl : WebGL, index : Int) -> Unit =
  #| (gl, index) => gl.enableVertexAttribArray(index)

///|
extern "js" fn gl_draw_arrays(
  gl : WebGL,
  mode : Int,
  first : Int,
  count : Int,
) -> Unit =
  #| (gl, mode, first, count) => gl.drawArrays(mode, first, count)
