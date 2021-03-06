module otya.smilebasic.project;
import otya.smilebasic.error;
import otya.smilebasic.data;
import otya.smilebasic.type;
import std.path;
import std.file;
import std.string;
import std.traits;
import std.conv;
import std.uni;
import std.typecons;
import std.range;
enum DialogResult
{
    FAILURE = 0,
    SUCCESS = 1,
    CANCEL = -1,
}

class Projects
{
    wstring currentProject;
    wstring rootPath;
    wstring projectPath;
    string projectPathU8;
    DialogResult result = DialogResult.FAILURE;//Default value
    wstring saveConfirm = 
r"ファイルを書き込みます。

          名前: %s

よろしいですか？
";
    this(wstring root)
    {
        rootPath = root;
        projectPath = buildPath(root, "PROJECTS"w);
        projectPathU8 = projectPath.to!string;
        if(exists(projectPathU8))
        {
            if(isFile(projectPathU8))
            {
                throw new Exception("PROJECTS is file");
            }
        }
        else
        {
            mkdir(projectPathU8);
        }
        createProjectInternal("[DEFAULT]");
        createProjectInternal("SYS");
    }
    static bool isValidProjectName(C)(C[] filename) if(isSomeChar!(C))
    {
        if(filename.length > 14)
        {
            return false;
        }
        foreach(c; filename)
        {
            if(!((c >= 'A' && c<= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-'))
            {
                return false;
            }
        }
        return true;
    }
    static bool isValidFileName(C)(C[] filename) if(isSomeChar!(C))
    {
        if(filename.length > 14)
        {
            return false;
        }
        foreach(c; filename)
        {
            if(!((c >= 'A' && c<= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-' || c == '@'))
            {
                return false;
            }
        }
        return true;
    }
    private void createProjectInternal(wstring name)
    {
        auto path = buildPath(projectPath, name.toUpper).to!string;
        if(!exists(path))
        {
            mkdir(path);
        }
        auto txt = buildPath(path, "TXT").to!string;
        if(!exists(txt))
        {
            mkdir(txt);
        }
        auto dat = buildPath(path, "DAT").to!string;
        if(!exists(dat))
        {
            mkdir(dat);
        }
    }
    static Tuple!(wstring, wstring, wstring) splitResourceName(wstring name)
    {
        auto ind = name.indexOf(":");
        wstring type, project;
        if(ind != -1)
        {
            type = name[0..ind];
            name = name[ind + 1..$];
        }
        ptrdiff_t sep = name.indexOf("/");
        if(sep != -1)
        {
            project = name[0..sep];
            name = name[sep + 1..$];
        }
        return tuple(type, project, name);
    }
    wstring[] getFileList(wstring project, wstring type)
    {
        import std.algorithm;
        import std.functional;
        if (project.empty)
            project = convertProjectName(currentProject);
        else if(!isValidProjectName(project))
        {
            return null;
        }
        auto dir(wstring type)
        {
            auto path = buildPath(projectPath, project, type).to!string;
            return dirEntries(path, SpanMode.shallow, false);
        }
        
        if(type == "")
        {
            return chain(dir("TXT").filter!(x=>x.isFile&&isValidFileName(baseName(x.name))).map!((x) => "*"w ~ baseName(x.name).to!wstring),
                         dir("DAT").filter!(x=>x.isFile&&isValidFileName(baseName(x.name))).map!((x) => " " ~ baseName(x.name).to!wstring)).array;
        }
        if(type == "TXT")
        {
            return dir("TXT").filter!(x=>x.isFile&&isValidFileName(baseName(x.name))).map!((x) => "*" ~ baseName(x.name).to!wstring).array;
        }
        if(type == "DAT")
        {
            return dir("DAT").filter!(x=>x.isFile&&isValidFileName(baseName(x.name))).map!((x) => " " ~ baseName(x.name).to!wstring).array;
        }
        return null;
    }
    bool loadFile(wstring project, wstring type, wstring name, out wstring contents)
    {
        contents = "";
        result = DialogResult.FAILURE;
        if(!isValidProjectName(project))
        {
            return false;
        }
        type = type.toUpper;
        //TODO:case-sensitive filesystem...
        name = name.toUpper;
        if (project.empty)
            project = convertProjectName(currentProject);
        if(type != "TXT" && type != "DAT")
        {
            return false;
        }
        if(!isValidFileName(name))
        {
            return false;
        }
        auto path = buildPath(projectPath, project, type, name).to!string;
        if (!path.exists)
        {
            //show dialog
            return false;
        }

        //show dialog
        result = DialogResult.SUCCESS;
        contents = readText(path).to!wstring;
        return true;
    }

    bool loadDataFile(T)(FileName file, ref Array!T contents, out DataHeader header)
    if (is(T == int) || is(T == double))
    {
        wstring project;
        result = DialogResult.FAILURE;
        if (file.project.empty)
            project = convertProjectName(currentProject);
        else
        {
            project = file.project;
            if (!isValidProjectName(project))
                throw new IllegalFunctionCall("LOAD");
        }
        if (!isValidFilename(file.name))
            throw new IllegalFunctionCall("LOAD");
        auto path = buildPath(projectPath, project, "DAT"w, file.name).to!string;

        //show dialog
        result = DialogResult.SUCCESS;
        import std.stdio;
        import std.algorithm;
        File f = File(path, "rb");
        DataHeader[1] harray;
        f.rawRead(harray);
        if (harray[0].magic != "PCBN0001")
        {
            f.seek(0);
            harray[0].dimension = 1;
            harray[0].dim[] = [cast(int)(f.size / int.sizeof), 0, 0, 0];
            harray[0].type = DataType.int_;
        }
        header = harray[0];
        if (harray[0].dimension != contents.dimCount)
        {
            throw new TypeMismatch("LOAD");
        }
        auto dim = harray[0].dim[0..harray[0].dimension];
        auto len = dim.reduce!((x, y) => x * y);
        T[] result;
        if (harray[0].type == DataType.int_)
        {
            int[] array = new int[len];
            f.rawRead(array);
            static if (!is(T == int))
            {
                result = array.map!(x => x.to!T).array;
            }
            else
            {
                result = array;
            }
        }
        else if (harray[0].type == DataType.double_)
        {
            double[] array = new double[len];
            f.rawRead(array);
            static if (!is(T == double))
            {
                result = array.map!(x => x.to!T).array;
            }
            else
            {
                result = array;
            }
        }
        else if (harray[0].type == DataType.ushort_)
        {
            ushort[] array = new ushort[len];
            f.rawRead(array);
            result = array.map!(x => x.to!T).array;
        }
        else
        {
            throw new TypeMismatch("LOAD(invalid file)");
        }
        //配列に書き込むというより配列を差し替えている
        contents.array = result;
        contents.dim[] = harray[0].dim[];
        contents.dimCount = harray[0].dimension;
        return true;
    }
    bool loadDataFile(T)(FileName file, ref Array!T contents)
        if (is(T == int) || is(T == double))
    {
        DataHeader dh;
        return loadDataFile(file, contents, dh);
    }

    void saveTextFile(FileName file, wstring content)
    {
        wstring project;
        result = DialogResult.FAILURE;
        if (file.project.empty)
            project = convertProjectName(currentProject);
        else
        {
            project = file.project;
            if (!isValidProjectName(project))
                throw new IllegalFunctionCall("SAVE");
        }
        if (!isValidFilename(file.name))
            throw new IllegalFunctionCall("SAVE");
        auto path = buildPath(projectPath, project, "TXT"w, file.name).to!string;
        write(path, content.to!string/*UTF8*/);
        result = DialogResult.SUCCESS;
    }

    void saveDataFile(T)(FileName file, Array!T content)
    if (is(T == int) || is(T == double))
    {
        wstring project;
        result = DialogResult.FAILURE;
        if (file.project.empty)
            project = convertProjectName(currentProject);
        else
        {
            project = file.project;
            if (!isValidProjectName(project))
                throw new IllegalFunctionCall("SAVE");
        }
        if (!isValidFilename(file.name))
            throw new IllegalFunctionCall("SAVE");
        auto path = buildPath(projectPath, project, "DAT"w, file.name).to!string;
        DataHeader[1] harray;
        DataHeader* head = harray.ptr;
        static if (is(T == int))
        {
            head.type = DataType.int_;
        }
        else
        {
            head.type = DataType.double_;
        }
        head.dim[] = content.dim[];
        head.dimension = cast(byte)content.dimCount;
        import std.stdio;
        File f = File(path, "wb");
        f.rawWrite(harray);
        f.rawWrite(content.array);
        result = DialogResult.SUCCESS;
    }

    wstring convertProjectName(wstring proj)
    {
        if (proj.empty)
        {
            if (currentProject.empty)
                return "[DEFAULT]";
            return currentProject;
        }
        return proj;
    }

    bool chkfile(wstring path)
    {
        auto file = parseFileName(path);
        if (!Projects.isValidFileName(file.name))
        {
            throw new IllegalFunctionCall("CHKFILE", 1);
        }
        if (!Projects.isValidProjectName(file.project))
        {
            throw new IllegalFunctionCall("CHKFILE", 1);
        }
        if (file.resource == Resource.illegal)
        {
            throw new IllegalFunctionCall("CHKFILE", 1);
        }
        bool isText = file.resource == Resource.none || file.resource == Resource.program || file.resource == Resource.text;
        auto proj = convertProjectName(file.project);
        auto p = buildPath(projectPath, proj, isText ? "TXT"w : "DAT"w, file.name).to!string;
        return p.exists;
    }

    static Resource getResource(wstring resname)
    {
        switch (std.uni.toUpper(resname))
        {
            case "PRG":
                return Resource.program;
            case "GRP":
                return Resource.graphic;
            case "DAT":
                return Resource.data;
            case "TXT":
                return Resource.text;
            case "GRPF":
                return Resource.graphicFont;
            default:
                return Resource.illegal;
        }
    }

    static FileName parseFileName(wstring input)
    {
        FileName result;
        auto s = splitResourceName(input);
        if (s[0].length)
        {
            auto resname = s[0];
            auto numind = resname.indexOfAny("1234567890");
            if (numind != -1)
            {
                auto resnum = resname[numind..$].to!int;
                resname = resname[0..numind];
                result.resourceNumber = resnum;
                result.hasResourceNumber = true;
            }
            result.resource = getResource(resname);
        }
        result.project = s[1];
        result.name = s[2];
        return result;
    }
    unittest
    {
        auto a = parseFileName("A");
        assert(a.resource == Resource.none && !a.hasResourceNumber && a.project == "" && a.name == "A");
        a = parseFileName("GRP:B");
        assert(a.resource == Resource.graphic && !a.hasResourceNumber && a.project == "" && a.name == "B");
        a = parseFileName("PRG10:CD");
        assert(a.resource == Resource.program && a.hasResourceNumber && a.resourceNumber == 10 && a.project == "" && a.name == "CD");
        a = parseFileName("DAT:SYS/EF");
        assert(a.resource == Resource.data && !a.hasResourceNumber && a.project == "SYS" && a.name == "EF");
    }
}

enum Resource
{
    none,
    program,
    graphic,
    data,
    text,
    illegal,
    graphicFont,
}

struct FileName
{
    Resource resource;
    bool hasResourceNumber;
    int resourceNumber;
    wstring project;
    wstring name;
}
