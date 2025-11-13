section .bss
	md5_block	resb 64 ; 512-bit input block
	md5_words	resb 64 ; 16 x 32-bit words parsed from user input
	md5_digest	resb 16 ; 128-bit MD5 result


section .data
	prompt db "Enter a value to hash: ", 0
	prompt_len equ $ - prompt

	error_msg_too_long db "Input too long.", 10
	error_msg_too_long_len equ $ - error_msg_too_long

	; MD5 initialization constants
	md5_A0	dd 0x67452301
	md5_B0	dd 0xEFCDAB89
	md5_C0	dd 0x98BADCFE
	md5_D0	dd 0x10325476


section .text
	global _start

_start:
	; write the user input prompt
	mov rax, 1
	mov rdi, 1
	mov rsi, prompt
	mov rdx, prompt_len
	syscall

	; read user input using stdin
	mov rax, 0			; syscall: read
	mov rdi, 0			; fd: stdin
	mov rsi, md5_block		; buffer
	mov rdx, 64			; read up to 64 bytes into the buffer
	syscall
	mov rbx, rax

	call check_len			; returns AL = status
	cmp al, 0
	jne .handle_len_error
	
	; after successful length check
	lea rsi, [rel md5_block]
	call pad_block

	lea rsi, [rel md5_block]
	lea rdi, [rel md5_words]
	call parse_words
	
	mov rax, 1
	mov rdi, 1
	mov rsi, md5_words
	mov rdx, 64
	syscall

	jmp .after

.handle_len_error:
	cmp al, 1
	jne .maybe_exit
	mov rax, 1
	mov rdi, 1
	mov rsi, error_msg_too_long
	mov rdx, error_msg_too_long_len
	syscall
	jmp _exit

.maybe_exit:
	jmp _exit

.after:
	jmp _exit

check_len:
	cmp rbx, 0
	je .empty
	
	mov rcx, rbx
	dec rcx

	mov al, byte [md5_block + rcx]
	cmp al, 10			; '\n'
	jne .check55
	dec rbx

	cmp rbx, 0
	je .empty


.check55:
	cmp rbx, 55
	jbe .ok
	mov al, 1			; too long
	ret

.ok:
	xor al, al			; okay length
	ret

.empty:
	mov al, 2			; empty/EOF
	jmp _start

pad_block:
	mov byte [rsi+rbx], 0x80
	mov rax, rbx			; rbx is the length
	add rax, 1
	mov rcx, 56
	sub rcx, rax			; gives amount to pad in rcx

	lea rdi, [rsi + rbx +1]
	xor eax, eax
	rep stosb

	mov rax, rbx
	shl rax, 3
	mov qword [rsi + 56], rax

	ret

init_md5:
	; Load 32-bit MD5 constants into registers
	mov eax, [rel md5_A0]
	mov ebx, [rel md5_B0]
	mov ecx, [rel md5_C0]
	mov edx, [rel md5_D0]
	ret

parse_words:
	; RSI = md5_block (input)
	; RDI = md5_words (output)

	; Load batch 1
	mov eax, [rsi + 0]
	mov ebx, [rsi + 4]
	mov ecx, [rsi + 8]
	mov edx, [rsi + 12]
	mov r8d, [rsi + 16]
	mov r9d, [rsi + 20]
	mov r10d, [rsi + 24]
	mov r11d, [rsi + 28]

	; Store batch 1
	mov [rdi + 0], eax
	mov [rdi + 4], ebx
	mov [rdi + 8], ecx
	mov [rdi + 12], edx
	mov [rdi + 16], r8d
	mov [rdi + 20], r9d
	mov [rdi + 24], r10d
	mov [rdi + 28], r11d

	; Load batch 2
	mov eax, [rsi + 32]
	mov ebx, [rsi + 36]
	mov ecx, [rsi + 40]
	mov edx, [rsi + 44]
	mov r8d, [rsi + 48]
	mov r9d, [rsi + 52]
	mov r10d, [rsi + 56]
	mov r11d, [rsi + 60]

	; Store batch 2
	mov [rdi + 32], eax
	mov [rdi + 36], ebx
	mov [rdi + 40], ecx
	mov [rdi + 44], edx
	mov [rdi + 48], r8d
	mov [rdi + 52], r9d
	mov [rdi + 56], r10d
	mov [rdi + 60], r11d
	ret


_exit:
	; exit with 0
	mov rax, 60
	xor rdi, rdi
	syscall
