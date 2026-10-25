module pwm_interp (
    target,
    target_valid,
    clear,
    clock,
    pwm,
    duty,
    ramping
);

    input [11:0] target;
    input target_valid;
    input clear;
    input clock;
    output pwm;
    output [11:0] duty;
    output ramping;

    wire [4:0] _20;
    wire _21;
    wire _22;
    wire _66;
    wire [15:0] _24;
    wire [3:0] _55;
    wire [15:0] _56;
    wire [12:0] _28;
    wire [12:0] _32;
    wire [11:0] _4;
    wire gnd;
    wire [12:0] _31;
    wire [12:0] _33;
    wire [12:0] _34;
    wire [12:0] _5;
    reg [12:0] step;
    wire _49;
    wire [1:0] _50;
    wire [2:0] _51;
    wire [15:0] _52;
    wire [15:0] _53;
    wire [4:0] _47;
    wire [4:0] _44;
    wire [4:0] _45;
    wire [4:0] _46;
    wire [4:0] _48;
    wire [4:0] _6;
    reg [4:0] remaining;
    wire _41;
    wire _42;
    wire [11:0] _38;
    wire period_end;
    wire _43;
    wire [15:0] _54;
    wire _8;
    wire [15:0] _57;
    wire [15:0] _9;
    reg [15:0] acc;
    wire [11:0] _26;
    wire vdd;
    wire [11:0] _36;
    wire _11;
    wire _13;
    wire [11:0] _60;
    wire [11:0] _61;
    wire _59;
    wire [11:0] _63;
    wire [11:0] _14;
    reg [11:0] counter;
    wire _64;
    reg _67;
    assign _20 = 5'b00000;
    assign _21 = remaining == _20;
    assign _22 = ~ _21;
    assign _66 = 1'b0;
    assign _24 = 16'b0000000000000000;
    assign _55 = 4'b0000;
    assign _56 = { _26,
                   _55 };
    assign _28 = 13'b0000000000000;
    assign _32 = { gnd,
                   _26 };
    assign _4 = target;
    assign gnd = 1'b0;
    assign _31 = { gnd,
                   _4 };
    assign _33 = _31 - _32;
    assign _34 = _8 ? _33 : step;
    assign _5 = _34;
    always @(posedge _13) begin
        if (_11)
            step <= _28;
        else
            step <= _5;
    end
    assign _49 = step[12:12];
    assign _50 = { _49,
                   _49 };
    assign _51 = { _50,
                   _49 };
    assign _52 = { _51,
                   step };
    assign _53 = acc + _52;
    assign _47 = 5'b10000;
    assign _44 = 5'b00001;
    assign _45 = remaining - _44;
    assign _46 = _43 ? _45 : remaining;
    assign _48 = _8 ? _47 : _46;
    assign _6 = _48;
    always @(posedge _13) begin
        if (_11)
            remaining <= _20;
        else
            remaining <= _6;
    end
    assign _41 = remaining == _20;
    assign _42 = ~ _41;
    assign _38 = 12'b111111111110;
    assign period_end = counter == _38;
    assign _43 = period_end & _42;
    assign _54 = _43 ? _53 : acc;
    assign _8 = target_valid;
    assign _57 = _8 ? _56 : _54;
    assign _9 = _57;
    always @(posedge _13) begin
        if (_11)
            acc <= _24;
        else
            acc <= _9;
    end
    assign _26 = acc[15:4];
    assign vdd = 1'b1;
    assign _36 = 12'b000000000000;
    assign _11 = clear;
    assign _13 = clock;
    assign _60 = 12'b000000000001;
    assign _61 = counter + _60;
    assign _59 = counter == _38;
    assign _63 = _59 ? _36 : _61;
    assign _14 = _63;
    always @(posedge _13) begin
        if (_11)
            counter <= _36;
        else
            counter <= _14;
    end
    assign _64 = counter < _26;
    always @(posedge _13) begin
        if (_11)
            _67 <= _66;
        else
            _67 <= _64;
    end
    assign pwm = _67;
    assign duty = _26;
    assign ramping = _22;

endmodule
module quadrature (
    button,
    b,
    clear,
    clock,
    a,
    position,
    up,
    down,
    button_down,
    pressed
);

    input button;
    input b;
    input clear;
    input clock;
    input a;
    output [15:0] position;
    output up;
    output down;
    output button_down;
    output pressed;

    wire _27;
    reg _29;
    wire _30;
    wire _31;
    wire [15:0] _40;
    wire [15:0] _49;
    wire [15:0] _45;
    wire [15:0] _46;
    wire _42;
    wire _43;
    wire [15:0] _47;
    reg [15:0] button_count;
    wire [15:0] _2;
    wire _41;
    wire _38;
    wire _39;
    wire _53;
    wire _4;
    reg _34;
    reg button_synced;
    reg _54;
    wire button_clean;
    wire [15:0] _152;
    wire [15:0] _149;
    wire [2:0] _78;
    wire _76;
    wire _77;
    wire [3:0] _79;
    wire [3:0] _66;
    wire _80;
    wire _81;
    wire _82;
    wire _83;
    wire _9;
    wire [15:0] _150;
    wire [3:0] _140;
    wire [2:0] _138;
    wire [3:0] _73;
    wire [3:0] _74;
    wire [3:0] _69;
    wire [3:0] _88;
    wire lost_track;
    wire [3:0] _86;
    wire [3:0] _89;
    wire [3:0] _10;
    reg [3:0] moved;
    wire [3:0] _72;
    wire forward;
    wire [3:0] _75;
    wire _136;
    wire _137;
    wire [3:0] _139;
    wire _141;
    wire _142;
    wire _65;
    wire _143;
    wire gnd;
    reg _61;
    wire [15:0] _104;
    wire _100;
    wire _101;
    wire [15:0] _105;
    reg [15:0] b_count;
    wire [15:0] _11;
    wire _99;
    wire _96;
    wire _97;
    wire _111;
    wire _13;
    reg _92;
    reg b_synced;
    reg _112;
    wire b_clean;
    wire _62;
    reg _57;
    wire [15:0] _127;
    wire _123;
    wire _124;
    wire [15:0] _128;
    reg [15:0] a_count;
    wire [15:0] _15;
    wire _122;
    wire _119;
    wire _120;
    wire _134;
    wire vdd;
    wire _17;
    wire _19;
    wire _21;
    reg _115;
    reg a_synced;
    reg _135;
    wire a_clean;
    wire _58;
    wire step;
    wire _144;
    wire _23;
    wire [15:0] _153;
    wire [15:0] _24;
    reg [15:0] _147;
    assign _27 = 1'b0;
    always @(posedge _19) begin
        if (_17)
            _29 <= _27;
        else
            _29 <= button_clean;
    end
    assign _30 = ~ _29;
    assign _31 = button_clean & _30;
    assign _40 = 16'b1111111111111111;
    assign _49 = 16'b0000000000000000;
    assign _45 = 16'b0000000000000001;
    assign _46 = _2 + _45;
    assign _42 = ~ _41;
    assign _43 = _39 & _42;
    assign _47 = _43 ? _46 : _49;
    always @(posedge _19) begin
        if (_17)
            button_count <= _49;
        else
            button_count <= _47;
    end
    assign _2 = button_count;
    assign _41 = _2 == _40;
    assign _38 = button_synced == button_clean;
    assign _39 = ~ _38;
    assign _53 = _39 & _41;
    assign _4 = button;
    always @(posedge _19) begin
        if (_17)
            _34 <= _27;
        else
            _34 <= _4;
    end
    always @(posedge _19) begin
        if (_17)
            button_synced <= _27;
        else
            button_synced <= _34;
    end
    always @(posedge _19) begin
        if (_17)
            _54 <= _27;
        else
            if (_53)
                _54 <= button_synced;
    end
    assign button_clean = _54;
    assign _152 = _147 + _45;
    assign _149 = _147 - _45;
    assign _78 = _75[2:0];
    assign _76 = _75[3:3];
    assign _77 = ~ _76;
    assign _79 = { _77,
                   _78 };
    assign _66 = 4'b0110;
    assign _80 = _66 < _79;
    assign _81 = ~ _80;
    assign _82 = _65 ? _81 : gnd;
    assign _83 = step ? _82 : gnd;
    assign _9 = _83;
    assign _150 = _9 ? _149 : _147;
    assign _140 = 4'b1010;
    assign _138 = _75[2:0];
    assign _73 = 4'b0001;
    assign _74 = moved + _73;
    assign _69 = 4'b0000;
    assign _88 = _65 ? _69 : _75;
    assign lost_track = _58 & _62;
    assign _86 = lost_track ? _69 : moved;
    assign _89 = step ? _88 : _86;
    assign _10 = _89;
    always @(posedge _19) begin
        if (_17)
            moved <= _69;
        else
            moved <= _10;
    end
    assign _72 = moved - _73;
    assign forward = a_clean ^ _61;
    assign _75 = forward ? _74 : _72;
    assign _136 = _75[3:3];
    assign _137 = ~ _136;
    assign _139 = { _137,
                    _138 };
    assign _141 = _139 < _140;
    assign _142 = ~ _141;
    assign _65 = a_clean & b_clean;
    assign _143 = _65 ? _142 : gnd;
    assign gnd = 1'b0;
    always @(posedge _19) begin
        if (_17)
            _61 <= _27;
        else
            _61 <= b_clean;
    end
    assign _104 = _11 + _45;
    assign _100 = ~ _99;
    assign _101 = _97 & _100;
    assign _105 = _101 ? _104 : _49;
    always @(posedge _19) begin
        if (_17)
            b_count <= _49;
        else
            b_count <= _105;
    end
    assign _11 = b_count;
    assign _99 = _11 == _40;
    assign _96 = b_synced == b_clean;
    assign _97 = ~ _96;
    assign _111 = _97 & _99;
    assign _13 = b;
    always @(posedge _19) begin
        if (_17)
            _92 <= _27;
        else
            _92 <= _13;
    end
    always @(posedge _19) begin
        if (_17)
            b_synced <= _27;
        else
            b_synced <= _92;
    end
    always @(posedge _19) begin
        if (_17)
            _112 <= _27;
        else
            if (_111)
                _112 <= b_synced;
    end
    assign b_clean = _112;
    assign _62 = b_clean ^ _61;
    always @(posedge _19) begin
        if (_17)
            _57 <= _27;
        else
            _57 <= a_clean;
    end
    assign _127 = _15 + _45;
    assign _123 = ~ _122;
    assign _124 = _120 & _123;
    assign _128 = _124 ? _127 : _49;
    always @(posedge _19) begin
        if (_17)
            a_count <= _49;
        else
            a_count <= _128;
    end
    assign _15 = a_count;
    assign _122 = _15 == _40;
    assign _119 = a_synced == a_clean;
    assign _120 = ~ _119;
    assign _134 = _120 & _122;
    assign vdd = 1'b1;
    assign _17 = clear;
    assign _19 = clock;
    assign _21 = a;
    always @(posedge _19) begin
        if (_17)
            _115 <= _27;
        else
            _115 <= _21;
    end
    always @(posedge _19) begin
        if (_17)
            a_synced <= _27;
        else
            a_synced <= _115;
    end
    always @(posedge _19) begin
        if (_17)
            _135 <= _27;
        else
            if (_134)
                _135 <= a_synced;
    end
    assign a_clean = _135;
    assign _58 = a_clean ^ _57;
    assign step = _58 ^ _62;
    assign _144 = step ? _143 : gnd;
    assign _23 = _144;
    assign _153 = _23 ? _152 : _150;
    assign _24 = _153;
    always @(posedge _19) begin
        if (_17)
            _147 <= _49;
        else
            _147 <= _24;
    end
    assign position = _147;
    assign up = _23;
    assign down = _9;
    assign button_down = button_clean;
    assign pressed = _31;

endmodule
module knob_pwm (
    enc_button,
    enc_b,
    enc_a,
    clear,
    clock,
    pwm,
    coarse,
    target,
    duty
);

    input enc_button;
    input enc_b;
    input enc_a;
    input clear;
    input clock;
    output pwm;
    output coarse;
    output [11:0] target;
    output [11:0] duty;

    wire [11:0] _31;
    wire _27;
    wire _25;
    reg target_valid;
    wire vdd;
    wire [11:0] _18;
    wire [11:0] _54;
    wire [11:0] _53;
    wire [12:0] _50;
    wire [12:0] _49;
    wire [12:0] _51;
    wire _52;
    wire [11:0] _55;
    wire [11:0] _45;
    wire [11:0] _40;
    wire [11:0] _39;
    wire _34;
    wire _36;
    wire _4;
    reg _35;
    wire [11:0] _41;
    wire [12:0] _42;
    wire gnd;
    wire [12:0] _38;
    wire [12:0] _43;
    wire _44;
    wire [11:0] _47;
    wire _24;
    wire [11:0] _48;
    wire _6;
    wire _8;
    wire _10;
    wire [19:0] _22;
    wire _23;
    wire [11:0] _56;
    wire [11:0] _11;
    reg [11:0] target_reg;
    wire _13;
    wire _15;
    wire [13:0] _30;
    wire _57;
    assign _31 = _30[12:1];
    assign _27 = 1'b0;
    assign _25 = _23 | _24;
    always @(posedge _15) begin
        if (_13)
            target_valid <= _27;
        else
            target_valid <= _25;
    end
    assign vdd = 1'b1;
    assign _18 = 12'b000000000000;
    assign _54 = 12'b111111111111;
    assign _53 = _51[11:0];
    assign _50 = { gnd,
                   _41 };
    assign _49 = { gnd,
                   target_reg };
    assign _51 = _49 + _50;
    assign _52 = _51[12:12];
    assign _55 = _52 ? _54 : _53;
    assign _45 = _43[11:0];
    assign _40 = 12'b000100000000;
    assign _39 = 12'b000000010000;
    assign _34 = _22[19:19];
    assign _36 = ~ _35;
    assign _4 = _36;
    always @(posedge _15) begin
        if (_13)
            _35 <= _27;
        else
            if (_34)
                _35 <= _4;
    end
    assign _41 = _35 ? _40 : _39;
    assign _42 = { gnd,
                   _41 };
    assign gnd = 1'b0;
    assign _38 = { gnd,
                   target_reg };
    assign _43 = _38 - _42;
    assign _44 = _43[12:12];
    assign _47 = _44 ? _18 : _45;
    assign _24 = _22[17:17];
    assign _48 = _24 ? _47 : target_reg;
    assign _6 = enc_button;
    assign _8 = enc_b;
    assign _10 = enc_a;
    quadrature
        quadrature
        ( .clock(_15),
          .clear(_13),
          .a(_10),
          .b(_8),
          .button(_6),
          .pressed(_22[19:19]),
          .button_down(_22[18:18]),
          .down(_22[17:17]),
          .up(_22[16:16]),
          .position(_22[15:0]) );
    assign _23 = _22[16:16];
    assign _56 = _23 ? _55 : _48;
    assign _11 = _56;
    always @(posedge _15) begin
        if (_13)
            target_reg <= _18;
        else
            target_reg <= _11;
    end
    assign _13 = clear;
    assign _15 = clock;
    pwm_interp
        pwm_interp
        ( .clock(_15),
          .clear(_13),
          .target(target_reg),
          .target_valid(target_valid),
          .ramping(_30[13:13]),
          .duty(_30[12:1]),
          .pwm(_30[0:0]) );
    assign _57 = _30[0:0];
    assign pwm = _57;
    assign coarse = _35;
    assign target = target_reg;
    assign duty = _31;

endmodule
