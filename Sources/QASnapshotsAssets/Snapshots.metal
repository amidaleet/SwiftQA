#include <metal_stdlib>
using namespace metal;

constant float colorThreshold = 0.07;

kernel void fastCheckForColorEquality(
  texture2d<float, access::read> imageA [[texture(0)]],
  texture2d<float, access::read> imageB [[texture(1)]],
  device atomic_uint* failedFlag [[buffer(0)]],
  uint2 pointPosition [[thread_position_in_grid]],
  uint groupIndex [[thread_index_in_threadgroup]]
) {
  // Out of grid check
  if ((pointPosition.x >= imageA.get_width()) || (pointPosition.y >= imageA.get_height())) {
    return;
  }
  
  threadgroup uint groupFailedFlag;
  
  if (groupIndex == 0) {
    groupFailedFlag = 0;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  float4 pixelA = imageA.read(pointPosition);
  float4 pixelB = imageB.read(pointPosition);
  
  bool hasDifference = any(abs(pixelA - pixelB) > colorThreshold);
  
  if (hasDifference) {
    groupFailedFlag = 1;
  }
  threadgroup_barrier(mem_flags::mem_threadgroup);
  
  if (groupIndex == 0 ) {
    if (groupFailedFlag != 0) {
      atomic_store_explicit(failedFlag, 1, memory_order_relaxed);
    }
  }
}

kernel void renderSnapshotDiff(
  texture2d<float, access::read> imageA [[texture(0)]],
  texture2d<float, access::read> imageB [[texture(1)]],
  texture2d<float, access::write> diffTexture [[texture(2)]],
  uint2 pointPosition [[thread_position_in_grid]]
) {
  // Out of grid check
  if ((pointPosition.x >= diffTexture.get_width()) || (pointPosition.y >= diffTexture.get_height())) {
    return;
  }
  
  float4 pixelA = imageA.read(pointPosition);
  float4 pixelB = imageB.read(pointPosition);
  
  bool hasDifference = any(abs(pixelA - pixelB) > colorThreshold);
  
  if (hasDifference) {
    diffTexture.write(float4(1.0, 1.0, 1.0, 1.0), pointPosition); // Белый для различий, BGRA формат
  } else {
    diffTexture.write(float4(0.0, 0.0, 0.0, 1.0), pointPosition); // Черный для совпадений, BGRA формат
  }
}
