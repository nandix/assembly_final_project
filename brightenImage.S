/******************************************************************************
 *
 * \file brightenImage.S
 *
 * \brief This function brightens an image by an amount provided 
 *
 * \author Daniel Nix
 *
 * \date April 22, 2014
 *
 * This funciton is an assembly version of a C function to brighten a ppm
 * 	image by an amount provided by the user. It improves performance
 *	by reading in an entire word so that a pixel may be fetched in one
 *	operation. This means that a pixel takes one read instead of 3.
 *	as a result, this code is roughly a factor of two faster than the
 * 	original C code.
 *
 * It should be compiled and linked using the makefile as follows:
 *   make depend
 *   make
 * 
 ******************************************************************************/

	.data
msg:	.asciz "Rows: %d \nCols: %d \n"
	.align 2
bright:
	.asciz "Amt to brighten: %s\n"
	.align 2

	.text
	.global brightenImage
brightenImage:	
	stmfd	sp!,{r4, r5, r6, r7, r8, r9, lr}
	/*	
		args passed:
				r0: base address for image struct
				r1: integer number to increase brightness		

		Registers used:
				r4: i, rows index
				r5: j, columns index
				r6: rows
				r7: read in as columns, converted to 4-pix index
				r8: base address to image struct
				r9: holds the amount to brighten image
	*/

	mov r8, r0		// Move the base image address to r8 (don't mangle)

	// Convert the character string amount to brighten to an interger
	mov r0, r1		// Move the brighten string to r0
	bl atoi			// Convert to an integer
	mov r9, r0		// Move integer ammount to brighten to r9 (don't mangle)
	
	//X get rows (shifted 12 bytes from base address)
	ldr r6, [r8 , #12]	// Load rows from the image struct
	
	//X get columns (shifted 16 bytes from base address)
	ldr r7, [r8, #16]	// Load columns from image struct
	
	//X Calculate number of steps required to go through a row
	add r7, r7, r7, lsl #1	// there are 3/4 as many 4-pixels as pixels
	lsr r7, #2		// shift right 2 to divide by 4

	//X for i < rows
	sub sp, sp, #4		// Move the stack pointer down 4 bytes
	mov r4, #0		// Set i to zero
	str r4, [sp]		// Put i on the stack to free a register

row_loop:
	mov r5, #0		// Set j to zero
	
	//X Load the base address of the rows array
	ldr r1, [r8, #(5*4)]	// Offset is 20 bytes from image base address

	//X Offset by 4 * row_to_be_processed (zero indexed)
	mov r2, r4, lsl #2	// Get the offset. i*4
	
	//X Load the base address of the actual row
	ldr r10, [r1, r2]	// Load the base row address into r0

	//for j < columns (columns in terms of 4-pixels
col_loop:
	
	//	Read in next 4-pixel at address r0 + 4*(r5)
	//	- Find offset from base address
	mov r2,	#4
	mul r2, r2, r5 
	//	- ldr the word
	ldr r1, [r10, r2]	// Load the value of next 4-pixel

	//	Fill word with brightness, making sure not to go over 255 for
	// 	any individual r, g, or b value
	// 	- put amount to brighten in a register
	mov r3, r9	// put brighten in r3
	
	
	/*
		passing to brighten_4pix
			r0:	not used
			r1:	4-pixel to be processed
			r2:  	offset to i_th row
			r3:	amount to brighten
	*/
	bl brighten_4pix	// Brighten an individual 4-pixel
	
	
	//	Write word to memory
	//	- Use the same address as we read from
	str r0, [r10, r2]	

	//	Increment j
	add r5, r5, #1

	cmp r5, r7		// Compare j to 4-pixel columns
	blt col_loop		// If j >= 4-cols, go to row_loop
				// 	COULD BE SPECIAL CASING BEFORE THIS POINT
				//	IF PICTURE COLUMNS NOT A MULTIPLE OF 4

	
	// Increment i
	ldr r4, [sp]		// Get j off the stack
	add r4, r4, #1
	// Compare and go back to row loop
	cmp r4, r6
	str r4, [sp]

	blt row_loop

	add sp, sp, #4
	ldmfd	sp!,{r4, r5, r6, r7, r8, r9, lr}
	mov	pc,lr

brighten_4pix:
	stmfd sp!, {r4, r5, r6, r7, lr}
	
	/*
		passing to brighten_4pix
			r0:	not used
			r1:	4-pixel to be processed
			r2:  	offset to i_th row
			r3:	amount to brighten
	*/
	mov r0, #8
	mov r4, #0		// initialize byte counter to 0
	mov r5, #0xFF		// initialize mask to 0xFF to mask of one byte
loop_pix:
	//	- mask all but LSByte
	and r6, r1, r5		// Mask all but the byte to analyze of 4-pixel
	sub r1, r1, r6		// Clear the byte to analyze by subtracting
	mul r7, r4, r0		// Get the shift right to move to LSByte (8*i)
	lsr r6, r6, r7		// Shift byte to LSByte position
	add r6, r6, r3		// Add with amount to brighten
	cmp r6, #255		// Compare to 255
	movgt r6, #255		// Reset to 255 if greater than 255
	lsl r6, r6, r7		// Shift back to the correct byte position
	orr r1, r1, r6		// Logical or with r0 to put new value into 4-pixel

	lsl r5, r5, #8		// Shift the mask to cover the next byte
	add r4, r4, #1		// increment the byte counter
	cmp r4, #4		// see if we've looped through all 4 bytes
	blt loop_pix		// If we haven't, process the next byte

	mov r0, r1		// Return the processed 4-pixel in r0

	ldmfd sp!, {r4, r5, r6, r7, lr}
	mov pc, lr

