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

	; MD5 T constants (64 rounds)
	md5_T:
		dd 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee
		dd 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501
		dd 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be
		dd 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821
		dd 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa
		dd 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8
		dd 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed
		dd 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a
		dd 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c
		dd 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70
		dd 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05
		dd 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665
		dd 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039
		dd 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1
		dd 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1
		dd 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391

	; MD5 S rotation amounts (64 rounds)
	md5_S:
		db 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22
		db 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20
		db 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23
		db 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21

	; MD5 word indices (X[k] to use in each round)
	md5_K:
		db 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
		db 1, 6, 11, 0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12
		db 5, 8, 11, 14, 1, 4, 7, 10, 13, 0, 3, 6, 9, 12, 15, 2
		db 0, 7, 14, 5, 12, 3, 10, 1, 8, 15, 6, 13, 4, 11, 2, 9


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
	lea r15, [rel md5_block]
	call pad_block

	lea r15, [rel md5_block]
	lea rdi, [rel md5_words]
	call parse_words
	call init_md5			; initializes MD5 constants into r8d, r9d, r10d, r11d
	
	lea r15, [rel md5_words]
	call md5_rounds

	; Move into function later
	mov [rel md5_digest], r8d	; A
	mov [rel md5_digest + 4], r9d	; B
	mov [rel md5_digest + 8], r10d	; C
	mov [rel md5_digest + 12], r11d	; D

	; Print the digest (raw bytes for now)
	mov rax, 1
	mov rdi, 1
	lea rsi, [rel md5_digest]
	mov rdx, 16
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
	mov byte [r15+rbx], 0x80
	mov rax, rbx			; rbx is the length
	add rax, 1
	mov rcx, 56
	sub rcx, rax			; gives amount to pad in rcx

	lea rdi, [r15 + rbx +1]
	xor eax, eax
	rep stosb

	mov rax, rbx
	shl rax, 3
	mov qword [r15 + 56], rax

	ret

init_md5:
	; Load 32-bit MD5 constants into registers
	mov r8d, [rel md5_A0]
	mov r9d, [rel md5_B0]
	mov r10d, [rel md5_C0]
	mov r11d, [rel md5_D0]
	ret

parse_words:
	; R15 = md5_block (input)
	; RDI = md5_words (output)

	; Load batch 1
	mov eax, [r15 + 0]
	mov ebx, [r15 + 4]
	mov ecx, [r15 + 8]
	mov edx, [r15 + 12]
	mov r8d, [r15 + 16]
	mov r9d, [r15 + 20]
	mov r10d, [r15 + 24]
	mov r11d, [r15 + 28]

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
	mov eax, [r15 + 32]
	mov ebx, [r15 + 36]
	mov ecx, [r15 + 40]
	mov edx, [r15 + 44]
	mov r8d, [r15 + 48]
	mov r9d, [r15 + 52]
	mov r10d, [r15 + 56]
	mov r11d, [r15 + 60]

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

; MD5 AUXILIARY FUNCTIONS
aux_F:
	; rounds 0-15
	; edi = X, esi = Y, edx = Z
	; Return (X & Y) | (~X & Z) in eax
	
	; Calculate (X & Y)
	mov eax, edi			; eax = X
	and eax, esi			; eax = X & Y
	
	; Calcualte (~X & Z)
	mov ebx, edi			; ebx = X
	not ebx				; ebx = ~X
	and ebx, edx			; ebx = ~X & Z
	
	; Combine with OR
	or eax, ebx			; eax = (X & Y) | (~X & Z)
	ret

aux_G:
	; rounds 16-31
	; edi = X, esi = Y, edx = Z
	; Return (X & Z) | (Y & ~Z) in eax

	; Calculate (X & Z)
	mov eax, edi			; eax = X
	and eax, edx			; eax = X & Z

	; Calculate (Y & ~Z)
	mov ebx, esi			; ebx = Y
	mov ecx, edx			; ecx = Z
	not ecx				; ecx = ~Z
	and ebx, ecx			; ebx = Y & ~Z
	
	; Combine with OR
	or eax, ebx			; eax = (X & Z) | (Y & ~Z)
	ret

aux_H:
	; rounds 32-47
	; edi = X, esi = Y, edx = Z
	; Return X ^ Y ^ Z in eax
	
	; Calculate X ^ Y ^ Z
	mov eax, edi			; eax = X
	xor eax, esi			; eax = X ^ Y
	xor eax, edx			; eax = X ^ Y ^ Z
	ret

aux_I:
	; rounds 48-63
	; edi = X, esi = Y, edx = Z
	; Return Y ^ (X | ~Z)
	
	; Calculate (X | ~Z)
	mov eax, edi			; eax = X
	mov ecx, edx			; ecx = Z
	not ecx				; ecx = ~Z
	or eax, ecx			; eax = (X | ~Z)
	
	; Calculate Y ^ (X | ~Z)
	xor eax, esi
	ret

rotate_Left:
	; eax = valute to rotate
	; ecx = number of bits to rotate
	rol eax, cl			; rotating by the low byte of ecx
	ret

md5_rounds:
	; r8d = A, r9d = B, r10d = C, r11d = D
	; rsi points to md5_words
	; rcx = round counter (0-63)
	xor rcx, rcx			; rcx = 0

.round_loop:
	cmp rcx, 64
	jge .rounds_done
	
	; Load word index K[round]
	lea rax, [rel md5_K]
	movzx eax, byte [rax + rcx]	; eax = word index

	; Load X[k] from md5_words
	mov edx, [r15 + rax*4]		; edx = X[k]
	mov r14d, edx			; r14d = X[k]

	; Load T constant T[round]
	lea rax, [rel md5_T]
	mov r12d, [rax + rcx*4]		; r12d = T[round]

	; Load S rotation amount S[round]
	lea rax, [rel md5_S]
	movzx r13d, byte [rax + rcx]	; r13d = S[round]
	
	; Initialize aux function arguments (pass B, C, D)
	; Args: edi = X, esi = Y, edx = Z
	mov edi, r9d			; edi = B
	mov esi, r10d			; esi = C
	mov edx, r11d			; edx = D
	
	; Determine aux function to call
	mov rax, rcx			; rax = round count
	cmp rax, 16
	jl .call_F
	cmp rax, 32
	jl .call_G
	cmp rax, 48
	jl .call_H
	jmp .call_I

.call_F:
	call aux_F
	jmp .after_aux
.call_G:
	call aux_G
	jmp .after_aux
.call_H:
	call aux_H
	jmp .after_aux
.call_I:
	call aux_I

.after_aux:
	; eax contains result of aux function
	; Add components: A + eax + T + X[k]
	mov ebx, r8d			; ebx = A
	add ebx, eax			; ebx = A + aux result
	add ebx, r12d			; ebx = A + aux result + T
	add ebx, r14d			; ebx = A + aux result + T + X[k]

	; Rotate left by S[round]
	push rcx
	mov ecx, r13d
	rol ebx, cl
	pop rcx

	; Save old D value
	mov eax, r11d			; eax = old D
	
	; Shift variables: D = C, C = B
	mov r11d, r10d			; D = C
	mov r10d, r9d			; C = B

	; Update B = old B + rotate result
	add r9d, ebx

	; A = old D
	mov r8d, eax

	; Next round
	inc rcx
	jmp .round_loop

.rounds_done:
	ret

_exit:
	; exit with 0
	mov rax, 60
	xor rdi, rdi
	syscall
