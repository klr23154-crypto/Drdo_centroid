module centroid_top #(
    parameter THRESHOLD = 8'd119
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output reg  [9:0] centroid_x,
    output reg  [9:0] centroid_y,
    output reg        object_found,
    output reg        pipeline_done
);
    localparam IMG_WIDTH = 256;
    localparam N_PIXELS  = 65536;

    
    reg  [9:0] ram_row, ram_col;
    reg        ram_we, ram_re;
    reg  [7:0] ram_din;
    wire [7:0] ram_dout;

    single_port_ram u_ram (
        .clk      (clk),
        .we       (ram_we),
        .re       (ram_re),
        .row_addr (ram_row),
        .col_addr (ram_col),
        .data_in  (ram_din),
        .data_out (ram_dout)
    );


    reg         div_start;
    reg  [24:0] div_dividend;
    reg  [17:0] div_divisor;
    wire [24:0] div_quotient;
    wire [17:0] div_remainder;
    wire        div_valid;
    wire        div_dbz;

    restoring_divider25 u_div (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (div_start),
        .dividend    (div_dividend),
        .divisor     (div_divisor),
        .quotient    (div_quotient),
        .remainder   (div_remainder),
        .valid       (div_valid),
        .div_by_zero (div_dbz)
    );

    
    reg [24:0] sum_x;   
    reg [24:0] sum_y;
    reg [17:0] count;   

    localparam S_IDLE     = 3'd0;
    localparam S_PRELOAD  = 3'd1;
    localparam S_SCAN     = 3'd2;
    localparam S_FINALIZE = 3'd3;
    localparam S_DIV_X    = 3'd4;
    localparam S_DIV_Y    = 3'd5;
    localparam S_DONE     = 3'd6;

    reg [2:0]  state;
    reg [17:0] pix_cnt;
    reg [9:0]  cur_row, cur_col;

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            ram_we        <= 1'b0;
            ram_re        <= 1'b0;
            ram_row       <= 10'd0;
            ram_col       <= 10'd0;
            ram_din       <= 8'd0;
            pix_cnt       <= 18'd0;
            cur_row       <= 10'd0;
            cur_col       <= 10'd0;
            sum_x         <= 25'd0;
            sum_y         <= 25'd0;
            count         <= 18'd0;
            div_start     <= 1'b0;
            div_dividend  <= 25'd0;
            div_divisor   <= 18'd0;
            centroid_x    <= 10'd0;
            centroid_y    <= 10'd0;
            object_found  <= 1'b0;
            pipeline_done <= 1'b0;
        end else begin
            ram_we    <= 1'b0;
            ram_re    <= 1'b0;
            div_start <= 1'b0;

            case (state)

                S_IDLE: begin
                    pipeline_done <= 1'b0;
                    if (start) begin
                        pix_cnt <= 18'd0;
                        cur_row <= 10'd0;
                        cur_col <= 10'd0;
                        sum_x   <= 25'd0;
                        sum_y   <= 25'd0;
                        count   <= 18'd0;
                        ram_row <= 10'd0;
                        ram_col <= 10'd0;
                        state   <= S_PRELOAD;
                    end
                end

                S_PRELOAD: begin
               
                    state <= S_SCAN;
                end

                S_SCAN: begin
                    
                    if (ram_dout < THRESHOLD) begin
                        sum_x <= sum_x + cur_col;
                        sum_y <= sum_y + cur_row;
                        count <= count + 18'd1;
                    end

                  
                    if (cur_col == (IMG_WIDTH - 1)) begin
                        cur_col <= 10'd0;
                        cur_row <= cur_row + 10'd1;
                        ram_col <= 10'd0;
                        ram_row <= cur_row + 10'd1;
                    end else begin
                        cur_col <= cur_col + 10'd1;
                        ram_col <= cur_col + 10'd1;
                        ram_row <= cur_row;
                    end

                    pix_cnt <= pix_cnt + 18'd1;

                    if (pix_cnt == (N_PIXELS - 1))
                        state <= S_FINALIZE;
                end

                S_FINALIZE: begin
                    
                    if (count == 18'd0) begin
                        object_found  <= 1'b0;
                        centroid_x    <= 10'd0;
                        centroid_y    <= 10'd0;
                        pipeline_done <= 1'b1;
                        state         <= S_DONE;
                    end else begin
                        object_found <= 1'b1;
                        div_dividend <= sum_x;
                        div_divisor  <= count;
                        div_start    <= 1'b1;
                        state        <= S_DIV_X;
                    end
                end

                S_DIV_X: begin
                    if (div_valid) begin
                        centroid_x   <= div_quotient[9:0];
                        div_dividend <= sum_y;
                        div_divisor  <= count;
                        div_start    <= 1'b1;
                        state        <= S_DIV_Y;
                    end
                end

                S_DIV_Y: begin
                    if (div_valid) begin
                        centroid_y    <= div_quotient[9:0];
                        pipeline_done <= 1'b1;
                        state         <= S_DONE;
                    end
                end

                S_DONE: begin
                    
                end

            endcase
        end
    end
endmodule
