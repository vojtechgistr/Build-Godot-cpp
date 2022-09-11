# Build-Godot-cpp
This program creates the entire cpp workspace for godot (C++).

### Command Usage / Variation:
```
.\script.ps1 <project name> --disable-script-files --disable-gd-files
```

<br>

#### If you can't run the script because of the digital signature, you can:
- create a new file ```script.ps1``` and paste its contents into it. Then run the setup as above.
- or simply unblock it in the file security properties, like this:

<br>

<img src="https://user-images.githubusercontent.com/56306485/189515787-eaa1f0a5-c19d-4288-8de1-9f18527c8df0.png"/>

<br>

If you cannot execute scripts at all, run ```Set-ExecutionPolicy RemoteSigned``` in PowerShell as an administrator. Then type ```y``` or ```A``` and confirm.
