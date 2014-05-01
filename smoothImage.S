
	.data
msg:    .asciz "Rows: %d \nCols: %d \n"
        .align 2

no_mem:  // Message if we couldn't allocate space for the temporary image 
        .asciz "Unable to allocate memory for temporary image\n"        
        .align 2

t_col:	.word 0	// Holds a temporary column
t_row:	.word 0	// Holds a temporary row
	
	.text
	.global smoothImage
smoothImage:
	stmfd	sp!,{r4, r5, r6, r7, r8, r9, r10, r11, lr}

	mov r8, r0              // Move the base image address to r8 (don't mangle)

        //X get rows (shifted 12 bytes from base address)
        ldr r6, [r8 , #12]      // Load rows from the image struct

        //X get columns (shifted 16 bytes from base address)
        ldr r7, [r8, #16]       // Load columns from image struct


        //      - Allocate space for rows base address pointers array
        mov r0, r6, lsl #2      // space needed is 4*rows bytes
        bl malloc               // Allocate space to point to rows
        //      - If not successful, notify user and exit
        cmp r0, #0              // Check if malloc returned null

        bne allocated_rows
        ldr r0, =no_mem // If it did, notify user and get out!
        bl perror               // Print error message to screen

        ldmfd sp!,{r4, r5, r6, r7, r8, r9, r10, r11, lr}
        mov pc, lr
	
	// Allocate space for the temporary picture
	// - Call allocate_space with registers set as
	// 	r0 = base address to rows array
	//	r1 = number of rows to allocate
	// 	r2 = number of bytes to allocate per row
allocated_rows:
        /*
                r0: base address to rows array
                r1: number of rows
                r2: number of columns
        */

        mov r1, r6      	// Put the number of rows in r1
	add r2, r7, r7, lsl #1     		// put the number of bytes (3*(3-pixels)) in r2
	
        bl allocate_space
        mov r9, r0      // put the base address to temp in r9

        // Begin processing the image
process_image:
        mov r4, #1              // Reset i to zero to use again

	// ----------------- SMOOTH IMAGE EXCEPT BORDERS -----------------
	// For( each row except first and last )
	// - For( i = 1(not zero), i < rows-1, i++ )
        // Do the actual calculation
row_loop:
        mov r5, #1              // Set j to zero


	//	For( each column except first and last )
	// 	- for( j=1 (not zero), j < columns-1, j++ )
        //for j < columns (columns in terms of 4-pixels)
col_loop:

	//		smooth pixel at index i, j (returned in r0)
        /*
                passing to smooth_pix
                        r0:     base address to image
                        r1:     base address to temp
                        r2:     row index
			r3:	column index
        */
//*
	// SMOOTH PIXEL CALL (commented out for debugging)
	ldr r0, [r8, #(5*4)]	// Load the base address to image
	mov r1, r9		// Move the base address to temp
	mov r2, r4		// Move the current row index
	mov r3, r5		// Move the current column index
        bl smooth_pix     	// Grayscale an individual 3-pixel
//*/
	// DEBUGGING &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
	/*
		passing to get_pix
			r0:	base address to image
			r1:	row index
			r2:	3-pixel column index
	*/
/*
	ldr r0, [r8, #(5*4) ]
	mov r1, r4	// Move the row address
	mov r2, r5	// Move the column address
	bl read_pix
	// NOW THE PIXEL VALUE IS IN R0
*/
	// END DEBUGGING &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

	// 		store smoothed pixel at index i, j
        //      Write word to memory
        //      - Use address base+offset_in_bytes
	// Call write_pix
	
        /*
                passing to write_pix
                        r0:     base address to image
                        r1:     row index
                        r2:     3-pixel column index
        		r3:	pixel to write
	*/
	mov r3, r0	// Move the pixel to write
	mov r0, r9	// Move the base temp address
	mov r1, r4	// Move the row index
	mov r2, r5	// Move the column index
	bl write_pix	// Write the pixel	

        //      Increment j
        add r5, r5, #1

	sub r0, r7, #1		// Get cols-1 to compare
        cmp r5, r0              // Compare j to 3-pixel columns
        blt col_loop            // If j >= cols, go to row_loop


        // Increment i
        add r4, r4, #1
        // Compare and go back to row loop
	sub r0, r6, #1
        cmp r4, r0

        blt row_loop



	// ----------------- FIX FIRST AND LAST COL (except corners) -----
	// For( all rows except first and last )
	// - for( i=1 (not zero); i < rows-1; i++ )
	// 	Fix the columns j = 0 and j = cols-1 

	/*
		passing to read_pix
			r0:	base address to image
			r1:	row index
			r2:	3-pixel column index
                
		passing to write_pix
                        r0:     base address to image
                        r1:     row index
                        r2:     3-pixel column index
			r3:	pixel to write
        */
	
	mov r4, #1
	mov r5, #1	// 
fix_cols:
	//Write to the first column
	mov r0, r9	// Move the base address
	mov r1, r4	// Move the row index+1
	mov r2, #1	// Move the column index
	bl read_pix	// Get the pixel in r0
	mov r3, r0	// Move dat pixel
	mov r0, r9	// Move the base address
	mov r1, r4	// Move the row address
	mov r2, #0	
	bl write_pix	

	// R6 is rows R7 is cols
	// Write to the last column 
	mov r0, r9	// Move the base address
	mov r1, r4	// Move the row index
	sub r2, r7, #2	// Move the column index
	bl read_pix
	mov r3, r0	// Move dat pix
	mov r0, r9	// Move dat base address
	mov r1, r4	// Move dat row index
	sub r2, r7, #1
	bl write_pix
	
	add r4, r4, #1
	sub r0, r6, #1
	cmp r4, r0
	blt fix_cols
	
	// ----------------- FIX FIRST AND LAST ROW (except corners) -----
	// For( all columns except first and last )
	// - for( i=1 (not zero); i < cols-1; i++ )
	// 	Fix the rows j=0 and j=rows-1
	mov r5, #1	// Initialize counter to 1
fix_rows:
	//Write to the first column
	mov r0, r9	// Move the base address
	mov r1, #1	// Move the row index
	mov r2, r5	// Move the column index
	bl read_pix	// Read dat pix
	mov r3, r0	// Move dat pix
	mov r0, r9	// Move dat base address
	mov r1, #0	// Move dat row index
	mov r2, r5	// Move dat column index
	bl write_pix

	// R6 is rows R7 is cols
	// Write to the last column 
	mov r0, r9	// Move the base address
	sub r1, r6, #2	// Move the row index
	mov r2, r5	// Move the column index
	bl read_pix	// Read dat pixel
	mov r3, r0	// Move dat pix
	mov r0, r9	// Move dat base address
	sub r1, r6, #1	// Move dat row index
	mov r2, r5
	bl write_pix
	
	add r5, r5, #1
	sub r0, r7, #1
	cmp r5, r0
	blt fix_rows
	
	

	// ----------------- FIX CORNERS ---------------------------------
	// corners equal same as diagonal inward
	// tmp[0][0] = tmp[1][1];
	mov r0, r9	// Move the base address
	mov r1, #1	// Move the row address
	mov r2, #1	// Move the column address
	bl read_pix
	mov r3, r0	// Move dat pix
	mov r0, r9	// Move dat address
	mov r1, #0	// Move dat row index
	mov r2, #0	// Move dat col index
	bl write_pix

	// tmp[0][image->cols-1] = tmp[1][image->cols-2];
	mov r0, r9	// Move the base address
	mov r1, #1	// Move the row address
	sub r2, r7, #2	// Move the column address
	bl read_pix	// Read dat pix
	mov r3, r0	// MOve dat pix
	mov r0, r9	// Move dat address
	mov r1, #0	// Move dat row index
	sub r2, r7, #1	// Move dat column index
	bl write_pix

 	// tmp[rows-1][0] = tmp[rows-2][1];
	mov r0, r9	// Move the base address
	sub r1, r6, #2	// Move the row address
	mov r2, #1	// Move the column address
	bl read_pix	// Read dat pix
	mov r3, r0	// Move dat pix
	mov r0, r9	// Move dat address
	sub r1, r6, #1	// Move dat row address
	mov r2, #0	// Move dat column 
	bl write_pix 

 	// tmp[rows-1][cols-1] = tmp[rows-2][cols-2]; fix_corners:
	mov r0, r9	// Move the base address
	sub r1, r6, #2	// Move the row address
	sub r2, r7, #2	// Move the column address
	bl read_pix	// Read dat pix
	mov r3, r0	// Move dat pix
	mov r0, r9	// Move dat address
	sub r1, r6, #1	// Move dat row address
	sub r2, r7, #1	// Move dat column 
	bl write_pix 

	mov r4, #0
free_loop:
	
	ldr r0, [r8, #(5*4)]		// Load the image pointer
	ldr r0, [r0, r4, lsl #2]	// Load the row pointer
	bl free
	
	add r4, r4, #1
	cmp r4, r6
	ble free_loop
	
	ldr r0, [r8, #(5*4)]	// Load the image pointer
	bl free			// Free the row pointer

	str r9, [r8, #(5*4)]	// Point image to temp image

	ldmfd	sp!,{r4, r5, r6, r7, r8, r9, r10, r11, lr}
	mov	pc,lr

allocate_space:
        stmfd sp!, {r4, r5, r6, r7, r10, lr}
        /*
                r0: base address to rows array
                r1: number of rows
                r2: number of bytes to allocate
        */
        mov r5, r1      // Move the number of rows to r5
        mov r6, r2      // Move the number of columns to r6
        mov r10, r0     // Move the base address to r10 so we don't mangle
        mov r4, #0      // Initialize counter
alloc_loop:
        //      - For i < num_rows
        mov r0, r6      // Move the number of bytes to allocate into r0
        bl malloc       // Allocate space for the row
        cmp r0, #0      // See if malloc returned NULL
        beq unable_to_allocate  // If we couldn't allocate space, get out!

        // Put the address of row i into the grayscale pointer array
        mov r7, r4, lsl #2
        str r0, [r10, r7]       // Store the row base address in the correct location
        
        // Compare the counter to number of rows
        add r4, r4, #1          // Increment counter
        cmp r4, r5              // Compare counter
        blt alloc_loop  // If we haven't allocated all the rows yet, loop back
        bge successful_mem_alloc        // Return base address to rows array
        
unable_to_allocate:
        ldr r0, =no_mem         // If we couldn't allocate space
        bl perror               // Print the message to the user

successful_mem_alloc:
        mov r0, r10             // Move the base address of the rows array to r0
        ldmfd sp!, {r4, r5, r6, r7, r10, lr}
        mov pc, lr


smooth_pix:
        stmfd sp!, {r4, r5, r6, r7, r8, r9, r10, r11,  lr}

        /*
                passing to smooth_pix
                        r0:     base address to image
                        r1:     base address to temp
                        r2:     rows index
                        r3:     3-pixel columns index

		Other registers used
			r4:	red sum
			r5:	byte mask
			r6:	i index
			r7:	j index
        		r8:	color index
			r9:	green sum
			r10:	blue sum
	*/
		

	// Initialize mask to 0xFF000000
	mov r5, #0xFF000000
	// Initialize color index
	mov r8, #0
	mov r11, r0	// Move the base address so we don't mangle

	ldr r0, =t_row	// Store the temp row
	str r2, [r0]
	ldr r0, =t_col	// Store temp column
	str r3, [r0]	

	// For each color (r,g,b)
	// Set red, blue, green sum = 0
	mov r4, #0
	mov r9, #0
	mov r10, #0

//colorz:
	// Initialize i to -1
	mov r6, #-1
	// 	For( i=-1, i < 2, i++ )
rowz:
	// Initialize j to -1
	mov r7, #-1
	//		For( j=-1, j < 2, j++ )
columnz:
	// sum_of_color += image[i][j].color	
	// - Load the pixel image[i][j]

	ldr r0, =t_row	// Get the row
	ldr r2, [r0]
	ldr r0, =t_col 	// Get the column
	ldr r3, [r0]

	mov r0, r11	// Get the base address of image
	add r1, r2, r6	// Move row index of pixel to read into r1
	add r2, r3, r7	// Move the columns index into r2
	bl read_pix
	// - Add red to red sum (r4)
	and r1, r0, #0xFF0000		// Extract red pixel
	lsr r1, r1, #16			// Shift byte to LSB
	add r4, r4, r1			// Add to red sum	
	// - Add green to green sum (r9)
	and r1, r0, #0xFF00		// Extract green pixel
	lsr r1, r1, #8			// Shift byte to LSB
	add r9, r9, r1			// Add to green sum
	// - Add blue to blue sum (r10)
	and r1, r0, #0xFF		// Extract blue pixel
//	lsr r1, r1, #8			// Shift byte to LSB
	add r10, r10, r1		// Add to blue sum

	add r7, r7, #1
	// Compare j to 2
	cmp r7, #2
	blt columnz

	add r6, r6, #1
	// Compare i to 2
	cmp r6, #2
	blt rowz

//	add r8, r8, #1
	// Compare color index to 3
//	cmp r8, #3
//	blt colorz

	mov r0, r4	// Move red to r0
	bl run_calc	// Do the calculation
	bl crop		// Crop it
	mov r4, r0	// Move back to r4
	
	mov r0, r9	// Move green to r0
	bl run_calc	// Do the calculation
	bl crop		// Crop it
	mov r9, r0	// Move back to r9

	mov r0, r10	// Move blue to r0
	bl run_calc	// Do the calculation
	bl crop		// Crop it
	mov r10, r0	// move it back to r10

	mov r0, #0	// Set r0 to zero
	orr r0, r4, lsl #16	// Get bytes back into word
	orr r0, r9, lsl #8	//
	orr r0, r10, lsl #0	//


        ldmfd sp!, {r4, r5, r6, r7, r8, r9, r10, r11, lr}
        mov pc, lr

write_pix:
	stmfd sp!, { r1, r2, r3, r4, r5, lr}

        /*
                passing to write_pix
                        r0:     base address to image
                        r1:     row index
                        r2:     3-pixel column index
			r3:	pixel to write
        */

        // Get offset into rows array
        mov r4, r1, lsl #2      // 4*row index = offset
        // Load row base address
        ldr r0, [r0, r4]        // Load base address+offset
        // Get column offset into row
        add r4, r2, r2, lsl #1  // 3*column index = offset
//	mov r4, r2, lsl #3 // Shift 4 for debugging
        // Load a word from this address and store in r0
        str r3, [r0, r4]        // Write row_base_address+offset

	ldmfd sp!, { r1, r2, r3, r4, r5, lr}
	mov pc, lr

read_pix:
	stmfd sp!, { r1, r2, r3, r4, r5, lr}

	/*
		passing to get_pix
			r0:	base address to image
			r1:	row index
			r2:	3-pixel column index
	*/

	// Get offset into rows array
	mov r4, r1, lsl #2	// 4*row index = offset
	// Load row base address
	ldr r0, [r0, r4]	// Load base address+offset
	// Get column offset into row
	add r4, r2, r2, lsl #1	// 3*column index = offset
	// Load a word from this address and store in r0
	ldr r0, [r0, r4]	// Load row_base_address+offset

	ldmfd sp!, { r1, r2, r3, r4, r5, lr}
	mov pc, lr

run_calc:
	
	stmfd sp!, {r4, r5, lr}
	/*
		passing to run_calc
			r0:	sum of a color


	*/
	
	add r0, r0, r0, lsl #2	// get r0 * 5
	lsl r0, #1		// get 2*(r0*5) = r0*10
	add r0, #45		// Add 45
	mov r1, #90		
	bl divide
		
	ldmfd sp!, {r4, r5, lr}
	mov pc, lr
