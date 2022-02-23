module AudPlayer(
    input i_rst_n,
    input i_bclk,
    input i_daclrck,
    input i_en,
    input signed [15:0] i_dac_data,
    output o_aud_dacdat
);

localparam S_IDLE = 0;
localparam S_EN   = 1;
localparam S_PLAY = 2;
localparam S_WAIT = 3;

logic [ 1:0] state_w, state_r;
logic [ 3:0] counter_w, counter_r;
logic        o_aud_dacdat_w, o_aud_dacdat_r;
logic [15:0] dac_data_w, dac_data_r;
logic        delay_o_aud_dacdat_w, delay_o_aud_dacdat_r;

assign o_aud_dacdat = o_aud_dacdat_w;

always_comb begin

    // default 
    state_w = state_r;
    counter_w = counter_r;
    o_aud_dacdat_w = o_aud_dacdat_r;
    dac_data_w = dac_data_r;

    case(state_r)
        S_IDLE: begin
            if (i_en) begin 
                state_w = S_EN;
                counter_w = counter_r;
                o_aud_dacdat_w = o_aud_dacdat_r;
                dac_data_w = i_dac_data;
            end
            else begin
                state_w = state_r;
                counter_w = counter_r;
                o_aud_dacdat_w = o_aud_dacdat_r;
                dac_data_w = dac_data_r;
            end
        end
        S_EN: begin
            if (!i_daclrck) begin
                state_w = S_PLAY;
                counter_w = counter_r - 1;
                o_aud_dacdat_w = i_dac_data[counter_r];
                dac_data_w = dac_data_r;
            end
            else begin
                state_w = state_r;
                counter_w = counter_r;
                o_aud_dacdat_w = o_aud_dacdat_r;
                dac_data_w = dac_data_r;
            end
        end
        S_PLAY: begin
            if (counter_r == 0) begin
                state_w = S_WAIT;
                counter_w = 4'd15; 
            end
            else begin
                state_w = state_r;
                counter_w = counter_r - 1;
            end
            o_aud_dacdat_w = i_dac_data[counter_r];
            dac_data_w = dac_data_r;
        end
        S_WAIT: begin
            state_w = (i_daclrck) ? S_IDLE : state_r;
            counter_w = counter_r;
            o_aud_dacdat_w = o_aud_dacdat_r;
            dac_data_w = 0;
        end
        default: begin
            state_w = state_r;
            counter_w = counter_r;
            o_aud_dacdat_w = o_aud_dacdat_r;
            dac_data_w = dac_data_r;
        end
    endcase
end

always_ff @(posedge i_bclk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r <= S_IDLE;
        counter_r <= 4'd15;
        o_aud_dacdat_r <= 0;
        dac_data_r <= 0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        o_aud_dacdat_r <= o_aud_dacdat_w;
        dac_data_r <= dac_data_w;
    end
end


endmodule