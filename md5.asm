section .bss
	md5_block	resb 64 ; 512-bit input block
	md5_digest	resb 16 ; 128-bit MD5 result

section .data
	prompt db "Enter a value to hash: ", 0
	prompt_len equ $ - prompt

	error_msg_too_long db "Input too long.", 10
	error_msg_too_long_len equ $ - error_msg_too_long



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

	mov rax, 1
	mov rdi, 1
	mov rsi, md5_block
	mov rdx, rbx
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

_exit:
	; exit with 0
	mov rax, 60
	xor rdi, rdi
	syscall
