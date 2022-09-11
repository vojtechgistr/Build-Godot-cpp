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

# Gets the standard flags CC, CCX, etc.
env = DefaultEnvironment()

# Define our options
opts.Add(EnumVariable('target', `"Compilation target`", 'debug', ['d', 'debug', 'r', 'release']))
opts.Add(EnumVariable('platform', `"Compilation platform`", '', ['', 'windows', 'x11', 'linux', 'osx']))
opts.Add(EnumVariable('p', `"Compilation target, alias for 'platform'`", '', ['', 'windows', 'x11', 'linux', 'osx']))
opts.Add(BoolVariable('use_llvm', `"Use the LLVM / Clang compiler`", 'no'))
opts.Add(PathVariable('target_path', 'The path where the lib is installed.', 'project/bin/'))
opts.Add(PathVariable('target_name', 'The library name.', 'libexample', PathVariable.PathAccept))

# Local dependency paths, adapt them to your setup
godot_headers_path = `"godot-cpp/godot-headers/`"
cpp_bindings_path = `"godot-cpp/`"
cpp_library = `"libgodot-cpp`"

# only support 64 at this time..
bits = 64

# Updates the environment with the option variables.
opts.Update(env)

# Process some arguments
if env['use_llvm']:
    env['CC'] = 'clang'
    env['CXX'] = 'clang++'

if env['p'] != '':
    env['platform'] = env['p']

if env['platform'] == '':
    print(`"No valid target platform selected.`")
    quit();

# For the reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

# Check our platform specifics
if env['platform'] == `"osx`":
    env['target_path'] += 'osx/'
    cpp_library += '.osx'
    env.Append(CCFLAGS=['-arch', 'x86_64'])
    env.Append(CXXFLAGS=['-std=c++17'])
    env.Append(LINKFLAGS=['-arch', 'x86_64'])
    if env['target'] in ('debug', 'd'):
        env.Append(CCFLAGS=['-g', '-O2'])
    else:
        env.Append(CCFLAGS=['-g', '-O3'])

elif env['platform'] in ('x11', 'linux'):
    env['target_path'] += 'x11/'
    cpp_library += '.linux'
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])
    if env['target'] in ('debug', 'd'):
        env.Append(CCFLAGS=['-g3', '-Og'])
    else:
        env.Append(CCFLAGS=['-g', '-O3'])

elif env['platform'] == `"windows`":
    env['target_path'] += 'win64/'
    cpp_library += '.windows'
    # This makes sure to keep the session environment variables on windows,
    # that way you can run scons in a vs 2017 prompt and it will find all the required tools
    env.Append(ENV=os.environ)

    env.Append(CPPDEFINES=['WIN32', '_WIN32', '_WINDOWS', '_CRT_SECURE_NO_WARNINGS'])
    env.Append(CCFLAGS=['-W3', '-GR'])
    env.Append(CXXFLAGS='/std:c++17')
    if env['target'] in ('debug', 'd'):
        env.Append(CPPDEFINES=['_DEBUG'])
        env.Append(CCFLAGS=['-EHsc', '-MDd', '-ZI'])
        env.Append(LINKFLAGS=['-DEBUG'])
    else:
        env.Append(CPPDEFINES=['NDEBUG'])
        env.Append(CCFLAGS=['-O2', '-EHsc', '-MD'])

if env['target'] in ('debug', 'd'):
    cpp_library += '.debug'
else:
    cpp_library += '.release'

cpp_library += '.' + str(bits)

# make sure our binding library is properly includes
env.Append(CPPPATH=['.', godot_headers_path, cpp_bindings_path + 'include/', cpp_bindings_path + 'include/core/', cpp_bindings_path + 'include/gen/'])
env.Append(LIBPATH=[cpp_bindings_path + 'bin/'])
env.Append(LIBS=[cpp_library])

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=['src/'])
sources = Glob('src/*.cpp')

library = env.SharedLibrary(target=env['target_path'] + env['target_name'] , source=sources)

Default(library)

# Generates help for the -h scons option.
Help(opts.GenerateHelpText(env))"

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
    New-Item -Path '.\bin\example.gdnlib' -ItemType File
    $examplegdnlib = "[general]

singleton=false
load_once=true
symbol_prefix=`"godot_`"
reloadable=false

[entry]

X11.64=`"res://bin/x11/libexample.so`"
Windows.64=`"res://bin/win64/libexample.dll`"
OSX.64=`"res://bin/osx/libexample.dylib`"

[dependencies]

X11.64=[]
Windows.64=[]
OSX.64=[]"
    Set-Content -Path '.\bin\example.gdnlib' -Value $examplegdnlib


    New-Item -Path '.\bin\example.gdns' -ItemType File
    $examplegdns = "[gd_resource type=`"NativeScript`" load_steps=2 format=2]

[ext_resource path=`"res://bin/example.gdnlib`" type=`"GDNativeLibrary`" id=1]

[resource]

resource_name = `"example`"
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
