module AudRecorder(
	input i_rst_n,
	input i_clk,
	input i_lrc,
	input i_start,
	input i_pause,
	input i_stop,
	input i_data,
	output [19:0] o_address,
	output [15:0] o_data,

    output [19:0] o_stop_address // *** to give stop point

);

localparam S_IDLE = 0;
localparam S_PAUS = 1;
localparam S_WAIT = 2;
localparam S_SAVE = 3;

logic [ 1:0] state_w, state_r;
logic        lrc_w, lrc_r;
logic [ 4:0] counter_w, counter_r;
logic [19:0] o_address_w, o_address_r;
logic [15:0] o_data_w, o_data_r;

assign lrc_w = i_lrc; // does the rising moment really matter?

assign o_address = o_address_r;
assign o_data = o_data_r;

assign o_stop_address = o_address_r;

always_comb begin

    // dafault
    state_w = state_r;
    counter_w = counter_r;
    o_address_w = o_address_r;
    o_data_w = o_data_r;

    case(state_r)
        S_IDLE: begin
            if (i_start) begin
                state_w = S_WAIT;
                // o_address_w = 0;
                o_address_w = o_address_r; // *** to give stop address, if want to reset sram, just press rst_n
            end
            else begin
                state_w = state_r;
                o_address_w = o_address_r;
            end
            counter_w = 0;
            o_data_w = 0;
        end
        S_PAUS: begin
            if (i_stop) begin
                state_w = S_IDLE;
            end
            else if (i_start) begin
                state_w = S_WAIT;
            end
            else begin
                state_w = state_r;
            end
            counter_w = 0;
            o_address_w = o_address_r;
            // o_data_w = 0;
            // o_data_w = o_data_r; // *** maybe 1 cycle is not enough to save into SRAM?
            o_data_w = 0;
        end
        S_WAIT: begin
            if (i_stop) begin
                state_w = S_IDLE;
            end
            else if (i_pause) begin
                state_w = S_PAUS;
            end
            else if ( (lrc_r == 0)&(i_lrc == 1) ) begin
                state_w = S_SAVE;
            end
            else begin
                state_w = state_r;
            end
            counter_w = 0;
            o_address_w = o_address_r;
            // o_data_w = 0;
            // o_data_w = o_data_r; // ***
            o_data_w = 0;
        end
        S_SAVE: begin
            if (i_stop) begin
                state_w = S_IDLE;
                counter_w = 0;
                o_address_w = o_address_r;
                o_data_w = 0;
                // o_data_w = o_data_r; // ***
            end
            else if (i_pause) begin
                state_w = S_PAUS;
                counter_w = 0;
                o_address_w = o_address_r;
                o_data_w = 0;
                // o_data_w = o_data_r; // ***
            end
            else if (!i_lrc) begin
                state_w = S_PAUS;
                counter_w = 0;
                o_address_w = o_address_r + 1;
                // o_data_w = 0;
                o_data_w = o_data_r; // ***
            end
            else if (counter_r < 5'd16) begin
                state_w = state_r;
                counter_w = counter_r + 1;
                o_address_w = o_address_r;
                o_data_w[15:1] = o_data_r[14:0];
                o_data_w[ 0:0] = i_data;
            end
            else begin
                state_w = state_r;
                counter_w = counter_r;
                o_address_w = o_address_r;
                o_data_w = o_data_r;
            end
        end
        default: begin
            state_w = state_r;
            counter_w = counter_r;
            o_address_w = o_address_r;
            o_data_w = o_data_r;
        end
    endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r <= S_IDLE;
        counter_r <= 0;
        lrc_r <= 0;
        o_address_r <= 0; // will first store in 1?
        o_data_r <= 0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        lrc_r <= lrc_w;
        o_address_r <= o_address_w;
        o_data_r <= o_data_w;
    end
end


endmodule