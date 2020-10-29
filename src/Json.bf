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
using System.Text;
using System.Collections;
using System.Globalization;
using System.Collections;

namespace Spine {
	public static class Json {
		public static Object Deserialize (StreamReader text) {
			var parser = new SharpJson.JsonDecoder();
			parser.parseNumbersAsFloat = true;

			String str = new String();
			text.ReadToEnd(str);
			return parser.Decode(str);
		}
	}
}

/**
 * Copyright (c) 2016 Adriano Tinoco d'Oliveira Rezende
 *
 * Based on the JSON parser by Patrick van Bergen
 * http://techblog.procurios.nl/k/news/view/14605/14863/how-do-i-write-my-own-parser-(for-json).html
 *
 * Changes made:
 *
 * - Optimized parser speed (deserialize roughly near 3x faster than original)
 * - Added support to handle lexer/parser error messages with line numbers
 * - Added more fine grained control over type conversions during the parsing
 * - Refactory API (Separate Lexer code from Parser code and the Encoder from Decoder)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or substantial
 * portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 * LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
 * OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
namespace SharpJson
{
	class Lexer
	{
		public enum Token {
			None,
			Null,
			True,
			False,
			Colon,
			Comma,
			String,
			Number,
			CurlyOpen,
			CurlyClose,
			SquaredOpen,
			SquaredClose,
		};

		public bool hasError {
			get {
				return !success;
			}
		}

		public int lineNumber {
			get;
			private set;
		}

		public bool parseNumbersAsFloat {
			get;
			set;
		}

		String json;
		int index = 0;
		bool success = true;

		public this(String text)
		{
			Reset();
			json = text;
			parseNumbersAsFloat = false;
		}

		public void Reset()
		{
			index = 0;
			lineNumber = 1;
			success = true;
		}

		public String ParseString()
		{
			String parsed = new String();

			SkipWhiteSpaces();

			// "
			char16 c = json[index++];

			bool failed = false;
			bool complete = false;

			while (!complete && !failed) {
				if (index == json.Length)
					break;

				c = json[index++];
				if (c == '"') {
					complete = true;
					break;
				} else if (c == '\\') {
					if (index == json.Length)
						break;

					c = json[index++];

					switch (c) {
					case '"':
						parsed.Append('"');
						break;
					case '\\':
						parsed.Append('\\');
						break;
					case '/':
						parsed.Append('/');
						break;
					case 'b':
						parsed.Append('\b');
						break;
					case 'f':
						parsed.Append('\f');
						break;
					case 'n':
						parsed.Append('\n');
						break;
					case 'r':
						parsed.Append('\r');
						break;
					case 't':
						parsed.Append('\t');
						break;
					case 'u':
						int remainingCount = json.Length - index;
						if (remainingCount >= 4) {
							var hex = scope String(json, index, 4);

							// XXX: handle UTF
							parsed.Append((char16)int32.Parse(hex, NumberStyles.HexNumber));

							// skip 4 chars
							index += 4;
						} else {
							failed = true;
						}
						break;
					}
				} else {
					parsed.Append(c);
				}
			}

			if (!complete) {
				success = false;
				return null;
			}

			return parsed;
		}

		String GetNumberString()
		{
			SkipWhiteSpaces();

			int lastIndex = GetLastIndexOfNumber(index);
			int charCount = (lastIndex - index) + 1;

			var result = new String (json, index, charCount);

			index = lastIndex + 1;

			return result;
		}

		public float ParseFloatNumber()
		{
			var str = GetNumberString ();
			switch (float.Parse(str))
			{
				case .Err: return 0;
				case .Ok(var number): return number;
			}
		}

		public double ParseDoubleNumber()
		{
			var str = GetNumberString ();
			switch (double.Parse(str))
			{
				case .Err: return 0;
				case .Ok(var number): return number;
			}
		}

		int GetLastIndexOfNumber(int index)
		{
			int lastIndex;

			for (lastIndex = index; lastIndex < json.Length; lastIndex++) {
				char8 ch = json[lastIndex];

				if ((ch < '0' || ch > '9') && ch != '+' && ch != '-'
				    && ch != '.' && ch != 'e' && ch != 'E')
					break;
			}

			return lastIndex - 1;
		}

		void SkipWhiteSpaces()
		{
			for (; index < json.Length; index++) {
				char8 ch = json[index];

				if (ch == '\n')
					lineNumber++;
				if(!json[index].IsWhiteSpace)
					break;
			}
		}

		public Token LookAhead()
		{
			SkipWhiteSpaces();

			int savedIndex = index;
			return NextToken(json, ref savedIndex);
		}

		public Token NextToken()
		{
			SkipWhiteSpaces();
			return NextToken(json, ref index);
		}

		static Token NextToken(String json, ref int index)
		{
			if (index == json.Length)
				return Token.None;

			char8 c = json[index++];

			switch (c) {
			case '{':
				return Token.CurlyOpen;
			case '}':
				return Token.CurlyClose;
			case '[':
				return Token.SquaredOpen;
			case ']':
				return Token.SquaredClose;
			case ',':
				return Token.Comma;
			case '"':
				return Token.String;
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-':
				return Token.Number;
			case ':':
				return Token.Colon;
			}

			index--;

			int remainingCount = json.Length - index;

			// false
			if (remainingCount >= 5) {
				if (json[index] == 'f' &&
				    json[index + 1] == 'a' &&
				    json[index + 2] == 'l' &&
				    json[index + 3] == 's' &&
				    json[index + 4] == 'e') {
					index += 5;
					return Token.False;
				}
			}

			// true
			if (remainingCount >= 4) {
				if (json[index] == 't' &&
				    json[index + 1] == 'r' &&
				    json[index + 2] == 'u' &&
				    json[index + 3] == 'e') {
					index += 4;
					return Token.True;
				}
			}

			// null
			if (remainingCount >= 4) {
				if (json[index] == 'n' &&
				    json[index + 1] == 'u' &&
				    json[index + 2] == 'l' &&
				    json[index + 3] == 'l') {
					index += 4;
					return Token.Null;
				}
			}

			return Token.None;
		}
	}

	public class JsonDecoder
	{
		public String errorMessage {
			get;
			private set;
		}

		public bool parseNumbersAsFloat {
			get;
			set;
		}

		Lexer lexer;

		public this()
		{
			errorMessage = null;
			parseNumbersAsFloat = false;
		}

		public Object Decode(String text)
		{
			errorMessage = null;

			lexer = new Lexer(text);
			lexer.parseNumbersAsFloat = parseNumbersAsFloat;

			return ParseValue();
		}

		public static Object DecodeText(String text)
		{
			var builder = new JsonDecoder();
			return builder.Decode(text);
		}

		Dictionary<String, Object> ParseObject()
		{
			var table = new Dictionary<String, Object>();

			// {
			lexer.NextToken();

			while (true) {
				var token = lexer.LookAhead();

				switch (token) {
				case Lexer.Token.None:
					TriggerError("Invalid token");
					return null;
				case Lexer.Token.Comma:
					lexer.NextToken();
					break;
				case Lexer.Token.CurlyClose:
					lexer.NextToken();
					return table;
				default:
					// name
					String name = EvalLexer(lexer.ParseString());

					if (errorMessage != null)
						return null;

					// :
					token = lexer.NextToken();

					if (token != Lexer.Token.Colon) {
						TriggerError("Invalid token; expected ':'");
						return null;
					}

					// value
					Object value = ParseValue();

					if (errorMessage != null)
						return null;

					table[name] = value;
					break;
				}
			}
		}

		List<Object> ParseArray()
		{
			var array = new List<Object>();

			// [
			lexer.NextToken();

			while (true) {
				var token = lexer.LookAhead();

				switch (token) {
				case Lexer.Token.None:
					TriggerError("Invalid token");
					return null;
				case Lexer.Token.Comma:
					lexer.NextToken();
					break;
				case Lexer.Token.SquaredClose:
					lexer.NextToken();
					return array;
				default:
					Object value = ParseValue();

					if (errorMessage != null)
						return null;

					array.Add(value);
					break;
				}
			}
		}

		Object ParseValue()
		{
			switch (lexer.LookAhead()) {
			case Lexer.Token.String:
				return EvalLexer(lexer.ParseString());
			case Lexer.Token.Number:
				if (parseNumbersAsFloat)
					return EvalLexer(lexer.ParseFloatNumber());
				else
					return EvalLexer(lexer.ParseDoubleNumber());
			case Lexer.Token.CurlyOpen:
				return ParseObject();
			case Lexer.Token.SquaredOpen:
				return ParseArray();
			case Lexer.Token.True:
				lexer.NextToken();
				return true;
			case Lexer.Token.False:
				lexer.NextToken();
				return false;
			case Lexer.Token.Null:
				lexer.NextToken();
				return null;
			case Lexer.Token.None:
				fallthrough;
			default:
				TriggerError("Unable to parse value");
				return null;
			}

			
		}

		void TriggerError(String message)
		{
			errorMessage = new String()..AppendF("Error: '{0}' at line {1}",
			                             message, lexer.lineNumber);
		}

		T EvalLexer<T>(T value)
		{
			if (lexer.hasError)
				TriggerError("Lexical error ocurred");

			return value;
		}
	}
}
