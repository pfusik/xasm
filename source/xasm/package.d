// xasm 3.3.0 by Piotr Fusik <fox@scene.pl>
// https://xasm.atari.org

// Poetic License:
//
// This work 'as-is' we provide.
// No warranty express or implied.
// We've done our best,
// to debug and test.
// Liability for damages denied.
//
// Permission is granted hereby,
// to copy, share, and modify.
// Use as is fit,
// free or for profit.
// These rights, on this notice, rely.

module xasm;

import std.algorithm : canFind, find, sort;
import std.array : Appender, replaceFirst;
import std.conv : hexString, to;
import std.format : format;
import std.math : PI, rint, sin;
import std.range : empty, front, popFront;
import std.string : representation, startsWith, toUpper;
version (unittest) import std.stdio;

/// Severity of a `Diagnostic` reported during assembly.
enum Severity { warning, error }

/// A single warning or error emitted by the assembler, together with the
/// source location it refers to.
struct Diagnostic {
	Severity severity; /// Whether this diagnostic is a warning or a fatal error.
	string filename; /// Name of the source file the diagnostic refers to.
	int lineNo; /// 1-based line number within `filename`.
	string line; /// Text of the offending source line.
	string message; /// Human-readable description of the problem.
}

/// Callback invoked for every `Diagnostic` produced during assembly.
alias DiagnosticSink = void delegate(in Diagnostic d);

/// Callback that returns the contents of the source file at `path`.
alias SourceReader = immutable(ubyte)[] delegate(string path);

/// Callback that returns `length` bytes starting at `offset` from the binary
/// file at `path`, as used by binary include directives.
alias BinaryReader = immutable(ubyte)[] delegate(string path, int offset, int length);

/// Callback that receives the assembly listing one line at a time.
alias ListingSink = void delegate(const(char)[] line);

private class AssemblyError : Exception {
	this(string msg) {
		super(msg);
	}
}

/// An entry in the assembler's symbol table.
struct Label {
	int value; /// The value assigned to the label.
	bool unused = true; /// True until the label is referenced somewhere.
	bool unknownInPass1 = false; /// True if the value was not yet known during pass 1.
	bool passed = false; /// True once the label's definition was encountered in pass 2.
}

/// Assembles xasm 6502 source into an object file.
///
/// File and diagnostic I/O are delegated to caller-supplied callbacks, so the
/// assembler itself performs no direct file access.
class Assembler {

	/// Constructs an assembler that reads source and binary files through
	/// `sourceReader` and `binaryReader`, and reports warnings and errors
	/// through `diagnostics`.
	this(SourceReader sourceReader, BinaryReader binaryReader, DiagnosticSink diagnostics) {
		this.sourceReader = sourceReader;
		this.binaryReader = binaryReader;
		this.diagnostics = diagnostics;
	}

	bool listFalseConditionals; /// List lines skipped by false conditionals.
	bool listIncludedFiles = true; /// List the contents of included files.
	bool warnUnusedLabels; /// Warn about labels that are declared but never used.

	/// Labels to predefine, each in `NAME=VALUE` form, as given on the command line.
	string[] commandLineDefinitions = null;

	/// Sink that receives the assembly listing; if null, no listing is produced.
	ListingSink listingSink;

	/// Assembles the source file `sourceFilename`, reporting any problems
	/// through the diagnostics callback given to the constructor.
	void assemble(string sourceFilename) {
		this.sourceFilename = sourceFilename;
		try {
			pass2 = false;
			assemblyPass();
			pass2 = true;
			objectBuffer.clear();
			assemblyPass();
		} catch (AssemblyError e) {
			reportDiagnostics(e.msg, Severity.error);
		}
	}

	/// The assembled object code produced by the last call to `assemble`.
	const(ubyte)[] object() const { return objectBuffer.data; }

	/// The total number of source lines processed.
	size_t linesAssembled() const { return totalLines; }

	/// True if at least one label was defined.
	bool hasLabels() const { return labelTable.length > 0; }

	/// Looks up `label` (case-insensitively) and returns a pointer to its
	/// table entry, or null if it is not defined.
	const(Label*) getLabel(const(char)[] label) const { return label.toUpper in labelTable; }

	/// Writes the label table, sorted by name, to `sink` one line at a time.
	void listLabelTable(ListingSink sink) {
		sink("Label table:");
		foreach (string name; sort(labelTable.keys)) {
			Label l = labelTable[name];
			int value = l.value;
			char sign = ' ';
			if (value < 0) {
				sign = '-';
				value = -value;
			}
			immutable fmt = (l.value & 0xffff0000) != 0 ? "%s%s %s%08X %s" : "%s%s     %s%04X %s";
			sink(format(fmt,
				l.unused ? 'n' : ' ',
				l.unknownInPass1 ? '2' : ' ',
				sign, value, name));
		}
	}

private:
	version (unittest) static Assembler testAssembler() {
		return new Assembler(
			(string path) => (immutable(ubyte)[]).init,
			(string path, int offset, int length) => (immutable(ubyte)[]).init,
			null);
	}

	string sourceFilename = null;
	immutable(ubyte)[][string] sourceFiles;

	int totalLines;

	bool pass2 = false;

	bool optionFill; // opt f
	bool option5200; // opt g
	bool optionHeaders; // opt h
	bool optionListing; // opt l
	bool optionObject; // opt o
	bool optionUnusedLabels; // opt u

	string currentFilename;
	int lineNo;
	int includeLevel = 0;
	string line;
	int column;

	bool foundEnd;

	Label[string] labelTable;
	Label* currentLabel;
	string lastGlobalLabel;

	alias int function(int a, int b) OperatorFunction;

	bool inOpcode = false;

	struct ValOp {
		int value;
		OperatorFunction func;
		int priority;
	}

	ValOp[] valOpStack;

	int value;
	bool unknownInPass1;

	enum AddrMode {
		ACCUMULATOR = 0,
		IMMEDIATE = 1,
		ABSOLUTE = 2,
		ZEROPAGE = 3,
		ABSOLUTE_X = 4,
		ZEROPAGE_X = 5,
		ABSOLUTE_Y = 6,
		ZEROPAGE_Y = 7,
		INDIRECT_X = 8,
		INDIRECT_Y = 9,
		INDIRECT = 10,
		ABS_OR_ZP = 11, // temporarily used in readAddrMode
		STANDARD_MASK = 15,
		INCREMENT = 0x20,
		DECREMENT = 0x30,
		ZERO = 0x40
	}

	AddrMode addrMode;

	enum OrgModifier {
		NONE,
		FORCE_HEADER,
		FORCE_FFFF,
		RELOCATE
	}

	int origin = -1;
	int loadOrigin;
	int loadingOrigin;
	ushort[] blockEnds;
	int blockIndex;

	bool repeating; // line
	int repeatCounter; // line

	bool instructionBegin;
	bool sequencing;

	bool willSkip;
	bool skipping;
	ushort[] skipOffsets;
	int skipOffsetsIndex = 0;

	int repeatOffset; // instruction repeat

	bool wereManyInstructions;

	alias void delegate(int move) MoveFunction;

	int value1;
	AddrMode addrMode1;
	int value2;
	AddrMode addrMode2;

	struct IfContext {
		bool condition;
		bool wasElse;
		bool aConditionMatched;
	}

	IfContext[] ifContexts;

	char[32] listingLine;
	int listingColumn;
	string lastListedFilename = null;

	DiagnosticSink diagnostics;
	SourceReader sourceReader;
	BinaryReader binaryReader;

	immutable(ubyte)[] readSource(string filename) {
		try {
			return sourceReader(filename);
		} catch (Exception e) {
			throw new AssemblyError(e.msg);
		}
	}

	immutable(ubyte)[] readBinary(string path, int offset, int length) {
		try {
			return binaryReader(path, offset, length);
		} catch (Exception e) {
			throw new AssemblyError(e.msg);
		}
	}

	void reportDiagnostics(string msg, Severity s) {
		diagnostics(Diagnostic(s, currentFilename, lineNo, line, msg));
	}

	void warning(string msg) {
		reportDiagnostics(msg, Severity.warning);
	}

	void illegalCharacter() {
		throw new AssemblyError("Illegal character");
	}

	bool eol() {
		return column >= line.length;
	}

	char readChar() {
		if (eol())
			throw new AssemblyError("Unexpected end of line");
		return line[column++];
	}

	int readDigit(int base) {
		if (eol()) return -1;
		int r = line[column];
		if (r >= '0' && r <= '9') {
			r -= '0';
		} else {
			r &= 0xdf;
			if (r >= 'A' && r <= 'Z')
				r -= 'A' - 10;
			else
				return -1;
		}
		if (r < base) {
			column++;
			return r;
		}
		return -1;
	}

	int readNumber(int base) {
		long r = readDigit(base);
		if (r < 0)
			illegalCharacter();
		do {
			int d = readDigit(base);
			if (d < 0)
				return cast(int) r;
			r = r * base + d;
		} while (r <= 0x7fffffff);
		throw new AssemblyError("Number too big");
	}

	void readSpaces() {
		switch (readChar()) {
		case '\t':
		case ' ':
			break;
		default:
			throw new AssemblyError("Space expected");
		}
		while (!eol()) {
			switch (line[column]) {
			case '\t':
			case ' ':
				column++;
				break;
			default:
				return;
			}
		}
	}

	string readLabel() {
		int firstColumn = column;
		while (!eol()) {
			char c = line[column++];
			if (c >= '0' && c <= '9' || c == '_' || c == '?')
				continue;
			c &= 0xdf;
			if (c >= 'A' && c <= 'Z')
				continue;
			column--;
			break;
		}
		string label = line[firstColumn .. column].toUpper;
		if (label.startsWith('?')) {
			if (lastGlobalLabel is null)
				throw new AssemblyError("Global label must be declared first");
			label = lastGlobalLabel ~ label;
		}
		return label >= "A" ? label : null;
	}

	void readComma() {
		if (readChar() != ',')
			throw new AssemblyError("Bad or missing function parameter");
	}

	string readInstruction() {
		string r;
		for (int i = 0; i < 3; i++) {
			char c = readChar() & 0xdf;
			if (c < 'A' || c > 'Z')
				throw new AssemblyError("Illegal instruction");
			r ~= c;
		}
		return r;
	}

	string readFunction() {
		if (column + 5 >= line.length) return null;
		if (line[column + 3] != '(') return null;
		string r;
		for (int i = 0; i < 3; i++) {
			char c = line[column + i] & 0xdf;
			if (c < 'A' || c > 'Z') return null;
			r ~= c;
		}
		column += 4;
		return r;
	}

	string readFilename() {
		readSpaces();
		char delimiter = readChar();
		switch (delimiter) {
		case '"':
		case '\'':
			string filename;
			char c;
			while ((c = readChar()) != delimiter)
				filename ~= c;
			return filename;
		default:
			illegalCharacter();
		}
		assert(0);
	}

	void readStringChar(char c) {
		if (readChar() != c)
			throw new AssemblyError("String error");
	}

	ubyte[] readString() {
		if (eol()) return null;
		char delimiter = readChar();
		switch (delimiter) {
		case '"':
		case '\'':
			ubyte[] r;
			for (;;) {
				char c = readChar();
				if (c == delimiter) {
					if (eol()) return r;
					if (line[column] != delimiter) {
						if (line[column] == '*') {
							column++;
							foreach (ref ubyte b; r)
								b ^= 0x80;
						}
						return r;
					}
					column++;
				}
				r ~= cast(ubyte) c;
			}
		default:
			column--;
			return null;
		}
	}

	void checkNoExtraCharacters() {
		if (eol()) return;
		switch (line[column]) {
		case '\t':
		case ' ':
			return;
		default:
			throw new AssemblyError("Extra characters on line");
		}
	}

	void checkOriginDefined() {
		if (origin < 0)
			throw new AssemblyError("No ORG specified");
	}

	static int operatorPlus(int a, int b) {
		return b;
	}

	static int operatorMinus(int a, int b) {
		return -b;
	}

	static int operatorLow(int a, int b) {
		return b & 0xff;
	}

	static int operatorHigh(int a, int b) {
		return (b >> 8) & 0xff;
	}

	static int operatorLogicalNot(int a, int b) {
		return !b;
	}

	static int operatorBitwiseNot(int a, int b) {
		return ~b;
	}

	static int operatorAdd(int a, int b) {
		long r = cast(long) a + b;
		if (r < -0x80000000L || r > 0x7fffffffL)
			throw new AssemblyError("Arithmetic overflow");
		return a + b;
	}

	static int operatorSubtract(int a, int b) {
		long r = cast(long) a - b;
		if (r < -0x80000000L || r > 0x7fffffffL)
			throw new AssemblyError("Arithmetic overflow");
		return a - b;
	}

	static int operatorMultiply(int a, int b) {
		long r = cast(long) a * b;
		if (r < -0x80000000L || r > 0x7fffffffL)
			throw new AssemblyError("Arithmetic overflow");
		return a * b;
	}

	static int operatorDivide(int a, int b) {
		if (b == 0)
			throw new AssemblyError("Divide by zero");
		return a / b;
	}

	static int operatorModulus(int a, int b) {
		if (b == 0)
			throw new AssemblyError("Divide by zero");
		return a % b;
	}

	static int operatorAnd(int a, int b) {
		return a & b;
	}

	static int operatorOr(int a, int b) {
		return a | b;
	}

	static int operatorXor(int a, int b) {
		return a ^ b;
	}

	static int operatorEqual(int a, int b) {
		return a == b;
	}

	static int operatorNotEqual(int a, int b) {
		return a != b;
	}

	static int operatorLess(int a, int b) {
		return a < b;
	}

	static int operatorGreater(int a, int b) {
		return a > b;
	}

	static int operatorLessEqual(int a, int b) {
		return a <= b;
	}

	static int operatorGreaterEqual(int a, int b) {
		return a >= b;
	}

	static int operatorShiftLeft(int a, int b) {
		if (b < 0)
			return operatorShiftRight(a, -b);
		if (a != 0 && b >= 32)
			throw new AssemblyError("Arithmetic overflow");
		long r = cast(long) a << b;
		if (r & 0xffffffff00000000L)
			throw new AssemblyError("Arithmetic overflow");
		return a << b;
	}

	static int operatorShiftRight(int a, int b) {
		if (b < 0)
			return operatorShiftLeft(a, -b);
		if (b >= 32)
			b = 31;
		return a >> b;
	}

	static int operatorLogicalAnd(int a, int b) {
		return a && b;
	}

	static int operatorLogicalOr(int a, int b) {
		return a || b;
	}

	void pushValOp(int value, OperatorFunction func, int priority) {
		ValOp valOp;
		valOp.value = value;
		valOp.func = func;
		valOp.priority = priority;
		valOpStack ~= valOp;
	}

	void readValue() {
		assert(valOpStack.length == 0);
		unknownInPass1 = false;
		int priority = 0;
		do {
			int operand;
			char c = readChar();
			switch (c) {
			case '[':
				priority += 10;
				continue;
			case '+':
				pushValOp(0, &operatorPlus, priority + 8);
				continue;
			case '-':
				pushValOp(0, &operatorMinus, priority + 8);
				continue;
			case '<':
				pushValOp(0, &operatorLow, priority + 8);
				continue;
			case '>':
				pushValOp(0, &operatorHigh, priority + 8);
				continue;
			case '!':
				pushValOp(0, &operatorLogicalNot, priority + 4);
				continue;
			case '~':
				pushValOp(0, &operatorBitwiseNot, priority + 8);
				continue;
			case '(':
				throw new AssemblyError("Use square brackets instead");
			case '*':
				checkOriginDefined();
				operand = origin;
				break;
			case '#':
				if (!repeating)
					throw new AssemblyError("'#' is allowed only in repeated lines");
				operand = repeatCounter;
				break;
			case '\'':
			case '"':
				operand = readChar();
				if (operand == c)
					readStringChar(c);
				readStringChar(c);
				if (!eol() && line[column] == '*') {
					column++;
					operand ^= 0x80;
				}
				break;
			case '^':
				switch (readChar()) {
				case '0':
					operand = option5200 ? 0xc000 : 0xd000;
					break;
				case '1':
					operand = option5200 ? 0xc010 : 0xd010;
					break;
				case '2':
					operand = option5200 ? 0xe800 : 0xd200;
					break;
				case '3':
					if (option5200)
						throw new AssemblyError("There's no PIA chip in Atari 5200");
					operand = 0xd300;
					break;
				case '4':
					operand = 0xd400;
					break;
				default:
					illegalCharacter();
				}
				int d = readDigit(16);
				if (d < 0)
					illegalCharacter();
				operand += d;
				break;
			case '{':
				if (inOpcode)
					throw new AssemblyError("Nested opcodes not supported");
				ValOp[] savedValOpStack = valOpStack;
				AddrMode savedAddrMode = addrMode;
				bool savedUnknownInPass1 = unknownInPass1;
				bool savedInstructionBegin = instructionBegin;
				valOpStack.length = 0;
				inOpcode = true;
				assemblyInstruction(readInstruction());
				if (readChar() != '}')
					throw new AssemblyError("Missing '}'");
				assert(!instructionBegin);
				inOpcode = false;
				valOpStack = savedValOpStack;
				addrMode = savedAddrMode;
				unknownInPass1 = savedUnknownInPass1;
				instructionBegin = savedInstructionBegin;
				operand = value;
				break;
			case '$':
				operand = readNumber(16);
				break;
			case '%':
				operand = readNumber(2);
				break;
			default:
				column--;
				if (c >= '0' && c <= '9') {
					operand = readNumber(10);
					break;
				}
				string label = readLabel();
				if (label is null)
					illegalCharacter();
				if (Label* l = label in labelTable) {
					operand = l.value;
					l.unused = false;
					if (pass2) {
						if (l.passed) {
							if (l.unknownInPass1)
								unknownInPass1 = true;
						} else {
							if (l.unknownInPass1)
								throw new AssemblyError("Illegal forward reference");
							unknownInPass1 = true;
						}
					} else {
						if (l.unknownInPass1)
							unknownInPass1 = true;
					}
				} else {
					if (pass2)
						throw new AssemblyError("Undeclared label: " ~ label);
					unknownInPass1 = true;
				}
				break;
			}
			while (!eol() && line[column] == ']') {
				column++;
				priority -= 10;
				if (priority < 0)
					throw new AssemblyError("Unmatched bracket");
			}
			if (eol()) {
				if (priority != 0)
					throw new AssemblyError("Unmatched bracket");
				pushValOp(operand, &operatorPlus, 1);
			} else {
				switch (line[column++]) {
				case '+':
					pushValOp(operand, &operatorAdd, priority + 6);
					break;
				case '-':
					pushValOp(operand, &operatorSubtract, priority + 6);
					break;
				case '*':
					pushValOp(operand, &operatorMultiply, priority + 7);
					break;
				case '/':
					pushValOp(operand, &operatorDivide, priority + 7);
					break;
				case '%':
					pushValOp(operand, &operatorModulus, priority + 7);
					break;
				case '<':
					switch (readChar()) {
					case '<':
						pushValOp(operand, &operatorShiftLeft, priority + 7);
						break;
					case '=':
						pushValOp(operand, &operatorLessEqual, priority + 5);
						break;
					case '>':
						pushValOp(operand, &operatorNotEqual, priority + 5);
						break;
					default:
						column--;
						pushValOp(operand, &operatorLess, priority + 5);
						break;
					}
					break;
				case '=':
					switch (readChar()) {
					default:
						column--;
						goto case '=';
					case '=':
						pushValOp(operand, &operatorEqual, priority + 5);
						break;
					}
					break;
				case '>':
					switch (readChar()) {
					case '>':
						pushValOp(operand, &operatorShiftRight, priority + 7);
						break;
					case '=':
						pushValOp(operand, &operatorGreaterEqual, priority + 5);
						break;
					default:
						column--;
						pushValOp(operand, &operatorGreater, priority + 5);
						break;
					}
					break;
				case '!':
					switch (readChar()) {
					case '=':
						pushValOp(operand, &operatorNotEqual, priority + 5);
						break;
					default:
						illegalCharacter();
					}
					break;
				case '&':
					switch (readChar()) {
					case '&':
						pushValOp(operand, &operatorLogicalAnd, priority + 3);
						break;
					default:
						column--;
						pushValOp(operand, &operatorAnd, priority + 7);
						break;
					}
					break;
				case '|':
					switch (readChar()) {
					case '|':
						pushValOp(operand, &operatorLogicalOr, priority + 2);
						break;
					default:
						column--;
						pushValOp(operand, &operatorOr, priority + 6);
						break;
					}
					break;
				case '^':
					pushValOp(operand, &operatorXor, priority + 6);
					break;
				default:
					column--;
					if (priority != 0)
						throw new AssemblyError("Unmatched bracket");
					pushValOp(operand, &operatorPlus, 1);
					break;
				}
			}
			for (;;) {
				immutable sp = valOpStack.length - 1;
				if (sp <= 0 || valOpStack[sp].priority > valOpStack[sp - 1].priority)
					break;
				int operand1 = valOpStack[sp - 1].value;
				OperatorFunction func1 = valOpStack[sp - 1].func;
				valOpStack[sp - 1] = valOpStack[sp];
				valOpStack.length = sp;
				if (pass2 || !unknownInPass1) { // skip operations if unknown operands
					valOpStack[sp - 1].value = func1(operand1, valOpStack[sp - 1].value);
				}
			}
		} while (valOpStack.length != 1 || valOpStack[0].priority != 1);
		value = valOpStack[0].value;
		valOpStack.length = 0;
	}

	version (unittest) int testValue(string l) {
		line = l;
		column = 0;
		readValue();
		return value;
	}

	unittest {
		auto a = testAssembler();
		with (a) {
			assert(testValue("123") == 123);
			assert(testValue("$1234abCd") == 0x1234abcd);
			assert(testValue("%101") == 5);
			assert(testValue("^07") == 0xd007);
			assert(testValue("^1f") == 0xd01f);
			assert(testValue("^23") == 0xd203);
			assert(testValue("^31") == 0xd301);
			assert(testValue("^49") == 0xd409);
			assert(testValue("!0") == 1);
			assert(testValue("<$1234") == 0x34);
			assert(testValue(">$1234567") == 0x45);
			assert(testValue("1+2") == 3);
			assert(testValue("1+2*3") == 7);
			assert(testValue("[1+2]*3") == 9);
			assert(testValue("{nop}") == 0xea);
			assert(testValue("{CLC}+{sec}") == 0x50);
			assert(testValue("{Jsr}") == 0x20);
			assert(testValue("{bit a:}") == 0x2c);
			assert(testValue("{bIt $7d}") == 0x24);
		}
	}

	void mustBeKnownInPass1() {
		if (unknownInPass1)
			throw new AssemblyError("Label not defined before");
	}

	void readWord() {
		readValue();
		if ((!unknownInPass1 || pass2) && (value < -0xffff || value > 0xffff))
			throw new AssemblyError("Value out of range");
	}

	void readUnsignedWord() {
		readWord();
		if ((!unknownInPass1 || pass2) && value < 0)
			throw new AssemblyError("Value out of range");
	}

	void readKnownPositive() {
		readValue();
		mustBeKnownInPass1();
		if (value <= 0)
			throw new AssemblyError("Value out of range");
	}

	void optionalIncDec() {
		if (eol()) return;
		switch (line[column]) {
		case '+':
			column++;
			addrMode += AddrMode.INCREMENT;
			return;
		case '-':
			column++;
			addrMode += AddrMode.DECREMENT;
			return;
		default:
			return;
		}
	}

	void readAddrMode() {
		readSpaces();
		char c = readChar();
		switch (c) {
		case '@':
			addrMode = AddrMode.ACCUMULATOR;
			return;
		case '#':
		case '<':
		case '>':
			addrMode = AddrMode.IMMEDIATE;
			if (inOpcode && line[column] == '}')
				return;
			readWord();
			final switch (c) {
			case '#':
				break;
			case '<':
				value &= 0xff;
				break;
			case '>':
				value = (value >> 8) & 0xff;
				break;
			}
			return;
		case '(':
			if (inOpcode) {
				switch (readChar()) {
				case ',':
					switch (readChar()) {
					case 'X':
					case 'x':
						break;
					default:
						illegalCharacter();
					}
					if (readChar() != ')')
						throw new AssemblyError("Need parenthesis");
					addrMode = AddrMode.INDIRECT_X;
					return;
				case ')':
					if (readChar() == ',') {
						switch (readChar()) {
						case 'Y':
						case 'y':
							break;
						default:
							illegalCharacter();
						}
						addrMode = AddrMode.INDIRECT_Y;
						return;
					} else {
						column--;
						addrMode = AddrMode.INDIRECT;
						return;
					}
				default:
					column--;
					break;
				}
			}
			readUnsignedWord();
			switch (readChar()) {
			case ',':
				switch (readChar()) {
				case 'X':
				case 'x':
					addrMode = AddrMode.INDIRECT_X;
					break;
				case '0':
					addrMode = cast(AddrMode) (AddrMode.INDIRECT_X + AddrMode.ZERO);
					break;
				default:
					illegalCharacter();
				}
				if (readChar() != ')')
					throw new AssemblyError("Need parenthesis");
				return;
			case ')':
				if (eol()) {
					addrMode = AddrMode.INDIRECT;
					return;
				}
				if (line[column] == ',') {
					column++;
					switch (readChar()) {
					case 'Y':
					case 'y':
						addrMode = AddrMode.INDIRECT_Y;
						break;
					case '0':
						addrMode = cast(AddrMode) (AddrMode.INDIRECT_Y + AddrMode.ZERO);
						break;
					default:
						illegalCharacter();
					}
					optionalIncDec();
					return;
				}
				addrMode = AddrMode.INDIRECT;
				return;
			default:
				illegalCharacter();
			}
			break;
		case 'A':
		case 'a':
			if (!eol() && line[column] == ':') {
				column++;
				addrMode = AddrMode.ABSOLUTE;
			} else {
				addrMode = AddrMode.ABS_OR_ZP;
				column--;
			}
			break;
		case 'Z':
		case 'z':
			if (!eol() && line[column] == ':') {
				column++;
				addrMode = AddrMode.ZEROPAGE;
			} else {
				addrMode = AddrMode.ABS_OR_ZP;
				column--;
			}
			break;
		default:
			addrMode = AddrMode.ABS_OR_ZP;
			column--;
			break;
		}
		// absolute or zeropage addressing, optionally indexed
		if (inOpcode && (addrMode == AddrMode.ABSOLUTE || addrMode == AddrMode.ZEROPAGE)) {
			switch (readChar()) {
			case '}':
				column--;
				return;
			case ',':
				switch (readChar()) {
				case 'X':
				case 'x':
					addrMode += cast(AddrMode) (AddrMode.ABSOLUTE_X - AddrMode.ABSOLUTE);
					return;
				case 'Y':
				case 'y':
					addrMode += cast(AddrMode) (AddrMode.ABSOLUTE_Y - AddrMode.ABSOLUTE);
					return;
				default:
					illegalCharacter();
				}
				return;
			default:
				column--;
				break;
			}
		}
		readUnsignedWord();
		if (addrMode == AddrMode.ABS_OR_ZP) {
			if (unknownInPass1 || value > 0xff)
				addrMode = AddrMode.ABSOLUTE;
			else
				addrMode = AddrMode.ZEROPAGE;
		}
		if (eol()) return;
		if (line[column] == ',') {
			column++;
			switch (readChar()) {
			case 'X':
			case 'x':
				addrMode += cast(AddrMode) (AddrMode.ABSOLUTE_X - AddrMode.ABSOLUTE);
				optionalIncDec();
				return;
			case 'Y':
			case 'y':
				addrMode += cast(AddrMode) (AddrMode.ABSOLUTE_Y - AddrMode.ABSOLUTE);
				optionalIncDec();
				return;
			default:
				illegalCharacter();
			}
		}
	}

	void readAbsoluteAddrMode() {
		if (inOpcode && readChar() == '}') {
			column--;
		} else {
			readAddrMode();
			switch (addrMode) {
			case AddrMode.ABSOLUTE:
			case AddrMode.ZEROPAGE:
				break;
			default:
				illegalAddrMode();
			}
		}
		addrMode = AddrMode.ABSOLUTE;
	}

	version (unittest) AddrMode testAddrMode(string l) {
		line = l;
		column = 0;
		readAddrMode();
		return addrMode;
	}

	unittest {
		auto a = testAssembler();
		with (a) {
			assert(testAddrMode(" @") == AddrMode.ACCUMULATOR);
			assert(testAddrMode(" #0") == AddrMode.IMMEDIATE);
			assert(testAddrMode(" $abc,x-") == cast(AddrMode) (AddrMode.ABSOLUTE_X + AddrMode.DECREMENT));
			assert(testAddrMode(" $ab,Y+") == cast(AddrMode) (AddrMode.ZEROPAGE_Y + AddrMode.INCREMENT));
			assert(testAddrMode(" (0,x)") == AddrMode.INDIRECT_X);
			assert(testAddrMode(" ($ff),Y+") == cast(AddrMode) (AddrMode.INDIRECT_Y + AddrMode.INCREMENT));
			assert(testAddrMode(" ($abcd)") == AddrMode.INDIRECT);
			inOpcode = true;
			assert(testAddrMode(" a:}") == AddrMode.ABSOLUTE);
			assert(testAddrMode(" z:}") == AddrMode.ZEROPAGE);
			assert(testAddrMode(" a:,x}") == AddrMode.ABSOLUTE_X);
			assert(testAddrMode(" z:,y}") == AddrMode.ZEROPAGE_Y);
			assert(testAddrMode(" (,X)}") == AddrMode.INDIRECT_X);
			assert(testAddrMode(" (),y}") == AddrMode.INDIRECT_Y);
			assert(testAddrMode(" ()}") == AddrMode.INDIRECT);
			inOpcode = false;
		}
	}

	bool inFalseCondition() {
		foreach (IfContext ic; ifContexts) {
			if (!ic.condition) return true;
		}
		return false;
	}

	void listNibble(int x) {
		listingLine[listingColumn++] = cast(char) (x <= 9 ? x + '0' : x + ('A' - 10));
	}

	void listByte(ubyte x) {
		listNibble(x >> 4);
		listNibble(x & 0xf);
	}

	void listWord(ushort x) {
		listByte(cast(ubyte) (x >> 8));
		listByte(cast(ubyte) x);
	}

	void listLine() {
		if (!optionListing || listingSink is null || line is null)
			return;
		assert(pass2);
		if (inFalseCondition() && !listFalseConditionals)
			return;
		if (!listIncludedFiles && includeLevel > 0)
			return;
		if (currentFilename != lastListedFilename) {
			listingSink("Source: " ~ currentFilename);
			lastListedFilename = currentFilename;
		}
		int i = 4;
		int x = lineNo;
		while (x > 0 && i >= 0) {
			listingLine[i--] = '0' + x % 10;
			x /= 10;
		}
		while (i >= 0)
			listingLine[i--] = ' ';
		listingLine[5] = ' ';
		while (listingColumn < 32)
			listingLine[listingColumn++] = ' ';
		listingSink(format("%.32s%s", listingLine, line));
	}

	void listCommentLine() {
		if (currentLabel is null)
			listingColumn = 6;
		else {
			assert(!inFalseCondition());
			checkOriginDefined();
		}
		listLine();
	}

	Appender!(ubyte[]) objectBuffer;

	void objectByte(ubyte b) {
		version (unittest) {} else {
			assert(pass2);
			if (!optionObject) return;
		}
		objectBuffer.put(b);
	}

	void objectWord(ushort w) {
		objectByte(cast(ubyte) w);
		objectByte(cast(ubyte) (w >> 8));
	}

	void putByte(ubyte b) {
		if (inOpcode) {
			if (instructionBegin) {
				value = b;
				instructionBegin = false;
			}
			return;
		}
		if (willSkip) {
			assert(!pass2);
			willSkip = false;
			skipping = true;
		}
		if (skipping) {
			assert(!pass2);
			skipOffsets[$ - 1]++;
		}
		if (instructionBegin) {
			repeatOffset = -2;
			instructionBegin = false;
		}
		repeatOffset--;
		if (optionFill && loadingOrigin >= 0 && loadingOrigin != loadOrigin) {
			if (loadingOrigin > loadOrigin)
				throw new AssemblyError("Can't fill from higher to lower memory location");
			if (pass2) {
				while (loadingOrigin < loadOrigin) {
					objectByte(0xff);
					loadingOrigin++;
				}
			}
		}
		version (unittest) {
			objectByte(b);
		}
		if (pass2) {
			version (unittest) {
			} else {
				objectByte(b);
			}
			if (listingColumn < 29) {
				listByte(b);
				listingLine[listingColumn++] = ' ';
			} else {
				listingLine[29] = '+';
				listingColumn = 30;
			}
		}
		if (optionHeaders) {
			if (origin < 0)
				throw new AssemblyError("No ORG specified");
			assert(blockIndex >= 0);
			if (!pass2) {
				blockEnds[blockIndex] = cast(ushort) loadOrigin;
			}
		}
		if (origin >= 0) {
			origin++;
			loadingOrigin = ++loadOrigin;
		}
	}

	void putWord(ushort w) {
		putByte(cast(ubyte) w);
		putByte(cast(ubyte) (w >> 8));
	}

	void putCommand(ubyte b) {
		putByte(b);
		if (inOpcode) return;
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.ACCUMULATOR:
			break;
		case AddrMode.IMMEDIATE:
		case AddrMode.ZEROPAGE:
		case AddrMode.ZEROPAGE_X:
		case AddrMode.ZEROPAGE_Y:
		case AddrMode.INDIRECT_X:
		case AddrMode.INDIRECT_Y:
			if (pass2 && (value < -0xff || value > 0xff))
				throw new AssemblyError("Value out of range");
			putByte(cast(ubyte) value);
			break;
		case AddrMode.ABSOLUTE:
		case AddrMode.ABSOLUTE_X:
		case AddrMode.ABSOLUTE_Y:
		case AddrMode.INDIRECT:
			putWord(cast(ushort) value);
			break;
		default:
			assert(0);
		}
		switch (addrMode) {
		case cast(AddrMode) (AddrMode.ABSOLUTE_X + AddrMode.INCREMENT):
		case cast(AddrMode) (AddrMode.ZEROPAGE_X + AddrMode.INCREMENT):
			putByte(0xe8);
			break;
		case cast(AddrMode) (AddrMode.ABSOLUTE_X + AddrMode.DECREMENT):
		case cast(AddrMode) (AddrMode.ZEROPAGE_X + AddrMode.DECREMENT):
			putByte(0xca);
			break;
		case cast(AddrMode) (AddrMode.ABSOLUTE_Y + AddrMode.INCREMENT):
		case cast(AddrMode) (AddrMode.ZEROPAGE_Y + AddrMode.INCREMENT):
		case cast(AddrMode) (AddrMode.INDIRECT_Y + AddrMode.INCREMENT):
		case cast(AddrMode) (AddrMode.INDIRECT_Y + AddrMode.INCREMENT + AddrMode.ZERO):
			putByte(0xc8);
			break;
		case cast(AddrMode) (AddrMode.ABSOLUTE_Y + AddrMode.DECREMENT):
		case cast(AddrMode) (AddrMode.ZEROPAGE_Y + AddrMode.DECREMENT):
		case cast(AddrMode) (AddrMode.INDIRECT_Y + AddrMode.DECREMENT):
		case cast(AddrMode) (AddrMode.INDIRECT_Y + AddrMode.DECREMENT + AddrMode.ZERO):
			putByte(0x88);
			break;
		default:
			break;
		}
	}

	void noOpcode() {
		if (inOpcode)
			throw new AssemblyError("Can't get opcode of this");
	}

	void directive() {
		noOpcode();
		if (repeating)
			throw new AssemblyError("Can't repeat this directive");
		if (sequencing)
			throw new AssemblyError("Can't pair this directive");
	}

	void noRepeatSkipDirective() {
		directive();
		if (willSkip)
			throw new AssemblyError("Can't skip over this");
		repeatOffset = 0;
	}

	void illegalAddrMode() {
		throw new AssemblyError("Illegal addressing mode");
	}

	void addrModeForMove(int move) {
		final switch (move) {
		case 0:
			readAddrMode();
			break;
		case 1:
			value = value1;
			addrMode = addrMode1;
			break;
		case 2:
			value = value2;
			addrMode = addrMode2;
			break;
		}
	}

	void assemblyAccumulator(ubyte b, ubyte prefix, int move) {
		addrModeForMove(move);
		if (prefix != 0)
			putByte(prefix);
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.ACCUMULATOR:
		case AddrMode.INDIRECT:
			illegalAddrMode();
			break;
		case AddrMode.IMMEDIATE:
			if (b == 0x80) {
				// STA #
				illegalAddrMode();
			}
			putCommand(cast(ubyte) (b + 9));
			break;
		case AddrMode.ABSOLUTE:
			putCommand(cast(ubyte) (b + 0xd));
			break;
		case AddrMode.ZEROPAGE:
			putCommand(cast(ubyte) (b + 5));
			break;
		case AddrMode.ABSOLUTE_X:
			putCommand(cast(ubyte) (b + 0x1d));
			break;
		case AddrMode.ZEROPAGE_X:
			putCommand(cast(ubyte) (b + 0x15));
			break;
		case AddrMode.ZEROPAGE_Y:
			addrMode -= 1;
			goto case AddrMode.ABSOLUTE_Y;
		case AddrMode.ABSOLUTE_Y:
			putCommand(cast(ubyte) (b + 0x19));
			break;
		case AddrMode.INDIRECT_X:
			if ((addrMode & AddrMode.ZERO) != 0)
				putWord(0x00a2);
			putCommand(cast(ubyte) (b + 1));
			break;
		case AddrMode.INDIRECT_Y:
			if ((addrMode & AddrMode.ZERO) != 0)
				putWord(0x00a0);
			putCommand(cast(ubyte) (b + 0x11));
			break;
		default:
			assert(0);
		}
	}

	void assemblyShift(ubyte b) {
		readAddrMode();
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.ACCUMULATOR:
			if (b == 0xc0 || b == 0xe0) {
				// INC @, DEC @
				illegalAddrMode();
			}
			putByte(cast(ubyte) (b + 0xa));
			break;
		case AddrMode.ABSOLUTE:
			putCommand(cast(ubyte) (b + 0xe));
			break;
		case AddrMode.ZEROPAGE:
			putCommand(cast(ubyte) (b + 6));
			break;
		case AddrMode.ABSOLUTE_X:
			putCommand(cast(ubyte) (b + 0x1e));
			break;
		case AddrMode.ZEROPAGE_X:
			putCommand(cast(ubyte) (b + 0x16));
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblyCompareIndex(ubyte b) {
		readAddrMode();
		switch (addrMode) {
		case AddrMode.IMMEDIATE:
			putCommand(b);
			break;
		case AddrMode.ABSOLUTE:
			putCommand(cast(ubyte) (b + 0xc));
			break;
		case AddrMode.ZEROPAGE:
			putCommand(cast(ubyte) (b + 4));
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblyLda(int move) {
		assemblyAccumulator(0xa0, 0, move);
	}

	void assemblyLdx(int move) {
		addrModeForMove(move);
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.IMMEDIATE:
			putCommand(0xa2);
			break;
		case AddrMode.ABSOLUTE:
			putCommand(0xae);
			break;
		case AddrMode.ZEROPAGE:
			putCommand(0xa6);
			break;
		case AddrMode.ABSOLUTE_Y:
			putCommand(0xbe);
			break;
		case AddrMode.ZEROPAGE_Y:
			putCommand(0xb6);
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblyLdy(int move) {
		addrModeForMove(move);
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.IMMEDIATE:
			putCommand(0xa0);
			break;
		case AddrMode.ABSOLUTE:
			putCommand(0xac);
			break;
		case AddrMode.ZEROPAGE:
			putCommand(0xa4);
			break;
		case AddrMode.ABSOLUTE_X:
			putCommand(0xbc);
			break;
		case AddrMode.ZEROPAGE_X:
			putCommand(0xb4);
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblySta(int move) {
		assemblyAccumulator(0x80, 0, move);
	}

	void assemblyStx(int move) {
		addrModeForMove(move);
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.ABSOLUTE:
			putCommand(0x8e);
			break;
		case AddrMode.ZEROPAGE:
			putCommand(0x86);
			break;
		case AddrMode.ABSOLUTE_Y:
			addrMode += 1;
			goto case AddrMode.ZEROPAGE_Y;
		case AddrMode.ZEROPAGE_Y:
			putCommand(0x96);
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblySty(int move) {
		addrModeForMove(move);
		switch (addrMode & AddrMode.STANDARD_MASK) {
		case AddrMode.ABSOLUTE:
			putCommand(0x8c);
			break;
		case AddrMode.ZEROPAGE:
			putCommand(0x84);
			break;
		case AddrMode.ABSOLUTE_X:
			addrMode += 1;
			goto case AddrMode.ZEROPAGE_X;
		case AddrMode.ZEROPAGE_X:
			putCommand(0x94);
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblyBit() {
		readAddrMode();
		switch (addrMode) {
		case AddrMode.ABSOLUTE:
			putCommand(0x2c);
			break;
		case AddrMode.ZEROPAGE:
			putCommand(0x24);
			break;
		default:
			illegalAddrMode();
		}
	}

	void putJump() {
		switch (addrMode) {
		case AddrMode.ZEROPAGE:
			addrMode = AddrMode.ABSOLUTE;
			goto case AddrMode.ABSOLUTE;
		case AddrMode.ABSOLUTE:
			putCommand(0x4c);
			break;
		case AddrMode.INDIRECT:
			if (pass2 && (value & 0xff) == 0xff)
				warning("Buggy indirect jump");
			putCommand(0x6c);
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblyJmp() {
		readAddrMode();
		putJump();
	}

	void assemblyConditionalJump(ubyte b) {
		noOpcode();
		readAddrMode();
		if ((addrMode == AddrMode.ABSOLUTE || addrMode == AddrMode.ZEROPAGE)
		&& pass2 && origin >= 0 && value - origin - 2 >= -0x80 && value - origin - 2 <= 0x7f) {
			warning("Plain branch instruction would be sufficient");
		}
		putByte(b);
		putByte(3);
		putJump();
	}

	void assemblyJsr() {
		readAbsoluteAddrMode();
		putCommand(0x20);
	}

	ubyte calculateBranch(int offset) {
		if (offset < -0x80 || offset > 0x7f) {
			int dist = offset < 0 ? -offset - 0x80 : offset - 0x7f;
			throw new AssemblyError("Branch out of range by " ~ to!string(dist) ~ " bytes");
		}
		return cast(ubyte) offset;
	}

	void assemblyBranch(ubyte b) {
		readAbsoluteAddrMode();
		if (inOpcode) {
			putByte(b);
			return;
		}
		checkOriginDefined();
		putByte(b);
		putByte(pass2 ? calculateBranch(value - origin - 1) : 0);
	}

	void assemblyRepeat(ubyte b) {
		noOpcode();
		int offset = repeatOffset;
		if (offset >= 0)
			throw new AssemblyError("No instruction to repeat");
		if (pass2 && wereManyInstructions)
			warning("Repeating only the last instruction");
		putByte(b);
		putByte(calculateBranch(offset));
	}

	void assemblySkip(ubyte b) {
		noOpcode();
		if (willSkip) {
			skipOffsets[$ - 1] = 2;
			willSkip = false;
		}
		putByte(b);
		if (pass2)
			putByte(calculateBranch(skipOffsets[skipOffsetsIndex++]));
		else {
			putByte(0);
			skipOffsets ~= 0;
			willSkip = true;
		}
	}

	void assemblyInw() {
		noOpcode();
		readAddrMode();
		switch (addrMode) {
		case AddrMode.ABSOLUTE:
			putCommand(0xee);
			putWord(0x03d0);
			value++;
			putCommand(0xee);
			break;
		case AddrMode.ZEROPAGE:
			putCommand(0xe6);
			putWord(0x02d0);
			value++;
			putCommand(0xe6);
			break;
		case AddrMode.ABSOLUTE_X:
			putCommand(0xfe);
			putWord(0x03d0);
			value++;
			putCommand(0xfe);
			break;
		case AddrMode.ZEROPAGE_X:
			putCommand(0xf6);
			putWord(0x02d0);
			value++;
			putCommand(0xf6);
			break;
		default:
			illegalAddrMode();
		}
	}

	void assemblyMove() {
		noOpcode();
		readAddrMode();
		value1 = value;
		addrMode1 = addrMode;
		bool unknown1 = unknownInPass1;
		readAddrMode();
		value2 = value;
		addrMode2 = addrMode;
		unknownInPass1 = unknown1;
	}

	void assemblyMoveByte(MoveFunction load, MoveFunction store) {
		assemblyMove();
		load(1);
		store(2);
	}

	void assemblyMoveWord(MoveFunction load, MoveFunction store, ubyte inc, ubyte dec) {
		assemblyMove();
		switch (addrMode2) {
		case AddrMode.ABSOLUTE:
		case AddrMode.ZEROPAGE:
		case AddrMode.ABSOLUTE_X:
		case AddrMode.ZEROPAGE_X:
		case AddrMode.ABSOLUTE_Y:
		case AddrMode.ZEROPAGE_Y:
			break;
		default:
			illegalAddrMode();
		}
		switch (addrMode1) {
		case AddrMode.IMMEDIATE:
			int high = value1 >> 8 & 0xff;
			value1 &= 0xff;
			load(1);
			store(2);
			value2++;
			if (unknownInPass1) {
				value1 = high;
				load(1);
			} else {
				if (inc != 0 && (value1 + 1 & 0xff) == high)
					putByte(inc);
				else if (dec != 0 && (value1 - 1 & 0xff) == high)
					putByte(dec);
				else if (value1 != high) {
					value1 = high;
					load(1);
				}
			}
			store(2);
			break;
		case AddrMode.ABSOLUTE:
		case AddrMode.ZEROPAGE:
		case AddrMode.ABSOLUTE_X:
		case AddrMode.ZEROPAGE_X:
		case AddrMode.ABSOLUTE_Y:
		case AddrMode.ZEROPAGE_Y:
			load(1);
			store(2);
			value1++;
			value2++;
			load(1);
			store(2);
			break;
		default:
			illegalAddrMode();
		}
	}

	void storeDtaNumber(int val, char letter) {
		int limit = 0xffff;
		if (letter == 'b') limit = 0xff;
		if ((!unknownInPass1 || pass2) && (val < -limit || val > limit))
			throw new AssemblyError("Value out of range");
		final switch (letter) {
		case 'a':
			putWord(cast(ushort) val);
			break;
		case 'b':
		case 'l':
			putByte(cast(ubyte) val);
			break;
		case 'h':
			putByte(cast(ubyte) (val >> 8));
			break;
		}
	}

	void assemblyDtaInteger(char letter) {
		if (readFunction() == "SIN") {
			readWord();
			int sinCenter = value;
			readComma();
			readWord();
			int sinAmp = value;
			readComma();
			readKnownPositive();
			int sinPeriod = value;
			int sinMin = 0;
			int sinMax = sinPeriod - 1;
			switch (readChar()) {
			case ')':
				break;
			case ',':
				readUnsignedWord();
				mustBeKnownInPass1();
				sinMin = value;
				readComma();
				readUnsignedWord();
				mustBeKnownInPass1();
				sinMax = value;
				if (readChar() != ')') {
					illegalCharacter();
				}
				break;
			default:
				illegalCharacter();
			}
			while (sinMin <= sinMax) {
				int val = sinCenter + cast(int) rint(sinAmp * sin(sinMin * 2 * PI / sinPeriod));
				storeDtaNumber(val, letter);
				sinMin++;
			}
			return;
		}
		readWord();
		storeDtaNumber(value, letter);
	}

	bool realSign;

	int realExponent;

	long realMantissa;

	void putReal() {
		if (realMantissa == 0) {
			putWord(0);
			putWord(0);
			putWord(0);
			return;
		}
		while (realMantissa < 0x1000000000L) {
			realMantissa <<= 4;
			realExponent--;
		}
		if ((realExponent & 1) != 0) {
			if (realMantissa & 0xf)
				throw new AssemblyError("Out of precision");
			realMantissa >>= 4;
		}
		realExponent = (realExponent + 0x89) >> 1;
		if (realExponent < 64 - 49)
			throw new AssemblyError("Out of precision");
		if (realExponent > 64 + 49)
			throw new AssemblyError("Number too big");
		putByte(cast(ubyte) (realSign ? realExponent + 0x80 : realExponent));
		putByte(cast(ubyte) (realMantissa >> 32));
		putByte(cast(ubyte) (realMantissa >> 24));
		putByte(cast(ubyte) (realMantissa >> 16));
		putByte(cast(ubyte) (realMantissa >> 8));
		putByte(cast(ubyte) realMantissa);
	}

	bool readSign() {
		switch (readChar()) {
		case '+':
			return false;
		case '-':
			return true;
		default:
			column--;
			return false;
		}
	}

	void readExponent() {
		bool sign = readSign();
		char c = readChar();
		if (c < '0' || c > '9')
			illegalCharacter();
		int e = c - '0';
		c = readChar();
		if (c >= '0' && c <= '9')
			e = 10 * e + c - '0';
		else
			column--;
		realExponent += sign ? -e : e;
		putReal();
	}

	void readFraction() {
		for (;;) {
			char c = readChar();
			if (c >= '0' && c <= '9') {
				if (c != '0' && realMantissa >= 0x1000000000L)
					throw new AssemblyError("Out of precision");
				realMantissa <<= 4;
				realMantissa += c - '0';
				realExponent--;
				continue;
			}
			if (c == 'E' || c == 'e') {
				readExponent();
				return;
			}
			column--;
			putReal();
			return;
		}
	}

	void assemblyDtaReal() {
		realSign = readSign();
		realExponent = 0;
		realMantissa = 0;
		char c = readChar();
		if (c == '.') {
			readFraction();
			return;
		}
		if (c < '0' || c > '9')
			illegalCharacter();
		do {
			if (realMantissa < 0x1000000000L) {
				realMantissa <<= 4;
				realMantissa += c - '0';
			} else {
				if (c != '0')
					throw new AssemblyError("Out of precision");
				realExponent++;
			}
			c = readChar();
		} while (c >= '0' && c <= '9');
		switch (c) {
		case '.':
			readFraction();
			break;
		case 'E':
		case 'e':
			readExponent();
			break;
		default:
			column--;
			putReal();
			break;
		}
	}

	void assemblyDtaNumbers(char letter) {
		if (eol() || line[column] != '(') {
			column--;
			assemblyDtaInteger('b');
			return;
		}
		column++;
		for (;;) {
			final switch (letter) {
			case 'a':
			case 'b':
			case 'h':
			case 'l':
				assemblyDtaInteger(letter);
				break;
			case 'r':
				assemblyDtaReal();
				break;
			}
			switch (readChar()) {
			case ')':
				return;
			case ',':
				break;
			default:
				illegalCharacter();
			}
		}
	}

	void assemblyDta() {
		noOpcode();
		readSpaces();
		for (;;) {
			switch (readChar()) {
			case 'A':
			case 'a':
				assemblyDtaNumbers('a');
				break;
			case 'B':
			case 'b':
				assemblyDtaNumbers('b');
				break;
			case 'C':
			case 'c':
				ubyte[] s = readString();
				if (s is null) {
					column--;
					assemblyDtaInteger('b');
					break;
				}
				foreach (ubyte b; s) {
					putByte(b);
				}
				break;
			case 'D':
			case 'd':
				ubyte[] s = readString();
				if (s is null) {
					column--;
					assemblyDtaInteger('b');
					break;
				}
				foreach (ubyte b; s) {
					final switch (b & 0x60) {
					case 0x00:
						putByte(cast(ubyte) (b + 0x40));
						break;
					case 0x20:
					case 0x40:
						putByte(cast(ubyte) (b - 0x20));
						break;
					case 0x60:
						putByte(b);
						break;
					}
				}
				break;
			case 'H':
			case 'h':
				assemblyDtaNumbers('h');
				break;
			case 'L':
			case 'l':
				assemblyDtaNumbers('l');
				break;
			case 'R':
			case 'r':
				assemblyDtaNumbers('r');
				break;
			default:
				column--;
				assemblyDtaInteger('b');
				break;
			}
			if (eol() || line[column] != ',')
				break;
			column++;
		}
	}

	void assemblyEqu() {
		directive();
		if (currentLabel is null)
			throw new AssemblyError("Label name required");
		currentLabel.value = 0;
		readSpaces();
		readValue();
		currentLabel.value = value;
		currentLabel.unknownInPass1 = unknownInPass1;
		if (optionListing) {
			listingLine[6] = '=';
			int val = value;
			listingLine[7] = ' ';
			if (val < 0) {
				listingLine[7] = '-';
				val = -val;
			}
			listingColumn = 8;
			if ((val & 0xffff0000) != 0)
				listWord(cast(ushort) (val >> 16));
			else {
				while (listingColumn < 12)
					listingLine[listingColumn++] = ' ';
			}
			listWord(cast(ushort) val);
		}
	}

	void assemblyEnd() {
		directive();
		assert(!foundEnd);
		foundEnd = true;
	}

	void assemblyIftEli() {
		ifContexts[$ - 1].condition = true;
		if (!inFalseCondition()) {
			readSpaces();
			readValue();
			mustBeKnownInPass1();
			if (value != 0)
				ifContexts[$ - 1].aConditionMatched = true;
			else
				listLine();
			ifContexts[$ - 1].condition = value != 0;
		}
	}

	void checkMissingIft() {
		if (ifContexts.length == 0)
			throw new AssemblyError("Missing IFT");
	}

	void assemblyIft() {
		directive();
		ifContexts.length++;
		assemblyIftEli();
	}

	void assemblyEliEls() {
		directive();
		checkMissingIft();
		if (ifContexts[$ - 1].wasElse)
			throw new AssemblyError("EIF expected");
	}

	void assemblyEli() {
		assemblyEliEls();
		if (ifContexts[$ - 1].aConditionMatched) {
			ifContexts[$ - 1].condition = false;
			return;
		}
		assemblyIftEli();
	}

	void assemblyEls() {
		assemblyEliEls();
		with (ifContexts[$ - 1]) {
			if (condition && aConditionMatched)
				listLine();
			wasElse = true;
			condition = !aConditionMatched;
		}
	}

	void assemblyEif() {
		directive();
		checkMissingIft();
		ifContexts.length--;
	}

	void assemblyErt() {
		directive();
		readSpaces();
		readValue();
		if (pass2 && value != 0)
			throw new AssemblyError("User-defined error");
	}

	bool readOption() {
		switch (readChar()) {
		case '-':
			return false;
		case '+':
			return true;
		default:
			illegalCharacter();
		}
		assert(0);
	}

	void assemblyOpt() {
		directive();
		readSpaces();
		while (!eol()) {
			switch (line[column++]) {
			case 'F':
			case 'f':
				optionFill = readOption();
				break;
			case 'G':
			case 'g':
				option5200 = readOption();
				break;
			case 'H':
			case 'h':
				optionHeaders = readOption();
				break;
			case 'L':
			case 'l':
				optionListing = readOption() && pass2;
				break;
			case 'O':
			case 'o':
				optionObject = readOption();
				break;
			case 'U':
			case 'u':
				optionUnusedLabels = readOption();
				break;
			case '?':
				if (!readOption())
					throw new AssemblyError("OPT ?- not supported");
				break;
			default:
				column--;
				return;
			}
		}
	}

	void originWord(ushort value, char listingChar) {
		objectWord(value);
		listWord(value);
		listingLine[listingColumn++] = listingChar;
	}

	OrgModifier readOrgModifier() {
		readSpaces();
		if (column + 2 < line.length && line[column + 1] == ':') {
			switch (line[column]) {
			case 'F':
			case 'f':
				checkHeadersOn();
				column += 2;
				return OrgModifier.FORCE_FFFF;
			case 'A':
			case 'a':
				checkHeadersOn();
				column += 2;
				return OrgModifier.FORCE_HEADER;
			case 'R':
			case 'r':
				column += 2;
				return OrgModifier.RELOCATE;
			default:
				break;
			}
		}
		return OrgModifier.NONE;
	}

	void setOrigin(int addr, OrgModifier modifier) {
		origin = loadOrigin = addr;
		bool requestedHeader = modifier != OrgModifier.NONE;
		if (requestedHeader || loadingOrigin < 0 || (addr != loadingOrigin && !optionFill)) {
			blockIndex++;
			if (!pass2) {
				assert(blockIndex == blockEnds.length);
				blockEnds ~= cast(ushort) (addr - 1);
			}
			if (pass2 && optionHeaders) {
				if (addr - 1 == blockEnds[blockIndex]) {
					if (requestedHeader)
						throw new AssemblyError("Cannot generate an empty block");
					return;
				}
				if (modifier == OrgModifier.FORCE_FFFF || objectBuffer.data.length == 0) {
					assert(requestedHeader || addr != loadingOrigin);
					originWord(0xffff, '>');
					listingLine[listingColumn++] = ' ';
				}
				if (requestedHeader || addr != loadingOrigin) {
					originWord(cast(ushort) addr, '-');
					originWord(blockEnds[blockIndex], '>');
					listingLine[listingColumn++] = ' ';
					loadingOrigin = -1;
				}
			}
		}
	}

	void checkHeadersOn() {
		if (!optionHeaders)
			throw new AssemblyError("Illegal when Atari file headers disabled");
	}

	void assemblyOrg() {
		noRepeatSkipDirective();
		OrgModifier modifier = readOrgModifier();
		readUnsignedWord();
		mustBeKnownInPass1();
		if (modifier == OrgModifier.RELOCATE) {
			checkOriginDefined();
			origin = value;
		}
		else {
			setOrigin(value, modifier);
		}
	}

	void assemblyRunIni(ushort addr) {
		noRepeatSkipDirective();
		checkHeadersOn();
		loadingOrigin = -1; // don't fill
		OrgModifier modifier = readOrgModifier();
		if (modifier == OrgModifier.RELOCATE)
			throw new AssemblyError("r: invalid here");
		setOrigin(addr, modifier);
		readUnsignedWord();
		putWord(cast(ushort) (value));
		loadingOrigin = -1; // don't fill
	}

	void assemblyIcl() {
		directive();
		string filename = readFilename();
		checkNoExtraCharacters();
		listLine();
		includeLevel++;
		assemblyFile(filename);
		includeLevel--;
		line = null;
	}

	void assemblyIns() {
		string filename = readFilename();
		int offset = 0;
		int length = -1;
		if (!eol() && line[column] == ',') {
			column++;
			readValue();
			mustBeKnownInPass1();
			offset = value;
			if (!eol() && line[column] == ',') {
				column++;
				readKnownPositive();
				length = value;
			}
		}
		if (inOpcode)
			length = 1;
		immutable(ubyte)[] data = readBinary(filename, offset, length);
		if (length >= 0 && data.length < length)
			throw new AssemblyError("File is too short");
		foreach (ubyte b; data)
			putByte(b);
	}

	void assemblyInstruction(string instruction) {
		if (!inOpcode && origin < 0 && currentLabel !is null && instruction != "EQU")
			throw new AssemblyError("No ORG specified");
		instructionBegin = true;
		switch (instruction) {
		case "ADC":
			assemblyAccumulator(0x60, 0, 0);
			break;
		case "ADD":
			assemblyAccumulator(0x60, 0x18, 0);
			break;
		case "AND":
			assemblyAccumulator(0x20, 0, 0);
			break;
		case "ASL":
			assemblyShift(0x00);
			break;
		case "BCC":
			assemblyBranch(0x90);
			break;
		case "BCS":
			assemblyBranch(0xb0);
			break;
		case "BEQ":
			assemblyBranch(0xf0);
			break;
		case "BIT":
			assemblyBit();
			break;
		case "BMI":
			assemblyBranch(0x30);
			break;
		case "BNE":
			assemblyBranch(0xd0);
			break;
		case "BPL":
			assemblyBranch(0x10);
			break;
		case "BRK":
			putByte(0x00);
			break;
		case "BVC":
			assemblyBranch(0x50);
			break;
		case "BVS":
			assemblyBranch(0x70);
			break;
		case "CLC":
			putByte(0x18);
			break;
		case "CLD":
			putByte(0xd8);
			break;
		case "CLI":
			putByte(0x58);
			break;
		case "CLV":
			putByte(0xb8);
			break;
		case "CMP":
			assemblyAccumulator(0xc0, 0, 0);
			break;
		case "CPX":
			assemblyCompareIndex(0xe0);
			break;
		case "CPY":
			assemblyCompareIndex(0xc0);
			break;
		case "DEC":
			assemblyShift(0xc0);
			break;
		case "DEX":
			putByte(0xca);
			break;
		case "DEY":
			putByte(0x88);
			break;
		case "DTA":
			assemblyDta();
			break;
		case "EIF":
			assemblyEif();
			break;
		case "ELI":
			assemblyEli();
			break;
		case "ELS":
			assemblyEls();
			break;
		case "END":
			assemblyEnd();
			break;
		case "EOR":
			assemblyAccumulator(0x40, 0, 0);
			break;
		case "EQU":
			assemblyEqu();
			break;
		case "ERT":
			assemblyErt();
			break;
		case "ICL":
			assemblyIcl();
			break;
		case "IFT":
			assemblyIft();
			break;
		case "INC":
			assemblyShift(0xe0);
			break;
		case "INI":
			assemblyRunIni(0x2e2);
			break;
		case "INS":
			assemblyIns();
			break;
		case "INX":
			putByte(0xe8);
			break;
		case "INY":
			putByte(0xc8);
			break;
		case "INW":
			assemblyInw();
			break;
		case "JCC":
			assemblyConditionalJump(0xb0);
			break;
		case "JCS":
			assemblyConditionalJump(0x90);
			break;
		case "JEQ":
			assemblyConditionalJump(0xd0);
			break;
		case "JMI":
			assemblyConditionalJump(0x10);
			break;
		case "JMP":
			assemblyJmp();
			break;
		case "JNE":
			assemblyConditionalJump(0xf0);
			break;
		case "JPL":
			assemblyConditionalJump(0x30);
			break;
		case "JSR":
			assemblyJsr();
			break;
		case "JVC":
			assemblyConditionalJump(0x70);
			break;
		case "JVS":
			assemblyConditionalJump(0x50);
			break;
		case "LDA":
			assemblyLda(0);
			break;
		case "LDX":
			assemblyLdx(0);
			break;
		case "LDY":
			assemblyLdy(0);
			break;
		case "LSR":
			assemblyShift(0x40);
			break;
		case "MVA":
			assemblyMoveByte(&assemblyLda, &assemblySta);
			break;
		case "MVX":
			assemblyMoveByte(&assemblyLdx, &assemblyStx);
			break;
		case "MVY":
			assemblyMoveByte(&assemblyLdy, &assemblySty);
			break;
		case "MWA":
			assemblyMoveWord(&assemblyLda, &assemblySta, 0, 0);
			break;
		case "MWX":
			assemblyMoveWord(&assemblyLdx, &assemblyStx, 0xe8, 0xca);
			break;
		case "MWY":
			assemblyMoveWord(&assemblyLdy, &assemblySty, 0xc8, 0x88);
			break;
		case "NOP":
			putByte(0xea);
			break;
		case "OPT":
			assemblyOpt();
			break;
		case "ORA":
			assemblyAccumulator(0x00, 0, 0);
			break;
		case "ORG":
			assemblyOrg();
			break;
		case "PHA":
			putByte(0x48);
			break;
		case "PHP":
			putByte(0x08);
			break;
		case "PLA":
			putByte(0x68);
			break;
		case "PLP":
			putByte(0x28);
			break;
		case "RCC":
			assemblyRepeat(0x90);
			break;
		case "RCS":
			assemblyRepeat(0xb0);
			break;
		case "REQ":
			assemblyRepeat(0xf0);
			break;
		case "RMI":
			assemblyRepeat(0x30);
			break;
		case "RNE":
			assemblyRepeat(0xd0);
			break;
		case "ROL":
			assemblyShift(0x20);
			break;
		case "ROR":
			assemblyShift(0x60);
			break;
		case "RPL":
			assemblyRepeat(0x10);
			break;
		case "RTI":
			putByte(0x40);
			break;
		case "RTS":
			putByte(0x60);
			break;
		case "RUN":
			assemblyRunIni(0x2e0);
			break;
		case "RVC":
			assemblyRepeat(0x50);
			break;
		case "RVS":
			assemblyRepeat(0x70);
			break;
		case "SBC":
			assemblyAccumulator(0xe0, 0, 0);
			break;
		case "SCC":
			assemblySkip(0x90);
			break;
		case "SCS":
			assemblySkip(0xb0);
			break;
		case "SEC":
			putByte(0x38);
			break;
		case "SED":
			putByte(0xf8);
			break;
		case "SEI":
			putByte(0x78);
			break;
		case "SEQ":
			assemblySkip(0xf0);
			break;
		case "SMI":
			assemblySkip(0x30);
			break;
		case "SNE":
			assemblySkip(0xd0);
			break;
		case "SPL":
			assemblySkip(0x10);
			break;
		case "STA":
			assemblySta(0);
			break;
		case "STX":
			assemblyStx(0);
			break;
		case "STY":
			assemblySty(0);
			break;
		case "SUB":
			assemblyAccumulator(0xe0, 0x38, 0);
			break;
		case "SVC":
			assemblySkip(0x50);
			break;
		case "SVS":
			assemblySkip(0x70);
			break;
		case "TAX":
			putByte(0xaa);
			break;
		case "TAY":
			putByte(0xa8);
			break;
		case "TSX":
			putByte(0xba);
			break;
		case "TXA":
			putByte(0x8a);
			break;
		case "TXS":
			putByte(0x9a);
			break;
		case "TYA":
			putByte(0x98);
			break;
		default:
			throw new AssemblyError("Illegal instruction");
		}
		skipping = false;
	}

	version (unittest) ubyte[] testInstruction(string l) {
		objectBuffer.clear();
		line = l;
		column = 0;
		assemblyInstruction(readInstruction());
		return objectBuffer.data;
	}

	unittest {
		auto a = testAssembler();
		with (a) {
			assert(testInstruction("nop") == representation(hexString!"ea"));
			assert(testInstruction("add (5,0)") == representation(hexString!"18a2006105"));
			assert(testInstruction("mwa #$abcd $1234") == representation(hexString!"a9cd8d3412a9ab8d3512"));
			assert(testInstruction("mwx #-256 $80") == representation(hexString!"a2008680ca8681"));
			assert(testInstruction("dta 5,d'Foo'*,a($4589)") == representation(hexString!"05a6efef8945"));
			assert(testInstruction("dta r(1,12,123,1234567890,12345678900000,.5,.03,000.1664534589,1e97)")
			== representation(hexString!"400100000000 401200000000 410123000000 441234567890 461234567890 3f5000000000 3f0300000000 3f1664534589 701000000000"));
		}
	}

	void assemblySequence() {
		assert(!inOpcode);
		string instruction = readInstruction();
		string[] extraInstructions;
		while (!eol() && line[column] == ':') {
			sequencing = true;
			column++;
			extraInstructions ~= readInstruction();
		}
		if (!extraInstructions.empty) {
			int savedColumn = column;
			if (willSkip)
				warning("Skipping only the first instruction");
			assemblyInstruction(instruction);
			checkNoExtraCharacters();
			wereManyInstructions = false;
			foreach (nextInstruction; extraInstructions) {
				column = savedColumn;
				assemblyInstruction(nextInstruction);
				wereManyInstructions = true;
			}
		} else {
			sequencing = false;
			assemblyInstruction(instruction);
			wereManyInstructions = false;
		}
	}

	void assemblyLine() {
		lineNo++;
		totalLines++;
		column = 0;
		listingColumn = 6;
		if (origin >= 0) {
			listWord(cast(ushort) origin);
			listingLine[listingColumn++] = ' ';
		}
		string label = readLabel();
		currentLabel = null;
		if (label !is null) {
			if (!inFalseCondition()) {
				if (!label.canFind('?'))
					lastGlobalLabel = label;
				if (!pass2) {
					if (label in labelTable)
						throw new AssemblyError("Label declared twice");
					currentLabel = &labelTable.require(label, Label(origin));
				} else {
					assert(label in labelTable);
					currentLabel = &labelTable[label];
					currentLabel.passed = true;
					if (currentLabel.unused && warnUnusedLabels && optionUnusedLabels)
						warning("Unused label: " ~ label);
				}
			}
			if (eol()) {
				listCommentLine();
				return;
			}
			readSpaces();
		}
		commentOrRep: for (;;) {
			if (eol()) {
				listCommentLine();
				return;
			}
			switch (line[column]) {
			case '\t':
			case ' ':
				column++;
				continue;
			case '*':
			case ';':
			case '|':
				listCommentLine();
				return;
			case ':':
				if (inFalseCondition()) {
					listCommentLine();
					return;
				}
				column++;
				readUnsignedWord();
				mustBeKnownInPass1();
				int repeatLimit = value;
				if (repeatLimit == 0) {
					listCommentLine();
					return;
				}
				readSpaces();
				repeating = true;
				if (repeatLimit == 1)
					break;
				if (willSkip)
					warning("Skipping only the first instruction");
				int savedColumn = column;
				for (repeatCounter = 0; repeatCounter < repeatLimit; repeatCounter++) {
					column = savedColumn;
					assemblySequence();
				}
				checkNoExtraCharacters();
				listLine();
				wereManyInstructions = true;
				return;
			default:
				repeating = false;
				break commentOrRep;
			}
		}
		if (inFalseCondition()) {
			switch (readInstruction()) {
			case "END":
				assemblyEnd();
				break;
			case "IFT":
				assemblyIft();
				break;
			case "ELI":
				assemblyEli();
				break;
			case "ELS":
				assemblyEls();
				break;
			case "EIF":
				assemblyEif();
				break;
			default:
				listCommentLine();
				return;
			}
			checkNoExtraCharacters();
			listCommentLine();
			return;
		}
		assemblySequence();
		checkNoExtraCharacters();
		listLine();
	}

	void assemblyFile(string filename) {
		immutable(ubyte)[] source = sourceFiles.require(filename, readSource(filename));
		string oldFilename = currentFilename;
		int oldLineNo = lineNo;
		currentFilename = filename;
		lineNo = 0;
		foundEnd = false;
		line = "";
		readChar: while (!foundEnd) {
			if (source.empty)
				break;
			ubyte b = source.front;
			source.popFront;
			switch (b) {
			case '\r':
				assemblyLine();
				line = "";
				if (source.empty)
					break readChar;
				b = source.front;
				source.popFront;
				if (b != '\n')
					line ~= cast(char) b;
				break;
			case '\n':
			case 0x9b:
				assemblyLine();
				line = "";
				break;
			default:
				line ~= cast(char) b;
				break;
			}
		}
		if (!foundEnd)
			assemblyLine();
		foundEnd = false;
		currentFilename = oldFilename;
		lineNo = oldLineNo;
	}

	unittest {
		auto a = testAssembler();
		with (a) {
			sourceFiles[""] = " lda:sne:ldy:inx $1234".representation;
			assemblyFile("");
			pass2 = true;
			objectBuffer.clear();
			assemblyFile("");
			writefln!"%(%02x%)"(objectBuffer.data);
			assert(objectBuffer.data == [0xad, 0x34, 0x12, 0xd0, 0x03, 0xac, 0x34, 0x12, 0xe8]);
		}
	}

	void assemblyPass() {
		origin = -1;
		loadOrigin = -1;
		loadingOrigin = -1;
		blockIndex = -1;
		optionFill = false;
		option5200 = false;
		optionHeaders = true;
		optionListing = pass2;
		optionObject = true;
		optionUnusedLabels = true;
		willSkip = false;
		skipping = false;
		repeatOffset = 0;
		wereManyInstructions = false;
		currentFilename = "command line";
		lineNo = 0;
		foreach (definition; commandLineDefinitions) {
			line = replaceFirst(definition, "=", " equ ");
			assemblyLine();
		}
		line = null;
		totalLines = 0;
		assemblyFile(sourceFilename);
		if (ifContexts.length != 0)
			throw new AssemblyError("Missing EIF");
		if (willSkip)
			throw new AssemblyError("Can't skip over this");
	}

}

///
unittest {
	import std.functional : toDelegate;
	import std.stdio : writeln;
	import xasm : Assembler;

	string[string] sources = [
		"src.asx": " org $600\nlbl equ *\n dta $42\n"
	];

	SourceReader sourceReader = (string path) => sources[path].representation;
	DiagnosticSink diagnosticSink = toDelegate((in Diagnostic diag) => stderr.writeln(diag));

	auto assembler = new Assembler(sourceReader, null, diagnosticSink);

	assembler.assemble("src.asx");

	assert( assembler.object == [0xff, 0xff, 0x00, 0x06, 0x00, 0x06, 0x42]);
	assert( assembler.getLabel("lbl").value == 0x600);
	assert(!assembler.getLabel("foo"));
}

// listIncludedFiles
unittest {
	import std.functional : toDelegate;

	string[string] sources = [
		"main.asx": " org $600\n icl 'inc.asx'\n dta $42\n",
		"inc.asx": " dta $37\n"
	];

	string[] listing(bool listIncludedFiles) {
		auto assembler = new Assembler(
			(string path) => sources[path].representation,
			null,
			toDelegate((in Diagnostic diag) => stderr.writeln(diag)));
		string[] lines;
		assembler.listIncludedFiles = listIncludedFiles;
		assembler.listingSink = (const(char)[] line) { lines ~= line.idup; };
		assembler.assemble("main.asx");
		assert(assembler.object == [0xff, 0xff, 0x00, 0x06, 0x01, 0x06, 0x37, 0x42]);
		return lines;
	}

	auto listed = listing(true);
	assert(listed.canFind!(l => l.canFind("icl 'inc.asx'")));
	assert(listed.canFind("Source: inc.asx"));
	assert(listed.canFind!(l => l.canFind("dta $37")));
	assert(listed.canFind("Source: main.asx"));
	assert(listed.canFind!(l => l.canFind("dta $42")));

	auto notListed = listing(false);
	assert(notListed.canFind!(l => l.canFind("icl 'inc.asx'")));
	assert(!notListed.canFind("Source: inc.asx"));
	assert(!notListed.canFind!(l => l.canFind("dta $37")));
	assert(notListed.canFind!(l => l.canFind("dta $42")));
}