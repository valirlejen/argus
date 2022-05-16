// zig fmt: off
const mesh_common =
\\  struct DrawUniforms {
\\      object_to_world: mat4x4<f32>,
\\  }
\\  @group(1) @binding(0) var<uniform> draw_uniforms: DrawUniforms;
\\
\\  struct FrameUniforms {
\\      world_to_clip: mat4x4<f32>,
\\  }
\\  @group(0) @binding(0) var<uniform> frame_uniforms: FrameUniforms;
;
pub const mesh_vs = mesh_common ++
\\  struct VertexOut {
\\      @builtin(position) position_clip: vec4<f32>,
\\      @location(0) position: vec3<f32>,
\\      @location(1) normal: vec3<f32>,
\\      @location(2) texcoord: vec2<f32>,
\\      @location(3) tangent: vec4<f32>,
\\  }
\\  @stage(vertex) fn main(
\\      @location(0) position: vec3<f32>,
\\      @location(1) normal: vec3<f32>,
\\      @location(2) texcoord: vec2<f32>,
\\      @location(3) tangent: vec4<f32>,
\\  ) -> VertexOut {
\\      var output: VertexOut;
\\      output.position_clip = vec4(position, 1.0) * draw_uniforms.object_to_world * frame_uniforms.world_to_clip;
\\      output.position = (vec4(position, 1.0) * draw_uniforms.object_to_world).xyz;
\\      output.normal = normal;
\\      output.texcoord = texcoord;
\\      output.tangent = tangent;
\\      return output;
\\  }
;
pub const mesh_fs = mesh_common ++
\\  @stage(fragment) fn main(
\\      @location(0) position: vec3<f32>,
\\      @location(1) normal: vec3<f32>,
\\      @location(2) texcoord: vec2<f32>,
\\      @location(3) tangent: vec4<f32>,
\\  ) -> @location(0) vec4<f32> {
\\      return vec4(1.0);
\\  }
// zig fmt: on
;
