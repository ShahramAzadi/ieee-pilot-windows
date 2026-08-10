# IEEE PILOT Windows

This repository contains a Windows-compatible build of IEEE PILOT 1.12.

This is a Windows port of the original IEEE PILOT project by Eric S. Raymond.

## Windows compatibility changes

- Added Windows support for file access and sleep functions.
- Replaced termcap linking with ncurses for MSYS2 builds.
- Added compatibility adjustments for Windows compilation.

The Windows compatibility modifications were made with assistance from ChatGPT.

## Building on Windows

The project can be built using MSYS2 with the UCRT64 environment.

Required tools:

- GCC
- Bison
- Flex
- ncurses

Build:

```bash
make
```

## Running on Windows

After building the project, it is recommended to run IEEE PILOT from Windows PowerShell or Command Prompt rather than from the MSYS2 terminal.

Example:

```powershell
.\pilot.exe .\examples\hello.p
```

Pre-built binaries

If you do not want to build the source code yourself, you can download the pre-built Windows executables from the Releases section.

The release package contains:

pilot.exe — IEEE PILOT interpreter

pilotconv.exe — PILOT converter