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

	/// <summary>Stores the setup pose and all of the stateless data for a skeleton.</summary>
	public class SkeletonData {
		public String name ~ delete _;
		public List<BoneData> bones = new List<BoneData>() ~ DeleteContainerAndItems!(_); // Ordered parents first
		public List<SlotData> slots = new List<SlotData>() ~ DeleteContainerAndItems!(_); // Setup pose draw order.
		public List<Skin> skins = new List<Skin>() ~ DeleteContainerAndItems!(_);
		public Skin defaultSkin;
		public List<EventData> events = new List<EventData>() ~ DeleteContainerAndItems!(_);
		public List<Animation> animations = new List<Animation>() ~ DeleteContainerAndItems!(_);
		public List<IkConstraintData> ikConstraints = new List<IkConstraintData>() ~ DeleteContainerAndItems!(_);
		public List<TransformConstraintData> transformConstraints = new List<TransformConstraintData>() ~ DeleteContainerAndItems!(_);
		public List<PathConstraintData> pathConstraints = new List<PathConstraintData>() ~ DeleteContainerAndItems!(_);
		public float x , y, width, height;
		public String version ~ delete _;
		public String hash ~ delete _;

		// Nonessential.
		public float fps;
		public String imagesPath ~ delete _;
		public String audioPath ~ delete _;

		public String Name { get { return name; } set { name = value; } }

		/// <summary>The skeleton's bones, sorted parent first. The root bone is always the first bone.</summary>
		public List<BoneData> Bones { get { return bones; } }

		public List<SlotData> Slots { get { return slots; } }

		/// <summary>All skins, including the default skin.</summary>
		public List<Skin> Skins { get { return skins; } set { skins = value; } }

		/// <summary>
		/// The skeleton's default skin.
		/// By default this skin contains all attachments that were not in a skin in Spine.
		/// </summary>
		/// <return>May be null.</return>
		public Skin DefaultSkin { get { return defaultSkin; } set { defaultSkin = value; } }

		public List<EventData> Events { get { return events; } set { events = value; } }
		public List<Animation> Animations { get { return animations; } set { animations = value; } }
		public List<IkConstraintData> IkConstraints { get { return ikConstraints; } set { ikConstraints = value; } }
		public List<TransformConstraintData> TransformConstraints { get { return transformConstraints; } set { transformConstraints = value; } }
		public List<PathConstraintData> PathConstraints { get { return pathConstraints; } set { pathConstraints = value; } }

		public float X { get { return x; } set { x = value; } }
		public float Y { get { return y; } set { y = value; } }
		public float Width { get { return width; } set { width = value; } }
		public float Height { get { return height; } set { height = value; } }
		/// <summary>The Spine version used to export this data, or null.</summary>
		public String Version { get { return version; } set { version = value; } }
		public String Hash { get { return hash; } set { hash = value; } }

		/// <summary>The path to the images directory as defined in Spine. Available only when nonessential data was exported. May be null</summary>
		public String ImagesPath { get { return imagesPath; } set { imagesPath = value; } }

		/// <summary>The path to the audio directory defined in Spine. Available only when nonessential data was exported. May be null.</summary>
		public String AudioPath { get { return audioPath; } set { audioPath = value; } }

		/// <summary>
		/// The dopesheet FPS in Spine. Available only when nonessential data was exported.</summary>
		public float Fps { get { return fps; } set { fps = value; } }

		// --- Bones.

		/// <summary>
		/// Finds a bone by comparing each bone's name.
		/// It is more efficient to cache the results of this method than to call it multiple times.</summary>
		/// <returns>May be null.</returns>
		public BoneData FindBone (String boneName) {
			//if (boneName == null) throw new ArgumentNullException("boneName", "boneName cannot be null.");
			var bones = this.bones;
			for (int i = 0, int n = bones.Count; i < n; i++) {
				BoneData bone = bones[i];
				if (bone.name == boneName) return bone;
			}
			return null;
		}

		/// <returns>-1 if the bone was not found.</returns>
		public int FindBoneIndex (String boneName) {
			//if (boneName == null) throw new ArgumentNullException("boneName", "boneName cannot be null.");
			var bones = this.bones;
			for (int i = 0, int n = bones.Count; i < n; i++)
				if (bones[i].name == boneName) return i;
			return -1;
		}

		// --- Slots.

		/// <returns>May be null.</returns>
		public SlotData FindSlot (String slotName) {
			//if (slotName == null) throw new ArgumentNullException("slotName", "slotName cannot be null.");
			List<SlotData> slots = this.slots;
			for (int i = 0, int n = slots.Count; i < n; i++) {
				SlotData slot = slots[i];
				if (slot.name == slotName) return slot;
			}
			return null;
		}

		/// <returns>-1 if the slot was not found.</returns>
		public int FindSlotIndex (String slotName) {
			//if (slotName == null) throw new ArgumentNullException("slotName", "slotName cannot be null.");
			List<SlotData> slots = this.slots;
			for (int i = 0, int n = slots.Count; i < n; i++)
				if (slots[i].name == slotName) return i;
			return -1;
		}

		// --- Skins.

		/// <returns>May be null.</returns>
		public Skin FindSkin (String skinName) {
			//if (skinName == null) throw new ArgumentNullException("skinName", "skinName cannot be null.");
			for (Skin skin in skins)
				if (skin.name == skinName) return skin;
			return null;
		}

		// --- Events.

		/// <returns>May be null.</returns>
		public EventData FindEvent (String eventDataName) {
			//if (eventDataName == null) throw new ArgumentNullException("eventDataName", "eventDataName cannot be null.");
			for (EventData eventData in events)
				if (eventData.name == eventDataName) return eventData;
			return null;
		}

		// --- Animations.

		/// <returns>May be null.</returns>
		public Animation FindAnimation (String animationName) {
			//if (animationName == null) throw new ArgumentNullException("animationName", "animationName cannot be null.");
			List<Animation> animations = this.animations;
			for (int i = 0, int n = animations.Count; i < n; i++) {
				Animation animation = animations[i];
				if (animation.name == animationName) return animation;
			}
			return null;
		}

		// --- IK constraints.

		/// <returns>May be null.</returns>
		public IkConstraintData FindIkConstraint (String constraintName) {
			//if (constraintName == null) throw new ArgumentNullException("constraintName", "constraintName cannot be null.");
			List<IkConstraintData> ikConstraints = this.ikConstraints;
			for (int i = 0, int n = ikConstraints.Count; i < n; i++) {
				IkConstraintData ikConstraint = ikConstraints[i];
				if (ikConstraint.name == constraintName) return ikConstraint;
			}
			return null;
		}

		// --- Transform constraints.

		/// <returns>May be null.</returns>
		public TransformConstraintData FindTransformConstraint (String constraintName) {
			//if (constraintName == null) throw new ArgumentNullException("constraintName", "constraintName cannot be null.");
			List<TransformConstraintData> transformConstraints = this.transformConstraints;
			for (int i = 0, int n = transformConstraints.Count; i < n; i++) {
				TransformConstraintData transformConstraint = transformConstraints[i];
				if (transformConstraint.name == constraintName) return transformConstraint;
			}
			return null;
		}

		// --- Path constraints.

		/// <returns>May be null.</returns>
		public PathConstraintData FindPathConstraint (String constraintName) {
			//if (constraintName == null) throw new ArgumentNullException("constraintName", "constraintName cannot be null.");
			List<PathConstraintData> pathConstraints = this.pathConstraints;
			for (int i = 0, int n = pathConstraints.Count; i < n; i++) {
				PathConstraintData constraint = pathConstraints[i];
				if (constraint.name.Equals(constraintName)) return constraint;
			}
			return null;
		}

		/// <returns>-1 if the path constraint was not found.</returns>
		public int FindPathConstraintIndex (String pathConstraintName) {
			//if (pathConstraintName == null) throw new ArgumentNullException("pathConstraintName", "pathConstraintName cannot be null.");
			List<PathConstraintData> pathConstraints = this.pathConstraints;
			for (int i = 0, int n = pathConstraints.Count; i < n; i++)
				if (pathConstraints[i].name.Equals(pathConstraintName)) return i;
			return -1;
		}

		// ---

		public new void ToString (String strBuffer) {
			if(name == null) base.ToString(strBuffer);
			else strBuffer.Append(name);
		}
	}
}
