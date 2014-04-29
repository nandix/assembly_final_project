
	.data
msg:    .asciz "Rows: %d \nCols: %d \n"
        .align 2

no_mem:  // Message if we couldn't allocate space for the temporary image 
        .asciz "Unable to allocate memory for temporary image\n"        
        .align 2

	
	.text
	.global smoothImage
smoothImage:
	stmfd	sp!,{r4, r5, r6, r7, r8, r9, r10, r11, lr}

	mov r8, r0              // Move the base image address to r8 (don't mangle)

        //X get rows (shifted 12 bytes from base address)
        ldr r6, [r8 , #12]      // Load rows from the image struct

        //X get columns (shifted 16 bytes from base address)
        ldr r7, [r8, #16]       // Load columns from image struct
	
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
        add r0, r7, r7, lsl #1	// get the number of bytes to allocate
	mov r2, r7     		// put the number of bytes (3*(3-pixels)) in r2

        bl allocate_space
        mov r9, r0      // put the base address to grayscale in r9

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
	ldr r0, [r8, #(5*4)]	// Load the base address to image
	mov r1, r9		// Move the base address to temp
	mov r2, r4		// Move the current row index
	mov r3, r5		// Move the current column index
        bl smooth_pix     	// Grayscale an individual 3-pixel

	// 		store smoothed pixel at index i, j
        //      Write word to memory
        //      - Use address base+offset_in_bytes
	// Call write_pix
	/*
		passing to write_pix
			r0:	word containing 3-pixel to write
			r1:	row index to write to
			r2:	column index to write to
			r3:	base address of temp
	*/
	
        strb r0, [r11, r5]      // Store the grayscale value to memory

        //      Increment j
        add r5, r5, #1

	sub r0, r7, #1		// Get cols-1 to compare
        cmp r5, r0              // Compare j to 3-pixel columns
        blt col_loop            // If j >= cols, go to row_loop


        // Increment i
        add r4, r4, #1
        // Compare and go back to row loop
	sub r0, r6, #1
        cmp r4, r6

        blt row_loop



	// ----------------- FIX FIRST AND LAST COL (except corners) -----
	// For( all rows except first and last )
	// - for( i=1 (not zero); i < rows-1; i++ )
	// 	Fix the columns j = 0 and j = cols-1 
	
	// ----------------- FIX FIRST AND LAST ROW (except corners) -----
	// For( all columns except first and last )
	// - for( i=1 (not zero); i < cols-1; i++ )
	// 	Fix the rows j=0 and j=rows-1

	// ----------------- FIX CORNERS ---------------------------------
	// corners equal same as diagonal inward
	// tmp[0][0] = tmp[1][1];
	// tmp[0][image->cols-1] = tmp[1][image->cols-2];
 	// tmp[rows-1][0] = tmp[rows-2][1];
 	// tmp[rows-1][cols-1] = tmp[rows-2][cols-2];


	ldmfd	sp!,{r4, r5, r6, r7, r8, r9, r10, r11, lr}
	mov	pc,lr

allocate_space:
        stmfd sp!, {r4, r5, r6, r7, r10, lr}
        /*
                r0: base address to rows array
                r1: number of rows
                r2: number of columns
        */
        mov r5, r1      // Move the number of rows to r5
        mov r6, r2      // Move the number of columns to r6
        mov r10, r0     // Move the base address to r10 so we don't mangle
        mov r4, #0      // Initialize counter
alloc_loop:
        //      - For i < num_rows
        mov r0, r6      // Move the number of columns (number of bytes to allocate) into r0
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
        stmfd sp!, {r4, r5, r6, r7, lr}

        /*
                passing to smooth_pix
                        r0:     base address to image
                        r1:     base address to temp
                        r2:     rows index
                        r3:     3-pixel columns index
        */
		

	// For each color (r,g,b)
	// Set sum = 0
	// 	For( i=-1, i < 2, i++ )
	//		For( j=-1, j < 2, j++ )
	//	

        ldmfd sp!, {r4, r5, r6, r7, lr}
        mov pc, lr

write_pix:
	stmfd sp!, {lr}

	ldmfd sp!, {lr}
	mov pc, lr

get_pix:
	stmfd sp!, {lr}

	/*
		passing to get_pix
	`		r0:	base address to image
			r1:	row index
			r2:	3-pixel column index
	*/

	ldmfd sp!, {lr}
	mov pc, lr

