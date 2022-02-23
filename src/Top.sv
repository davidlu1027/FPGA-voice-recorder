module Top (
	input i_rst_n,
	input i_clk, // 12MHz
	input i_key_0,//
	input i_key_1,
    input i_key_2,
	input [2:0] i_speed, // design how user can decide mode on your own
    input i_fast,
    input i_slow_1,
	input i_reverse,
	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	output [5:0] state_seven,
	input i_50M_clk,
	output [5:0] o_showtime
	//output [5:0] o_play_time,

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	// output  [8:0] o_ledg,
	// output [17:0] o_ledr
);

// design the FSM and states as you like
parameter S_IDLE       = 0;
parameter S_WAIT       = 1;
parameter S_RECD       = 2;
parameter S_RECD_PAUSE = 3;
parameter S_PLAY       = 4;
parameter S_PLAY_PAUSE = 5;

logic i2c_oen, i2c_sdat;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;

logic [3:0]state_r, state_w;
// logic fast_w, fast_r; // ***
// logic slow_1; // ***
// logic [ 2:0] speed; // ***


logic ini_finish;
logic dsp_finish;



assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign state_seven=state_r;

assign o_SRAM_WE_N = (state_r == S_RECD) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

// *** ------------------------------------------------ *** //

logic player_en;
// assign player_en = (state == S_PLAY) ? 1 : 0;
logic [3:0]ini_state;

logic recorder_start, recorder_pause, recorder_stop;
assign recorder_start = (state_r == S_RECD) ? 1 : 0;
assign recorder_pause = (state_r == S_RECD_PAUSE) ? 1 : 0; // *** delay one cycle???
assign recorder_stop  = (state_r == S_WAIT) ? 1 : 0;

logic dsp_start, dsp_pause, dsp_stop;
assign dsp_start = (state_r == S_PLAY) ? 1 : 0;
assign dsp_pause = (state_r == S_PLAY_PAUSE) ? 1 : 0; // *** delay one cycle???
assign dsp_stop  = (state_r == S_WAIT) ? 1 : 0;

logic [19:0] record_stopaddr;
logic [30:0] time_counter_w, time_counter_r;
logic [ 5:0] showtime_w, showtime_r;
logic [ 5:0] slow_counter_w, slow_counter_r;
assign o_showtime = showtime_r;

always_comb begin

	time_counter_w = time_counter_r;
	showtime_w = showtime_r;
	slow_counter_w = slow_counter_r;

	case(state_r)
		S_IDLE: begin
			time_counter_w = 0;
			showtime_w = 0;
			slow_counter_w = 0;
		end
		S_WAIT: begin
			time_counter_w = 0;
			showtime_w = 0;
			slow_counter_w = 0;
		end
		S_RECD: begin
			if (time_counter_r < 30'd50000000) begin
				time_counter_w = time_counter_r + 1;
				showtime_w = showtime_r;
				slow_counter_w = 0;
			end
			else begin
				time_counter_w = 0;
				showtime_w = showtime_r + 1;
				slow_counter_w = 0;
			end
		end
		S_PLAY: begin
			if (!i_fast) begin // slow or normal
				if (time_counter_r < 30'd50000000) begin
					time_counter_w = time_counter_r + 1;
					slow_counter_w = slow_counter_r;
					showtime_w = showtime_r;
				end
				else begin
					time_counter_w = 0;
					if (slow_counter_r == i_speed) begin
						showtime_w = showtime_r + 1;
						slow_counter_w = 0;
					end
					else begin
						showtime_w = showtime_r;
						slow_counter_w = slow_counter_r + 1;
					end
				end
			end
			else begin // fast
				if (time_counter_r < 30'd50000000) begin
					time_counter_w = time_counter_r + 1 + i_speed;
					showtime_w = showtime_r;
				end
				else begin
					time_counter_w = 0;
					showtime_w = showtime_r + 1;
				end
			end
		end
		default: begin
			time_counter_w = time_counter_r;
			showtime_w = showtime_r;
			slow_counter_w = slow_counter_r;
		end
	endcase
end

always_ff @(posedge i_50M_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		time_counter_r <= 0;
		showtime_r <= 0;
		slow_counter_r <= 0;
	end
	else begin
		time_counter_r <= time_counter_w;
		showtime_r <= showtime_w;
		slow_counter_r <= slow_counter_w;
	end
end

// *** ------------------------------------------------ *** //

// assign fast_w = (i_fast == 0) ? fast_r : i_fast;

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(1),
	.o_finished(ini_finish),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
	//.o_init_state(ini_state)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_AUD_BCLK),
	.i_start(dsp_start), // ***
	.i_pause(dsp_pause), // ***
	.i_stop(dsp_stop), // ***
	.i_speed(i_speed),
	.i_fast(i_fast),
	.i_slow_0(0), // constant interpolation
	.i_slow_1(i_slow_1), // linear interpolation
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play),
	.i_sram_stop(record_stopaddr),
	.i_reverse(i_reverse),
	.o_finish(dsp_finish),
	.o_player_en(player_en)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(state_r == S_PLAY), // *** enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(recorder_start), // ***
	.i_pause(recorder_pause), // ***
	.i_stop(recorder_stop), // ***
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_stop_address(record_stopaddr),//
	.o_data(data_record)
);


// *** ----------------------------------------------- *** //
always_comb begin
	case(state_r)
      S_IDLE:begin
          state_w=(ini_finish)?S_WAIT:S_IDLE;
      end
      S_WAIT:begin
          if(i_key_0)begin
              state_w=S_RECD;
          end
          else if (i_key_1)begin
              state_w=S_PLAY;
          end
          else begin
              state_w=S_WAIT;
          end
      end
      S_RECD:begin
          if(i_key_0)begin
              state_w=S_RECD_PAUSE;
          end
          else if (i_key_2)begin
              state_w=S_WAIT;
          end
          else begin
              state_w=S_RECD;
          end
      end
      S_RECD_PAUSE:begin
          if(i_key_0)begin
              state_w=S_RECD;
          end
          else if (i_key_2)begin
              state_w=S_WAIT;
          end
          else begin
              state_w=S_RECD_PAUSE;
          end
      end
      S_PLAY:begin
          if(i_key_1)begin
              state_w=S_PLAY_PAUSE;
          end
          else if (i_key_2)begin
              state_w=S_WAIT;
          end
		  else if(dsp_finish)begin
			  state_w=S_WAIT;
		  end
          else begin
              state_w=S_PLAY;
          end
      end
      S_PLAY_PAUSE:begin
          if(i_key_1)begin
              state_w=S_PLAY;
          end
          else if (i_key_2)begin
              state_w=S_WAIT;
          end
          else begin
              state_w=S_PLAY_PAUSE;
          end
      end
	  default: begin
		  state_w = state_r;
	  end
    endcase
end
// *** ----------------------------------------------- *** //

always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r<=0;
        // speed<=0; // ***
        // fast_r<=0; // ***
        // slow_1<=0; // ***
	end
	else begin
		state_r<=state_w;
        // speed<=i_speed; // ***
        // fast_r<=fast_w; // ***
        // slow_1<=i_slow_1; // ***
	end
end

endmodule
