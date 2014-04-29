
	.data
msg:	.asciz "Rows: %d \nCols: %d \n"
	.align 2

	.text
	.global negateImage
negateImage:	
	stmfd	sp!,{lr}
	/*
		Registers used:
				r4: i, rows index
				r5: j, columns index
				r6: rows
				r7: read in as columns, converted to 4-pix index
				r8: base address to image struct
	*/
	
	mov r8, r0		// Move the base image address to r8 (don't mangle)
	//X get rows (shifted 12 bytes from base address)
	ldr r6, [r0 , #12]	// Load rows from the image struct
	
	//X get columns (shifted 16 bytes from base address)
	ldr r7, [r0, #16]	// Load columns from image struct
	
	//X Calculate number of steps required to go through a row
	add r7, r7, r7, lsl #1	// there are 3/4 as many 4-pixels as pixels
	lsr r7, #2		// shift right 2 to divide by 4

	//X for i < rows
	mov r4, #0		// Set i to zero
row_loop:
	mov r5, #0		// Set j to zero
	
	//X Load the base address of the rows array
	ldr r1, [r8, #(5*4)]	// Offset is 20 bytes from image base address

	//X Offset by 4 * row_to_be_processed (zero indexed)
	mov r2, r4, lsl #2	// Get the offset. i*4
	
	//X Load the base address of the actual row
	ldr r0, [r1, r2]	// Load the base row address into r0

	//for j < columns (columns in terms of 4-pixels
col_loop:
	
	//	Read in next 4-pixel at address r0 + 4*(r5)
	//	- Find offset from base address
	mov r2,	#4
	mul r2, r2, r5 
	//	- ldr the word
	ldr r1, [r0, r2]	// Load the base address of the next 4-pixel

	//	Fill word with [255,255,255,255]
	// 	- put 255 in a register
	mov r3, #255	// 255 in r2
	//	- orr with itself shifted left 8
	orr r3, r3, lsl #8
	// 	- orr with itself shifted left 16
	orr r3, r3, lsl #16

	//	Subtract: [255,255,255,255]-word
	sub r3, r3, r1
	
	//	Write word to memory
	//	- Use the same address as we read from
	str r3, [r0, r2]	

	//	Increment i
	add r5, r5, #1

	cmp r5, r7		// Compare j to 4-pixel columns
	blt col_loop		// If j >= 4-cols, go to row_loop
				// 	COULD BE SPECIAL CASING BEFORE THIS POINT
				//	IF PICTURE COLUMNS NOT A MULTIPLE OF 4

	
	// Increment j
	add r4, r4, #1
	// Compare and go back to row loop
	cmp r4, r6
	blt row_loop

	ldmfd	sp!,{lr}
	mov	pc,lr
