Param(
  [string]$name="gdnative_cpp_project",
  [string]$script_files,
  [string]$gd_files
)

if ($name.Contains("--disable-")) {

    $script_files = $name
    $name = "gdnative_cpp_project"
}

if (Test-Path -Path ".\$name\") {
    
    throw "Error: Cannot use duplicate project names!"

} else {

    Write-Output "-----------------------------------------`nProject name set as: $name"

    Write-Output "[0%] Downloading venv module...`n-----------------------------------------"

    if (($gd_files -ne "--disable-gd-files" -and $script_files -ne "--disable-gd-files") -And -Not (Test-Path -Path ".\venv\Scripts\")) {
        python -m venv venv
    }

    if ($gd_files -ne "--disable-gd-files" -and $script_files -ne "--disable-gd-files") {
        .\venv\Scripts\Activate.ps1
        pip install scons
    }


    Write-Output "-----------------------------------------`n[17%] Creating '$name' folder...`n-----------------------------------------"

    mkdir $name
    cd .\$name\


    if($gd_files -ne "--disable-gd-files" -and $script_files -ne "--disable-gd-files") {
        
        Write-Output "-----------------------------------------`n[21%] Adding submodules...`n-----------------------------------------"
        git init
        git submodule add -b 3.x https://github.com/godotengine/godot-cpp
        cd godot-cpp
        git submodule update --init

        
        Write-Output "-----------------------------------------`n[29%] Building modules...`n-----------------------------------------"

        
        scons platform=windows generate_bindings=yes -j4
        cd ..
        godot --gdnative-generate-json-api api.json

        deactivate

        Write-Output "-----------------------------------------`n[82%] Creating source folders...`n-----------------------------------------"

        mkdir src
        mkdir project

    }

    if ($script_files -ne "--disable-script-files" -and $gd_files -ne "--disable-script-files") {

        # Original code obtained from https://github.com/PowerShell/PowerShell/issues/2736

        # Formats JSON in a nicer format than the built-in ConvertTo-Json does.
        function Format-Json {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory, ValueFromPipeline)]
                [string]
                $InputObject
            )
            Begin {
                $Buffer = New-Object 'System.Collections.Generic.List[string]'
            }

            Process {
                $Buffer.Add($InputObject)
            }

            End {
                $json = [string]::Join("`n", $Buffer.ToArray())

                [int]$indent = 0;
                $result = ($json -Split '\n' |
                    % {
                        if ($_ -match '^\s*[\}\]]') {
                            # This line contains ] or }, decrement the indentation level
                            if (--$indent -lt 0) {
                                #fail safe
                                $indent = 0
                            }
                        }
                        $line = (' ' * $indent * 2) + $_.TrimStart().Replace(': ', ': ')
                        if ($_ -match '[\[\{](?!(.*[\{\[\"]))') {
                            # This line contains [ or {, increment the indentation level
                            $indent++
                        }
                        $line
                    }) -Join "`n"

                # Unescape Html characters (<>&')
                $result.Replace('\u0027', "'").Replace('\u003c', "<").Replace('\u003e', ">").Replace('\u0026', "&")
            }
        }

        mkdir .vscode
    
        Write-Output "-----------------------------------------`n[95%] Generating script files...`n-----------------------------------------"

        # create tasks.json
        $jsonBase = @{}
        $taskObject = New-Object System.Collections.ArrayList
        $taskObject.Add(@{"label"="Build C++ Files";"type"="shell";"command"=".\build.ps1";"problemMatcher"=New-Object System.Collections.ArrayList;"group"=@{"kind"="build";"isDefault"=$true}})
        $jsonBase.Add("version", "2.0.0")
        $jsonBase.Add("tasks", $taskObject)
        $jsonBase | ConvertTo-Json -Depth 5 | Format-Json | Out-File ".\.vscode\tasks.json" -Encoding UTF8

        #create build.ps1
        $buildScript = "..\venv\Scripts\Activate.ps1`nscons platform=windows`ndeactivate"
        $buildScript | Out-File ".\build.ps1"

        #create SConstruct file
        $SConstruct = "#!python
import os

opts = Variables([], ARGUMENTS)

# Define the relative path to the Godot headers.
godot_headers_path = `"godot-cpp/godot-headers`"
godot_bindings_path = `"godot-cpp`"

# Gets the standard flags CC, CCX, etc.
env = DefaultEnvironment()

# Define our options. Use future-proofed names for platforms.
platform_array = [`"`", `"windows`", `"linuxbsd`", `"macos`", `"x11`", `"linux`", `"osx`"]
opts.Add(EnumVariable(`"target`", `"Compilation target`", `"debug`", [`"d`", `"debug`", `"r`", `"release`"]))
opts.Add(EnumVariable(`"platform`", `"Compilation platform`", `"`", platform_array))
opts.Add(EnumVariable(`"p`", `"Alias for 'platform'`", `"`", platform_array))
opts.Add(BoolVariable(`"use_llvm`", `"Use the LLVM / Clang compiler`", `"no`"))
opts.Add(PathVariable(`"target_path`", `"The path where the lib is installed.`", `"project/bin/`"))
opts.Add(PathVariable(`"target_name`", `"The library name.`", `"lib`", PathVariable.PathAccept))

# Updates the environment with the option variables.
opts.Update(env)

# Process platform arguments. Here we use the same names as GDNative.
if env[`"p`"] != `"`":
    env[`"platform`"] = env[`"p`"]

if env[`"platform`"] == `"macos`":
    env[`"platform`"] = `"osx`"
elif env[`"platform`"] in (`"x11`", `"linuxbsd`"):
    env[`"platform`"] = `"linux`"
elif env[`"platform`"] == `"bsd`":
    env[`"platform`"] = `"freebsd`"

if env[`"platform`"] == `"`":
    print(`"No valid target platform selected.`")
    quit()

platform = env[`"platform`"]

# Check our platform specifics.
if platform == `"osx`":
    if not env[`"use_llvm`"]:
        env[`"use_llvm`"] = `"yes`"
    if env[`"target`"] in (`"debug`", `"d`"):
        env.Append(CCFLAGS=[`"-g`", `"-O2`", `"-arch`", `"x86_64`", `"-std=c++14`"])
        env.Append(LINKFLAGS=[`"-arch`", `"x86_64`"])
    else:
        env.Append(CCFLAGS=[`"-g`", `"-O3`", `"-arch`", `"x86_64`", `"-std=c++14`"])
        env.Append(LINKFLAGS=[`"-arch`", `"x86_64`"])
elif platform == `"linux`":
    if env[`"target`"] in (`"debug`", `"d`"):
        env.Append(CCFLAGS=[`"-fPIC`", `"-g3`", `"-Og`"])
    else:
        env.Append(CCFLAGS=[`"-fPIC`", `"-g`", `"-O3`"])
elif platform == `"windows`":
    # This makes sure to keep the session environment variables
    # on Windows, so that you can run scons in a VS 2017 prompt
    # and it will find all the required tools.
    env = Environment(ENV=os.environ)
    opts.Update(env)

    env.Append(CCFLAGS=[`"-DWIN32`", `"-D_WIN32`", `"-D_WINDOWS`", `"-W3`", `"-GR`", `"-D_CRT_SECURE_NO_WARNINGS`"])
    if env[`"target`"] in (`"debug`", `"d`"):
        env.Append(CCFLAGS=[`"-EHsc`", `"-D_DEBUG`", `"-MDd`"])
    else:
        env.Append(CCFLAGS=[`"-O2`", `"-EHsc`", `"-DNDEBUG`", `"-MD`"])

if env[`"use_llvm`"] == `"yes`":
    env[`"CC`"] = `"clang`"
    env[`"CXX`"] = `"clang++`"

SConscript(`"godot-cpp/SConstruct`")


def add_sources(sources, dir):
    for f in os.listdir(dir):
        if f.endswith(`".cpp`"):
            sources.append(dir + `"/`" + f)


env.Append(
    CPPPATH=[
        godot_headers_path,
        godot_bindings_path + `"/include`",
        godot_bindings_path + `"/include/gen/`",
        godot_bindings_path + `"/include/core/`",
    ]
)

env.Append(
    LIBS=[
        env.File(os.path.join(`"godot-cpp/bin`", `"libgodot-cpp.%s.%s.64%s`" % (platform, env[`"target`"], env[`"LIBSUFFIX`"])))
    ]
)

env.Append(LIBPATH=[godot_bindings_path + `"/bin/`"])

sources = []
add_sources(sources, `"src`", )
# add_sources(sources, `"src/player`")
# add_sources(sources, `"src/world`")

library = env.SharedLibrary(target=env[`"target_path`"] + `"/`" + platform + `"/`" + env[`"target_name`"], source=sources)
Default(library)
"

    New-Item -Path '.\SConstruct' -ItemType File
    Set-Content -Path '.\SConstruct' -Value $SConstruct

    if ($script_files -ne "--disable-gd-files" -and $gd_files -ne "--disable-gd-files") {

    Write-Output "-----------------------------------------`n[97%] Generating project files...`n-----------------------------------------"

    #generate project files
    cd .\project\


    # create bin & import folder with .gdignore file
    mkdir bin
    mkdir .\.import\
    New-Item -Path '.\.import\.gdignore' -ItemType File

    
    # create default env
    New-Item -Path '.\default_env.tres' -ItemType File

    $default_env = "[gd_resource type=`"Environment`" load_steps=2 format=2]

[sub_resource type=`"ProceduralSky`" id=1]

[resource]
background_mode = 2
background_sky = SubResource( 1 )"

    Set-Content -Path '.\default_env.tres' -Value $default_env


    # create project.godot
    New-Item -Path '.\project.godot' -ItemType File

    $project_godot = "; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=4

[application]

config/name=`"$name`"
run/main_scene=`"res://main.tscn`"

[gui]

common/drop_mouse_on_gui_input_disabled=true

[physics]

common/enable_pause_aware_picking=true

[rendering]

environment/default_environment=`"res://default_env.tres`""

    Set-Content -Path '.\project.godot' -Value $project_godot


    # create main scene
    New-Item -Path '.\main.tscn' -ItemType File

    $main_tscn = "[gd_scene format=2]

[node name=`"Main`" type=`"Node2D`"]"

    Set-Content -Path '.\main.tscn' -Value $main_tscn

    Write-Output "-----------------------------------------`n[99%] Generating example .cpp files...`n-----------------------------------------"

    # create example.h
    New-Item -Path '..\src\example.h' -ItemType File

    $exampleh = "#ifndef GDEXAMPLE_H
#define GDEXAMPLE_H

#include <Godot.hpp>
#include <Sprite.hpp>

namespace godot
{

    //   class name : inheritance
    class GDExample : public Sprite
    {
        GODOT_CLASS(GDExample, Sprite)

    private:
        float time_passed;
        godot::Godot *gd;

    public:
        static void _register_methods();

        GDExample();
        ~GDExample();

        void _init(); // our initializer called by Godot

        void _ready();

        void _process(float delta);

    protected:
    };

}

#endif"

    Set-Content -Path '..\src\example.h' -Value $exampleh


    # create example.cpp
    New-Item -Path '..\src\example.cpp' -ItemType File
    $examplecpp = "#include `"example.h`"

using namespace godot;

void GDExample::_register_methods()
{
    // Register functions
    register_method(`"_process`", &GDExample::_process);
    register_method(`"_ready`", &GDExample::_ready);
}

GDExample::GDExample()
{
}

GDExample::~GDExample()
{
    // add your cleanup here
}

void GDExample::_init()
{
    // initialize any variables here
    time_passed = 0.0;
}

// Call when script is ready
void GDExample::_ready()
{
    // add your code here
}

// Every frame
void GDExample::_process(float delta)
{
    time_passed += delta;

    Vector2 new_position = Vector2(10.0 + (10.0 * sin(time_passed * 2.0)), 10.0 + (10.0 * cos(time_passed * 1.5)));

    set_position(new_position);
}
"

    Set-Content -Path '..\src\example.cpp' -Value $examplecpp


    # create gdlibrary.cpp
    New-Item -Path '..\src\gdlibrary.cpp'
    $gdlibrarycpp = "#include `"example.h`"

extern `"C`" void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *o)
{
    godot::Godot::gdnative_init(o);
}

extern `"C`" void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *o)
{
    godot::Godot::gdnative_terminate(o);
}

extern `"C`" void GDN_EXPORT godot_nativescript_init(void *handle)
{
    godot::Godot::nativescript_init(handle);

    // Register C++ classes to godot library
    godot::register_class<godot::GDExample>();
    // godot::register_class<godot::SomeNewClassName>();
}"
    Set-Content -Path '..\src\gdlibrary.cpp' -Value $gdlibrarycpp

    
    # create example library
    New-Item -Path '.\bin\lib.gdnlib' -ItemType File
    $examplegdnlib = "[general]

singleton=false
load_once=true
symbol_prefix=`"godot_`"
reloadable=true

[entry]

X11.64=`"res://bin/x11/lib.so`"
Windows.64=`"res://bin/windows/lib.dll`"
OSX.64=`"res://bin/osx/lib.dylib`"

[dependencies]

X11.64=[]
Windows.64=[]
OSX.64=[]"
    Set-Content -Path '.\bin\lib.gdnlib' -Value $examplegdnlib


    New-Item -Path '.\bin\example.gdns' -ItemType File
    $examplegdns = "[gd_resource type=`"NativeScript`" load_steps=2 format=2]

[ext_resource path=`"res://bin/lib.gdnlib`" type=`"GDNativeLibrary`" id=1]

[resource]

resource_name = `"lib`"
class_name = `"GDExample`"
library = ExtResource( 1 )"
    Set-Content -Path '.\bin\example.gdns' -Value $examplegdns
    
    }

    cd ..

    # open vscode
    code .

    # open godot
    # gdb godot
    # run -e --path .\project\
}


    cd ..
    Write-Host "-----------------------------------------`n[100%] Done: creation completed...`n-----------------------------------------"

}

exit
