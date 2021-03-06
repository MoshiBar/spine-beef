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
using System.Collections;
using Spine.Collections;

namespace Spine {
	/// <summary>Stores attachments by slot index and attachment name.
	/// <para>See SkeletonData <see cref="Spine.SkeletonData.DefaultSkin"/>, Skeleton <see cref="Spine.Skeleton.Skin"/>, and
	/// <a href="http://esotericsoftware.com/spine-runtime-skins">Runtime skins</a> in the Spine Runtimes Guide.</para>
	/// </summary>
	public class Skin {
		public String name ~ delete _;
		private OrderedDictionary<SkinEntry, Attachment> attachments = new OrderedDictionary<SkinEntry, Attachment>(SkinEntryComparer.Instance) ~ delete _;
		public readonly List<BoneData> bones = new List<BoneData>() ~ delete _;
		public readonly List<ConstraintData> constraints = new List<ConstraintData>() ~ DeleteContainerAndItems!(_);

		public String Name => name;
		public OrderedDictionary<SkinEntry, Attachment> Attachments => attachments;
		public List<BoneData> Bones => bones;
		public List<ConstraintData> Constraints => constraints;

		public this (String name) {
			//if (name == null) throw new ArgumentNullException("name", "name cannot be null.");
			this.name = name;
		}

		public ~this(){
			for(var entry in attachments.Keys){
				delete entry.key.Attachment;
				delete entry.key.Name;
			}
		}

		/// <summary>Adds an attachment to the skin for the specified slot index and name.
		/// If the name already exists for the slot, the previous value is replaced.</summary>
		public void SetAttachment (int slotIndex, String name, Attachment attachment) {
			//if (attachment == null) throw new ArgumentNullException("attachment", "attachment cannot be null.");
			//if (slotIndex < 0) throw new ArgumentNullException("slotIndex", "slotIndex must be >= 0.");
			attachments[SkinEntry(slotIndex, name, attachment)] = attachment;
		}

		///<summary>Adds all attachments, bones, and constraints from the specified skin to this skin.</summary>
		public void AddSkin (Skin skin) {
			for (BoneData data in skin.bones)
				if (!bones.Contains(data)) bones.Add(data);

			for (ConstraintData data in skin.constraints)
				if (!constraints.Contains(data)) constraints.Add(data);

			for (SkinEntry entry in skin.attachments.Keys)
				SetAttachment(entry.SlotIndex, entry.Name, entry.Attachment);
		}

		///<summary>Adds all attachments from the specified skin to this skin. Attachments are deep copied.</summary>
		public void CopySkin (Skin skin) {
			for (BoneData data in skin.bones)
				if (!bones.Contains(data)) bones.Add(data);

			for (ConstraintData data in skin.constraints)
				if (!constraints.Contains(data)) constraints.Add(data);

			for (SkinEntry entry in skin.attachments.Keys) {
				if (entry.Attachment is MeshAttachment)
					SetAttachment(entry.SlotIndex, entry.Name,
						entry.Attachment != null ? ((MeshAttachment)entry.Attachment).NewLinkedMesh() : null);
				else
					SetAttachment(entry.SlotIndex, entry.Name, entry.Attachment != null ? entry.Attachment.Copy() : null);
			}
		}

		/// <summary>Returns the attachment for the specified slot index and name, or null.</summary>
		/// <returns>May be null.</returns>
		public Attachment GetAttachment (int slotIndex, String name) {
			var lookup = SkinEntry(slotIndex, name, null);
			Attachment attachment = null;
			bool containsKey = attachments.TryGetValue(lookup, out attachment);
			return containsKey ? attachment : null;
		}

		/// <summary> Removes the attachment in the skin for the specified slot index and name, if any.</summary>
		public void RemoveAttachment (int slotIndex, String name) {
			//if (slotIndex < 0) throw new ArgumentOutOfRangeException("slotIndex", "slotIndex must be >= 0");
			var lookup = SkinEntry(slotIndex, name, null);
			attachments.Remove(lookup);
		}

		///<summary>Returns all attachments contained in this skin.</summary>
		public ICollection<SkinEntry> GetAttachments () {
			return this.attachments.Keys;
		}

		/// <summary>Returns all attachments in this skin for the specified slot index.</summary>
		/// <param name="slotIndex">The target slotIndex. To find the slot index, use <see cref="Spine.Skeleton.FindSlotIndex"/> or <see cref="Spine.SkeletonData.FindSlotIndex"/>
		public void GetAttachments (int slotIndex, List<SkinEntry> attachments) {
			for (SkinEntry entry in this.attachments.Keys)
				if (entry.SlotIndex == slotIndex) attachments.Add(entry);
		}

		///<summary>Clears all attachments, bones, and constraints.</summary>
		public void Clear () {
			attachments.Clear();
			bones.Clear();
			constraints.Clear();
		}

		public String ToString () {
			return name;
		}

		/// <summary>Attach all attachments from this skin if the corresponding attachment from the old skin is currently attached.</summary>
		public void AttachAll (Skeleton skeleton, Skin oldSkin) {
			for (SkinEntry entry in oldSkin.attachments.Keys) {
				int slotIndex = entry.SlotIndex;
				Slot slot = skeleton.slots[slotIndex];
				if (slot.Attachment == entry.Attachment) {
					Attachment attachment = GetAttachment(slotIndex, entry.Name);
					if (attachment != null) slot.Attachment = attachment;
				}
			}
		}

		/// <summary>Stores an entry in the skin consisting of the slot index, name, and attachment.</summary>
		public struct SkinEntry : IHashable {
			private readonly int slotIndex;
			private readonly String name;
			private readonly Attachment attachment;
			public readonly int hashCode;

			public this (int slotIndex, String name, Attachment attachment) {
				this.slotIndex = slotIndex;
				this.name = name;
				this.attachment = attachment;
				this.hashCode = this.name.GetHashCode() + this.slotIndex * 37;
			}

			public int SlotIndex {
				get {
					return slotIndex;
				}
			}

			/// <summary>The name the attachment is associated with, equivalent to the skin placeholder name in the Spine editor.</summary>
			public String Name {
				get {
					return name;
				}
			}

			public Attachment Attachment {
				get {
					return attachment;
				}
			}
			public int GetHashCode()
			{
				return hashCode;
			}

			public static bool operator ==(SkinEntry a, SkinEntry b) => a.slotIndex == b.slotIndex && a.name == b.name;
		}

		// Avoids boxing in the dictionary and is necessary to omit entry.attachment in the comparison.
		class SkinEntryComparer : IEqualityComparer<SkinEntry> {
			public static readonly SkinEntryComparer Instance = new SkinEntryComparer() ~ delete _;

			bool IEqualityComparer<SkinEntry>.Equals (SkinEntry e1, SkinEntry e2) {
				if (e1.SlotIndex != e2.SlotIndex) return false;
				if (!String.Equals(e1.Name, e2.Name, StringComparison.Ordinal)) return false;
				return true;
			}

			int IEqualityComparer<SkinEntry>.GetHashCode (SkinEntry e) {
				return e.Name.GetHashCode() + e.SlotIndex * 37;
			}
		}
	}
}
