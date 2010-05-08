// Written in the D programming language.

/**
d2tags - converts DMD2's JSON output to Exuberant Ctags format.

Copyright: Copyright MIURA Masahiro 2010 - 2010.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB playrecord.org, MIURA Masahiro)
References: $(LINK http://ctags.sourceforge.net/)

         Copyright MIURA Masahiro 2010 - 2010.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/

import std.conv;
import std.file;
import std.json;
import std.path;
import std.stdio;
import std.string;

string affiliation(in JSONValue[string] jsonObject)
{
    string kind = jsonObject["kind"].str;
    if (kind == "module")
	return "file:";

    string name = jsonObject["name"].str;
    switch (kind) {
    case "class", "struct", "enum", "union":
	return kind ~ ":" ~ name;
    case "template":
	return "kind:template";	// XXX nonstandard tagfield
    case "interface":
	return "class:" ~ name;	// XXX
    default:
	writefln("DEBUG: kind=[%s]", kind);
	assert(false);
    }
}

void convertJSONObject(in string tagFile, ref string[] tagLines,
    in JSONValue[string] jsonObject, in JSONValue[string] parentJsonObject)
{
    auto m = "members" in jsonObject;
    if (m != null) {
	string kind = jsonObject["kind"].str;
	if ((kind != "module") && (kind != "template")) {
	    string newLine = format("%s\t%s\t%d;\"\t",
		jsonObject["name"].str, tagFile, jsonObject["line"].integer);

	    switch (kind) {
	    case "class", "interface":
		newLine ~= "c\t" ~ affiliation(parentJsonObject);
		break;
	    case "struct":
		newLine ~= "s\t" ~ affiliation(parentJsonObject);
		break;
	    case "union":
		newLine ~= "u\t" ~ affiliation(parentJsonObject);
		break;
	    case "enum":
		newLine ~= "g\t" ~ affiliation(parentJsonObject);
		break;
	    default:
		assert(false);
	    }
	    tagLines ~= newLine;
	}

	foreach (member; m.array)
	    convertJSONObject(tagFile, tagLines, member.object, jsonObject);
	return;
    }

    if (("name" !in jsonObject) || ("line" !in jsonObject))
	return;
    auto name = jsonObject["name"].str;
    if (name.indexOf(' ') != -1)
	return;

    string newLine = format("%s\t%s\t%d;\"\t",
	name, tagFile, jsonObject["line"].integer);
    string parentName;
    // Note: "module" object may lack "name".
    if (parentJsonObject["kind"].str == "module")
	parentName = parentJsonObject["file"].str;
    else parentName = parentJsonObject["name"].str;

    switch (jsonObject["kind"].str) {
    case "alias":
	newLine ~= "t\t" ~ affiliation(parentJsonObject);
	break;
    case "constructor":
	// Special case: Use the class name as the tagname.
	newLine = format("%s\t%s\t%d;\"\tm\tclass:%s",
	    parentName, tagFile, jsonObject["line"].integer, parentName);
	break;
    case "enum member":
	newLine ~= "e\tenum:" ~ parentName;
	break;
    case "function":
	newLine ~= "f\t" ~ affiliation(parentJsonObject);
	break;
    case "struct":
	newLine ~= "s\t" ~ affiliation(parentJsonObject);
    case "typedef":
	newLine ~= "t\t" ~ affiliation(parentJsonObject);
    case "variable":
	switch (parentJsonObject["kind"].str) {
	case "class", "struct":
	    newLine ~= "m\t" ~ affiliation(parentJsonObject);
	    break;
	default:
	    newLine ~= "v\t" ~ affiliation(parentJsonObject);
	    break;
	}
	break;
    default:
	writefln("DEBUG: kind=[%s]", jsonObject["kind"].str);
	writefln("DEBUG: name=[%s]", jsonObject["name"].str);
	assert(false);
    }
    tagLines ~= newLine;
    return;
}

void convertJSONFile(in string directory, in string name,
    ref string[] tagLines)
{
    JSONValue val = parseJSON(readText(std.path.join(directory, name)));

    // for each D source file...
    foreach (JSONValue v; val.array) {
	JSONValue[string] srcFileObject = v.object;
	string tagFile = std.path.join(directory, srcFileObject["file"].str);
	if (tagFile.indexOf("./") == 0)
	    tagFile = tagFile[2..$];
	convertJSONObject(tagFile, tagLines, srcFileObject, null);
    }
}

void convertJSONFileOrDir(in string path, ref string[] tagLines)
{
    if (isfile(path)) {
	convertJSONFile(dirname(path), basename(path), tagLines);
	return;
    }
    if (isdir(path)) {
	foreach (jsonFilePath; listdir(path, "*.json")) {
	    convertJSONFile(dirname(jsonFilePath), basename(jsonFilePath),
		tagLines);
	}
	return;
    }
}

void main(string[] args)
{
    string[] tagLines;

    foreach (path; args[1..$])
	convertJSONFileOrDir(path, tagLines);

    tagLines.sort;
    writeln("!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/");
    foreach (line; tagLines) {
	writeln(line);
    }
}

// eof
