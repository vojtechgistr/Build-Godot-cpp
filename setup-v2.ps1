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
        mkdir lib
        cd lib

        git init
        git submodule add -b 3.x https://github.com/godotengine/godot-cpp
        cd godot-cpp
        git submodule update --init

        
        Write-Output "-----------------------------------------`n[29%] Building modules...`n-----------------------------------------"

        
        scons platform=windows generate_bindings=yes -j4
        cd ../..
        godot --gdnative-generate-json-api api.json

        deactivate

        Write-Output "-----------------------------------------`n[82%] Creating source folders...`n-----------------------------------------"

        mkdir src
        mkdir project
        mkdir include

    }

    if ($script_files -ne "--disable-script-files" -and $gd_files -ne "--disable-script-files") {


        mkdir .vscode

        Write-Output "-----------------------------------------`n[95%] Generating script files...`n-----------------------------------------"

        # create tasks.json
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/.vscode/tasks.json" -OutFile ".\.vscode\tasks.json"

        #create build.ps1
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/build.ps1" -OutFile ".\build.ps1"

        #create SConstruct file
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/SConstruct" -OutFile ".\SConstruct" 

        if ($script_files -ne "--disable-gd-files" -and $gd_files -ne "--disable-gd-files") {

        Write-Output "-----------------------------------------`n[97%] Generating project files...`n-----------------------------------------"

        #generate project files
        cd .\project\
        mkdir .\bin
        mkdir .\.import
        mkdir .\Assets\Art\Animations
        mkdir .\Assets\Art\Sprites
        mkdir .\Assets\Art\Tilesets
        mkdir .\Assets\Audio\Music
        mkdir .\Assets\Audio\Sound
        mkdir .\Assets\Levels\Prefabs
        mkdir .\Assets\Levels\Scenes
        mkdir .\Assets\Levels\UI
        mkdir .\Scripts\Characters
        mkdir .\Scripts\Characters\Player
        mkdir .\Scripts\Objects

        # create import folder with .gdignore file
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/project/.import/.gdignore" -OutFile ".\.import\.gdignore"
    
        # create default env
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/project/default_env.tres" -OutFile ".\default_env.tres"

        # create project.godot
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/project/project.godot" -OutFile ".\project.godot"

        # create world scene
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/project/Assets/Levels/Scenes/world.tscn" -OutFile ".\Assets\Levels\Scenes\world.tscn"

        Write-Output "-----------------------------------------`n[99%] Generating example .cpp files...`n-----------------------------------------"

        # create example.h
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/include/example.h" -OutFile "..\include\example.h"

        # create example.cpp
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/src/example.cpp" -OutFile "..\src\example.cpp"

        # create gdlibrary.cpp
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/src/gdlibrary.cpp" -OutFile "..\src\gdlibrary.cpp"
        
        # create example library
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/project/bin/lib.gdnlib" -OutFile ".\bin\lib.gdnlib"

        # create example library script
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DaRealAdalbertBro/Build-Godot-cpp/main/project_files/project/Assets/Scripts/Objects/example.gdns" -OutFile ".\Scripts\Objects\example.gdns"

        ((Get-Content -path ".\project.godot" -Raw) -replace "gdnative_cpp_project", $name) | Set-Content -Path ".\project.godot"
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
