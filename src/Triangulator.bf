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

#define EXPERIMENTAL

using System;
using System.Collections;

namespace Spine
{
	//[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
	//[Il2CppSetOption(Option.NullChecks, false)]
	public class Triangulator {
		private readonly List<List<float>> convexPolygons = new List<List<float>>() ~ delete _;
		private readonly List<List<int>> convexPolygonsIndices = new List<List<int>>() ~ delete _;

		private readonly List<int> indices = new List<int>() ~ delete _;
		private readonly List<bool> isConcave = new List<bool>() ~ delete _;
		private readonly List<int> triangles = new List<int>() ~ delete _;

		private readonly Pool<List<float>> polygonPool = new Pool<List<float>>() ~ delete _;
		private readonly Pool<List<int>> polygonIndicesPool = new Pool<List<int>>() ~ delete _;

		public List<int> Triangulate (List<float> vertices) {
			int vertexCount = vertices.Count >> 1;

			indices.GrowUnitialized(vertexCount - indices.Count);
			for (int i = 0; i < vertexCount; i++)
				indices[i] = i;

			isConcave.GrowUnitialized(vertexCount - isConcave.Count);
			for (int i = 0, int n = vertexCount; i < n; ++i)
				isConcave[i] = IsConcave(i, vertexCount, vertices, indices);

			var triangles = this.triangles;
			triangles.Clear();
			triangles.EnsureCapacity(Math.Max(0, vertexCount - 2) << 2, true);

			int indicesOffset = 0;
			while (vertexCount > 3) {
				// Find ear tip.
				int previous = vertexCount - 1, i = 0, next = 1;

				// outer:
				while (true) {
					if (!isConcave[i + indicesOffset]) {
						int p1 = indices[previous + indicesOffset] << 1, p2 = indices[i + indicesOffset] << 1, p3 = indices[next + indicesOffset] << 1;
						float p1x = vertices[p1], p1y = vertices[p1 + 1];
						float p2x = vertices[p2], p2y = vertices[p2 + 1];
						float p3x = vertices[p3], p3y = vertices[p3 + 1];
						for (int ii = (next + 1) % vertexCount; ii != previous; ii = (ii + 1) % vertexCount) {
							if (!isConcave[ii + indicesOffset]) continue;
							int v = indices[ii + indicesOffset] << 1;
							float vx = vertices[v], vy = vertices[v + 1];
							if (PositiveArea(p3x, p3y, p1x, p1y, vx, vy)) {
								if (PositiveArea(p1x, p1y, p2x, p2y, vx, vy)) {
									if (PositiveArea(p2x, p2y, p3x, p3y, vx, vy)) break; //goto break_outer; // break outer;
								}
							}
						}
						break;
					}
					break_outer:

					if (next == 0) {
						do repeat {
							if (!isConcave[i + indicesOffset]) break;
							i--;
						} while (i > 0);
						break;
					}

					previous = i;
					i = next;
					next = (next + 1) % vertexCount;
				}

				// Cut ear tip.
				triangles.Add(indices[(vertexCount + i - 1) % vertexCount + indicesOffset]);
				triangles.Add(indices[i + indicesOffset]);
				triangles.Add(indices[(i + 1) % vertexCount + indicesOffset]);
#if EXPERIMENTAL
				indicesOffset++;
#else
				indicesArray.RemoveAt(i);
				isConcaveArray.RemoveAt(i);
#endif
				vertexCount--;

				int previousIndex = (vertexCount + i - 1) % vertexCount + indicesOffset;
				int nextIndex = i == vertexCount ? 0 : i + indicesOffset;
				isConcave[previousIndex] = IsConcave(previousIndex, vertexCount, vertices, indices);
				isConcave[nextIndex] = IsConcave(nextIndex, vertexCount, vertices, indices);
			}

			if (vertexCount == 3) {
				triangles.Add(indices[2]);
				triangles.Add(indices[0]);
				triangles.Add(indices[1]);
			}
			return triangles;
		}

		public List<List<float>> Decompose (List<float> vertices, List<int> triangles) {
			//var vertices = verticesArray.Items;
			var convexPolygons = this.convexPolygons;
			/*for (int i = 0, n = convexPolygons.Count; i < n; i++) {
				polygonPool.Free(convexPolygons.Items[i]);
			}*/
			polygonPool.FreeAll(convexPolygons);
			convexPolygons.Clear();

			var convexPolygonsIndices = this.convexPolygonsIndices;
			/*for (int i = 0, n = convexPolygonsIndices.Count; i < n; i++) {
				polygonIndicesPool.Free(convexPolygonsIndices.Items[i]);
			}*/
			polygonIndicesPool.FreeAll(convexPolygonsIndices);
			convexPolygonsIndices.Clear();

			var polygonIndices = polygonIndicesPool.Obtain();
			polygonIndices.Clear();

			var polygon = polygonPool.Obtain();
			polygon.Clear();

			// Merge subsequent triangles if they form a triangle fan.
			int fanBaseIndex = -1, lastWinding = 0;
			//int[] trianglesItems = triangles.Items;
			for (int i = 0, int n = triangles.Count; i < n; i += 3) {
				int t1 = triangles[i] << 1, t2 = triangles[i + 1] << 1, t3 = triangles[i + 2] << 1;
				float x1 = vertices[t1], y1 = vertices[t1 + 1];
				float x2 = vertices[t2], y2 = vertices[t2 + 1];
				float x3 = vertices[t3], y3 = vertices[t3 + 1];

				// If the base of the last triangle is the same as this triangle, check if they form a convex polygon (triangle fan).
				var merged = false;
				if (fanBaseIndex == t1) {
					int o = polygon.Count - 4;
					var p = polygon;
					int winding1 = Winding(p[o], p[o + 1], p[o + 2], p[o + 3], x3, y3);
					int winding2 = Winding(x3, y3, p[0], p[1], p[2], p[3]);
					if (winding1 == lastWinding && winding2 == lastWinding) {
						polygon.Add(x3);
						polygon.Add(y3);
						polygonIndices.Add(t3);
						merged = true;
					}
				}

				// Otherwise make this triangle the new base.
				if (!merged) {
					if (polygon.Count > 0) {
						convexPolygons.Add(polygon);
						convexPolygonsIndices.Add(polygonIndices);
					} else {
						polygonPool.Free(polygon);
						polygonIndicesPool.Free(polygonIndices);
					}
					polygon = polygonPool.Obtain();
					polygon.Clear();
					polygon.Add(x1);
					polygon.Add(y1);
					polygon.Add(x2);
					polygon.Add(y2);
					polygon.Add(x3);
					polygon.Add(y3);
					polygonIndices = polygonIndicesPool.Obtain();
					polygonIndices.Clear();
					polygonIndices.Add(t1);
					polygonIndices.Add(t2);
					polygonIndices.Add(t3);
					lastWinding = Winding(x1, y1, x2, y2, x3, y3);
					fanBaseIndex = t1;
				}
			}

			if (polygon.Count > 0) {
				convexPolygons.Add(polygon);
				convexPolygonsIndices.Add(polygonIndices);
			}

			// Go through the list of polygons and try to merge the remaining triangles with the found triangle fans.
			for (int i = 0, int n = convexPolygons.Count; i < n; i++) {
				polygonIndices = convexPolygonsIndices[i];
				if (polygonIndices.Count == 0) continue;
				int firstIndex = polygonIndices[0];
				int lastIndex = polygonIndices[polygonIndices.Count - 1];

				polygon = convexPolygons[i];
				int o = polygon.Count - 4;
				var p = polygon;
				float prevPrevX = p[o], prevPrevY = p[o + 1];
				float prevX = p[o + 2], prevY = p[o + 3];
				float firstX = p[0], firstY = p[1];
				float secondX = p[2], secondY = p[3];
				int winding = Winding(prevPrevX, prevPrevY, prevX, prevY, firstX, firstY);

				for (int ii = 0; ii < n; ii++) {
					if (ii == i) continue;
					var otherIndices = convexPolygonsIndices[ii];
					if (otherIndices.Count != 3) continue;
					int otherFirstIndex = otherIndices[0];
					int otherSecondIndex = otherIndices[1];
					int otherLastIndex = otherIndices[2];

					var otherPoly = convexPolygons[ii];
					float x3 = otherPoly[otherPoly.Count - 2], y3 = otherPoly[otherPoly.Count - 1];

					if (otherFirstIndex != firstIndex || otherSecondIndex != lastIndex) continue;
					int winding1 = Winding(prevPrevX, prevPrevY, prevX, prevY, x3, y3);
					int winding2 = Winding(x3, y3, firstX, firstY, secondX, secondY);
					if (winding1 == winding && winding2 == winding) {
						otherPoly.Clear();
						otherIndices.Clear();
						polygon.Add(x3);
						polygon.Add(y3);
						polygonIndices.Add(otherLastIndex);
						prevPrevX = prevX;
						prevPrevY = prevY;
						prevX = x3;
						prevY = y3;
						ii = 0;
					}
				}
			}

			// Remove empty polygons that resulted from the merge step above.
			for (int i = convexPolygons.Count - 1; i >= 0; i--) {
				polygon = convexPolygons[i];
				if (polygon.Count == 0) {
					convexPolygons.RemoveAt(i);
					polygonPool.Free(polygon);
					polygonIndices = convexPolygonsIndices[i];
					convexPolygonsIndices.RemoveAt(i);
					polygonIndicesPool.Free(polygonIndices);
				}
			}
			return convexPolygons;
		}

		[Inline]
		private static bool IsConcave (int index, int vertexCount, List<float> vertices, List<int> indices) {
			int previous = indices[(vertexCount + index - 1) % vertexCount] << 1;
			int current = indices[index] << 1;
			int next = indices[(index + 1) % vertexCount] << 1;
			return !PositiveArea(vertices[previous], vertices[previous + 1], vertices[current], vertices[current + 1], vertices[next],
				vertices[next + 1]);
		}

		[Inline]
		private static bool PositiveArea(float p1x, float p1y, float p2x, float p2y, float p3x, float p3y) =>
			p1x * (p3y - p2y) + p2x * (p1y - p3y) + p3x * (p2y - p1y) >= 0;

		[Inline]
		private static int Winding (float p1x, float p1y, float p2x, float p2y, float p3x, float p3y) {
			float px = p2x - p1x, py = p2y - p1y;
			return (p3x * py - p3y * px + px * p1y - p1x * py >= 0) ? 1 : -1;
		}
	}
}
