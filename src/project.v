/*
 * Tiny Turing Machine - ASIC Implementation for Tiny Tapeout
 * 
 * Features:
 * - 8-bit tape with configurable wrap-around
 * - 4 states, binary alphabet
 * - 4 STT banks (3 presets + 1 custom)
 * - Manual STT configuration
 * - Loop mode with auto-restart
 * - Flexible output routing
 * 
 * TAPE CONVENTION: Bit 7 = LEFTMOST position, Bit 0 = RIGHTMOST position
 *                  Visual: [7][6][5][4][3][2][1][0]
 *                  Head position 0 = leftmost, 7 = rightmost
 */

module tt_um_chrimenz_tinyturing (
    input  wire [7:0] ui_in,    // Dedicated inputs (multifunctional)
    output wire [7:0] uo_out,   // Dedicated outputs (tape or status)
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (status or tape)
    output wire [7:0] uio_oe,   // IOs: Enable path (always output)
    input  wire       ena,      // Design enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Active-low reset
);

    // ========================================================================
    // Parameters & Constants
    // ========================================================================
    
    localparam TAPE_SIZE = 8;
    localparam HEAD_POS_WIDTH = 3;
    localparam STATE_WIDTH = 2;
    localparam ALPHABET_WIDTH = 1;
    localparam MOVE_DIR_WIDTH = 1;
    
    localparam STT_ADDR_WIDTH = STATE_WIDTH + ALPHABET_WIDTH; // 3 bits (0-7)
    localparam STT_DATA_WIDTH = STATE_WIDTH + ALPHABET_WIDTH + MOVE_DIR_WIDTH; // 4 bits
    localparam STT_LEN = 1 << STT_ADDR_WIDTH; // 8 entries
    localparam STT_NUM_BANKS = 4;

    // Move directions
    localparam MOVE_LEFT  = 1'b0;
    localparam MOVE_RIGHT = 1'b1;

    // Operating modes
    localparam MODE_WIDTH = 3;
    localparam [MODE_WIDTH-1:0] 
        MODE_INIT_STT  = 3'd0,
        MODE_INIT_TAPE = 3'd1,
        MODE_INIT_HEAD = 3'd2,
        MODE_RUN       = 3'd3,
        MODE_HALT      = 3'd4;

    // ========================================================================
    // STT Presets (Bank 0-2)
    // ========================================================================
    
    // Preset 0: Unary Incrementer
    // Adds 1 to a unary number (string of 1s)
    // State 0: Scan right until 0, State 1: Write 1 and halt
    localparam [STT_DATA_WIDTH*STT_LEN-1:0] STT_PRESET_0 = {
        4'b0001,  // [0] S0,0 → S0,0,R (blank,continue right)
        4'b0111,  // [1] S0,1 → S1,1,R (1, write 1, go right)
        4'b0011,  // [2] S1,0 → S0,1,R (found blank, write 1, go right)
        4'b0111,  // [3] S1,1 → S1,1,R (try to find blank, continue)
        4'b0000,  // [4] S2,0 → (unused)
        4'b0000,  // [5] S2,1 → (unused)
        4'b0000,  // [6] S3,0 → (unused)
        4'b0000   // [7] S3,1 → (unused)
    };
    
    // Preset 1: Flip Bits
    // Flips bits from left to right until halted
    localparam [STT_DATA_WIDTH*STT_LEN-1:0] STT_PRESET_1 = {
        4'b0011,  // [0] S0,0 → S0,1,R (flip 0→1, go right)
        4'b0001,  // [1] S0,1 → S0,0,R (flip 1→0, go right)
        4'b0000,  // [2] S1,0 → S0,1,R (found blank, write 1, go right)
        4'b0000,  // [3] S1,1 → S1,1,R (try to find blank, continue)
        4'b0000,  // [4] S2,0 → (unused)
        4'b0000,  // [5] S2,1 → (unused)
        4'b0000,  // [6] S3,0 → (unused)
        4'b0000   // [7] S3,1 → (unused)
    };
    
    // Preset 2: Wally
    // go right until a 1 is found, change it to 0, go left until a one is found, place a 1 right of it, repeat
    localparam [STT_DATA_WIDTH*STT_LEN-1:0] STT_PRESET_2 = {
        4'b0001,  // [7] S0,1 → S2,0,R (write 0, switch state) search for next 1
        4'b0100,  // [6] S0,0 → S1,1,R (write 1, switch state) found a 1 turn around
        4'b0100,  // [5] S1,1 → S2,0,R (write 0, switch state) found zero
        4'b1011,  // [4] S1,0 → S1,1,R (write 1, stay)
        4'b0011,  // [3] S2,1 → S1,1,R (write 1, switch state)
        4'b1011,  // [2] S2,0 → S2,0,R (write 0, stay)
        4'b0000,  // [1] S3,1 → (unused)
        4'b0000   // [0] S3,0 → (unused)
    };

    // Preset initial tapes
    // Tape convention: Bit 7 = LEFT, Bit 0 = RIGHT
    // Visual display: [7][6][5][4][3][2][1][0]
    // Head position: 0=leftmost, 7=rightmost
    localparam [TAPE_SIZE-1:0] PRESET_TAPE_0 = 8'b11100000; // Three 1s on the LEFT (bit positions 7,6,5)
    localparam [TAPE_SIZE-1:0] PRESET_TAPE_1 = 8'b01011010; // Binary 15 on the LEFT (bit positions 7-4)
    localparam [TAPE_SIZE-1:0] PRESET_TAPE_2 = 8'b10001011; // Blank for pattern

    // Preset initial positions
    localparam [HEAD_POS_WIDTH-1:0] PRESET_HEAD_0 = 3'd0; // Start at leftmost (position 0, bit 7)
    localparam [HEAD_POS_WIDTH-1:0] PRESET_HEAD_1 = 3'd0; // Start at rightmost for counter (position 7, bit 0)
    localparam [HEAD_POS_WIDTH-1:0] PRESET_HEAD_2 = 3'd2; // Start at leftmost (position 0, bit 7)

    // Preset initial states
    localparam [STATE_WIDTH-1:0] PRESET_STATE_0 = 2'd0;
    localparam [STATE_WIDTH-1:0] PRESET_STATE_1 = 2'd0;
    localparam [STATE_WIDTH-1:0] PRESET_STATE_2 = 2'd0;

    // ========================================================================
    // State Registers
    // ========================================================================
    
    reg [TAPE_SIZE-1:0] tape;
    reg [HEAD_POS_WIDTH-1:0] headpos;
    reg [STATE_WIDTH-1:0] state;
    reg [MODE_WIDTH-1:0] mode;

    // Loop restart values
    reg [TAPE_SIZE-1:0] initial_tape;
    reg [HEAD_POS_WIDTH-1:0] initial_headpos;
    reg [STATE_WIDTH-1:0] initial_state;
    reg [1:0] initial_bank; // Remember which STT bank to use

    // STT memory: [address][bank]
    reg [STT_DATA_WIDTH-1:0] stt_mem [0:STT_LEN-1][0:STT_NUM_BANKS-1];

    // Flag to track if initial values have been saved
    reg initial_saved;

    // ========================================================================
    // Tape Access Helper - Maps head position to bit index
    // ========================================================================
    // Head position 0 = leftmost  = bit 7
    // Head position 1 = bit 6
    // ...
    // Head position 7 = rightmost = bit 0
    
    wire [2:0] tape_bit_index;
    assign tape_bit_index = 3'd7 - headpos;  // Invert: pos 0→bit7, pos 7→bit0

    // ========================================================================
    // STT Lookup Wires
    // ========================================================================
    
    wire [STT_ADDR_WIDTH-1:0] stt_addr;
    wire [1:0] stt_bank_sel;
    wire [STT_DATA_WIDTH-1:0] stt_entry;
    wire [STATE_WIDTH-1:0] next_state;
    wire write_symbol;
    wire move_dir;
    wire current_symbol;

    // Select STT bank based on mode and ui_in
    assign stt_bank_sel = (mode == MODE_INIT_STT) ? 2'd3 : 
                          (mode == MODE_RUN || mode == MODE_HALT) ? ui_in[6:5] : 
                          initial_bank;
    
    // Build STT address from current state and symbol
    assign current_symbol = tape[tape_bit_index];
    assign stt_addr = {state, current_symbol};
    assign stt_entry = stt_mem[stt_addr][stt_bank_sel];
    
    // Parse STT entry: {next_state[1:0], write_symbol[0], move_dir[0]}
    assign next_state = stt_entry[3:2];
    assign write_symbol = stt_entry[1];
    assign move_dir = stt_entry[0];

    // ========================================================================
    // Output Routing (Combinational)
    // ========================================================================
    
    wire output_swap;
    assign output_swap = (mode == MODE_RUN || mode == MODE_HALT) ? ui_in[2] : 1'b0;

    // Status signals
    wire [2:0] status_headpos;
    wire [1:0] status_state;
    wire [2:0] status_mode;
    
    assign status_headpos = headpos;
    assign status_state = state;
    assign status_mode = mode;

    // Output multiplexing based on swap bit
    assign uo_out = output_swap ? {status_mode, status_state, status_headpos} : tape;
    assign uio_out = output_swap ? tape : {status_mode, status_state, status_headpos};
    
    // UIO pins always configured as outputs
    assign uio_oe = 8'hFF;

    // ========================================================================
    // Main State Machine
    // ========================================================================
    
    always @(posedge clk) begin
        if (~rst_n) begin
            // ================================================================
            // Reset Logic - FIXED: No tasks, explicit assignments
            // ================================================================
            
            // Clear registers
            headpos <= {HEAD_POS_WIDTH{1'b0}};
            state <= {STATE_WIDTH{1'b0}};
            initial_saved <= 1'b0;
            initial_bank <= 2'd0;
            
            // Load STT Preset 0 into Bank 0 (unrolled for synthesis)
            stt_mem[0][0] <= STT_PRESET_0[31:28];
            stt_mem[1][0] <= STT_PRESET_0[27:24];
            stt_mem[2][0] <= STT_PRESET_0[23:20];
            stt_mem[3][0] <= STT_PRESET_0[19:16];
            stt_mem[4][0] <= STT_PRESET_0[15:12];
            stt_mem[5][0] <= STT_PRESET_0[11:8];
            stt_mem[6][0] <= STT_PRESET_0[7:4];
            stt_mem[7][0] <= STT_PRESET_0[3:0];
            
            // Load STT Preset 1 into Bank 1
            stt_mem[0][1] <= STT_PRESET_1[31:28];
            stt_mem[1][1] <= STT_PRESET_1[27:24];
            stt_mem[2][1] <= STT_PRESET_1[23:20];
            stt_mem[3][1] <= STT_PRESET_1[19:16];
            stt_mem[4][1] <= STT_PRESET_1[15:12];
            stt_mem[5][1] <= STT_PRESET_1[11:8];
            stt_mem[6][1] <= STT_PRESET_1[7:4];
            stt_mem[7][1] <= STT_PRESET_1[3:0];
            
            // Load STT Preset 2 into Bank 2
            stt_mem[0][2] <= STT_PRESET_2[31:28];
            stt_mem[1][2] <= STT_PRESET_2[27:24];
            stt_mem[2][2] <= STT_PRESET_2[23:20];
            stt_mem[3][2] <= STT_PRESET_2[19:16];
            stt_mem[4][2] <= STT_PRESET_2[15:12];
            stt_mem[5][2] <= STT_PRESET_2[11:8];
            stt_mem[6][2] <= STT_PRESET_2[7:4];
            stt_mem[7][2] <= STT_PRESET_2[3:0];
            
            // Determine mode based on ui_in[7]
            if (ui_in[7]) begin
                // Manual mode: Start STT configuration
                mode <= MODE_INIT_STT;
                tape <= {TAPE_SIZE{1'b0}};
            end else begin
                // Automatic mode
                initial_bank <= ui_in[6:5];
                
                if (ui_in[1]) begin
                    // Manual tape initialization requested
                    mode <= MODE_INIT_TAPE;
                    tape <= {TAPE_SIZE{1'b0}};
                end else begin
                    // Use preset tape/head/state
                    case (ui_in[6:5])
                        2'b00: begin
                            tape <= PRESET_TAPE_0;
                            headpos <= PRESET_HEAD_0;
                            state <= PRESET_STATE_0;
                        end
                        2'b01: begin
                            tape <= PRESET_TAPE_1;
                            headpos <= PRESET_HEAD_1;
                            state <= PRESET_STATE_1;
                        end
                        2'b10: begin
                            tape <= PRESET_TAPE_2;
                            headpos <= PRESET_HEAD_2;
                            state <= PRESET_STATE_2;
                        end
                        2'b11: begin
                            // Custom program - use zeros as default TODO: better default or reload last? 
                            tape <= {TAPE_SIZE{1'b0}};
                            headpos <= {HEAD_POS_WIDTH{1'b0}};
                            state <= {STATE_WIDTH{1'b0}};
                        end
                    endcase
                    mode <= MODE_RUN;
                end
            end
            
        end else begin
            // ================================================================
            // State Machine Logic
            // ================================================================
            
            case (mode)
                // ============================================================
                // MODE_INIT_STT: Custom STT Configuration
                // ============================================================
                MODE_INIT_STT: begin
                    if (ui_in[7]) begin
                        // Write STT entry to bank 3 (custom)
                        stt_mem[ui_in[6:4]][3] <= ui_in[3:0];
                    end else begin
                        // Configuration complete, move to tape init
                        mode <= MODE_INIT_TAPE;
                    end
                end
                
                // ============================================================
                // MODE_INIT_TAPE: Manual Tape Initialization
                // ============================================================
                MODE_INIT_TAPE: begin
                    // Write ui_in directly to tape
                    tape <= ui_in;
                    mode <= MODE_INIT_HEAD;
                end
                
                // ============================================================
                // MODE_INIT_HEAD: Manual Head/State Initialization
                // ============================================================
                MODE_INIT_HEAD: begin
                    headpos <= ui_in[2:0];      // Bits [2:0]
                    state <= ui_in[4:3];        // Bits [4:3]
                    mode <= MODE_RUN;
                    initial_saved <= 1'b0;      // Will save on first RUN cycle
                end
                
                // ============================================================
                // MODE_RUN: Execute Turing Machine
                // ============================================================
                MODE_RUN: begin
                    // Save initial state on first run cycle for loop restart
                    if (~initial_saved) begin
                        initial_tape <= tape;
                        initial_headpos <= headpos;
                        initial_state <= state;
                        initial_saved <= 1'b1;
                    end
                    
                    // Execute STT step: write to tape at current head position
                    tape[tape_bit_index] <= write_symbol;
                    state <= next_state;
                    
                    // Move head with wrap/halt logic
                    // Remember: headpos 0=left, 7=right
                    // MOVE_LEFT decreases headpos, MOVE_RIGHT increases headpos
                    if (move_dir == MOVE_LEFT) begin
                        if (headpos == 3'd0) begin
                            // At leftmost position
                            if (ui_in[3]) begin
                                // Wrap enabled: jump to right
                                headpos <= 3'd7;
                            end else begin
                                // Wrap disabled: halt
                                mode <= MODE_HALT;
                            end
                        end else begin
                            // Normal move left (decrease position)
                            headpos <= headpos - 3'd1;
                        end
                    end else begin // MOVE_RIGHT
                        if (headpos == 3'd7) begin
                            // At rightmost position
                            if (ui_in[3]) begin
                                // Wrap enabled: jump to left
                                headpos <= 3'd0;
                            end else begin
                                // Wrap disabled: halt
                                mode <= MODE_HALT;
                            end
                        end else begin
                            // Normal move right (increase position)
                            headpos <= headpos + 3'd1;
                        end
                    end
                end
                
                // ============================================================
                // MODE_HALT: Machine Halted
                // ============================================================
                MODE_HALT: begin
                    // Check if loop mode is enabled
                    if (ui_in[4]) begin
                        // Loop mode: restart with initial values
                        tape <= initial_tape;
                        headpos <= initial_headpos;
                        state <= initial_state;
                        mode <= MODE_RUN;
                        // Keep initial_saved = 1, don't re-save
                    end
                    // Otherwise stay in HALT (single-run mode)
                end
                
                // ============================================================
                // Default: Should never reach here
                // ============================================================
                default: begin
                    mode <= MODE_HALT;
                end
            endcase
        end
    end

    wire _unused = &{ena, uio_in[7:0], 1'b0};

endmodule