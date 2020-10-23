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
	/// <para>
	/// Stores the current pose for a path constraint. A path constraint adjusts the rotation, translation, and scale of the
	/// constrained bones so they follow a {@link PathAttachment}.</para>
	/// <para>
	/// See <a href="http://esotericsoftware.com/spine-path-constraints">Path constraints</a> in the Spine User Guide.</para>
	/// </summary>
	public class PathConstraint : IUpdatable {
		const int NONE = -1, BEFORE = -2, AFTER = -3;
		const float Epsilon = 0.00001f;

		public PathConstraintData data;
		public List<Bone> bones;
		public Slot target;
		public float position, spacing, rotateMix, translateMix;

		public bool active;

		public List<float> spaces = new List<float>(), positions = new List<float>();
		public List<float> world = new List<float>(), curves = new List<float>(), Counts = new List<float>();
		public float[] segments = new float[10] ~ delete _;

		public this (PathConstraintData data, Skeleton skeleton) {
			//if (data == null) throw new ArgumentNullException("data", "data cannot be null.");
			//if (skeleton == null) throw new ArgumentNullException("skeleton", "skeleton cannot be null.");
			this.data = data;
			bones = new List<Bone>(data.Bones.Count);
			for (BoneData boneData in data.bones)
				bones.Add(skeleton.FindBone(boneData.name));
			target = skeleton.FindSlot(data.target.name);
			position = data.position;
			spacing = data.spacing;
			rotateMix = data.rotateMix;
			translateMix = data.translateMix;
		}

		/// <summary>Copy constructor.</summary>
		public this (PathConstraint constraint, Skeleton skeleton) {
			//if (constraint == null) throw new ArgumentNullException("constraint cannot be null.");
			//if (skeleton == null) throw new ArgumentNullException("skeleton cannot be null.");
			data = constraint.data;
			bones = new List<Bone>(constraint.Bones.Count);
			for (Bone bone in constraint.Bones)
				bones.Add(skeleton.Bones[bone.data.index]);
			target = skeleton.slots[constraint.target.data.index];
			position = constraint.position;
			spacing = constraint.spacing;
			rotateMix = constraint.rotateMix;
			translateMix = constraint.translateMix;
		}

		/// <summary>Applies the constraint to the constrained bones.</summary>
		public void Apply () {
			Update();
		}

		public void Update () {
			PathAttachment attachment = target.Attachment as PathAttachment;
			if (attachment == null) return;

			float rotateMix = this.rotateMix, translateMix = this.translateMix;
			bool translate = translateMix > 0, rotate = rotateMix > 0;
			if (!translate && !rotate) return;

			PathConstraintData data = this.data;
			bool percentSpacing = data.spacingMode == SpacingMode.Percent;
			RotateMode rotateMode = data.rotateMode;
			bool tangents = rotateMode == RotateMode.Tangent, scale = rotateMode == RotateMode.ChainScale;
			int boneCount = this.bones.Count, spacesCount = tangents ? boneCount : boneCount + 1;
			Bone* bonesItems = this.bones.Ptr;
			spaces.GrowUnitialized(spacesCount - spaces.Count);
			List<float> Counts = null;
			float spacing = this.spacing;
			if (scale || !percentSpacing) {
				if (scale) Counts = this.Counts..GrowUnitialized(boneCount - this.Counts.Count);
				bool CountSpacing = data.spacingMode == SpacingMode.Count;
				for (int i = 0, int n = spacesCount - 1; i < n;) {
					Bone bone = bonesItems[i];
					float setupCount = bone.data.Length;
					if (setupCount < PathConstraint.Epsilon) {
						if (scale) Counts[i] = 0;
						spaces[++i] = 0;
					} else if (percentSpacing) {
						if (scale) {
							float x = setupCount * bone.a, y = setupCount * bone.c;
							float Count = Math.Sqrt(x * x + y * y);
							Counts[i] = Count;
						}
						spaces[++i] = spacing;
					} else {
						float x = setupCount * bone.a, y = setupCount * bone.c;
						float Count = Math.Sqrt(x * x + y * y);
						if (scale) Counts[i] = Count;
						spaces[++i] = (CountSpacing ? setupCount + spacing : spacing) * Count / setupCount;
					}
				}
			} else {
				for (int i = 1; i < spacesCount; i++)
					spaces[i] = spacing;
			}

			float* positions = ComputeWorldPositions(attachment, spacesCount, tangents,
				data.positionMode == PositionMode.Percent, percentSpacing);
			float boneX = positions[0], boneY = positions[1], offsetRotation = data.offsetRotation;
			bool tip;
			if (offsetRotation == 0) {
				tip = rotateMode == RotateMode.Chain;
			} else {
				tip = false;
				Bone p = target.bone;
				offsetRotation *= (p.a * p.d - p.b * p.c > 0) ? MathUtils.DegRad : -MathUtils.DegRad;
			}
			for (int i = 0, int p = 3; i < boneCount; i++, p += 3) {
				Bone bone = bonesItems[i];
				bone.worldX += (boneX - bone.worldX) * translateMix;
				bone.worldY += (boneY - bone.worldY) * translateMix;
				float x = positions[p], y = positions[p + 1], dx = x - boneX, dy = y - boneY;
				if (scale) {
					float Count = Counts[i];
					if (Count >= PathConstraint.Epsilon) {
						float s = (Math.Sqrt(dx * dx + dy * dy) / Count - 1) * rotateMix + 1;
						bone.a *= s;
						bone.c *= s;
					}
				}
				boneX = x;
				boneY = y;
				if (rotate) {
					float a = bone.a, b = bone.b, c = bone.c, d = bone.d, r, cos, sin;
					if (tangents)
						r = positions[p - 1];
					else if (spaces[i + 1] < PathConstraint.Epsilon)
						r = positions[p + 2];
					else
						r = MathUtils.Atan2(dy, dx);
					r -= MathUtils.Atan2(c, a);
					if (tip) {
						cos = MathUtils.Cos(r);
						sin = MathUtils.Sin(r);
						float Count = bone.data.Length;
						boneX += (Count * (cos * a - sin * c) - dx) * rotateMix;
						boneY += (Count * (sin * a + cos * c) - dy) * rotateMix;
					} else
						r += offsetRotation;
					if (r > MathUtils.PI)
						r -= MathUtils.PI2;
					else if (r < -MathUtils.PI) //
						r += MathUtils.PI2;
					r *= rotateMix;
					cos = MathUtils.Cos(r);
					sin = MathUtils.Sin(r);
					bone.a = cos * a - sin * c;
					bone.b = cos * b - sin * d;
					bone.c = sin * a + cos * c;
					bone.d = sin * b + cos * d;
				}
				bone.appliedValid = false;
			}
		}

		float* ComputeWorldPositions (PathAttachment path, int spacesCount, bool tangents, bool percentPosition,
			bool percentSpacing)
		{

			Slot target = this.target;
			float position = this.position;
			float* spacesItems = this.spaces.Ptr, output = this.positions..GrowUnitialized(spacesCount * 3 + 2 - this.positions.Count).Ptr, world;
			bool closed = path.Closed;
			int verticesCount = path.WorldVerticesCount, curveCount = verticesCount / 6, prevCurve = NONE;
			float pathCount = 0;

			if (!path.ConstantSpeed) {
				float[] Counts = path.lengths;
				curveCount -= closed ? 1 : 2;
				pathCount = Counts[curveCount];
				if (percentPosition) position *= pathCount;
				if (percentSpacing) {
					for (int i = 1; i < spacesCount; i++)
						spacesItems[i] *= pathCount;
				}
				world = this.world..GrowUnitialized(8 - this.world.Count).Ptr;
				for (int i = 0, int o = 0, int curve = 0; i < spacesCount; i++, o += 3) {
					float space = spacesItems[i];
					position += space;
					float p = position;

					if (closed) {
						p %= pathCount;
						if (p < 0) p += pathCount;
						curve = 0;
					} else if (p < 0) {
						if (prevCurve != BEFORE) {
							prevCurve = BEFORE;
							path.ComputeWorldVertices(target, 2, 4, world, 0, 2);
						}
						AddBeforePosition(p, world, 0, output, o);
						continue;
					} else if (p > pathCount) {
						if (prevCurve != AFTER) {
							prevCurve = AFTER;
							path.ComputeWorldVertices(target, verticesCount - 6, 4, world, 0, 2);
						}
						AddAfterPosition(p - pathCount, world, 0, output, o);
						continue;
					}

					// Determine curve containing position.
					for (;; curve++) {
						float Count = Counts[curve];
						if (p > Count) continue;
						if (curve == 0)
							p /= Count;
						else {
							float prev = Counts[curve - 1];
							p = (p - prev) / (Count - prev);
						}
						break;
					}
					if (curve != prevCurve) {
						prevCurve = curve;
						if (closed && curve == curveCount) {
							path.ComputeWorldVertices(target, verticesCount - 4, 4, world, 0, 2);
							path.ComputeWorldVertices(target, 0, 4, world, 4, 2);
						} else
							path.ComputeWorldVertices(target, curve * 6 + 2, 8, world, 0, 2);
					}
					AddCurvePosition(p, world[0], world[1], world[2], world[3], world[4], world[5], world[6], world[7], output, o,
						tangents || (i > 0 && space < PathConstraint.Epsilon));
				}
				return output;
			}

			// World vertices.
			if (closed) {
				verticesCount += 2;
				world = this.world..GrowUnitialized(verticesCount - this.world.Count).Ptr;
				path.ComputeWorldVertices(target, 2, verticesCount - 4, world, 0, 2);
				path.ComputeWorldVertices(target, 0, 2, world, verticesCount - 4, 2);
				world[verticesCount - 2] = world[0];
				world[verticesCount - 1] = world[1];
			} else {
				curveCount--;
				verticesCount -= 4;
				world = this.world..GrowUnitialized(verticesCount - this.world.Count).Ptr;
				path.ComputeWorldVertices(target, 2, verticesCount, world, 0, 2);
			}

			// Curve Counts.
			float* curves = this.curves..GrowUnitialized(curveCount - this.curves.Count).Ptr;
			pathCount = 0;
			float x1 = world[0], y1 = world[1], cx1 = 0, cy1 = 0, cx2 = 0, cy2 = 0, x2 = 0, y2 = 0;
			float tmpx, tmpy, dddfx, dddfy, ddfx, ddfy, dfx, dfy;
			for (int i = 0, int w = 2; i < curveCount; i++, w += 6) {
				cx1 = world[w];
				cy1 = world[w + 1];
				cx2 = world[w + 2];
				cy2 = world[w + 3];
				x2 = world[w + 4];
				y2 = world[w + 5];
				tmpx = (x1 - cx1 * 2 + cx2) * 0.1875f;
				tmpy = (y1 - cy1 * 2 + cy2) * 0.1875f;
				dddfx = ((cx1 - cx2) * 3 - x1 + x2) * 0.09375f;
				dddfy = ((cy1 - cy2) * 3 - y1 + y2) * 0.09375f;
				ddfx = tmpx * 2 + dddfx;
				ddfy = tmpy * 2 + dddfy;
				dfx = (cx1 - x1) * 0.75f + tmpx + dddfx * 0.16666667f;
				dfy = (cy1 - y1) * 0.75f + tmpy + dddfy * 0.16666667f;
				pathCount += Math.Sqrt(dfx * dfx + dfy * dfy);
				dfx += ddfx;
				dfy += ddfy;
				ddfx += dddfx;
				ddfy += dddfy;
				pathCount += Math.Sqrt(dfx * dfx + dfy * dfy);
				dfx += ddfx;
				dfy += ddfy;
				pathCount += Math.Sqrt(dfx * dfx + dfy * dfy);
				dfx += ddfx + dddfx;
				dfy += ddfy + dddfy;
				pathCount += Math.Sqrt(dfx * dfx + dfy * dfy);
				curves[i] = pathCount;
				x1 = x2;
				y1 = y2;
			}
			if (percentPosition)
				position *= pathCount;
			else
				position *= pathCount / path.lengths[curveCount - 1];

			if (percentSpacing) {
				for (int i = 1; i < spacesCount; i++)
					spacesItems[i] *= pathCount;
			}

			float[] segments = this.segments;
			float curveLength = 0;
			for (int i = 0, int o = 0, int curve = 0, int segment = 0; i < spacesCount; i++, o += 3) {
				float space = spacesItems[i];
				position += space;
				float p = position;

				if (closed) {
					p %= pathCount;
					if (p < 0) p += pathCount;
					curve = 0;
				} else if (p < 0) {
					AddBeforePosition(p, world, 0, output, o);
					continue;
				} else if (p > pathCount) {
					AddAfterPosition(p - pathCount, world, verticesCount - 4, output, o);
					continue;
				}

				// Determine curve containing position.
				for (;; curve++) {
					float Count = curves[curve];
					if (p > Count) continue;
					if (curve == 0)
						p /= Count;
					else {
						float prev = curves[curve - 1];
						p = (p - prev) / (Count - prev);
					}
					break;
				}

				// Curve segment Counts.
				if (curve != prevCurve) {
					prevCurve = curve;
					int ii = curve * 6;
					x1 = world[ii];
					y1 = world[ii + 1];
					cx1 = world[ii + 2];
					cy1 = world[ii + 3];
					cx2 = world[ii + 4];
					cy2 = world[ii + 5];
					x2 = world[ii + 6];
					y2 = world[ii + 7];
					tmpx = (x1 - cx1 * 2 + cx2) * 0.03f;
					tmpy = (y1 - cy1 * 2 + cy2) * 0.03f;
					dddfx = ((cx1 - cx2) * 3 - x1 + x2) * 0.006f;
					dddfy = ((cy1 - cy2) * 3 - y1 + y2) * 0.006f;
					ddfx = tmpx * 2 + dddfx;
					ddfy = tmpy * 2 + dddfy;
					dfx = (cx1 - x1) * 0.3f + tmpx + dddfx * 0.16666667f;
					dfy = (cy1 - y1) * 0.3f + tmpy + dddfy * 0.16666667f;
					curveLength = Math.Sqrt(dfx * dfx + dfy * dfy);
					segments[0] = curveLength;
					for (ii = 1; ii < 8; ii++) {
						dfx += ddfx;
						dfy += ddfy;
						ddfx += dddfx;
						ddfy += dddfy;
						curveLength += Math.Sqrt(dfx * dfx + dfy * dfy);
						segments[ii] = curveLength;
					}
					dfx += ddfx;
					dfy += ddfy;
					curveLength += Math.Sqrt(dfx * dfx + dfy * dfy);
					segments[8] = curveLength;
					dfx += ddfx + dddfx;
					dfy += ddfy + dddfy;
					curveLength += Math.Sqrt(dfx * dfx + dfy * dfy);
					segments[9] = curveLength;
					segment = 0;
				}

				// Weight by segment Count.
				p *= curveCount;
				for (;; segment++) {
					float Count = segments[segment];
					if (p > Count) continue;
					if (segment == 0)
						p /= Count;
					else {
						float prev = segments[segment - 1];
						p = segment + (p - prev) / (Count - prev);
					}
					break;
				}
				AddCurvePosition(p * 0.1f, x1, y1, cx1, cy1, cx2, cy2, x2, y2, output, o, tangents || (i > 0 && space < PathConstraint.Epsilon));
			}
			return output;
		}

		static void AddBeforePosition (float p, float* temp, int i, float* output, int o) {
			float x1 = temp[i], y1 = temp[i + 1], dx = temp[i + 2] - x1, dy = temp[i + 3] - y1, r = MathUtils.Atan2(dy, dx);
			output[o] = x1 + p * MathUtils.Cos(r);
			output[o + 1] = y1 + p * MathUtils.Sin(r);
			output[o + 2] = r;
		}

		static void AddAfterPosition (float p, float* temp, int i, float* output, int o) {
			float x1 = temp[i + 2], y1 = temp[i + 3], dx = x1 - temp[i], dy = y1 - temp[i + 1], r = MathUtils.Atan2(dy, dx);
			output[o] = x1 + p * MathUtils.Cos(r);
			output[o + 1] = y1 + p * MathUtils.Sin(r);
			output[o + 2] = r;
		}

		static void AddCurvePosition (float p, float x1, float y1, float cx1, float cy1, float cx2, float cy2, float x2, float y2,
			float* output, int o, bool tangents) {
			if (p < PathConstraint.Epsilon || p.IsNaN) {
				output[o] = x1;
				output[o + 1] = y1;
				output[o + 2] = Math.Atan2(cy1 - y1, cx1 - x1);
				return;
			}
			float tt = p * p, ttt = tt * p, u = 1 - p, uu = u * u, uuu = uu * u;
			float ut = u * p, ut3 = ut * 3, uut3 = u * ut3, utt3 = ut3 * p;
			float x = x1 * uuu + cx1 * uut3 + cx2 * utt3 + x2 * ttt, y = y1 * uuu + cy1 * uut3 + cy2 * utt3 + y2 * ttt;
			output[o] = x;
			output[o + 1] = y;
			if (tangents) {
				if (p < 0.001f)
					output[o + 2] = Math.Atan2(cy1 - y1, cx1 - x1);
				else
					output[o + 2] = Math.Atan2(y - (y1 * uu + cy1 * ut * 2 + cy2 * tt), x - (x1 * uu + cx1 * ut * 2 + cx2 * tt));
			}
		}

		/// <summary>The position along the path.</summary>
		public float Position { get { return position; } set { position = value; } }
		/// <summary>The spacing between bones.</summary>
		public float Spacing { get { return spacing; } set { spacing = value; } }
		/// <summary>A percentage (0-1) that controls the mix between the constrained and unconstrained rotations.</summary>
		public float RotateMix { get { return rotateMix; } set { rotateMix = value; } }
		/// <summary>A percentage (0-1) that controls the mix between the constrained and unconstrained translations.</summary>
		public float TranslateMix { get { return translateMix; } set { translateMix = value; } }
		/// <summary>The bones that will be modified by this path constraint.</summary>
		public List<Bone> Bones { get { return bones; } }
		/// <summary>The slot whose path attachment will be used to constrained the bones.</summary>
		public Slot Target { get { return target; } set { target = value; } }
		public bool Active { get { return active; } }
		/// <summary>The path constraint's setup pose data.</summary>
		public PathConstraintData Data { get { return data; } }
	}
}
