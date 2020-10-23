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
	public class Skeleton {
		public SkeletonData data;
		public List<Bone> bones ~ DeleteContainerAndItems!(_);
		public List<Slot> slots ~ DeleteContainerAndItems!(_);
		public List<Slot> drawOrder ~ delete _;
		public List<IkConstraint> ikConstraints ~ DeleteContainerAndItems!(_);
		public List<TransformConstraint> transformConstraints ~ DeleteContainerAndItems!(_);
		public List<PathConstraint> pathConstraints ~ DeleteContainerAndItems!(_);
		public List<IUpdatable> updateCache = new List<IUpdatable>() ~ delete _;
		public List<Bone> updateCacheReset = new List<Bone>() ~ delete _;
		public Skin skin;
		public float r = 1, g = 1, b = 1, a = 1;
		public float time;
		private float scaleX = 1, scaleY = 1;
		public float x, y;

		public SkeletonData Data { get { return data; } }
		public List<Bone> Bones { get { return bones; } }
		public List<IUpdatable> UpdateCacheList { get { return updateCache; } }
		public List<Slot> Slots { get { return slots; } }
		public List<Slot> DrawOrder { get { return drawOrder; } }
		public List<IkConstraint> IkConstraints { get { return ikConstraints; } }
		public List<PathConstraint> PathConstraints { get { return pathConstraints; } }
		public List<TransformConstraint> TransformConstraints { get { return transformConstraints; } }
		public Skin Skin { get { return skin; } set { SetSkin(value); } }
		public float R { get { return r; } set { r = value; } }
		public float G { get { return g; } set { g = value; } }
		public float B { get { return b; } set { b = value; } }
		public float A { get { return a; } set { a = value; } }
		public float Time { get { return time; } set { time = value; } }
		public float X { get { return x; } set { x = value; } }
		public float Y { get { return y; } set { y = value; } }
		public float ScaleX { get { return scaleX; } set { scaleX = value; } }
		public float ScaleY { get { return scaleY * (Bone.yDown ? -1 : 1); } set { scaleY = value; } }

		//[Obsolete("Use ScaleX instead. FlipX is when ScaleX is negative.")]
		//public bool FlipX { get { return scaleX < 0; } set { scaleX = value ? -1f : 1f; } }

		//[Obsolete("Use ScaleY instead. FlipY is when ScaleY is negative.")]
		//public bool FlipY { get { return scaleY < 0; } set { scaleY = value ? -1f : 1f; } }

		public Bone RootBone {
			get { return bones.Count == 0 ? null : bones[0]; }
		}

		public this (SkeletonData data) {
			//if (data == null) throw new ArgumentNullException("data", "data cannot be null.");
			this.data = data;

			bones = new List<Bone>(data.bones.Count);
			for (BoneData boneData in data.bones) {
				Bone bone;
				if (boneData.parent == null) {
					bone = new Bone(boneData, this, null);
				} else {
					Bone parent = bones[boneData.parent.index];
					bone = new Bone(boneData, this, parent);
					parent.children.Add(bone);
				}
				bones.Add(bone);
			}

			slots = new List<Slot>(data.slots.Count);
			drawOrder = new List<Slot>(data.slots.Count);
			for (SlotData slotData in data.slots) {
				Bone bone = bones[slotData.boneData.index];
				Slot slot = new Slot(slotData, bone);
				slots.Add(slot);
				drawOrder.Add(slot);
			}

			ikConstraints = new List<IkConstraint>(data.ikConstraints.Count);
			for (IkConstraintData ikConstraintData in data.ikConstraints)
				ikConstraints.Add(new IkConstraint(ikConstraintData, this));

			transformConstraints = new List<TransformConstraint>(data.transformConstraints.Count);
			for (TransformConstraintData transformConstraintData in data.transformConstraints)
				transformConstraints.Add(new TransformConstraint(transformConstraintData, this));

			pathConstraints = new List<PathConstraint> (data.pathConstraints.Count);
			for (PathConstraintData pathConstraintData in data.pathConstraints)
				pathConstraints.Add(new PathConstraint(pathConstraintData, this));

			UpdateCache();
			UpdateWorldTransform();
		}

		/// <summary>Caches information about bones and constraints. Must be called if the <see cref="Skin"/> is modified or if bones, constraints, or
		/// constraints, or weighted path attachments are added or removed.</summary>
		public void UpdateCache () {
			var updateCache = this.updateCache;
			updateCache.Clear();
			this.updateCacheReset.Clear();

			int boneCount = this.bones.Count;
			var bones = this.bones;
			for (int i = 0; i < boneCount; i++) {
				Bone bone = bones[i];
				bone.sorted = bone.data.skinRequired;
				bone.active = !bone.sorted;
			}
			if (skin != null) {
				Object* skinBones = skin.bones.Ptr;
				for (int i = 0, int n = skin.bones.Count; i < n; i++) {
					Bone bone = (Bone)bones[((BoneData)skinBones[i]).index];
					do repeat {
						bone.sorted = false;
						bone.active = true;
						bone = bone.parent;
					} while (bone != null);
				}
			}

			int ikCount = this.ikConstraints.Count, transformCount = this.transformConstraints.Count, pathCount = this.pathConstraints.Count;
			var ikConstraints = this.ikConstraints;
			var transformConstraints = this.transformConstraints;
			var pathConstraints = this.pathConstraints;
			int constraintCount = ikCount + transformCount + pathCount;
			//outer:
			for (int i = 0; i < constraintCount; i++) {
				a: for (int ii = 0; ii < ikCount; ii++) {
					IkConstraint constraint = ikConstraints[ii];
					if (constraint.data.order == i) {
						SortIkConstraint(constraint);
						break a; //goto continue_outer; //continue outer;
					}
				}
				a: for (int ii = 0; ii < transformCount; ii++) {
					TransformConstraint constraint = transformConstraints[ii];
					if (constraint.data.order == i) {
						SortTransformConstraint(constraint);
						break; //goto continue_outer; //continue outer;
					}
				}
				a: for (int ii = 0; ii < pathCount; ii++) {
					PathConstraint constraint = pathConstraints[ii];
					if (constraint.data.order == i) {
						SortPathConstraint(constraint);
						break a; //goto continue_outer; //continue outer;
					}
				}
				//continue_outer: {}
			}

			for (int i = 0; i < boneCount; i++)
				SortBone(bones[i]);
		}

		private void SortIkConstraint (IkConstraint constraint) {
			constraint.active = constraint.target.active
				&& (!constraint.data.skinRequired || (skin != null && skin.constraints.Contains(constraint.data)));
			if (!constraint.active) return;

			Bone target = constraint.target;
			SortBone(target);

			var constrained = constraint.bones;
			Bone parent = constrained[0];
			SortBone(parent);

			if (constrained.Count > 1) {
				Bone child = constrained[constrained.Count - 1];
				if (!updateCache.Contains(child))
					updateCacheReset.Add(child);
			}

			updateCache.Add(constraint);

			SortReset(parent.children);
			constrained[constrained.Count - 1].sorted = true;
		}

		private void SortPathConstraint (PathConstraint constraint) {
			constraint.active = constraint.target.bone.active
				&& (!constraint.data.skinRequired || (skin != null && skin.constraints.Contains(constraint.data)));
			if (!constraint.active) return;

			Slot slot = constraint.target;
			int slotIndex = slot.data.index;
			Bone slotBone = slot.bone;
			if (skin != null) SortPathConstraintAttachment(skin, slotIndex, slotBone);
			if (data.defaultSkin != null && data.defaultSkin != skin)
				SortPathConstraintAttachment(data.defaultSkin, slotIndex, slotBone);

			Attachment attachment = slot.attachment;
			if (attachment is PathAttachment) SortPathConstraintAttachment(attachment, slotBone);

			var constrained = constraint.bones;
			int boneCount = constrained.Count;
			for (int i = 0; i < boneCount; i++)
				SortBone(constrained[i]);

			updateCache.Add(constraint);

			for (int i = 0; i < boneCount; i++)
				SortReset(constrained[i].children);
			for (int i = 0; i < boneCount; i++)
				constrained[i].sorted = true;
		}

		private void SortTransformConstraint (TransformConstraint constraint) {
			constraint.active = constraint.target.active
				&& (!constraint.data.skinRequired || (skin != null && skin.constraints.Contains(constraint.data)));
			if (!constraint.active) return;

			SortBone(constraint.target);

			var constrained = constraint.bones;
			int boneCount = constrained.Count;
			if (constraint.data.local) {
				for (int i = 0; i < boneCount; i++) {
					Bone child = constrained[i];
					SortBone(child.parent);
					if (!updateCache.Contains(child)) updateCacheReset.Add(child);
				}
			} else {
				for (int i = 0; i < boneCount; i++)
					SortBone(constrained[i]);
			}

			updateCache.Add(constraint);

			for (int i = 0; i < boneCount; i++)
				SortReset(constrained[i].children);
			for (int i = 0; i < boneCount; i++)
				constrained[i].sorted = true;
		}

		private void SortPathConstraintAttachment (Skin skin, int slotIndex, Bone slotBone) {
			for (var entryObj in skin.Attachments.Keys) {
				var entry = (Skin.SkinEntry)entryObj.key;
				if (entry.SlotIndex == slotIndex) SortPathConstraintAttachment(entry.Attachment, slotBone);
			}
		}

		private void SortPathConstraintAttachment (Attachment attachment, Bone slotBone) {
			if (!(attachment is PathAttachment)) return;
			int[] pathBones = ((PathAttachment)attachment).bones;
			if (pathBones == null)
				SortBone(slotBone);
			else {
				var bones = this.bones;
				for (int i = 0, int n = pathBones.Count; i < n;) {
					int nn = pathBones[i++];
					nn += i;
					while (i < nn)
						SortBone(bones[pathBones[i++]]);
				}
			}
		}

		private void SortBone (Bone bone) {
			if (bone.sorted) return;
			Bone parent = bone.parent;
			if (parent != null) SortBone(parent);
			bone.sorted = true;
			updateCache.Add(bone);
		}

		private static void SortReset (List<Bone> bones) {
			var bonesItems = bones;
			for (int i = 0, int n = bones.Count; i < n; i++) {
				Bone bone = bonesItems[i];
				if (!bone.active) continue;
				if (bone.sorted) SortReset(bone.children);
				bone.sorted = false;
			}
		}

		/// <summary>Updates the world transform for each bone and applies constraints.</summary>
		public void UpdateWorldTransform () {
			var updateCacheReset = this.updateCacheReset;
			var updateCacheResetItems = updateCacheReset;
			for (int i = 0, int n = updateCacheReset.Count; i < n; i++) {
				Bone bone = updateCacheResetItems[i];
				bone.ax = bone.x;
				bone.ay = bone.y;
				bone.arotation = bone.rotation;
				bone.ascaleX = bone.scaleX;
				bone.ascaleY = bone.scaleY;
				bone.ashearX = bone.shearX;
				bone.ashearY = bone.shearY;
				bone.appliedValid = true;
			}
			var updateItems = this.updateCache;
			for (int i = 0, int n = updateCache.Count; i < n; i++)
				updateItems[i].Update();
		}

		/// <summary>
		/// Temporarily sets the root bone as a child of the specified bone, then updates the world transform for each bone and applies
		/// all constraints.
	 	/// </summary>
		public void UpdateWorldTransform (Bone parent) {
			// This partial update avoids computing the world transform for constrained bones when 1) the bone is not updated
			// before the constraint, 2) the constraint only needs to access the applied local transform, and 3) the constraint calls
			// updateWorldTransform.
			var updateCacheReset = this.updateCacheReset;
			var updateCacheResetItems = updateCacheReset;
			for (int i = 0, int n = updateCacheReset.Count; i < n; i++) {
				Bone bone = updateCacheResetItems[i];
				bone.ax = bone.x;
				bone.ay = bone.y;
				bone.arotation = bone.rotation;
				bone.ascaleX = bone.scaleX;
				bone.ascaleY = bone.scaleY;
				bone.ashearX = bone.shearX;
				bone.ashearY = bone.shearY;
				bone.appliedValid = true;
			}

			// Apply the parent bone transform to the root bone. The root bone always inherits scale, rotation and reflection.
			Bone rootBone = this.RootBone;
			float pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d;
			rootBone.worldX = pa * x + pb * y + parent.worldX;
			rootBone.worldY = pc * x + pd * y + parent.worldY;

			float rotationY = rootBone.rotation + 90 + rootBone.shearY;
			float la = MathUtils.CosDeg(rootBone.rotation + rootBone.shearX) * rootBone.scaleX;
			float lb = MathUtils.CosDeg(rotationY) * rootBone.scaleY;
			float lc = MathUtils.SinDeg(rootBone.rotation + rootBone.shearX) * rootBone.scaleX;
			float ld = MathUtils.SinDeg(rotationY) * rootBone.scaleY;
			rootBone.a = (pa * la + pb * lc) * scaleX;
			rootBone.b = (pa * lb + pb * ld) * scaleX;
			rootBone.c = (pc * la + pd * lc) * scaleY;
			rootBone.d = (pc * lb + pd * ld) * scaleY;

			// Update everything except root bone.
			var updateCache = this.updateCache;
			var updateCacheItems = updateCache;
			for (int i = 0, int n = updateCache.Count; i < n; i++) {
				var updatable = updateCacheItems[i];
				if (updatable != rootBone)
					updatable.Update();
			}
		}

		/// <summary>Sets the bones, constraints, and slots to their setup pose values.</summary>
		public void SetToSetupPose () {
			SetBonesToSetupPose();
			SetSlotsToSetupPose();
		}

		/// <summary>Sets the bones and constraints to their setup pose values.</summary>
		public void SetBonesToSetupPose () {
			var bonesItems = this.bones;
			for (int i = 0, int n = bones.Count; i < n; i++)
				bonesItems[i].SetToSetupPose();

			var ikConstraintsItems = this.ikConstraints;
			for (int i = 0, int n = ikConstraints.Count; i < n; i++) {
				IkConstraint constraint = ikConstraintsItems[i];
				constraint.mix = constraint.data.mix;
				constraint.softness = constraint.data.softness;
				constraint.bendDirection = constraint.data.bendDirection;
				constraint.compress = constraint.data.compress;
				constraint.stretch = constraint.data.stretch;
			}

			var transformConstraintsItems = this.transformConstraints;
			for (int i = 0, int n = transformConstraints.Count; i < n; i++) {
				TransformConstraint constraint = transformConstraintsItems[i];
				TransformConstraintData constraintData = constraint.data;
				constraint.rotateMix = constraintData.rotateMix;
				constraint.translateMix = constraintData.translateMix;
				constraint.scaleMix = constraintData.scaleMix;
				constraint.shearMix = constraintData.shearMix;
			}

			var pathConstraintItems = this.pathConstraints;
			for (int i = 0, int n = pathConstraints.Count; i < n; i++) {
				PathConstraint constraint = pathConstraintItems[i];
				PathConstraintData constraintData = constraint.data;
				constraint.position = constraintData.position;
				constraint.spacing = constraintData.spacing;
				constraint.rotateMix = constraintData.rotateMix;
				constraint.translateMix = constraintData.translateMix;
			}
		}

		public void SetSlotsToSetupPose () {
			var slots = this.slots;
			drawOrder.Clear();
			for (int i = 0, int n = slots.Count; i < n; i++)
				drawOrder.Add(slots[i]);

			for (int i = 0, int n = slots.Count; i < n; i++)
				slots[i].SetToSetupPose();
		}

		/// <returns>May be null.</returns>
		public Bone FindBone (String boneName) {
			//if (boneName == null) throw new ArgumentNullException("boneName", "boneName cannot be null.");
			var bones = this.bones;
			for (int i = 0, int n = bones.Count; i < n; i++) {
				Bone bone = bones[i];
				if (bone.data.name == boneName) return bone;
			}
			return null;
		}

		/// <returns>-1 if the bone was not found.</returns>
		public int FindBoneIndex (String boneName) {
			//if (boneName == null) throw new ArgumentNullException("boneName", "boneName cannot be null.");
			var bones = this.bones;
			var bonesItems = bones;
			for (int i = 0, int n = bones.Count; i < n; i++)
				if (bonesItems[i].data.name == boneName) return i;
			return -1;
		}

		/// <returns>May be null.</returns>
		public Slot FindSlot (String slotName) {
			//if (slotName == null) throw new ArgumentNullException("slotName", "slotName cannot be null.");
			var slots = this.slots;
			for (int i = 0, int n = slots.Count; i < n; i++) {
				Slot slot = slots[i];
				if (slot.data.name == slotName) return slot;
			}
			return null;
		}

		/// <returns>-1 if the bone was not found.</returns>
		public int FindSlotIndex (String slotName) {
			//if (slotName == null) throw new ArgumentNullException("slotName", "slotName cannot be null.");
			var slots = this.slots;
			for (int i = 0, int n = slots.Count; i < n; i++)
				if (slots[i].data.name.Equals(slotName)) return i;
			return -1;
		}

		/// <summary>Sets a skin by name (see SetSkin).</summary>
		public void SetSkin (String skinName) {
			Skin foundSkin = data.FindSkin(skinName);
			//if (foundSkin == null) throw new ArgumentException("Skin not found: " + skinName, "skinName");
			SetSkin(foundSkin);
		}

		/// <summary>
		/// <para>Sets the skin used to look up attachments before looking in the <see cref="SkeletonData.DefaultSkin"/>. If the
		/// skin is changed, <see cref="UpdateCache()"/> is called.
		/// </para>
	 	/// <para>Attachments from the new skin are attached if the corresponding attachment from the old skin was attached.
		/// If there was no old skin, each slot's setup mode attachment is attached from the new skin.
		/// </para>
		/// <para>After changing the skin, the visible attachments can be reset to those attached in the setup pose by calling
		/// <see cref="Skeleton.SetSlotsToSetupPose()"/>.
		/// Also, often <see cref="AnimationState.Apply(Skeleton)"/> is called before the next time the
		/// skeleton is rendered to allow any attachment keys in the current animation(s) to hide or show attachments from the new skin.</para>
		/// </summary>
		/// <param name="newSkin">May be null.</param>
		public void SetSkin (Skin newSkin) {
			if (newSkin == skin) return;
			if (newSkin != null) {
				if (skin != null)
					newSkin.AttachAll(this, skin);
				else {
					List<Slot> slots = this.slots;
					for (int i = 0, int n = slots.Count; i < n; i++) {
						Slot slot = slots[i];
						String name = slot.data.attachmentName;
						if (name != null && name.Length > 0) {
							Attachment attachment = newSkin.GetAttachment(i, name);
							if (attachment != null) slot.Attachment = attachment;
						}
					}
				}
			}
			skin = newSkin;
			UpdateCache();
		}

		/// <summary>Finds an attachment by looking in the {@link #skin} and {@link SkeletonData#defaultSkin} using the slot name and attachment name.</summary>
		/// <returns>May be null.</returns>
		public Attachment GetAttachment (String slotName, String attachmentName) {
			return GetAttachment(data.FindSlotIndex(slotName), attachmentName);
		}

		/// <summary>Finds an attachment by looking in the skin and skeletonData.defaultSkin using the slot index and attachment name.First the skin is checked and if the attachment was not found, the default skin is checked.</summary>
		/// <returns>May be null.</returns>
		public Attachment GetAttachment (int slotIndex, String attachmentName) {
			//if (attachmentName == null) throw new ArgumentNullException("attachmentName", "attachmentName cannot be null.");
			if (skin != null) {
				Attachment attachment = skin.GetAttachment(slotIndex, attachmentName);
				if (attachment != null) return attachment;
			}
			return data.defaultSkin != null ? data.defaultSkin.GetAttachment(slotIndex, attachmentName) : null;
		}

		/// <summary>A convenience method to set an attachment by finding the slot with FindSlot, finding the attachment with GetAttachment, then setting the slot's slot.Attachment.</summary>
		/// <param name="attachmentName">May be null to clear the slot's attachment.</param>
		public void SetAttachment (String slotName, String attachmentName) {
			//if (slotName == null) throw new ArgumentNullException("slotName", "slotName cannot be null.");
			List<Slot> slots = this.slots;
			for (int i = 0, int n = slots.Count; i < n; i++) {
				Slot slot = slots[i];
				if (slot.data.name == slotName) {
					Attachment attachment = null;
					if (attachmentName != null) {
						attachment = GetAttachment(i, attachmentName);
						//if (attachment == null) throw new Exception("Attachment not found: " + attachmentName + ", for slot: " + slotName);
					}
					slot.Attachment = attachment;
					return;
				}
			}
			//throw new Exception("Slot not found: " + slotName);
		}

		/// <returns>May be null.</returns>
		public IkConstraint FindIkConstraint (String constraintName) {
			//if (constraintName == null) throw new ArgumentNullException("constraintName", "constraintName cannot be null.");
			List<IkConstraint> ikConstraints = this.ikConstraints;
			for (int i = 0, int n = ikConstraints.Count; i < n; i++) {
				IkConstraint ikConstraint = ikConstraints[i];
				if (ikConstraint.data.name == constraintName) return ikConstraint;
			}
			return null;
		}

		/// <returns>May be null.</returns>
		public TransformConstraint FindTransformConstraint (String constraintName) {
			//if (constraintName == null) throw new ArgumentNullException("constraintName", "constraintName cannot be null.");
			List<TransformConstraint> transformConstraints = this.transformConstraints;
			for (int i = 0, int n = transformConstraints.Count; i < n; i++) {
				TransformConstraint transformConstraint = transformConstraints[i];
				if (transformConstraint.data.Name == constraintName) return transformConstraint;
			}
			return null;
		}

		/// <returns>May be null.</returns>
		public PathConstraint FindPathConstraint (String constraintName) {
			//if (constraintName == null) throw new ArgumentNullException("constraintName", "constraintName cannot be null.");
			List<PathConstraint> pathConstraints = this.pathConstraints;
			for (int i = 0, int n = pathConstraints.Count; i < n; i++) {
				PathConstraint constraint = pathConstraints[i];
				if (constraint.data.Name.Equals(constraintName)) return constraint;
			}
			return null;
		}

		public void Update (float delta) {
			time += delta;
		}

		/// <summary>Returns the axis aligned bounding box (AABB) of the region and mesh attachments for the current pose.</summary>
		/// <param name="x">The horizontal distance between the skeleton origin and the left side of the AABB.</param>
		/// <param name="y">The vertical distance between the skeleton origin and the bottom side of the AABB.</param>
		/// <param name="width">The width of the AABB</param>
		/// <param name="height">The height of the AABB.</param>
		/// <param name="vertexBuffer">Reference to hold a float[]. May be a null reference. This method will assign it a new float[] with the appropriate size as needed.</param>
		public void GetBounds (out float x, out float y, out float width, out float height, ref float[] vertexBuffer) {
			float[] temp = vertexBuffer;
			temp = temp ?? new float[8];
			var drawOrderItems = this.drawOrder;
			float minX = int32.MaxValue, minY = int32.MaxValue, maxX = int32.MinValue, maxY = int32.MinValue;
			for (int i = 0, int n = drawOrderItems.Count; i < n; i++) {
				Slot slot = drawOrderItems[i];
				if (!slot.bone.active) continue;
				int verticesCount = 0;
				float[] vertices = null;
				Attachment attachment = slot.attachment;
				var regionAttachment = attachment as RegionAttachment;
				if (regionAttachment != null) {
					verticesCount = 8;
					vertices = temp;
					if (vertices.Count < 8) vertices = temp = new float[8];
					regionAttachment.ComputeWorldVertices(slot.bone, temp, 0);
				} else {
					var meshAttachment = attachment as MeshAttachment;
					if (meshAttachment != null) {
						MeshAttachment mesh = meshAttachment;
						verticesCount = mesh.WorldVerticesCount;
						vertices = temp;
						if (vertices.Count < verticesCount) vertices = temp = new float[verticesCount];
						mesh.ComputeWorldVertices(slot, 0, verticesCount, &temp[0], 0);
					}
				}

				if (vertices != null) {
					for (int ii = 0; ii < verticesCount; ii += 2) {
						float vx = vertices[ii], vy = vertices[ii + 1];
						minX = Math.Min(minX, vx);
						minY = Math.Min(minY, vy);
						maxX = Math.Max(maxX, vx);
						maxY = Math.Max(maxY, vy);
					}
				}
			}
			x = minX;
			y = minY;
			width = maxX - minX;
			height = maxY - minY;
			vertexBuffer = temp;
		}

		[Export, LinkName("Skeleton_GetSlot")]
		public Slot GetSlot(int index) => slots[index];
	}
}
