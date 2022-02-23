module I2cInitializer(
    input  i_rst_n,
    input  i_clk,
    input  i_start,
    output o_finished,
    output o_sclk,
    inout  o_sdat,
    output o_oen
);
localparam [239: 0] setup_data = 240'b00110100_000_1001_0_0000_000100110100_000_1000_0_0001_100100110100_000_0111_0_0100_001000110100_000_0110_0_0000_000000110100_000_0101_0_0000_000000110100_000_0100_0_0001_010100110100_000_0011_0_0111_100100110100_000_0010_0_0111_100100110100_000_0001_0_1001_011100110100_000_0000_0_1001_0111;

localparam IDLE = 0;
localparam READY = 1;
localparam PROC = 2;
localparam FIN1 = 3;
localparam FIN2 = 4;

logic [2:0] state,state_w;
logic [2:0] sclk_S, sclk_S_w;
logic [239:0] data, data_w;
logic oen;
logic sdat, sdat_w;
logic sclk, sclk_w;
logic finish, finish_w;
logic [4:0] control_1, control_1_w; 
logic [4:0] control_2, control_2_w; 
logic [1:0]fin_state,fin_state_w;

assign o_finished = finish;
assign o_sclk = sclk;
assign o_sdat = oen? sdat: 1'bz;
assign o_oen = oen;

always_comb begin
	    state_w = state;
		data_w = data;
		sdat_w = sdat;
		sclk_w = sclk;
		sclk_S_w = sclk_S;
		finish_w = 0;
		oen = 1;
		control_1_w = 0;
		control_2_w = 0;
		fin_state_w=0;
	case(state)
		IDLE: begin
			if(i_start) begin
				state_w = READY;
				data_w = setup_data;
				sclk_w = 1;
				sdat_w = 0;
				sclk_S_w = 0;
			end
			else begin
				state_w = state;
				data_w = data;
				sdat_w = sdat;
				sclk_w = sclk;
				sclk_S_w = sclk_S;
			end
			finish_w = 0;
			oen = 1;
			control_1_w = 0;
			control_2_w = 0;
		end
		READY: begin
			state_w = PROC;
			data_w = data << 1;
			sdat_w = data[239];
			sclk_w = 0;
			sclk_S_w = 0;
			finish_w = finish;
			oen = 1;
			control_1_w = 0;
			control_2_w = 0;
		end
		PROC: begin
			if(control_1<5'd3) begin
				case(sclk_S)
					0: begin
						control_2_w = control_2;
						control_1_w = control_1;
						sdat_w = sdat;
						sclk_w = 1;
						sclk_S_w = 1;
						data_w = data;
					end
					1: begin
						control_2_w = control_2;
						control_1_w = control_1;
						sdat_w = sdat;
						sclk_w = 0;
						sclk_S_w = 2;
						data_w = data;
					end
					2: begin
						control_2_w = (control_2==5'd8)? 0:control_2 + 5'd1;
						control_1_w = (control_2==5'd8)? control_1+5'd1:control_1;
						sdat_w = data[239];
						sclk_w = 0;
						sclk_S_w = 0;
						data_w = (control_2==5'd7)? data: ((control_2==5'd8)&&(control_1==5'd2))? data: data << 1;
					end
				endcase
				oen = (control_2==5'd8)? 0:1;
				state_w = state;
				finish_w = 0;
			end
			else begin
				control_2_w = 0;
				control_1_w = 0;
				sdat_w = 0;
				sclk_w = 1;
				sclk_S_w = 0;
				data_w = data;
				oen = 1;
				state_w = FIN1;
				finish_w = 0;
			end
		end
		FIN1: begin
			control_2_w = 0;
			control_1_w = 0;
			sdat_w = (fin_state==0)?1:0;
			sclk_w = (fin_state==2)?1:0;
			sclk_S_w = 0;
			data_w = data;
			oen = 1;
			state_w = (fin_state==2)?FIN2:FIN1;
			finish_w = 0;
			fin_state_w=fin_state+1;
		end
		FIN2: begin
			fin_state_w=fin_state;
			if(data!=240'd0) begin
				state_w = PROC;
				data_w = data << 1;
				sdat_w = data[239];
				sclk_w = 0;
				sclk_S_w = 0;
				finish_w = 0;
				oen = 1;
				control_1_w = 0;
				control_2_w = 0;
			end
			else begin
				state_w = FIN2;
				data_w = data;
				sdat_w = 0;
				sclk_w = 0;
				sclk_S_w = 0; //don't care
				finish_w = 1;
				oen = 1;
				control_1_w = 0;
				control_2_w = 0;
			end
		end
		default: begin
			state_w = state;
			data_w = data;
			sdat_w = sdat;
			sclk_w = sclk;
			sclk_S_w = sclk_S;
			finish_w = 0;
			oen = 1;
			control_1_w = 0;
			control_2_w = 0;
		end
	endcase
end
always_ff @(posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state <= IDLE;
		data <= setup_data;
		control_1 <= 0;
		control_2 <= 0;
		sdat <= 1;
		sclk <= 1;
		sclk_S <= 2;
		finish <= 0;
		fin_state<=0;
	end else begin
		state <= state_w;
		data <= data_w;
		control_1 <= control_1_w;
		control_2 <= control_2_w;
		sdat <= sdat_w;
		sclk <= sclk_w;
		sclk_S <= sclk_S_w;
		finish <= finish_w;
		fin_state<=fin_state_w;
	end
end
endmodule