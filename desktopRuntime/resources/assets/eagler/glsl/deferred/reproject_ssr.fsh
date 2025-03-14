#line 2

/*
 * Copyright (c) 2023-2025 lax1dude. All Rights Reserved.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 * 
 */

precision lowp int;
precision highp float;
precision highp sampler2D;

in vec2 v_position2f;

layout(location = 0) out vec4 reflectionOutput4f;
layout(location = 1) out vec4 hitVectorOutput4f;

uniform sampler2D u_gbufferDepthTexture;
uniform sampler2D u_gbufferNormalTexture;
uniform sampler2D u_reprojectionReflectionInput4f;
uniform sampler2D u_reprojectionHitVectorInput4f;
uniform sampler2D u_lastFrameColorInput4f;
uniform sampler2D u_lastFrameDepthInput;

uniform mat4 u_lastProjectionMatrix4f;
uniform mat4x2 u_lastInverseProjMatrix4x2f;

uniform mat4 u_inverseProjectionMatrix4f;

uniform float u_sampleStep1f;

uniform vec4 u_pixelAlignment4f;

uniform int u_sampleDelta1i;

#define maxAge 55.0
#define maxSamples 50.0

void main() {
	vec2 v_position2f2 = (floor(v_position2f * u_pixelAlignment4f.xy) + 0.25) * (2.0 / u_pixelAlignment4f.zw);
	float fragDepth = textureLod(u_gbufferDepthTexture, v_position2f2, 0.0).r;

	if(fragDepth < 0.000001) {
		reflectionOutput4f = vec4(0.0, 0.0, 0.0, 0.0);
		hitVectorOutput4f = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	vec4 reflectionBuffer4f = textureLod(u_reprojectionReflectionInput4f, v_position2f, 0.0);
	vec4 hitVectorBuffer4f = textureLod(u_reprojectionHitVectorInput4f, v_position2f, 0.0);
	vec4 surfaceNormal4f = textureLod(u_gbufferNormalTexture, v_position2f2, 0.0);
	surfaceNormal4f.xyz *= 2.0;
	surfaceNormal4f.xyz -= 1.0;

	vec4 reflectionInput4f;
	vec4 hitVectorInput4f;
	float f;
	vec4 fragPos4f;
	vec4 reflectionNormal4f;
	float sampleStepMod;
	vec3 sampleOffset3f;
	vec3 reflectionSamplePos3f;
	float reflectDepthSample;
	vec2 sampleFragDepth;
	vec4 colorSample;

	for(int itr = 0; itr < u_sampleDelta1i; ++itr) {
		reflectionInput4f = reflectionBuffer4f;
		hitVectorInput4f = hitVectorBuffer4f;
		reflectionBuffer4f = vec4(0.0, 0.0, 0.0, 0.0);
		hitVectorBuffer4f = vec4(0.0, 0.0, 0.0, 0.0);
		hitVectorInput4f.a += 1.0;
		f = reflectionInput4f.a < 1.0 ? 1.0 : reflectionInput4f.a;
		reflectionInput4f.a = hitVectorInput4f.a > maxAge ? f : reflectionInput4f.a;
		if(reflectionInput4f.a < 1.0) {
			reflectionBuffer4f = reflectionInput4f;
			hitVectorBuffer4f = hitVectorInput4f;
			continue;
		}

		fragPos4f = u_inverseProjectionMatrix4f * (vec4(v_position2f2, fragDepth, 1.0) * 2.0 - 1.0);
		fragPos4f.xyz /= fragPos4f.w;
		fragPos4f.w = 1.0;
		reflectionNormal4f.xyz = reflect(normalize(fragPos4f.xyz), surfaceNormal4f.xyz);
		reflectionNormal4f.w = 1.0;
		sampleStepMod = (reflectionInput4f.a * 0.03 + 0.15 + length(fragPos4f.xyz) * 0.03) * u_sampleStep1f;
		sampleOffset3f = reflectionNormal4f.xyz * reflectionInput4f.a * sampleStepMod;
		fragPos4f.xyz += sampleOffset3f;
		reflectionNormal4f = u_lastProjectionMatrix4f * fragPos4f;
		reflectionNormal4f.xyz /= reflectionNormal4f.w;
		reflectionNormal4f.w = 1.0;
		reflectionSamplePos3f = reflectionNormal4f.xyz;
		reflectionSamplePos3f *= 0.5;
		reflectionSamplePos3f += 0.5;
		reflectionSamplePos3f.xy = (floor(reflectionSamplePos3f.xy * u_pixelAlignment4f.zw) + 0.5) * (0.5 / u_pixelAlignment4f.xy);

		if(clamp(reflectionSamplePos3f.xy, vec2(0.001), vec2(0.999)) != reflectionSamplePos3f.xy) {
			continue;
		}

		reflectDepthSample = textureLod(u_lastFrameDepthInput, reflectionSamplePos3f.xy, 0.0).r;
		sampleFragDepth = u_lastInverseProjMatrix4x2f * vec4(reflectionNormal4f.xy, reflectDepthSample * 2.0 - 1.0, 1.0);
		sampleFragDepth.x /= sampleFragDepth.y;

		reflectDepthSample = sampleFragDepth.x - fragPos4f.z;
		if(reflectDepthSample < sampleStepMod * 3.0) {
			reflectionInput4f.a += 1.0;
			reflectionBuffer4f = reflectionInput4f.a >= maxSamples ? vec4(0.0, 0.0, 0.0, 0.0) : reflectionInput4f;
			hitVectorBuffer4f = vec4(0.0, 0.0, 0.0, hitVectorInput4f.a);
			continue;
		}

		if(abs(reflectDepthSample) > sampleStepMod * 6.0) {
			continue;
		}

		colorSample = textureLod(u_lastFrameColorInput4f, reflectionSamplePos3f.xy, 0.0);
		reflectionBuffer4f = vec4(colorSample.rgb, 0.0);
		reflectionBuffer4f.g += 0.0005;
		hitVectorBuffer4f = vec4(colorSample.a > 0.0 ? sampleOffset3f : vec3(0.0), 0.0);
		hitVectorBuffer4f.g += colorSample.a > 0.0 ? 0.0004 : 0.0;
	}

	reflectionOutput4f = reflectionBuffer4f;
	hitVectorOutput4f = hitVectorBuffer4f;
}
