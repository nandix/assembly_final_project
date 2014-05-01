
	.data
msg:	.asciz "Rows: %d \nCols: %d \n"
	.align 2

no_mem:
	.asciz "Unable to allocate memory for graymap\n"	// Message if we couldn't allocate space for graymap
	.align 2

bad_err:
	.asciz "Cannot convert bitmap to grayscale\n"
	.align 2

minMax:	.word 0, 1 // Holds current minimum and maximum values


	.text
	.global grayscaleImage
grayscaleImage:
	stmfd	sp!,{r4, r5, r6, r7, r8, r9, r10, r11, lr}
	/*	
		args passed:
				r0: base address for image struct
				r1: integer number to increase brightness		

		Registers used:
				r4: i, rows index
				r5: j, columns index
				r6: rows
				r7: 3-pixel columns
				r8: base address to image struct
	*/

	mov r8, r0		// Move the base image address to r8 (don't mangle)

	// Get magic number
	ldr r0, [r8]		// Get magic number
	sub r0, r0, #48		// Convert to an integer

	cmp r0, #1
	beq bad_img		// See if magic number is 1
	
	cmp r0, #4		// See if magic number is 4
	bne good_img

	// If the image was magic number 1 or 4, print mesage to user and exit
bad_img:
	ldr r1, =bad_err	// Load bad image error mesage
	ldr r0, =stderr		// Return 1 for an error
	bl fprintf
	ldmfd sp!,{r4, r5, r6, r7, r8, r9, r10, lr}
//	mov pc, lr		// Exit from bad image case
	bl exit			// Exit from bad image case

good_img:
	//X get rows (shifted 12 bytes from base address)
	ldr r6, [r8 , #12]	// Load rows from the image struct
	
	//X get columns (shifted 16 bytes from base address)
	ldr r7, [r8, #16]	// Load columns from image struct
	
	//X for i < rows
	mov r4, #0		// Set i to zero


	// If the image was type 2 or 5, loop through and find the min and max
	cmp r0, #2		// See if "Magic Number" is 2
	beq minMax_rows		// If grayscale, find the min and max values 

	cmp r0, #5		// See if "Magic Number" is 5
	bne not_grayscale	// If not 2 or 5, it's not grayscale so skip the next block

	// 	- For i < rows
minMax_rows:
	
	mov r5, #0	// Reset j to zero
	//X Get base address for grayscale row
        ldr r1, [r8, #(6*4)]    // Offset is 24 bytes from image base address
	// Find offset to row to be processed: r1 + 4*counter
	mov r2, r4, lsl #2	// move i*4 into r2
	ldr r10, [r1, r2]	// Load r1 offset by 4*i bytes
 
	mov r1, #1		// Move 0 into r1 to hold max
	mov r2, #0		// Move 1 into r2 to hold min
	// 	- For j < cols
minMax_cols:
	/*
		r10:	base address to grayscale row
		
	*/
	//		- Load next byte in grayscale[i][j]
	ldrb r0, [r10, r5]	// Load byte from (row base address) + (j byte offset)
	// 		- Compare image[i][j] to max and min
	cmp r0, r1	// Compare next grayscale value to min
	// 		- If gray_image[i][j] < min, set appropriately
	movlt r1, r0	// Store new min	

	//		- If gray_image[i][j] > max, set appropriately
	cmp r0, r2	// Check if value is greater than the max 
	movgt r2, r0	// If it is, store it in the max


	add r5, r5, #1		// Increment the columns counter
	cmp r5, r7		// Compare j to number of columns
	blt minMax_cols		// Go through columns loop again if counter <= Cols
	
	add r4, r4, #1		// Increment rows counter
	cmp r4, r6		// Compare rows to rows counter
	blt minMax_rows		// Go through rows loop again if counter <= rows
	
	ldr r3, =minMax		// load the address of minMax
	str r1, [r3]		// Store the min
	add r3, #4		// Offset by 4 bytes
	str r2, [r3]		// Store the max

	//	- Put pointer to minMax in r0 to return
	ldr r0, =minMax
	ldmfd sp!,{r4, r5, r6, r7, r8, r9, r10, lr}
	mov pc, lr	// Return after checking min and max grayscale values	

not_grayscale:

	// Check if our grayscale pointer is NULL
	ldr r0, [r8, #(6*4)]
	// If NULL 
	cmp r0, #0	// Compare the pointer to zero (NULL)
	bne process_image	// If the pointer wasn't null, go on processing

	// 	- Allocate space for rows base address pointers array
	mov r0, r6, lsl #2  	// space needed is 4*rows bytes
	bl malloc		// Allocate space to point to rows
	//	- If not successful, notify user and exit
	cmp r0, #0		// Check if malloc returned null
	
	bne allocated_rows
	ldr r0, =no_mem	// If it did, notify user and get out!
	bl perror		// Print error message to screen

	ldmfd sp!,{r4, r5, r6, r7, r8, r9, r10, lr}
        mov pc, lr 

allocated_rows:
	/*
		r0: base address to rows array
		r1: number of rows
		r2: number of columns
	*/

	mov r1, r6	// Put the number of rows in r1
	mov r2, r7	// put the number of cols in r2	

	bl allocate_space
	mov r9, r0 	// put the base address to grayscale in r9

	// Begin processing the image
process_image:
	mov r4, #0		// Reset i to zero to use again
	// Do the actual calculation
row_loop:
	mov r5, #0		// Set j to zero
	
	//X Load the base address of the rows array
	ldr r1, [r8, #(5*4)]	// Offset is 20 bytes from image base address

	//X Offset by 4 * row_to_be_processed (zero indexed)
	mov r2, r4, lsl #2	// Get the offset. i*4
	
	//X Load the base address of the actual row
	ldr r10, [r1, r2]	// Load the base row address into r0
	ldr r11, [r9, r2]	// Load base row address for grayscale
	//for j < columns (columns in terms of 3-pixels)
col_loop:
	
	//	Read in next 3-pixel at address r0 + 3*(r5)
	//	- Find offset from base address
	mov r2,	#3
	mul r2, r2, r5 
	//	- ldr the word
	ldr r1, [r10, r2]	// Load the value of next 4-pixel

	
	
	/*
		passing to gray_pix
			r0:	not used
			r1:	4-pixel to be processed
			r2:  	offset to i_th row
			r3:	amount to brighten
	*/
	bl gray_pix	// Grayscale an individual 3-pixel
	
	
	//	Write word to memory
	//	- Use address base+offset_in_bytes

	strb r0, [r11, r5]	// Store the grayscale value to memory

	//	Increment j
	add r5, r5, #1

	cmp r5, r7		// Compare j to 3-pixel columns
	blt col_loop		// If j >= cols, go to row_loop

	
	// Increment i
	add r4, r4, #1
	// Compare and go back to row loop
	cmp r4, r6

	blt row_loop

	// Decrement the magicNumber
	ldr r0, [r8] 		// Load the magic number
	sub r0, r0, #1		// decrement the magic number
	str r0, [r8]		// Store the magic number

	str r9, [r8, #(6*4)]	// Store the base address of grayscaleImage in struct

	ldr r0, =minMax		// Put the pointer to minMax in r0 to return
	// Put the minMax pointer in r0 to return
	ldmfd	sp!, {r4, r5, r6, r7, r8, r9, r10, r11, lr}
	mov	pc, lr


gray_pix:
	stmfd sp!, {r4, r5, r6, r7, lr}
	
	/*
		passing to gray_pix
			r0:	not used
			r1:	pixel to be processed
			r2:  	offset to i_th row
			r3:	amount to brighten
	*/

	// Compute 1*blue 	(offset 0)
	//	-Mask to get first byte
	and r4, r1, #0xFF0000
	//	-Shift right 16
	lsr r4, r4, #16

	// Compute 6*green 	(offset 1)
	// 	-Mask to get 2nd byte
	and r5, r1, #0xFF00
	//	-Shift right 16
	lsr r5, r5, #8
	// 	-Calculate 6*green
	mov r0, #6
	mul r5, r5, r0

	// Compute blue 	(offset 2)
	//	-Mask to get 3rd byte
	and r6, r1, #0xFF
	// 	-Don't need to calculate blue (multiplied by 1)
	mov r0, #3
	mul r6, r6, r0	// Multiply by 6	

	// Add red, blue, and green
	// 	-Add red+green
	add r4, r4, r5
	//	-Add (r+g)+blue
	add r4, r4, r6
	// Compute 5 + (r+g+b), store in r0
	add r0, r4, #5
	
	// Divide [5+r+g+b] by 10, dropping decimal
	mov r5, r1
	mov r1, #10
	bl divide
	mov r1, r5
	
	// Crop value between 0 and 255
	bl crop

	// Grayscale value is returned in r0, as left by "crop"
	
	ldmfd sp!, {r4, r5, r6, r7, lr}
	mov pc, lr

allocate_space:
	stmfd sp!, {r4, r5, r6, r7, r10, lr}
	/*
		r0: base address to rows array
		r1: number of rows
		r2: number of columns
	*/
	mov r5, r1	// Move the number of rows to r5
	mov r6, r2	// Move the number of columns to r6
	mov r10, r0	// Move the base address to r10 so we don't mangle
	mov r4, #0	// Initialize counter
alloc_loop:
	// 	- For i < num_rows
	mov r0, r6	// Move the number of columns (number of bytes to allocate) into r0
	bl malloc	// Allocate space for the row
	cmp r0, #0	// See if malloc returned NULL
	beq unable_to_allocate	// If we couldn't allocate space, get out!

	// Put the address of row i into the grayscale pointer array
	mov r7, r4, lsl #2
	str r0, [r10, r7]	// Store the row base address in the correct location
	
	// Compare the counter to number of rows
	add r4, r4, #1		// Increment counter
	cmp r4, r5		// Compare counter
	blt alloc_loop	// If we haven't allocated all the rows yet, loop back
	bge successful_mem_alloc	// Return base address to rows array
	
unable_to_allocate:
	ldr r0, =no_mem		// If we couldn't allocate space
	bl perror		// Print the message to the user

successful_mem_alloc:
	mov r0, r10		// Move the base address of the rows array to r0
	ldmfd sp!, {r4, r5, r6, r7, r10, lr}
	mov pc, lr
