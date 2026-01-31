///|
priv struct Vec3 {
  x : Double
  y : Double
  z : Double
}

///|
fn vec3(x : Double, y : Double, z : Double) -> Vec3 {
  { x, y, z }
}

///|
fn Vec3::add(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x + other.x, y: self.y + other.y, z: self.z + other.z }
}

///|
fn Vec3::sub(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x - other.x, y: self.y - other.y, z: self.z - other.z }
}

///|
fn Vec3::mul(self : Vec3, s : Double) -> Vec3 {
  { x: self.x * s, y: self.y * s, z: self.z * s }
}

///|
fn Vec3::dot(self : Vec3, other : Vec3) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///|
fn Vec3::cross(self : Vec3, other : Vec3) -> Vec3 {
  {
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x,
  }
}

///|
fn Vec3::length(self : Vec3) -> Double {
  self.dot(self).sqrt()
}

///|
fn Vec3::normalize(self : Vec3) -> Vec3 {
  let len = self.length()
  if len <= 0.0 {
    self
  } else {
    self.mul(1.0 / len)
  }
}

///|
fn clamp(x : Double, min_val : Double, max_val : Double) -> Double {
  if x < min_val {
    min_val
  } else if x > max_val {
    max_val
  } else {
    x
  }
}

///|
fn mat4_perspective(
  fov_y : Double,
  aspect : Double,
  near : Double,
  far : Double,
) -> Array[Double] {
  let f = 1.0 / @math.tan(fov_y / 2.0)
  let nf = 1.0 / (near - far)
  [
    f / aspect,
    0.0,
    0.0,
    0.0,
    0.0,
    f,
    0.0,
    0.0,
    0.0,
    0.0,
    (far + near) * nf,
    -1.0,
    0.0,
    0.0,
    2.0 * far * near * nf,
    0.0,
  ]
}

///|
fn mat4_look_at(eye : Vec3, center : Vec3, up : Vec3) -> Array[Double] {
  let f = center.sub(eye).normalize()
  let s = f.cross(up).normalize()
  let u = s.cross(f)
  [
    s.x,
    u.x,
    -f.x,
    0.0,
    s.y,
    u.y,
    -f.y,
    0.0,
    s.z,
    u.z,
    -f.z,
    0.0,
    -s.dot(eye),
    -u.dot(eye),
    f.dot(eye),
    1.0,
  ]
}

///|
fn mat4_mul(a : Array[Double], b : Array[Double]) -> Array[Double] {
  let out = Array::make(16, 0.0)
  for c = 0; c < 4; c = c + 1 {
    for r = 0; r < 4; r = r + 1 {
      let i = c * 4 + r
      let a0 = a[0 * 4 + r] * b[c * 4 + 0]
      let a1 = a[1 * 4 + r] * b[c * 4 + 1]
      let a2 = a[2 * 4 + r] * b[c * 4 + 2]
      let a3 = a[3 * 4 + r] * b[c * 4 + 3]
      out[i] = a0 + a1 + a2 + a3
    }
  }
  out
}
