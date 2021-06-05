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
using System.IO;
using System.Collections;

namespace Spine {
	public class SkeletonJson {
		public float Scale { get; set; }

		private AttachmentLoader attachmentLoader;
		private List<LinkedMesh> linkedMeshes = new List<LinkedMesh>() ~ DeleteContainerAndItems!(_);

		public this (params Atlas[] atlasArray)
			: this(new AtlasAttachmentLoader(atlasArray)) {
		}

		public this (AttachmentLoader attachmentLoader) {
			//if (attachmentLoader == null) throw new ArgumentNullException("attachmentLoader", "attachmentLoader cannot be null.");
			this.attachmentLoader = attachmentLoader;
			Scale = 1;
		}

		public SkeletonData ReadSkeletonData (String path)
		{
			//using (var reader = new StreamReader(new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read)))
			var reader = scope StreamReader();
			reader.Open(path);

			SkeletonData skeletonData = ReadSkeletonData(reader);
			String name = new String();
			Path.GetFileNameWithoutExtension(path, name);
			skeletonData.name = name;
			return skeletonData;
		}

		public SkeletonData ReadSkeletonData (StreamReader reader) {
			//if (reader == null) throw new ArgumentNullException("reader", "reader cannot be null.");

			float scale = this.Scale;
			var skeletonData = new SkeletonData();

			var root = Json.Deserialize(reader) as Dictionary<String, Object>;
			//if (root == null) throw new Exception("Invalid JSON.");

			// Skeleton.
			if (root.ContainsKey("skeleton")) {
				var skeletonMap = (Dictionary<String, Object>)root["skeleton"];
				skeletonData.hash = (String)skeletonMap["hash"];
				skeletonData.version = (String)skeletonMap["spine"];
				//if ("3.8.75" == skeletonData.version)
					//throw new Exception("Unsupported skeleton data, please export with a newer version of Spine.");
				skeletonData.x = GetFloat(skeletonMap, "x", 0);
				skeletonData.y = GetFloat(skeletonMap, "y", 0);
				skeletonData.width = GetFloat(skeletonMap, "width", 0);
				skeletonData.height = GetFloat(skeletonMap, "height", 0);
				skeletonData.fps = GetFloat(skeletonMap, "fps", 30);
				skeletonData.imagesPath = GetString(skeletonMap, "images", null);
				skeletonData.audioPath = GetString(skeletonMap, "audio", null);
			}

			// Bones.
			if (root.ContainsKey("bones")) {
				for (Dictionary<String, Object> boneMap in (List<Object>)root["bones"]) {
					BoneData parent = null;
					if (boneMap.ContainsKey("parent")) {
						parent = skeletonData.FindBone((String)boneMap["parent"]);
						//if (parent == null)
						//	throw new Exception("Parent bone not found: " + boneMap["parent"]);
					}
					var data = new BoneData(skeletonData.Bones.Count, (String)boneMap["name"], parent);
					data.Length = GetFloat(boneMap, "Count", 0) * scale;
					data.x = GetFloat(boneMap, "x", 0) * scale;
					data.y = GetFloat(boneMap, "y", 0) * scale;
					data.rotation = GetFloat(boneMap, "rotation", 0);
					data.scaleX = GetFloat(boneMap, "scaleX", 1);
					data.scaleY = GetFloat(boneMap, "scaleY", 1);
					data.shearX = GetFloat(boneMap, "shearX", 0);
					data.shearY = GetFloat(boneMap, "shearY", 0);

					String toStr = scope String();
					TransformMode.Normal.ToString(toStr);

					String tm = GetString(boneMap, "transform", toStr);
					data.transformMode = Enum.Parse<TransformMode>(tm, true);
					data.skinRequired = GetBoolean(boneMap, "skin", false);

					skeletonData.bones.Add(data);
				}
			}

			// Slots.
			if (root.ContainsKey("slots")) {
				for (Dictionary<String, Object> slotMap in (List<Object>)root["slots"]) {
					var slotName = (String)slotMap["name"];
					var boneName = (String)slotMap["bone"];
					BoneData boneData = skeletonData.FindBone(boneName);
					//if (boneData == null) throw new Exception("Slot bone not found: " + boneName);
					var data = new SlotData(skeletonData.Slots.Count, slotName, boneData);

					if (slotMap.ContainsKey("color")) {
						String color = (String)slotMap["color"];
						data.r = ToColor(color, 0);
						data.g = ToColor(color, 1);
						data.b = ToColor(color, 2);
						data.a = ToColor(color, 3);
					}

					if (slotMap.ContainsKey("dark")) {
						var color2 = (String)slotMap["dark"];
						data.r2 = ToColor(color2, 0, 6); // expectedCount = 6. ie. "RRGGBB"
						data.g2 = ToColor(color2, 1, 6);
						data.b2 = ToColor(color2, 2, 6);
						data.hasSecondColor = true;
					}

					data.attachmentName = GetString(slotMap, "attachment", null);
					if (slotMap.ContainsKey("blend"))
						data.blendMode = Enum.Parse<BlendMode>((String)slotMap["blend"], true);
					else
						data.blendMode = BlendMode.Normal;
					skeletonData.slots.Add(data);
				}
			}

			// IK constraints.
			if (root.ContainsKey("ik")) {
				for (Dictionary<String, Object> constraintMap in (List<Object>)root["ik"]) {
					IkConstraintData data = new IkConstraintData((String)constraintMap["name"]);
					data.order = GetInt(constraintMap, "order", 0);
					data.skinRequired = GetBoolean(constraintMap,"skin", false);

					if (constraintMap.ContainsKey("bones")) {
						List<Object> boneList = (List<Object>)constraintMap["bones"];
						var bones = new BoneData[boneList.Count];
						for(int i < boneList.Count) {
							BoneData bone = skeletonData.FindBone((String)boneList[i]);
							//if (bone == null) throw new Exception("IK bone not found: " + boneName);
							data.bones[i] = bone;
						}
						data.bones = bones;
					}

					String targetName = (String)constraintMap["target"];
					data.target = skeletonData.FindBone(targetName);
					//if (data.target == null) throw new Exception("IK target bone not found: " + targetName);
					data.mix = GetFloat(constraintMap, "mix", 1);
					data.softness = GetFloat(constraintMap, "softness", 0) * scale;
					data.bendDirection = GetBoolean(constraintMap, "bendPositive", true) ? 1 : -1;
					data.compress = GetBoolean(constraintMap, "compress", false);
					data.stretch = GetBoolean(constraintMap, "stretch", false);
					data.uniform = GetBoolean(constraintMap, "uniform", false);

					skeletonData.ikConstraints.Add(data);
				}
			}

			// Transform constraints.
			if (root.ContainsKey("transform")) {
				for (Dictionary<String, Object> constraintMap in (List<Object>)root["transform"]) {
					TransformConstraintData data = new TransformConstraintData((String)constraintMap["name"]);
					data.order = GetInt(constraintMap, "order", 0);
					data.skinRequired = GetBoolean(constraintMap,"skin", false);

					if (constraintMap.ContainsKey("bones")) {
						List<Object> boneList = (List<Object>)constraintMap["bones"];
						var bones = new BoneData[boneList.Count];
						for(int i < boneList.Count) {
							BoneData bone = skeletonData.FindBone((String)boneList[i]);
							data.bones[i] = bone;
						}
						data.bones = bones;
					}

					String targetName = (String)constraintMap["target"];
					data.target = skeletonData.FindBone(targetName);
					//if (data.target == null) throw new Exception("Transform constraint target bone not found: " + targetName);

					data.local = GetBoolean(constraintMap, "local", false);
					data.relative = GetBoolean(constraintMap, "relative", false);

					data.offsetRotation = GetFloat(constraintMap, "rotation", 0);
					data.offsetX = GetFloat(constraintMap, "x", 0) * scale;
					data.offsetY = GetFloat(constraintMap, "y", 0) * scale;
					data.offsetScaleX = GetFloat(constraintMap, "scaleX", 0);
					data.offsetScaleY = GetFloat(constraintMap, "scaleY", 0);
					data.offsetShearY = GetFloat(constraintMap, "shearY", 0);

					data.rotateMix = GetFloat(constraintMap, "rotateMix", 1);
					data.translateMix = GetFloat(constraintMap, "translateMix", 1);
					data.scaleMix = GetFloat(constraintMap, "scaleMix", 1);
					data.shearMix = GetFloat(constraintMap, "shearMix", 1);

					skeletonData.transformConstraints.Add(data);
				}
			}

			// Path constraints.
			if(root.ContainsKey("path")) {
				for (Dictionary<String, Object> constraintMap in (List<Object>)root["path"]) {
					PathConstraintData data = new PathConstraintData((String)constraintMap["name"]);
					data.order = GetInt(constraintMap, "order", 0);
					data.skinRequired = GetBoolean(constraintMap,"skin", false);

					if (constraintMap.ContainsKey("bones")) {
						List<Object> boneList = (List<Object>)constraintMap["bones"];
						var bones = new BoneData[boneList.Count];
						for(int i < boneList.Count) {
							BoneData bone = skeletonData.FindBone((String)boneList[i]);
							data.bones[i] = bone;
						}
						data.bones = bones;
					}

					String targetName = (String)constraintMap["target"];
					data.target = skeletonData.FindSlot(targetName);
					//if (data.target == null) throw new Exception("Path target slot not found: " + targetName);

					data.positionMode = Enum.Parse<PositionMode>(GetString(constraintMap, "positionMode", "percent"), true);
					data.spacingMode = Enum.Parse<SpacingMode>(GetString(constraintMap, "spacingMode", "Count"), true);
					data.rotateMode = Enum.Parse<RotateMode>(GetString(constraintMap, "rotateMode", "tangent"), true);
					data.offsetRotation = GetFloat(constraintMap, "rotation", 0);
					data.position = GetFloat(constraintMap, "position", 0);
					if (data.positionMode == PositionMode.Fixed) data.position *= scale;
					data.spacing = GetFloat(constraintMap, "spacing", 0);
					if (data.spacingMode == SpacingMode.Count || data.spacingMode == SpacingMode.Fixed) data.spacing *= scale;
					data.rotateMix = GetFloat(constraintMap, "rotateMix", 1);
					data.translateMix = GetFloat(constraintMap, "translateMix", 1);

					skeletonData.pathConstraints.Add(data);
				}
			}

			// Skins.
			if (root.ContainsKey("skins")) {
				for (Dictionary<String, Object> skinMap in (List<Object>)root["skins"]) {
					Skin skin = new Skin((String)skinMap["name"]);
					if (skinMap.ContainsKey("bones")) {
						for (String entryName in (List<Object>)skinMap["bones"]) {
							BoneData bone = skeletonData.FindBone(entryName);
							//if (bone == null) throw new Exception("Skin bone not found: " + entryName);
							skin.bones.Add(bone);
						}
					}
					if (skinMap.ContainsKey("ik")) {
						for (String entryName in (List<Object>)skinMap["ik"]) {
							IkConstraintData constraint = skeletonData.FindIkConstraint(entryName);
							//if (constraint == null) throw new Exception("Skin IK constraint not found: " + entryName);
							skin.constraints.Add(constraint);
						}
					}
					if (skinMap.ContainsKey("transform")) {
						for (String entryName in (List<Object>)skinMap["transform"]) {
							TransformConstraintData constraint = skeletonData.FindTransformConstraint(entryName);
							//if (constraint == null) throw new Exception("Skin transform constraint not found: " + entryName);
							skin.constraints.Add(constraint);
						}
					}
					if (skinMap.ContainsKey("path")) {
						for (String entryName in (List<Object>)skinMap["path"]) {
							PathConstraintData constraint = skeletonData.FindPathConstraint(entryName);
							//if (constraint == null) throw new Exception("Skin path constraint not found: " + entryName);
							skin.constraints.Add(constraint);
						}
					}
					if (skinMap.ContainsKey("attachments")) {
						for ((String, Object) slotEntry in (Dictionary<String, Object>)skinMap["attachments"]) {
							int slotIndex = skeletonData.FindSlotIndex(slotEntry.0);
							for ((String, Object) entry in ((Dictionary<String, Object>)slotEntry.1)) {
								//try {
									Attachment attachment = ReadAttachment((Dictionary<String, Object>)entry.1, skin, slotIndex, entry.0, skeletonData);
									if (attachment != null) skin.SetAttachment(slotIndex, entry.0, attachment);
								//} catch (Exception e) {
								//	throw new Exception("Error reading attachment: " + entry.Key + ", skin: " + skin, e);
								//}
							}
						}
					}
					skeletonData.skins.Add(skin);
					if (skin.name == "default") skeletonData.defaultSkin = skin;
				}
			}

			// Linked meshes.
			for (int i = 0, int n = linkedMeshes.Count; i < n; i++) {
				LinkedMesh linkedMesh = linkedMeshes[i];
				Skin skin = linkedMesh.skin == null ? skeletonData.defaultSkin : skeletonData.FindSkin(linkedMesh.skin);
				//if (skin == null) throw new Exception("Slot not found: " + linkedMesh.skin);
				Attachment parent = skin.GetAttachment(linkedMesh.slotIndex, linkedMesh.parent);
				//if (parent == null) throw new Exception("Parent mesh not found: " + linkedMesh.parent);
				linkedMesh.mesh.DeformAttachment = linkedMesh.inheritDeform ? (VertexAttachment)parent : linkedMesh.mesh;
				linkedMesh.mesh.ParentMesh = (MeshAttachment)parent;
				linkedMesh.mesh.UpdateUVs();
			}
			linkedMeshes.Clear();

			// Events.
			if (root.ContainsKey("events")) {
				for ((String, Object) entry in (Dictionary<String, Object>)root["events"]) {
					var entryMap = (Dictionary<String, Object>)entry.1;
					var data = new EventData(entry.0);
					data.Int = GetInt(entryMap, "int", 0);
					data.Float = GetFloat(entryMap, "float", 0);
					data.string = GetString(entryMap, "String", String.Empty);
					data.AudioPath = GetString(entryMap, "audio", null);
					if (data.AudioPath != null) {
						data.Volume = GetFloat(entryMap, "volume", 1);
						data.Balance = GetFloat(entryMap, "balance", 0);
					}
					skeletonData.events.Add(data);
				}
			}

			// Animations.
			if (root.ContainsKey("animations")) {
				for ((String, Object) entry in (Dictionary<String, Object>)root["animations"]) {
					//try {
						ReadAnimation((Dictionary<String, Object>)entry.1, entry.0, skeletonData);
					//} catch (Exception e) {
					//	throw new Exception("Error reading animation: " + entry.Key, e);
					//}
				}
			}

			//skeletonData.bones.TrimExcess();
			//skeletonData.slots.TrimExcess();
			//skeletonData.skins.TrimExcess();
			//skeletonData.events.TrimExcess();
			//skeletonData.animations.TrimExcess();
			//skeletonData.ikConstraints.TrimExcess();
			return skeletonData;
		}

		private Attachment ReadAttachment (Dictionary<String, Object> map, Skin skin, int slotIndex, String _name, SkeletonData skeletonData) {
			float scale = this.Scale;
			String name = GetString(map, "name", _name);

			var typeName = GetString(map, "type", "region");
			var type = Enum.Parse<AttachmentType>(typeName, true).GetValueOrDefault();

			String path = GetString(map, "path", name);

			switch (type) {
			case AttachmentType.Region:
				RegionAttachment region = attachmentLoader.NewRegionAttachment(skin, name, path);
				if (region == null) return null;
				region.Path = path;
				region.x = GetFloat(map, "x", 0) * scale;
				region.y = GetFloat(map, "y", 0) * scale;
				region.scaleX = GetFloat(map, "scaleX", 1);
				region.scaleY = GetFloat(map, "scaleY", 1);
				region.rotation = GetFloat(map, "rotation", 0);
				region.width = GetFloat(map, "width", 32) * scale;
				region.height = GetFloat(map, "height", 32) * scale;

				if (map.ContainsKey("color")) {
					var color = (String)map["color"];
					region.r = ToColor(color, 0);
					region.g = ToColor(color, 1);
					region.b = ToColor(color, 2);
					region.a = ToColor(color, 3);
				}

				region.UpdateOffset();
				return region;
			case AttachmentType.Boundingbox:
				BoundingBoxAttachment boxAttachment = attachmentLoader.NewBoundingBoxAttachment(skin, name);
				if (boxAttachment == null) return null;
				ReadVertices(map, boxAttachment, GetInt(map, "vertexCount", 0) << 1);
				return boxAttachment;
			case AttachmentType.Mesh, AttachmentType.Linkedmesh: {
					MeshAttachment mesh = attachmentLoader.NewMeshAttachment(skin, name, path);
					if (mesh == null) return null;
					mesh.Path = path;

					if (map.ContainsKey("color")) {
						var color = (String)map["color"];
						mesh.r = ToColor(color, 0);
						mesh.g = ToColor(color, 1);
						mesh.b = ToColor(color, 2);
						mesh.a = ToColor(color, 3);
					}

					mesh.Width = GetFloat(map, "width", 0) * scale;
					mesh.Height = GetFloat(map, "height", 0) * scale;

					String parent = GetString(map, "parent", null);
					if (parent != null) {
						linkedMeshes.Add(new LinkedMesh(mesh, GetString(map, "skin", null), slotIndex, parent, GetBoolean(map, "deform", true)));
						return mesh;
					}

					float[] uvs = GetFloatArray(map, "uvs", 1);
					ReadVertices(map, mesh, uvs.Count);
					mesh.triangles = GetUIntArray(map, "triangles");
					mesh.regionUVs = uvs;
					mesh.UpdateUVs();

					if (map.ContainsKey("hull")) mesh.HullCount = GetInt(map, "hull", 0) * 2;
					if (map.ContainsKey("edges")) mesh.Edges = GetUIntArray(map, "edges");
					return mesh;
				}
			case AttachmentType.Path: {
					PathAttachment pathAttachment = attachmentLoader.NewPathAttachment(skin, name);
					if (pathAttachment == null) return null;
					pathAttachment.closed = GetBoolean(map, "closed", false);
					pathAttachment.constantSpeed = GetBoolean(map, "constantSpeed", true);

					int vertexCount = GetInt(map, "vertexCount", 0);
					ReadVertices(map, pathAttachment, vertexCount << 1);

					// potential BOZO see Java impl
					pathAttachment.lengths = GetFloatArray(map, "Counts", scale);
					return pathAttachment;
				}
			case AttachmentType.Point: {
					PointAttachment point = attachmentLoader.NewPointAttachment(skin, name);
					if (point == null) return null;
					point.x = GetFloat(map, "x", 0) * scale;
					point.y = GetFloat(map, "y", 0) * scale;
					point.rotation = GetFloat(map, "rotation", 0);

					//String color = GetString(map, "color", null);
					//if (color != null) point.color = color;
					return point;
				}
			case AttachmentType.Clipping: {
					ClippingAttachment clip = attachmentLoader.NewClippingAttachment(skin, name);
					if (clip == null) return null;

					String end = GetString(map, "end", null);
					if (end != null) {
						SlotData slot = skeletonData.FindSlot(end);
						//if (slot == null) throw new Exception("Clipping end slot not found: " + end);
						clip.EndSlot = slot;
					}

					ReadVertices(map, clip, GetInt(map, "vertexCount", 0) << 1);

					//String color = GetString(map, "color", null);
					// if (color != null) clip.color = color;
					return clip;
				}
			default:
				return null;
			}
		}

		private void ReadVertices (Dictionary<String, Object> map, VertexAttachment attachment, int verticesCount) {
			attachment.WorldVerticesCount = (uint32)verticesCount;
			float[] vertices = GetFloatArray(map, "vertices", 1);
			float scale = Scale;
			if (verticesCount == vertices.Count) {
				if (scale != 1) {
					for (int i = 0; i < vertices.Count; i++) {
						vertices[i] *= scale;
					}
				}
				attachment.vertices = vertices;
				return;
			}
			List<float> weights = new List<float>(verticesCount * 3 * 3);
			List<int> bones = new List<int>(verticesCount * 3);
			for (int i = 0, int n = vertices.Count; i < n;) {
				int boneCount = (int)vertices[i++];
				bones.Add(boneCount);
				for (int nn = i + boneCount * 4; i < nn; i += 4) {
					bones.Add((int)vertices[i]);
					weights.Add(vertices[i + 1] * this.Scale);
					weights.Add(vertices[i + 2] * this.Scale);
					weights.Add(vertices[i + 3]);
				}
			}
			var bonesArray = new int[bones.Count];
			bones.CopyTo(bonesArray);
			attachment.bones = bonesArray;

			var weightsArray = new float[weights.Count];
			weights.CopyTo(weightsArray);
			attachment.vertices = weightsArray;
		}

		private void ReadAnimation (Dictionary<String, Object> map, String name, SkeletonData skeletonData) {
			var scale = this.Scale;
			var timelines = new List<Timeline>();
			float duration = 0;

			// Slot timelines.
			if (map.ContainsKey("slots")) {
				for ((String, Object) entry in (Dictionary<String, Object>)map["slots"]) {
					String slotName = entry.0;
					int slotIndex = skeletonData.FindSlotIndex(slotName);
					var timelineMap = (Dictionary<String, Object>)entry.1;
					for ((String, Object) timelineEntry in timelineMap) {
						var values = (List<Object>)timelineEntry.1;
						var timelineName = (String)timelineEntry.0;
						if (timelineName == "attachment") {
							var timeline = new AttachmentTimeline(values.Count);
							timeline.slotIndex = slotIndex;

							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								float time = GetFloat(valueMap, "time", 0);
								timeline.SetFrame(frameIndex++, time, (String)valueMap["name"]);
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[timeline.FrameCount - 1]);

						} else if (timelineName == "color") {
							var timeline = new ColorTimeline(values.Count);
							timeline.slotIndex = slotIndex;

							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								float time = GetFloat(valueMap, "time", 0);
								String c = (String)valueMap["color"];
								timeline.SetFrame(frameIndex, time, ToColor(c, 0), ToColor(c, 1), ToColor(c, 2), ToColor(c, 3));
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * ColorTimeline.ENTRIES]);

						} else if (timelineName == "twoColor") {
							var timeline = new TwoColorTimeline(values.Count);
							timeline.slotIndex = slotIndex;

							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								float time = GetFloat(valueMap, "time", 0);
								String light = (String)valueMap["light"];
								String dark = (String)valueMap["dark"];
								timeline.SetFrame(frameIndex, time, ToColor(light, 0), ToColor(light, 1), ToColor(light, 2), ToColor(light, 3),
									ToColor(dark, 0, 6), ToColor(dark, 1, 6), ToColor(dark, 2, 6));
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * TwoColorTimeline.ENTRIES]);

						} //else
							//throw new Exception("Invalid timeline type for a slot: " + timelineName + " (" + slotName + ")");
					}
				}
			}

			// Bone timelines.
			if (map.ContainsKey("bones")) {
				for ((String, Object) entry in (Dictionary<String, Object>)map["bones"]) {
					String boneName = entry.0;
					int boneIndex = skeletonData.FindBoneIndex(boneName);
					//if (boneIndex == -1) throw new Exception("Bone not found: " + boneName);
					var timelineMap = (Dictionary<String, Object>)entry.1;
					for ((String, Object) timelineEntry in timelineMap) {
						var values = (List<Object>)timelineEntry.1;
						var timelineName = (String)timelineEntry.0;
						if (timelineName == "rotate") {
							var timeline = new RotateTimeline(values.Count);
							timeline.boneIndex = boneIndex;

							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								timeline.SetFrame(frameIndex, GetFloat(valueMap, "time", 0), GetFloat(valueMap, "angle", 0));
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * RotateTimeline.ENTRIES]);

						} else if (timelineName == "translate" || timelineName == "scale" || timelineName == "shear") {
							TranslateTimeline timeline;
							float timelineScale = 1, defaultValue = 0;
							if (timelineName == "scale") {
								timeline = new ScaleTimeline(values.Count);
								defaultValue = 1;
							}
							else if (timelineName == "shear")
								timeline = new ShearTimeline(values.Count);
							else {
								timeline = new TranslateTimeline(values.Count);
								timelineScale = scale;
							}
							timeline.boneIndex = boneIndex;

							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								float time = GetFloat(valueMap, "time", 0);
								float x = GetFloat(valueMap, "x", defaultValue);
								float y = GetFloat(valueMap, "y", defaultValue);
								timeline.SetFrame(frameIndex, time, x * timelineScale, y * timelineScale);
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * TranslateTimeline.ENTRIES]);

						} //else
							//throw new Exception("Invalid timeline type for a bone: " + timelineName + " (" + boneName + ")");
					}
				}
			}

			// IK constraint timelines.
			if (map.ContainsKey("ik")) {
				for ((String, Object) constraintMap in (Dictionary<String, Object>)map["ik"]) {
					IkConstraintData constraint = skeletonData.FindIkConstraint(constraintMap.0);
					var values = (List<Object>)constraintMap.1;
					var timeline = new IkConstraintTimeline(values.Count);
					timeline.ikConstraintIndex = skeletonData.ikConstraints.IndexOf(constraint);
					int frameIndex = 0;
					for (Dictionary<String, Object> valueMap in values) {
						timeline.SetFrame(frameIndex, GetFloat(valueMap, "time", 0), GetFloat(valueMap, "mix", 1),
							GetFloat(valueMap, "softness", 0) * scale, GetBoolean(valueMap, "bendPositive", true) ? 1 : -1,
							GetBoolean(valueMap, "compress", false), GetBoolean(valueMap, "stretch", false));
						ReadCurve(valueMap, timeline, frameIndex);
						frameIndex++;
					}
					timelines.Add(timeline);
					duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * IkConstraintTimeline.ENTRIES]);
				}
			}

			// Transform constraint timelines.
			if (map.ContainsKey("transform")) {
				for ((String, Object) constraintMap in (Dictionary<String, Object>)map["transform"]) {
					TransformConstraintData constraint = skeletonData.FindTransformConstraint(constraintMap.0);
					var values = (List<Object>)constraintMap.1;
					var timeline = new TransformConstraintTimeline(values.Count);
					timeline.transformConstraintIndex = skeletonData.transformConstraints.IndexOf(constraint);
					int frameIndex = 0;
					for (Dictionary<String, Object> valueMap in values) {
						timeline.SetFrame(frameIndex, GetFloat(valueMap, "time", 0), GetFloat(valueMap, "rotateMix", 1),
								GetFloat(valueMap, "translateMix", 1), GetFloat(valueMap, "scaleMix", 1), GetFloat(valueMap, "shearMix", 1));
						ReadCurve(valueMap, timeline, frameIndex);
						frameIndex++;
					}
					timelines.Add(timeline);
					duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * TransformConstraintTimeline.ENTRIES]);
				}
			}

			// Path constraint timelines.
			if (map.ContainsKey("path")) {
				for ((String, Object) constraintMap in (Dictionary<String, Object>)map["path"]) {
					int index = skeletonData.FindPathConstraintIndex(constraintMap.0);
					//if (index == -1) throw new Exception("Path constraint not found: " + constraintMap.Key);
					PathConstraintData data = skeletonData.pathConstraints[index];
					var timelineMap = (Dictionary<String, Object>)constraintMap.1;
					for ((String, Object) timelineEntry in timelineMap) {
						var values = (List<Object>)timelineEntry.1;
						var timelineName = (String)timelineEntry.0;
						if (timelineName == "position" || timelineName == "spacing") {
							PathConstraintPositionTimeline timeline;
							float timelineScale = 1;
							if (timelineName == "spacing") {
								timeline = new PathConstraintSpacingTimeline(values.Count);
								if (data.spacingMode == SpacingMode.Count || data.spacingMode == SpacingMode.Fixed) timelineScale = scale;
							}
							else {
								timeline = new PathConstraintPositionTimeline(values.Count);
								if (data.positionMode == PositionMode.Fixed) timelineScale = scale;
							}
							timeline.pathConstraintIndex = index;
							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								timeline.SetFrame(frameIndex, GetFloat(valueMap, "time", 0), GetFloat(valueMap, timelineName, 0) * timelineScale);
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * PathConstraintPositionTimeline.ENTRIES]);
						}
						else if (timelineName == "mix") {
							PathConstraintMixTimeline timeline = new PathConstraintMixTimeline(values.Count);
							timeline.pathConstraintIndex = index;
							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								timeline.SetFrame(frameIndex, GetFloat(valueMap, "time", 0), GetFloat(valueMap, "rotateMix", 1),
									GetFloat(valueMap, "translateMix", 1));
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[(timeline.FrameCount - 1) * PathConstraintMixTimeline.ENTRIES]);
						}
					}
				}
			}

			// Deform timelines.
			if (map.ContainsKey("deform")) {
				for ((String, Object) deformMap in (Dictionary<String, Object>)map["deform"]) {
					Skin skin = skeletonData.FindSkin(deformMap.0);
					for ((String, Object) slotMap in (Dictionary<String, Object>)deformMap.1) {
						int slotIndex = skeletonData.FindSlotIndex(slotMap.0);
						//if (slotIndex == -1) throw new Exception("Slot not found: " + slotMap.Key);
						for ((String, Object) timelineMap in (Dictionary<String, Object>)slotMap.1) {
							var values = (List<Object>)timelineMap.1;
							VertexAttachment attachment = (VertexAttachment)skin.GetAttachment(slotIndex, timelineMap.0);
							//if (attachment == null) throw new Exception("Deform attachment not found: " + timelineMap.Key);
							bool weighted = attachment.bones != null;
							float[] vertices = attachment.vertices;
							int deformCount = weighted ? vertices.Count / 3 * 2 : vertices.Count;

							var timeline = new DeformTimeline(values.Count);
							timeline.slotIndex = slotIndex;
							timeline.attachment = attachment;

							int frameIndex = 0;
							for (Dictionary<String, Object> valueMap in values) {
								float[] deform;
								if (!valueMap.ContainsKey("vertices")) {
									deform = weighted ? new float[deformCount] : vertices;
								} else {
									deform = new float[deformCount];
									int start = GetInt(valueMap, "offset", 0);
									float[] verticesValue = GetFloatArray(valueMap, "vertices", 1);
									Array.Copy(verticesValue, 0, deform, start, verticesValue.Count);
									if (scale != 1) {
										for (int i = start, int n = i + verticesValue.Count; i < n; i++)
											deform[i] *= scale;
									}

									if (!weighted) {
										for (int i = 0; i < deformCount; i++)
											deform[i] += vertices[i];
									}
								}

								timeline.SetFrame(frameIndex, GetFloat(valueMap, "time", 0), deform);
								ReadCurve(valueMap, timeline, frameIndex);
								frameIndex++;
							}
							timelines.Add(timeline);
							duration = Math.Max(duration, timeline.frames[timeline.FrameCount - 1]);
						}
					}
				}
			}

			// Draw order timeline.
			if (map.ContainsKey("drawOrder") || map.ContainsKey("draworder")) {
				var values = (List<Object>)map[map.ContainsKey("drawOrder") ? "drawOrder" : "draworder"];
				var timeline = new DrawOrderTimeline(values.Count);
				int slotCount = skeletonData.slots.Count;
				int frameIndex = 0;
				for (Dictionary<String, Object> drawOrderMap in values) {
					int[] drawOrder = null;
					if (drawOrderMap.ContainsKey("offsets")) {
						drawOrder = new int[slotCount];
						for (int i = slotCount - 1; i >= 0; i--)
							drawOrder[i] = -1;
						var offsets = (List<Object>)drawOrderMap["offsets"];
						int[] unchanged = new int[slotCount - offsets.Count];
						int originalIndex = 0, unchangedIndex = 0;
						for (Dictionary<String, Object> offsetMap in offsets) {
							int slotIndex = skeletonData.FindSlotIndex((String)offsetMap["slot"]);
							//if (slotIndex == -1) throw new Exception("Slot not found: " + offsetMap["slot"]);
							// Collect unchanged items.
							while (originalIndex != slotIndex)
								unchanged[unchangedIndex++] = originalIndex++;
							// Set changed items.
							int index = originalIndex + (int)(float)offsetMap["offset"];
							drawOrder[index] = originalIndex++;
						}
						// Collect remaining unchanged items.
						while (originalIndex < slotCount)
							unchanged[unchangedIndex++] = originalIndex++;
						// Fill in unchanged items.
						for (int i = slotCount - 1; i >= 0; i--)
							if (drawOrder[i] == -1) drawOrder[i] = unchanged[--unchangedIndex];
					}
					timeline.SetFrame(frameIndex++, GetFloat(drawOrderMap, "time", 0), drawOrder);
				}
				timelines.Add(timeline);
				duration = Math.Max(duration, timeline.frames[timeline.FrameCount - 1]);
			}

			// Event timeline.
			if (map.ContainsKey("events")) {
				var eventsMap = (List<Object>)map["events"];
				var timeline = new EventTimeline(eventsMap.Count);
				int frameIndex = 0;
				for (Dictionary<String, Object> eventMap in eventsMap) {
					EventData eventData = skeletonData.FindEvent((String)eventMap["name"]);
					//if (eventData == null) throw new Exception("Event not found: " + eventMap["name"]);
					var e = new Event(GetFloat(eventMap, "time", 0), eventData) {
						intValue = GetInt(eventMap, "int", eventData.Int),
						floatValue = GetFloat(eventMap, "float", eventData.Float),
						StringValue = GetString(eventMap, "String", eventData.string)
					};
					if (e.data.AudioPath != null) {
						e.volume = GetFloat(eventMap, "volume", eventData.Volume);
						e.balance = GetFloat(eventMap, "balance", eventData.Balance);
					}
					timeline.SetFrame(frameIndex++, e);
				}
				timelines.Add(timeline);
				duration = Math.Max(duration, timeline.frames[timeline.FrameCount - 1]);
			}

			//timelines.TrimExcess();
			skeletonData.animations.Add(new Animation(name, timelines, duration));
		}

		static void ReadCurve (Dictionary<String, Object> valueMap, CurveTimeline timeline, int frameIndex) {
			if (!valueMap.ContainsKey("curve"))
				return;
			Object curveObject = valueMap["curve"];
			if (curveObject is String)
				timeline.SetStepped(frameIndex);
			else
				timeline.SetCurve(frameIndex, (float)curveObject, GetFloat(valueMap, "c2", 0), GetFloat(valueMap, "c3", 1), GetFloat(valueMap, "c4", 1));
		}

		public class LinkedMesh {
			public String parent, skin;
			public int slotIndex;
			public MeshAttachment mesh;
			public bool inheritDeform;

			public this (MeshAttachment mesh, String skin, int slotIndex, String parent, bool inheritDeform) {
				this.mesh = mesh;
				this.skin = skin;
				this.slotIndex = slotIndex;
				this.parent = parent;
				this.inheritDeform = inheritDeform;
			}
		}

		static float[] GetFloatArray(Dictionary<String, Object> map, String name, float scale) {
			var list = (List<Object>)map[name];
			var values = new float[list.Count];
			if (scale == 1) {
				for (int i = 0, int n = list.Count; i < n; i++)
					values[i] = (float)list[i];
			} else {
				for (int i = 0, int n = list.Count; i < n; i++)
					values[i] = (float)list[i] * scale;
			}
			return values;
		}

		static int32[] GetIntArray(Dictionary<String, Object> map, String name) {
			var list = (List<Object>)map[name];
			var values = new int32[list.Count];
			for (int i = 0, int n = list.Count; i < n; i++)
				values[i] = (int32)(float)list[i];
			return values;
		}

		static uint32[] GetUIntArray(Dictionary<String, Object> map, String name) {
			var list = (List<Object>)map[name];
			var values = new uint32[list.Count];
			for (int i = 0, int n = list.Count; i < n; i++)
				values[i] = (uint32)(float)list[i];
			return values;
		}

		static float GetFloat(Dictionary<String, Object> map, String name, float defaultValue) {
			if (!map.ContainsKey(name))
				return defaultValue;
			return (float)map[name];
		}

		static int GetInt(Dictionary<String, Object> map, String name, int defaultValue) {
			if (!map.ContainsKey(name))
				return defaultValue;
			return (int)(float)map[name];
		}

		static bool GetBoolean(Dictionary<String, Object> map, String name, bool defaultValue) {
			if (!map.ContainsKey(name))
				return defaultValue;
			return (bool)map[name];
		}

		static String GetString(Dictionary<String, Object> map, String name, String defaultValue) {
			if (!map.ContainsKey(name))
				return defaultValue;
			return (String)map[name];
		}

		static float ToColor(String hexString, int colorIndex, int expectedCount = 8) {
			//if (hexString.Count != expectedCount)
				//throw new ArgumentException("Color hexidecimal Count must be " + expectedCount + ", recieved: " + hexString, "hexString");
			return int32.Parse(StringView(hexString, colorIndex * 2, 2), .HexNumber).Get(0) / 255f;
		}
	}
}
