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
using System.Globalization;
using System.IO;
using System.Reflection;

namespace Spine {
	public class Atlas : IEnumerable<AtlasRegion> {
		readonly List<AtlasPage> pages = new List<AtlasPage>() ~ DeleteContainerAndItems!(_);
		List<AtlasRegion> regions = new List<AtlasRegion>() ~ DeleteContainerAndItems!(_);
		TextureLoader textureLoader ~ delete (Object)_;

		#region IEnumerable implementation
		public IEnumerator<AtlasRegion> GetEnumerator () {
			return new box regions.GetEnumerator();
		}

		IEnumerator<AtlasRegion> IEnumerable<AtlasRegion>.GetEnumerator () {
			return new box regions.GetEnumerator();
		}
		#endregion

		public this (String path, TextureLoader textureLoader)
		{
			StreamReader reader = scope StreamReader();
			reader.Open(path);
			//try {
			var dir = scope String();
			Path.GetDirectoryPath(path, dir);
			Load(reader, dir, textureLoader);
			//} catch (Exception ex) {
			//	throw new Exception("Error reading atlas file: " + path, ex);
			//}
		}

		public this (StreamReader reader, String dir, TextureLoader textureLoader) {
			Load(reader, dir, textureLoader);
		}

		public this (List<AtlasPage> pages, List<AtlasRegion> regions) {
			this.pages = pages;
			this.regions = regions;
			this.textureLoader = null;
		}

		private void Load (StreamReader reader, String imagesDir, TextureLoader textureLoader) {
			//if (textureLoader == null) throw new ArgumentNullException("textureLoader", "textureLoader cannot be null.");
			this.textureLoader = textureLoader;

			String[] tuple = scope String[4];
			for(int i = 0; i < tuple.Count; i++) tuple[i] = scope:: String();

			AtlasPage page = null;
			read: while (true) {
				String line = scope String();
				switch(reader.ReadLine(line)){
				case .Err: break read;
				case .Ok: break;
				}
				//if (line == null) break;
				if (line..Trim().Length == 0){
					page = null;
				}
				else if (page == null) {
					page = new AtlasPage();
					page.name = new String(line);

					if (ReadTuple(reader, tuple) == 2) { // size is only optional for an atlas packed with an old TexturePacker.
						page.width = int.Parse(tuple[0]);
						page.height = int.Parse(tuple[1]);
						ReadTuple(reader, tuple);
					}
					page.format = Enum.Parse<Format>(tuple[0], false);
					//page.format = (Format)Enum.Parse(typeof(Format), tuple[0], false);
					
					ReadTuple(reader, tuple);
					page.minFilter = Enum.Parse<TextureFilter>(tuple[0], false);
					page.magFilter = Enum.Parse<TextureFilter>(tuple[1], false);

					String direction = ReadValue(reader, scope .());
					page.uWrap = TextureWrap.ClampToEdge;
					page.vWrap = TextureWrap.ClampToEdge;
					if (direction == "x")
						page.uWrap = TextureWrap.Repeat;
					else if (direction == "y")
						page.vWrap = TextureWrap.Repeat;
					else if (direction == "xy")
						page.uWrap = page.vWrap = TextureWrap.Repeat;

					String texPath = scope String();
					Path.InternalCombine(texPath, imagesDir, line);

					textureLoader.Load(page, texPath);

					pages.Add(page);

				} else {
					AtlasRegion region = new AtlasRegion();
					region.name = new String(line);
					region.page = page;

					String rotateValue = ReadValue(reader, scope .());
					if (rotateValue == "true")
						region.degrees = 90;
					else if (rotateValue == "false")
						region.degrees = 0;
					else
						region.degrees = int.Parse(rotateValue);

					region.rotate = region.degrees == 90;

					ReadTuple(reader, tuple);
					int x = int.Parse(tuple[0]);
					int y = int.Parse(tuple[1]);

					ReadTuple(reader, tuple);
					int width = int.Parse(tuple[0]);
					int height = int.Parse(tuple[1]);

					region.u = x / (float)page.width;
					region.v = y / (float)page.height;
					if (region.rotate) {
						region.u2 = (x + height) / (float)page.width;
						region.v2 = (y + width) / (float)page.height;
					} else {
						region.u2 = (x + width) / (float)page.width;
						region.v2 = (y + height) / (float)page.height;
					}
					region.x = x;
					region.y = y;
					region.width = Math.Abs(width);
					region.height = Math.Abs(height);

					if (ReadTuple(reader, tuple) == 4) { // split is optional
						region.splits = new int [] (int.Parse(tuple[0]),
												int.Parse(tuple[1]),
												int.Parse(tuple[2]),
												int.Parse(tuple[3]));

						if (ReadTuple(reader, tuple) == 4) { // pad is optional, but only present with splits
							region.pads = new int [] (int.Parse(tuple[0]),
												int.Parse(tuple[1]),
												int.Parse(tuple[2]),
												int.Parse(tuple[3]));

							ReadTuple(reader, tuple);
						}
					}

					region.originalWidth = int.Parse(tuple[0]);
					region.originalHeight = int.Parse(tuple[1]);

					ReadTuple(reader, tuple);
					region.offsetX = int.Parse(tuple[0]);
					region.offsetY = int.Parse(tuple[1]);


					var indexStr = ReadValue(reader, scope .());
					region.index = int.Parse(indexStr);

					regions.Add(region);
				}
			}
		}

		static String ReadValue (StreamReader reader, String strBuffer)
		{
			String line = scope String();
			reader.ReadLine(line);

			int colon = line.IndexOf(':');
			//if (colon == -1) throw new Exception("Invalid line: " + line);
			strBuffer.Append(scope String(line, colon + 1)..Trim());
			//return str;//.SubString(colon + 1).Trim();
			return strBuffer;
		}

		/// <summary>Returns the number of tuple values read (1, 2 or 4).</summary>
		static int ReadTuple (StreamReader reader, String[] tuple)
		{
			String line = scope String();
			reader.ReadLine(line);
			int colon = line.IndexOf(':');
			//if (colon == -1) throw new Exception("Invalid line: " + line);
			int i = 0, lastMatch = colon + 1;
			for (; i < 3; i++) {
				int comma = line.IndexOf(',', lastMatch);
				if (comma == -1) break;
				tuple[i]..Clear()..Append(line, lastMatch, comma - lastMatch)..Trim(); //line.SubString(lastMatch, comma - lastMatch).Trim();
				lastMatch = comma + 1;
			}
			tuple[i]..Clear()..Append(line, lastMatch)..Trim();//line.Substring(lastMatch).Trim();
			return i + 1;
		}

		public void FlipV () {
			for (int i = 0, int n = regions.Count; i < n; i++) {
				AtlasRegion region = regions[i];
				region.v = 1 - region.v;
				region.v2 = 1 - region.v2;
			}
		}

		/// <summary>Returns the first region found with the specified name. This method uses String comparison to find the region, so the result
		/// should be cached rather than calling this method multiple times.</summary>
		/// <returns>The region, or null.</returns>
		public AtlasRegion FindRegion (String name) {
			for (int i = 0, int n = regions.Count; i < n; i++)
				if (regions[i].name == name) return regions[i];
			return null;
		}

		public void Dispose () {
			if (textureLoader == null) return;
			for (int i = 0, int n = pages.Count; i < n; i++)
				textureLoader.Unload(pages[i].rendererObject);
		}
	}

	public enum Format {
		Alpha,
		Intensity,
		LuminanceAlpha,
		RGB565,
		RGBA4444,
		RGB888,
		RGBA8888
	}

	public enum TextureFilter {
		Nearest,
		Linear,
		MipMap,
		MipMapNearestNearest,
		MipMapLinearNearest,
		MipMapNearestLinear,
		MipMapLinearLinear
	}

	public enum TextureWrap {
		MirroredRepeat,
		ClampToEdge,
		Repeat
	}

	public class AtlasPage {
		public String name ~ delete _;
		public Format format;
		public TextureFilter minFilter;
		public TextureFilter magFilter;
		public TextureWrap uWrap;
		public TextureWrap vWrap;
		public Object rendererObject;
		public int width, height;

		/*public AtlasPage Clone () {
			return MemberwiseClone() as AtlasPage;
		}*/
	}

	public class AtlasRegion {
		public AtlasPage page;
		public String name ~ delete _;
		public int x, y, width, height;
		public float u, v, u2, v2;
		public float offsetX, offsetY;
		public int originalWidth, originalHeight;
		public int index;
		public bool rotate;
		public int degrees;
		public int[] splits;
		public int[] pads;

		/*public AtlasRegion Clone () {
			return MemberwiseClone() as AtlasRegion;
		}*/
	}

	public interface TextureLoader {
		void Load (AtlasPage page, String path);
		void Unload (Object texture);
	}
}
