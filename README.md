# MD5 Hasher in Assembly

A work-in-progress program that implements the MD5 hashing algorithm in x86-64 Assembly. The goal is to accept user input and return the computed MD5 hash.

## Files

- `md5.asm` – Program entry point; currently handles user input, validation, and initiates the hashing process.

## Build Instructions

This project is assembled using [NASM](https://www.nasm.us/) (Netwide Assembler).

**To build:**
```bash
nasm -f elf64 md5.asm -o md5.o
ld md5.o -o md5
```

## Notes
- This implementation is written entirely in x86-64 Assembly.
- Designed for Linux x86-64 systems.
- Make sure you have NASM and the standard Linux linker (`ld`) installed.
