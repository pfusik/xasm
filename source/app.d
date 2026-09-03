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

import std.algorithm;
import std.array;
import std.path;
import std.stdio;
import std.exception : assumeUnique;
import std.range : empty, front, popFront;
import std.functional : toDelegate;

version (Windows) {
	import core.sys.windows.windows;
}

import xasm;

const string TITLE = "xasm 3.3.0";

File messageStream;

string sourceFilename = null;
bool[26] options;
string[26] optionParameters;
string objectFilename = null;

int exitCode = 0;

File listingStream;
string listingFilename;     // -l FILENAME, "-" or <source>.lst
string labelTableFilename;  // -t FILENAME, "-" or listingFilename
string listingDestination;  // where listingStream currently writes

string[] makeSources = null;

void registerSource(string filename) {
	if (find(makeSources, filename).empty)
		makeSources ~= filename;
}

string makeEscape(string s) {
	return s.replace("$", "$$");
}

pure bool isOption(string arg) {
	if (arg.length < 2) return false;
	if (arg[0] == '-') return true;
	if (arg[0] != '/') return false;
	if (arg.length == 2) return true;
	if (arg[2] == ':') return true;
	return false;
}

bool getOption(char letter) {
	assert(letter >= 'a' && letter <= 'z');
	return options[letter - 'a'];
}

void setOption(char letter) {
	assert(letter >= 'a' && letter <= 'z');
	if (options[letter - 'a']) {
		exitCode = 3;
		return;
	}
	options[letter - 'a'] = true;
}

void reportDiagnostic(in Diagnostic d) {
	messageStream.flush();
	version (Windows) {
		HANDLE stderrHandle = GetStdHandle(STD_ERROR_HANDLE);
		CONSOLE_SCREEN_BUFFER_INFO csbi;
		GetConsoleScreenBufferInfo(stderrHandle, &csbi);
		SetConsoleTextAttribute(stderrHandle, (csbi.wAttributes & ~0xf) | (d.severity == Severity.error ? 12 : 14));
		scope (exit) SetConsoleTextAttribute(stderrHandle, csbi.wAttributes);
	}
	if (d.line !is null)
		stderr.writeln(d.line);
	stderr.writefln("%s (%d) %s: %s", d.filename, d.lineNo,
		d.severity == Severity.error ? "ERROR" : "WARNING", d.message);
	exitCode = max(exitCode, d.severity == Severity.error ? 2 : 1);
}

immutable(ubyte)[] readSourceFile(string filename) {
	if (filename != "-") {
		filename = filename.defaultExtension("asx");
		if (getOption('p'))
			filename = absolutePath(filename);
		registerSource(filename);
	}
	File f = filename == "-" ? stdin : File(filename);
	return f.byChunk(65536).joiner.array.assumeUnique;
}

immutable(ubyte)[] readBinaryFile(string path, int offset, int length) {
	registerSource(path);
	File f = File(path);
	try {
		f.seek(offset, offset >= 0 ? SEEK_SET : SEEK_END);
	} catch (Exception e) {
		throw new Exception("Error seeking file");
	}
	if (length < 0)
		return f.byChunk(65536).joiner.array.assumeUnique;
	ubyte[] buffer = new ubyte[cast(size_t) length];
	return f.rawRead(buffer).assumeUnique;
}

string listingOption(char letter, string fallback) {
	string filename = optionParameters[letter - 'a'];
	if (filename is null)
		return fallback;
	return filename == "-" ? "-" : buildNormalizedPath(absolutePath(filename));
}

void openListingFile(string filename, string msg) {
	if (filename == listingDestination)
		return;
	if (filename == "-") {
		listingStream = stdout;
	} else {
		if (!getOption('q'))
			messageStream.writeln(msg);
		listingStream = File(filename, "wb");  // implicitly closes the previous file
	}
	listingDestination = filename;
	listingStream.writeln(TITLE);
}

void writeLabelTable(Assembler assembler) {
	openListingFile(labelTableFilename, "Writing label table...");
	assembler.listLabelTable((const(char)[] line) { listingStream.writeln(line); });
}

void writeObjectFile(const(ubyte)[] object) {
	if (object.length == 0)
		return;
	if (objectFilename == "-") {
		stdout.rawWrite(object);
		return;
	}
	if (!getOption('q'))
		messageStream.writeln("Writing object file...");
	auto f = File(objectFilename, "wb");
	f.rawWrite(object);
}

int main(string[] args) {
	string[] commandLineDefinitions;

	for (int i = 1; i < args.length; i++) {
		string arg = args[i];
		if (isOption(arg)) {
			char letter = arg[1];
			if (letter >= 'A' && letter <= 'Z')
				letter += 'a' - 'A';
			switch (letter) {
			case 'c':
			case 'i':
			case 'm':
			case 'p':
			case 'q':
			case 'u':
				if (arg.length != 2)
					exitCode = 3;
				setOption(letter);
				break;
			case 'd':
				string definition = null;
				if (arg[0] == '/') {
					if (arg.length >= 3 && arg[2] == ':')
						definition = arg[3 .. $];
				} else if (i + 1 < args.length && !isOption(args[i + 1]))
					definition = args[++i];
				if (definition is null || find(definition, '=').empty)
					exitCode = 3;
				commandLineDefinitions ~= definition;
				break;
			case 'l':
			case 't':
			case 'o':
				setOption(letter);
				string filename = null;
				if (arg[0] == '/') {
					if (arg.length >= 3 && arg[2] == ':')
						filename = arg[3 .. $];
				} else if (i + 1 < args.length && !isOption(args[i + 1]))
					filename = args[++i];
				if (filename is null && (letter == 'o' || arg.length != 2))
					exitCode = 3;
				optionParameters[letter - 'a'] = filename;
				break;
			default:
				exitCode = 3;
				break;
			}
			continue;
		}
		if (sourceFilename !is null)
			exitCode = 3;
		sourceFilename = arg;
	}
	version (unittest)
		return 0;
	else {
		if (sourceFilename is null)
			exitCode = 3;
		objectFilename = optionParameters['o' - 'a'];
		if (objectFilename is null) {
			objectFilename = sourceFilename == "-"
				? "-"
				: sourceFilename.setExtension("obx");
		}
		messageStream = objectFilename == "-" ? stderr : stdout;
		if (!getOption('q'))
			messageStream.writeln(TITLE);
		if (exitCode != 0) {
			messageStream.write(
`Syntax: xasm SOURCE [OPTIONS]
-c             Include false conditionals in listing
-d LABEL=VALUE Define a label
-i             Don't list included files
-l [FILENAME]  Generate listing
-o FILENAME    Set object file name
-M             Print Makefile rule
-p             Print absolute paths in listing and error messages
-q             Suppress info messages
-t [FILENAME]  List label table
-u             Warn of unused labels
`);
			return exitCode;
		}
		listingFilename = listingOption('l',
			buildNormalizedPath(absolutePath(sourceFilename.setExtension("lst"))));
		labelTableFilename = listingOption('t', listingFilename);
		auto assembler = new Assembler(
			toDelegate(&readSourceFile),
			toDelegate(&readBinaryFile),
			toDelegate(&reportDiagnostic));
		assembler.commandLineDefinitions = commandLineDefinitions;
		assembler.listFalseConditionals = getOption('c');
		assembler.listIncludedFiles = !getOption('i');
		assembler.warnUnusedLabels = getOption('u');
		if (getOption('l'))
			assembler.listingSink = (const(char)[] line) {
				openListingFile(listingFilename, "Writing listing file...");
				listingStream.writeln(line);
			};
		assembler.assemble(sourceFilename);
		try {
			writeObjectFile(assembler.object);
			if (getOption('t') && assembler.hasLabels)
				writeLabelTable(assembler);
		} catch (Exception e) {
			reportDiagnostic(Diagnostic(Severity.error, "", 0, null, e.msg));
			exitCode = 2;
		}
		if (exitCode <= 1) {
			if (!getOption('q')) {
				messageStream.writefln("%d lines of source assembled", assembler.linesAssembled);
				if (assembler.object.length > 0)
					messageStream.writefln("%d bytes written to the object file", assembler.object.length);
			}
			if (getOption('m')) {
				messageStream.writef("%s:", makeEscape(objectFilename));
				foreach (filename; makeSources)
					messageStream.writef(" %s", makeEscape(filename));
				messageStream.write("\n\txasm");
				for (int i = 1; i < args.length; i++) {
					string arg = args[i];
					if (isOption(arg)) {
						char letter = arg[1];
						if (letter >= 'A' && letter <= 'Z')
							letter += 'a' - 'A';
						switch (letter) {
						case 'm':
							break;
						case 'o':
							if (arg[0] == '/')
								messageStream.writef(" /%c:$@", arg[1]);
							else {
								messageStream.writef(" -%c $@", arg[1]);
								++i;
							}
							break;
						default:
							if (arg[0] == '-'
							 && (letter == 'd' || letter == 'l' || letter == 't')
							 && i + 1 < args.length && !isOption(args[i + 1])) {
								messageStream.writef(" %s %s", arg, makeEscape(args[++i]));
							}
							else {
								messageStream.writef(" %s", makeEscape(arg));
							}
							break;
						}
						continue;
					}
					messageStream.write(" $<");
				}
				messageStream.writeln();
			}
		}
		return exitCode;
	}
}
