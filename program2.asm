.model small
.stack 100H
.386
MAX = 15

;JUMPS ; auto generate inverted condition jmp on far jumps
.data
	err_source    	db 'Source failo nepavyko atidaryti skaitymui',13,10,'$'
	apie    		db 'Programa priima du failus (failo pavadinimas + .txt turi uzimti ne daugiau 13 simboliu). Programa palygina failuose esancius simbolius ir i stdout isveda nesutampancius simbolius ir ju pozicija nuo failo pradzios',13,10,'$'
	apie2 			db 'program2 [/?] sourceFile sourceFile' ,13,10, '$'
	nesutapimai		db 'Failuose nesutampa sie simboliai :', 13,10, '$'
	pozicija_text	db 'Pozicija - ', '$'
	raides_text		db ' nesutampancios raides - ', '$'
	
	sourceF   		db MAX dup (0)
	sourceF2		db MAX dup (0)
	
	sourceFHandle	dw ?
	sourceF2Handle	dw ?
	
	buffer			db 20 dup (?)
	buffer2			db 20 dup (?)
	
	simbolis1	 	db 0
	simbolis2		db 0
	simbolis_count	dw 0
	simbolis_number_buffer dw 0
	count_cx		dw 0
	index			dw 0


.code
START:
	mov			ax, @data
	mov			es, ax			; es kad galetume naudot stosb funkcija: Store AL at address ES:(E)DI
	mov			si, 81h      	; programos paleidimo parametrai rasomi segmente es pradedant 129 (arba 81h) baitu  
	
	call		skip_spaces
	
	;jei nieko nebuvo ivesta tai reikia isvesti pagalbos pranesima
	
	mov			al, byte ptr ds:[si]	; nuskaityti pirma parametro simboli
	cmp			al, 13					; jei nera parametru
	je			help					; tai isvesti pagalba

	;jei buvo nuskaitytas /? vistiek isvedam pagalba
	mov			ax, word ptr ds:[si]	; su word ptr nuskaitome 2 simobolius 
	cmp			ax, 3F2Fh        		; jei nuskaityta "/?" - 3F = '?'; 2F = '/' susikeicia vietom jaunesnysis ir vyresnysis baitai
	je			help         			; rastas "/?", vadinasi reikia isvesti pagalba

readSourceFile:

	lea			di, sourceF
	call		read_filename					; perkelti is parametro i eilute
	cmp			byte ptr ds:[sourceF], '$' 		;jei nieko nenuskaite
	je			error_source

	lea			di, sourceF2
	call		read_filename					; perkelti is parametro i eilute
	mov			ax, @data
	mov			ds, ax
	
source_from_file:
	
	mov	dx, offset sourceF				; failo pavadinimas
	mov	ah, 3dh                			; atidaro faila - komandos kodas
	mov	al, 0                  			; 0 - reading, 1-writing, 2-abu
	int	21h								; INT 21h / AH= 3Dh - open existing file
	jc	error_source					; CF set on error AX = error code.
	mov	sourceFHandle, ax				; issaugojam filehandle	
	
	cmp			byte ptr ds:[sourceF2], '$' 		;jei nieko nenuskaite
	jne			sourceF2_funkcija
	
	MOV sourceF2Handle, 0
	JMP skaitom
sourceF2_funkcija:
	mov	dx, offset sourceF2				; failo pavadinimas
	mov	ah, 3dh                			; atidaro faila - komandos kodas
	mov	al, 0                  			; 0 - reading, 1-writing, 2-abu
	int	21h								; INT 21h / AH= 3Dh - open existing file
	jc	error_source					; CF set on error AX = error code.
	mov	sourceF2Handle, ax				; issaugojam filehandle	

skaitom:
	mov	bx, sourceFHandle
	mov	dx, offset buffer       		; address of buffer in dx
	mov	cx, 20     						; kiek baitu nuskaitysim
	mov	ah, 3fh  						; function 3Fh - read from file
	int	21h
	MOV count_cx, ax
	cmp sourceF2Handle, 0
	JE read_from_stdin
	
	mov	bx, sourceF2Handle
	mov	dx, offset buffer2       		; address of buffer in dx
	mov	cx, 20      					; kiek baitu nuskaitysim
	mov	ah, 3fh         				; function 3Fh - read from file
	int	21h
	JMP testi
	
read_from_stdin:
	mov	bx, sourceF2Handle
	mov	dx, offset buffer2       		; address of buffer in dx
	mov	cx, 20      					; kiek baitu nuskaitysim
	mov	ah, 3fh         				; function 3Fh - read from file
	int	21h
	SUB ax, 2
	
testi:	
	cmp count_cx,ax
	JGE cx_priskyrimas
	
	MOV cx, ax							;patikrinam kiek is tikruju buvo nuskaityta
	CMP ax, 0							;
	JE	_end							;jeigu 0 tai baigiam darba
	MOV simbolis_number_buffer, 0
	JMP lyginam_simbolius

cx_priskyrimas:
	MOV cx, count_cx					;patikrinam kiek is tikruju buvo nuskaityta
	CMP ax, 0							;
	JE	_end							;jeigu 0 tai baigiam darba
	MOV simbolis_number_buffer, 0

lyginam_simbolius:
	
	; dirbam su pirmuoju failu ir pasidedam simboli i kintamaji simbolis
	MOV si, offset buffer
	ADD si, simbolis_number_buffer	;kelinttas bufferi
	MOV al, [si]
	MOV simbolis1, al
	
	; dirbam su antruoju failu ir simboli pasiliekam al registre (persikeliam i simboli2 tik jei reiketu spausdinti)
	MOV si, offset buffer2
	ADD si, simbolis_number_buffer	; kelintas bufferi
	MOV al, [si]
	MOV simbolis2, al
	
	INC simbolis_number_buffer
	; palyginam du simbolius (jeigu simboliai lygus nespausdinam nieko, jei nelygus tada atspausdinam simboli ir pozicija nuo failo pradzios
	INC simbolis_count
	cmp al, simbolis1
	JNE spausdinti_simboli

	LOOP lyginam_simbolius
	JMP skaitom

spausdinti_simboli:
	;isvedam texta pozicija - 
	MOV ah, 09h
	MOV dx, offset pozicija_text
	INT 21h
	
	
	MOV index, cx
	PUSH si di
	JMP convert_and_print
	
spausdinti_toliau:
	POP di si
	MOV cx, index
	;isvedam texta nesutampantys simboliai - 
	MOV ah, 09h
	MOV dx, offset raides_text
	INT 21h
	
	;isvedame simboli is pirmojo failo
	MOV dl, simbolis1
	MOV ah, 2
	INT 21h
	
	;isvedame tarpa tarp simboliu
	MOV dl,' '
	MOV ah, 2
	INT 21h
	
	;isvedame simboli is antrojo failo
	MOV dl, simbolis2
	MOV ah, 2
	INT 21h
	
	; po isvedimo atspausdinam nauja eilute
	MOV dl, 10
	MOV ah, 02h
	INT 21h
	MOV dl, 13
	MOV ah, 02h
	INT 21h

	
	LOOP lyginam_simbolius
	JMP skaitom
	
convert_and_print:
	MOV ax, simbolis_count
	MOV cx, 0
	MOV bx, 10
convert:
	XOR dx,dx
	DIV bx
ADD dl, '0'
loop1:
	PUSH dx
	INC cx
	CMP ax, 0
	JA convert
	
print_number:
	POP dx				; griztam i praeita reiksme
	MOV ah, 2
	INT 21h
	LOOP print_number
	JMP spausdinti_toliau

read_filename PROC near

	push		ax						;pasidedam ax į SS, kad nepasimestu reiksme		
	call		skip_spaces	
	MOV 		cx, 14 					;vienu maziau nes reikia pasilikti vietos '$' zenklui gale
read_filename_start:
	cmp	byte ptr ds:[si], 13			; jei nera parametru
	je	read_filename_end				; tai taip, tai baigtas failo vedimas
	cmp	byte ptr ds:[si], ' '			; jei tarpas
	jne	read_filename_next				; tai praleisti visus tarpus, ir sokti prie kito parametro
read_filename_end:
	mov	al, '$'							; irasyti '$' gale
	stosb                          		; Store AL at address ES:(E)DI, di = di + 1
	pop	ax
	ret
read_filename_next:
	lodsb								; uzkrauna kita simboli
	stosb                           	; Store AL at address ES:(E)DI, di = di + 1
	LOOP read_filename_start
	JMP _end

read_filename ENDP	


skip_spaces PROC near

skip_spaces_loop:
	cmp 		byte ptr ds:[si], ' '
	jne 		skip_spaces_end
	inc 		si
	jmp 		skip_spaces_loop
skip_spaces_end:
	ret
	
skip_spaces ENDP

error_source:
	mov	ax, @data
	mov	ds, ax
	
	mov	dx, offset err_source      
	mov	ah, 09h
	int	21h

	mov	dx, offset sourceF
	int	21h
	
	mov	ax, 4c01h
	int	21h 

help:
	mov	ax, @data
	mov	ds, ax
	
	mov	dx, offset apie      
	mov	ah, 09h
	int	21h
	
	; po isvedimo atspausdinam nauja eilute
	MOV dl, 10
	MOV ah, 02h
	INT 21h
	MOV dl, 13
	MOV ah, 02h
	INT 21h
	
	mov	dx, offset apie2     
	mov	ah, 09h
	int	21h

_end:
	mov	bx, sourceFHandle	; pabaiga skaitomo failo
	mov	ah, 3eh			; uzdaryti
	int	21h
	mov	bx, sourceF2Handle	; pabaiga skaitomo failo
	mov	ah, 3eh			; uzdaryti
	int	21h

	
	mov	ax, 4c00h
	int	21h  
	
end START

;GAL BUS KADA NAUDINGA

;KAIP ATSPAUSDINTI VISA BUFFERI ISKART
	;mov	bx, 1
	;mov	dx, offset buffer       ; address of buffer in dx
	;mov	cx, ax      		; kiek baitu nuskaitysim
	;mov	ah, 40h        	; function 3Fh - read from file
	;int	21h
	