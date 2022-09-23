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
        git submodule add -b main https://github.com/DaRealAdalbertBro/Build-Godot-cpp/tree/main/project_files
        cd godot-cpp
        git submodule update --init

        
        Write-Output "-----------------------------------------`n[29%] Building modules...`n-----------------------------------------"

        
        scons platform=windows generate_bindings=yes -j4
        cd ..
        godot --gdnative-generate-json-api api.json

        deactivate

   
    Write-Output "-----------------------------------------`n[97%] Generating project files...`n-----------------------------------------"

# modify project name of project.godot
cd .\project
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
run/main_scene=`"res://Assets/Levels/Scenes/world.tscn`"

[gui]

common/drop_mouse_on_gui_input_disabled=true

[physics]

common/enable_pause_aware_picking=true

[rendering]

environment/default_environment=`"res://default_env.tres`""

    Set-Content -Path '.\project.godot' -Value $project_godot


    
    
    


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
