/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated January 1, 2020. Replaces all prior versions.
 *
 * Copyright (c) 2013-2020, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software
 * or otherwise create derivative works of the Spine Runtimes (collectively,
 * "Products"), provided that each user of the Products must obtain their own
 * Spine Editor license and redistribution of the Products in any form must
 * include this license and copyright notice.
 *
 * THE SPINE RUNTIMES ARE PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES,
 * BUSINESS INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THE SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

using System;
using System.Collections;

namespace Spine {
	/// <summary>
	/// Stores a bone's current pose.
	/// <para>
	/// A bone has a local transform which is used to compute its world transform. A bone also has an applied transform, which is a
	/// local transform that can be applied to compute the world transform. The local transform and applied transform may differ if a
	/// constraint or application code modifies the world transform after it was computed from the local transform.
	/// </para>
	/// </summary>
	public sealed class Bone : IUpdatable {
		static public bool yDown;

		public BoneData data;
		public Skeleton skeleton;
		public Bone parent;
		public List<Bone> children = new List<Bone>() ~ delete _;
		public float x, y, rotation, scaleX, scaleY, shearX, shearY;
		public float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;
		public bool appliedValid;

		public float a, b, worldX;
		public float c, d, worldY;

		public bool sorted, active;

		public BoneData Data => data;
		public Skeleton Skeleton => skeleton;
		public Bone Parent => parent;
		public List<Bone> Children => children;
		/// <summary>Returns false when the bone has not been computed because <see cref="BoneData.SkinRequired"/> is true and the
		/// <see cref="Skin">active skin</see> does not <see cref="Skin.Bones">contain</see> this bone.</summary>
		public bool Active => active;
		/// <summary>The local X translation.</summary>
		public ref float X => ref x;
		/// <summary>The local Y translation.</summary>
		public ref float Y => ref y;
		/// <summary>The local rotation.</summary>
		public ref float Rotation => ref rotation;

		/// <summary>The local scaleX.</summary>
		public ref float ScaleX => ref scaleX;

		/// <summary>The local scaleY.</summary>
		public ref float ScaleY => ref scaleY;

		/// <summary>The local shearX.</summary>
		public ref float ShearX => ref shearX;

		/// <summary>The local shearY.</summary>
		public ref float ShearY => ref shearY;

		/// <summary>The rotation, as calculated by any constraints.</summary>
		public ref float AppliedRotation => ref arotation;

		/// <summary>The applied local x translation.</summary>
		public ref float AX => ref ax;

		/// <summary>The applied local y translation.</summary>
		public ref float AY => ref ay;

		/// <summary>The applied local scaleX.</summary>
		public ref float AScaleX => ref ascaleX;

		/// <summary>The applied local scaleY.</summary>
		public ref float AScaleY => ref ascaleY;

		/// <summary>The applied local shearX.</summary>
		public ref float AShearX => ref ashearX;

		/// <summary>The applied local shearY.</summary>
		public ref float AShearY => ref ashearY;

		public float A => a;
		public float B => b;
		public float C => c;
		public float D => d;

		public float WorldX => worldX;
		public float WorldY => worldY;
		public float WorldRotationX => Math.Atan2(c, a) * MathUtils.RadDeg;
		public float WorldRotationY => Math.Atan2(d, b) * MathUtils.RadDeg;

		/// <summary>Returns the magnitide (always positive) of the world scale X.</summary>
		public float WorldScaleX => Math.Sqrt(a * a + c * c);

		/// <summary>Returns the magnitide (always positive) of the world scale Y.</summary>
		public float WorldScaleY => Math.Sqrt(b * b + d * d);

		/// <param name="parent">May be null.</param>
		public this (BoneData data, Skeleton skeleton, Bone parent) {
			//if (data == null) throw new ArgumentNullException("data", "data cannot be null.");
			//if (skeleton == null) throw new ArgumentNullException("skeleton", "skeleton cannot be null.");
			this.data = data;
			this.skeleton = skeleton;
			this.parent = parent;
			SetToSetupPose();
		}

		/// <summary>Same as <see cref="UpdateWorldTransform"/>. This method exists for Bone to implement <see cref="Spine.IUpdatable"/>.</summary>
		public void Update () {
			UpdateWorldTransform(x, y, rotation, scaleX, scaleY, shearX, shearY);
		}

		/// <summary>Computes the world transform using the parent bone and this bone's local transform.</summary>
		public void UpdateWorldTransform () {
			UpdateWorldTransform(x, y, rotation, scaleX, scaleY, shearX, shearY);
		}

		/// <summary>Computes the world transform using the parent bone and the specified local transform.</summary>
		public void UpdateWorldTransform (float x, float y, float rotation, float scaleX, float scaleY, float shearX, float shearY) {
			ax = x;
			ay = y;
			arotation = rotation;
			ascaleX = scaleX;
			ascaleY = scaleY;
			ashearX = shearX;
			ashearY = shearY;
			appliedValid = true;
			Skeleton skeleton = this.skeleton;

			Bone parent = this.parent;
			if (parent == null) { // Root bone.
				float rotationY = rotation + 90 + shearY, sx = skeleton.ScaleX, sy = skeleton.ScaleY;
				a = MathUtils.CosDeg(rotation + shearX) * scaleX * sx;
				b = MathUtils.CosDeg(rotationY) * scaleY * sx;
				c = MathUtils.SinDeg(rotation + shearX) * scaleX * sy;
				d = MathUtils.SinDeg(rotationY) * scaleY * sy;
				worldX = x * sx + skeleton.x;
				worldY = y * sy + skeleton.y;
				return;
			}

			float pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d;
			worldX = pa * x + pb * y + parent.worldX;
			worldY = pc * x + pd * y + parent.worldY;

			switch (data.transformMode) {
			case TransformMode.Normal: {
					float rotationY = rotation + 90 + shearY;
					float la = MathUtils.CosDeg(rotation + shearX) * scaleX;
					float lb = MathUtils.CosDeg(rotationY) * scaleY;
					float lc = MathUtils.SinDeg(rotation + shearX) * scaleX;
					float ld = MathUtils.SinDeg(rotationY) * scaleY;
					a = pa * la + pb * lc;
					b = pa * lb + pb * ld;
					c = pc * la + pd * lc;
					d = pc * lb + pd * ld;
					return;
				}
			case TransformMode.OnlyTranslation: {
					float rotationY = rotation + 90 + shearY;
					a = MathUtils.CosDeg(rotation + shearX) * scaleX;
					b = MathUtils.CosDeg(rotationY) * scaleY;
					c = MathUtils.SinDeg(rotation + shearX) * scaleX;
					d = MathUtils.SinDeg(rotationY) * scaleY;
					break;
				}
			case TransformMode.NoRotationOrReflection: {
					float s = pa * pa + pc * pc, prx;
					if (s > 0.0001f) {
						s = Math.Abs(pa * pd - pb * pc) / s;
						pb = pc * s;
						pd = pa * s;
						prx = Math.Atan2(pc, pa) * MathUtils.RadDeg;
					} else {
						pa = 0;
						pc = 0;
						prx = 90 - Math.Atan2(pd, pb) * MathUtils.RadDeg;
					}
					float rx = rotation + shearX - prx;
					float ry = rotation + shearY - prx + 90;
					float la = MathUtils.CosDeg(rx) * scaleX;
					float lb = MathUtils.CosDeg(ry) * scaleY;
					float lc = MathUtils.SinDeg(rx) * scaleX;
					float ld = MathUtils.SinDeg(ry) * scaleY;
					a = pa * la - pb * lc;
					b = pa * lb - pb * ld;
					c = pc * la + pd * lc;
					d = pc * lb + pd * ld;
					break;
				}
			case TransformMode.NoScale:
			case TransformMode.NoScaleOrReflection: {
					float cos = MathUtils.CosDeg(rotation), sin = MathUtils.SinDeg(rotation);
					float za = (pa * cos + pb * sin) / skeleton.ScaleX;
					float zc = (pc * cos + pd * sin) / skeleton.ScaleY;
					float s = Math.Sqrt(za * za + zc * zc);
					if (s > 0.00001f) s = 1 / s;
					za *= s;
					zc *= s;
					s = Math.Sqrt(za * za + zc * zc);
					if (data.transformMode == TransformMode.NoScale
						&& (pa * pd - pb * pc < 0) != (skeleton.ScaleX < 0 != skeleton.ScaleY < 0)) s = -s;

					float r = MathUtils.PI / 2 + Math.Atan2(zc, za);
					float zb = Math.Cos(r) * s;
					float zd = Math.Sin(r) * s;
					float la = MathUtils.CosDeg(shearX) * scaleX;
					float lb = MathUtils.CosDeg(90 + shearY) * scaleY;
					float lc = MathUtils.SinDeg(shearX) * scaleX;
					float ld = MathUtils.SinDeg(90 + shearY) * scaleY;
					a = za * la + zb * lc;
					b = za * lb + zb * ld;
					c = zc * la + zd * lc;
					d = zc * lb + zd * ld;
					break;
				}
			}

			a *= skeleton.ScaleX;
			b *= skeleton.ScaleX;
			c *= skeleton.ScaleY;
			d *= skeleton.ScaleY;
		}

		public void SetToSetupPose () {
			BoneData data = this.data;
			x = data.x;
			y = data.y;
			rotation = data.rotation;
			scaleX = data.scaleX;
			scaleY = data.scaleY;
			shearX = data.shearX;
			shearY = data.shearY;
		}

		/// <summary>
		/// Computes the individual applied transform values from the world transform. This can be useful to perform processing using
		/// the applied transform after the world transform has been modified directly (eg, by a constraint)..
		///
		/// Some information is ambiguous in the world transform, such as -1,-1 scale versus 180 rotation.
		/// </summary>
		public void UpdateAppliedTransform () {
			appliedValid = true;
			Bone parent = this.parent;
			if (parent == null) {
				ax = worldX;
				ay = worldY;
				arotation = Math.Atan2(c, a) * MathUtils.RadDeg;
				ascaleX = Math.Sqrt(a * a + c * c);
				ascaleY = Math.Sqrt(b * b + d * d);
				ashearX = 0;
				ashearY = Math.Atan2(a * b + c * d, a * d - b * c) * MathUtils.RadDeg;
				return;
			}
			float pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d;
			float pid = 1 / (pa * pd - pb * pc);
			float dx = worldX - parent.worldX, dy = worldY - parent.worldY;
			ax = (dx * pd * pid - dy * pb * pid);
			ay = (dy * pa * pid - dx * pc * pid);
			float ia = pid * pd;
			float id = pid * pa;
			float ib = pid * pb;
			float ic = pid * pc;
			float ra = ia * a - ib * c;
			float rb = ia * b - ib * d;
			float rc = id * c - ic * a;
			float rd = id * d - ic * b;
			ashearX = 0;
			ascaleX = Math.Sqrt(ra * ra + rc * rc);
			if (ascaleX > 0.0001f) {
				float det = ra * rd - rb * rc;
				ascaleY = det / ascaleX;
				ashearY = Math.Atan2(ra * rb + rc * rd, det) * MathUtils.RadDeg;
				arotation = Math.Atan2(rc, ra) * MathUtils.RadDeg;
			} else {
				ascaleX = 0;
				ascaleY = Math.Sqrt(rb * rb + rd * rd);
				ashearY = 0;
				arotation = 90 - Math.Atan2(rd, rb) * MathUtils.RadDeg;
			}
		}

		public void WorldToLocal (float worldX, float worldY, out float localX, out float localY) {
			float a = this.a, b = this.b, c = this.c, d = this.d;
			float invDet = 1 / (a * d - b * c);
			float x = worldX - this.worldX, y = worldY - this.worldY;
			localX = (x * d * invDet - y * b * invDet);
			localY = (y * a * invDet - x * c * invDet);
		}

		public void LocalToWorld (float localX, float localY, out float worldX, out float worldY) {
			worldX = localX * a + localY * b + this.worldX;
			worldY = localX * c + localY * d + this.worldY;
		}

		public float WorldToLocalRotationX {
			get {
				Bone parent = this.parent;
				if (parent == null) return arotation;
				float pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d, a = this.a, c = this.c;
				return Math.Atan2(pa * c - pc * a, pd * a - pb * c) * MathUtils.RadDeg;
			}
		}

		public float WorldToLocalRotationY {
			get {
				Bone parent = this.parent;
				if (parent == null) return arotation;
				float pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d, b = this.b, d = this.d;
				return Math.Atan2(pa * d - pc * b, pd * b - pb * d) * MathUtils.RadDeg;
			}
		}

		public float WorldToLocalRotation (float worldRotation) {
			float sin = MathUtils.SinDeg(worldRotation), cos = MathUtils.CosDeg(worldRotation);
			return Math.Atan2(a * sin - c * cos, d * cos - b * sin) * MathUtils.RadDeg + rotation - shearX;
		}

		public float LocalToWorldRotation (float _localRotation) {
			float localRotation = _localRotation - (rotation - shearX);
			float sin = MathUtils.SinDeg(localRotation), cos = MathUtils.CosDeg(localRotation);
			return Math.Atan2(cos * c + sin * d, cos * a + sin * b) * MathUtils.RadDeg;
		}

		/// <summary>
		/// Rotates the world transform the specified amount and sets isAppliedValid to false.
		/// </summary>
		/// <param name="degrees">Degrees.</param>
		public void RotateWorld (float degrees) {
			float a = this.a, b = this.b, c = this.c, d = this.d;
			float cos = MathUtils.CosDeg(degrees), sin = MathUtils.SinDeg(degrees);
			this.a = cos * a - sin * c;
			this.b = cos * b - sin * d;
			this.c = sin * a + cos * c;
			this.d = sin * b + cos * d;
			appliedValid = false;
		}

		public String ToString () => data.name;

		public Skeleton GetSkeleton() => skeleton;
	}
}
