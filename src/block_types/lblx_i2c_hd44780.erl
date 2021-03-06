%%% @doc 
%%% BLOCKTYPE
%%% LCD driver for display using HD44780 chip, with I2C interface
%%% DESCRIPTION
%%% Drive a LCD connected to the I2C bus
%%% Input value strings are displayed on the LCD.
%%% The display may be divided into an arbitrary number of segments.
%%% Each segment has a separate block input, and the 
%%% starting row and column number field width form each segment 
%%% is individually specified.
%%% LINKS
%%% https://www.sparkfun.com/datasheets/LCD/HD44780.pdf
%%% @end 

-module(lblx_i2c_hd44780).  

-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0, version/0]).
-export([create/2, create/4, create/5, upgrade/1, initialize/1, execute/2, delete/1]).

groups() -> [output, display, i2c_device].

version() -> "0.1.0".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: block_name(),
                      Description :: string()) -> config_attribs().

default_configs(BlockName, Description) -> 
  attrib_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
      {i2c_bus, {"i2c-1"}}, %| string | "i2c-1" | N/A |
      {i2c_addr, {16#27}},  %| byte | 27h | 0..FFh |
      {not_active_str, {"--------------------"}}, %| string | "--------------------" | N/A |
      {num_of_inputs, {1}}, %| int | 1 | 1..80 |
      {start_rows, [{1}]}, %| int array | 1 | 1..4 |
      {start_cols, [{1}]}, %| int array | 1 | 1..20 |
      {field_widths, [{80}]} %| int array | 80 | 1..80 |
    ]). 


-spec default_inputs() -> input_attribs().

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {display, {true, {true}}}, %| bool | true | true, false |
      {clear, {false, {false}}}, %| bool | false | true, false |
      {cursor, {true, {true}}}, %| bool | true | true, false |
      {blink_cursor, {true, {true}}}, %| bool | true | true, false |
      {backlight, {true, {true}}}, %| bool | true | true, false |
      {inputs, [{"Input", {"Input"}}]} %| string array | "Input" | N/A |
    ]). 


-spec default_outputs() -> output_attribs().
                            
default_outputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:outputs(),
    [
    ]). 


%%  
%% Create a set of block attributes for this block type.  
%% Init attributes are used to override the default attribute values
%% and to add attributes to the lists of default attributes
%%
-spec create(BlockName :: block_name(),
             Description :: string()) -> block_defn().

create(BlockName, Description) -> 
  create(BlockName, Description, [], [], []).

-spec create(BlockName :: block_name(),
             Description :: string(),  
             InitConfig :: config_attribs(), 
             InitInputs :: input_attribs()) -> block_defn().
   
create(BlockName, Description, InitConfig, InitInputs) -> 
  create(BlockName, Description, InitConfig, InitInputs, []).

-spec create(BlockName :: block_name(),
             Description :: string(), 
             InitConfig :: config_attribs(), 
             InitInputs :: input_attribs(), 
             InitOutputs :: output_attribs()) -> block_defn().

create(BlockName, Description, InitConfig, InitInputs, InitOutputs) ->

  % Update Default Config, Input, Output, and Private attribute values 
  % with the initial values passed into this function.
  %
  % If any of the intial attributes do not already exist in the 
  % default attribute lists, merge_attribute_lists() will create them.
    
  Config = attrib_utils:merge_attribute_lists(default_configs(BlockName, Description), InitConfig),
  Inputs = attrib_utils:merge_attribute_lists(default_inputs(), InitInputs), 
  Outputs = attrib_utils:merge_attribute_lists(default_outputs(), InitOutputs),

  % This is the block definition, 
  {Config, Inputs, Outputs}.


%%
%% Upgrade block attribute values, when block code and block data versions are different
%% 
-spec upgrade(BlockDefn :: block_defn()) -> {ok, block_defn()} | {error, atom()}.

upgrade({Config, Inputs, Outputs}) ->
  ModuleVer = version(),
  {BlockName, BlockModule, ConfigVer} = config_utils:name_module_version(Config),
  BlockType = type_utils:type_name(BlockModule),

  case attrib_utils:set_value(Config, version, version()) of
    {ok, UpdConfig} ->
      m_logger:info(block_type_upgraded_from_ver_to, 
                            [BlockName, BlockType, ConfigVer, ModuleVer]),
      {ok, {UpdConfig, Inputs, Outputs}};

    {error, Reason} ->
      m_logger:error(err_upgrading_block_type_from_ver_to, 
                            [Reason, BlockName, BlockType, ConfigVer, ModuleVer]),
      {error, Reason}
  end.


%%
%% Initialize block values
%% Perform any setup here as needed before starting execution
%%
-spec initialize(BlockState :: block_state()) -> block_state().

initialize({Config, Inputs, Outputs, Private}) ->

	 % Setup I2C comm channel of the display       
  case config_utils:init_i2c(Config, Private) of
    {ok, Private1, I2cDevice} ->
    
      init_lcd_driver(I2cDevice),

      case config_utils:get_integer_range(Config, num_of_inputs, 1, 80) of
        {ok, NumOfInputs} ->      
          % Create N inputs
          BlockName = config_utils:name(Config),

          Config1 = config_utils:resize_attribute_array_value(Config, 
                                  start_rows, NumOfInputs, {1}),

          Config2 = config_utils:resize_attribute_array_value(Config1, 
                                  start_cols, NumOfInputs, {1}),

          Config3 = config_utils:resize_attribute_array_value(Config2, 
                                  field_widths, NumOfInputs, {80}),

          Inputs1 = input_utils:resize_attribute_array_value(BlockName, Inputs, 
                                  inputs, NumOfInputs, {"Input", {"Input"}}),
          Status = initialed,
          Value = 0;

        {error, Reason} ->
          Inputs1 = Inputs,
          Config3 = Config,
          {Value, Status} = config_utils:log_error(Config, num_of_inputs, Reason)
      end;
      
    {error, _Reason} ->
      Status = proc_err,
      Value = null,
      Private1 = Private,
      Config3 = Config,
      Inputs1 = Inputs
  end,

  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

  % This is the block state
  {Config3, Inputs1, Outputs1, Private1}.


%%
%%  Execute the block specific functionality
%%
-spec execute(BlockState :: block_state(), 
              ExecMethod :: exec_method()) -> block_state().

execute({Config, Inputs, Outputs, Private}, disable) ->
  Outputs1 = output_utils:update_all_outputs(Outputs, null, disabled),
  {Config, Inputs, Outputs1, Private};

execute({Config, Inputs, Outputs, Private}, _ExecMethod) ->

  {ok, I2cDevice} = attrib_utils:get_value(Private, i2c_dev),

  case update_lcd_control(I2cDevice, Inputs) of
    % Clear screen input is off
    {false, Backlight} ->
      {ok, NumOfInputs} = attrib_utils:get_value(Config, num_of_inputs),

      {Value, Status} = update_lcd_data(I2cDevice, Backlight, Config, Inputs, NumOfInputs);

    % Clear screen input is on, don't write anything to screen  
    {true, _} ->
      Value = "",
      Status = normal
  end,
   
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

  % Return updated block state
  {Config, Inputs, Outputs1, Private}.


%% 
%%  Delete the block
%%	
-spec delete(BlockState :: block_state()) -> block_defn().

delete({Config, Inputs, Outputs, Private}) -> 
 
  case attrib_utils:get_value(Private, i2c_dev) of
    {ok, I2cDevice} ->
      shutdown_lcd(I2cDevice),

      % Close the I2C Channel
      {I2cRef, _I2cAddr} = I2cDevice,
      i2c_utils:close(I2cRef);

    _ -> ok
  end,
  {Config, Inputs, Outputs}.


%% ====================================================================
%% Internal functions
%% ====================================================================

%
% Commands
%
-define(CLEAR_DISPLAY, 16#01).
-define(RETURN_HOME, 16#02).
-define(ENTRY_MODE_SET, 16#04).
-define(DISPLAY_CONTROL, 16#08).
-define(CURSOR_DISPLAY_SHIFT, 16#10).
-define(FUNCTION_SET, 16#20).
-define(SET_CGRAM_ADDR, 16#40).
-define(SET_DDRAM_ADDR, 16#80).

%
% Command Parameters
%
-define(NO_PARAMS, 16#00).

%
% Entry Mode Set command params
%
-define(INCREMENT, 16#02).
-define(DECREMENT, 16#00).

-define(SHIFT, 16#01). 
-define(NO_SHIFT, 16#00). 

%
% Display Control Command params
%
-define(BLINK_CURSOR_ON, 16#01).
-define(BLINK_CURSOR_OFF, 16#00).

-define(CURSOR_ON, 16#02). 
-define(CURSOR_OFF, 16#00).

-define(DISPLAY_ON, 16#04).
-define(DISPLAY_OFF, 16#00).

%
% Function Set Command params
%
-define(DATA_LEN_8BITS, 16#10).
-define(DATA_LEN_4BITS, 16#00).

-define(NUM_LINES_2, 16#08).
-define(NUM_LINES_1, 16#00).

-define(FONT_5X10, 16#04).
-define(FONT_5X8, 16#00).

%
% Set data address (i.e. cursor location) params
%
-define(LINE_1, 16#00).
-define(LINE_2, 16#40).
-define(LINE_3, 16#14).
-define(LINE_4, 16#54).

%
%  Display maximums
%
-define(MAX_ROWS, 4).
-define(MAX_COLUMNS, 20).
-define(MAX_CHARS, 80).

%
% This code assumes the I2C Port Expander is wired to LCD Controller as follows:
%
%      Port  
% Expander Output: db7  db6  db5  db4  db3  db2  db1  db0
% ------------------|----|----|----|----|----|----|----|            
%     HD44780       V    V    V    V    V    V    V    V
% LCD Controller   db7  db6  db5  db4  bklt  EN  R/W   RS 
% 
% EN (Enable) must be set high (1) and then low (0) to write a value to the LCD
%   This requires 2 sequential writes of the same data.
% R/W must be set low (0) to write values and high (1) to read values from the LCD
% RS set low (0) for commands and high (1) for data (i.e. characters to display)
%

-define(RS_DATA, 16#01).
-define(RS_COMMAND, 16#00).

-define(RW_READ, 16#02).
-define(RW_WRITE, 16#00).

-define(ENABLE_SET, 16#04).
-define(ENABLE_CLR, 16#FB).

-define(BACKLIGHT_ON, 16#08).  
-define(BACKLIGHT_OFF, 16#00).


%
% Initialize the LCD driver 
%
-spec init_lcd_driver(I2cDevice :: lb_types:i2c_device()) -> ok.
                      
init_lcd_driver(I2cDevice) ->
  % Reset the LCD, get its attention
  write_command_high(I2cDevice, ?BACKLIGHT_OFF, 16#30),
  block_utils:sleep(5),

  write_command_high(I2cDevice, ?BACKLIGHT_OFF, 16#30),
  block_utils:sleep(1),

  write_command_high(I2cDevice, ?BACKLIGHT_OFF, 16#30),
  block_utils:sleep(1),

  write_command_high(I2cDevice, ?BACKLIGHT_OFF, ?FUNCTION_SET),
  block_utils:sleep(1),

  % The display should be reset and in 4 bit mode now
  % From this point use normal command and write data functions

  set_display_function(I2cDevice, ?BACKLIGHT_OFF, (?NUM_LINES_2 bor ?FONT_5X8 bor ?DATA_LEN_4BITS) ),

  set_display_control(I2cDevice, ?BACKLIGHT_OFF, ?DISPLAY_OFF),

  clear_display(I2cDevice, ?BACKLIGHT_OFF),

  set_entry_mode(I2cDevice, ?BACKLIGHT_OFF, ?INCREMENT),
  ok.


%
% Shutdown LCD
%
shutdown_lcd(I2cDevice) ->
  % Clear the display and turn it off
  clear_display(I2cDevice, ?BACKLIGHT_OFF),
  set_display_control(I2cDevice, ?BACKLIGHT_OFF, ?DISPLAY_OFF).


%
% Read control inputs and update the LCD control
%
update_lcd_control(I2cDevice, Inputs) ->

  case input_utils:get_boolean(Inputs, display) of
    {ok, true} -> Display = ?DISPLAY_ON;
            _  -> Display = ?DISPLAY_OFF
  end,

  case input_utils:get_boolean(Inputs, cursor) of
    {ok, true} -> Cursor = ?CURSOR_ON;
            _  -> Cursor = ?CURSOR_OFF
  end,

  case input_utils:get_boolean(Inputs, blink_cursor) of
    {ok, true} -> BlinkCursor = ?BLINK_CURSOR_ON;
            _  -> BlinkCursor = ?BLINK_CURSOR_OFF
  end,
 
  case input_utils:get_boolean(Inputs, backlight) of
    {ok, true} -> Backlight = ?BACKLIGHT_ON;
            _  -> Backlight = ?BACKLIGHT_OFF
  end,

  set_display_control(I2cDevice, Backlight, (Display bor Cursor bor BlinkCursor)),

  % While the clear input is True, clear the display
  case input_utils:get_boolean(Inputs, clear) of
    {ok, true} -> clear_display(I2cDevice, Backlight),
                  ClearScr = true;

            _  -> ClearScr = false
  end,
  {ClearScr, Backlight}.


%
% Read input string(s) and update LCD
%

update_lcd_data(I2cDevice, Backlight, Config, Inputs, NumOfInputs) ->
  update_lcd_data(I2cDevice, Backlight, Config, Inputs, NumOfInputs, 1, "", normal).

update_lcd_data(_I2cDevice, _Backlight, _Config, _Inputs, 0, _InputNum, Value, Status) ->
  {Value, Status};

update_lcd_data(I2cDevice, Backlight, Config, Inputs, NumOfInputs, InputNum, Value, _Status) ->
  case config_utils:get_integer_range(Config, {start_rows, InputNum}, 1, ?MAX_ROWS) of
    {ok, StartRow} ->

      case config_utils:get_integer_range(Config, {start_cols, InputNum}, 1, ?MAX_COLUMNS) of
        {ok, StartCol} ->

          case config_utils:get_integer_range(Config, {field_widths, InputNum}, 1, ?MAX_CHARS) of
            {ok, FieldWidth} ->

              case input_utils:get_string(Inputs, {inputs, InputNum}) of
                {ok, null} -> 
                  % Input is null, display config not active string value
                  {ok, InputStr} = config_utils:get_string(Config, not_active_str),
                  DisplayedStr = display_str(I2cDevice, Backlight, StartRow, StartCol, FieldWidth, InputStr),                
                  NewValue = Value ++ DisplayedStr,
                  NewStatus = normal;

                {ok, InputStr} -> 
                  DisplayedStr = display_str(I2cDevice, Backlight, StartRow, StartCol, FieldWidth, InputStr),                
                  NewValue = Value ++ DisplayedStr,
                  NewStatus = normal;

                {error, Reason} ->
                  {NewValue, NewStatus} = input_utils:log_error(Config, inputs, Reason)
              end;
            {error, Reason} ->
              {NewValue, NewStatus} = config_utils:log_error(Config, field_widths, Reason)
          end;
        {error, Reason} ->
          {NewValue, NewStatus} = config_utils:log_error(Config, start_cols, Reason)
      end;
    {error, Reason} ->
      {NewValue, NewStatus} = config_utils:log_error(Config, start_rows, Reason)
  end,
  
  case NewStatus of
    normal ->
      update_lcd_data(I2cDevice, Backlight, Config, Inputs, 
                  (NumOfInputs - 1), (InputNum + 1), NewValue, normal);

    _ -> % Error reading config or input value, terminate writing to display
      update_lcd_data(I2cDevice, Backlight, Config, Inputs, 0, 0, NewValue, NewStatus)
  end.


%
% Write the Input string to the display
%
-spec display_str(I2cDevice :: lb_types:i2c_device(),
                  Backlight :: byte(),
                  StartRow :: pos_integer(),
                  StartCol :: pos_integer(),
                  FieldWidth :: pos_integer(),
                  InputStr :: string()) -> string().

display_str(I2cDevice, Backlight, StartRow, StartCol, FieldWidth, InputStr) ->
  case StartRow of
    1 -> RowAddr = ?LINE_1;
    2 -> RowAddr = ?LINE_2;
    3 -> RowAddr = ?LINE_3;
    4 -> RowAddr = ?LINE_4
  end,

  RowColAddr = RowAddr + (StartCol - 1),
  set_data_addr(I2cDevice, Backlight, RowColAddr),

  % Clip or Pad string with spaces to fill field width
  DisplayStr = string:left(InputStr, FieldWidth),
  lists:map(fun(Char) -> write_data(I2cDevice, Backlight, Char) end, DisplayStr),
  DisplayStr.


clear_display(I2cDevice, Backlight) ->
  write_command(I2cDevice, Backlight, ?CLEAR_DISPLAY, ?NO_PARAMS).

% Unused
%return_home(I2cDevice, Backlight) ->
%  write_command(I2cDevice, Backlight, ?RETURN_HOME, ?NO_PARAMS).


set_display_function(I2cDevice, Backlight, Params) ->
  write_command(I2cDevice, Backlight, ?FUNCTION_SET, Params).


set_display_control(I2cDevice, Backlight, Params) ->
  write_command(I2cDevice, Backlight, ?DISPLAY_CONTROL, Params).


set_entry_mode(I2cDevice, Backlight, Params) ->
  write_command(I2cDevice, Backlight, ?ENTRY_MODE_SET, Params).


set_data_addr(I2cDevice, Backlight, Params) ->
  write_command(I2cDevice, Backlight, ?SET_DDRAM_ADDR, Params).


write_command(I2cDevice, Backlight, Command, Params) ->
  CmdAndParams = (Command bor Params),
  % Always operate in 4 bit mode when using an I2C interface
  % Write high nibble (bits 7-4) first, then low nibble (bits 3-0)
  write_command_high(I2cDevice, Backlight, CmdAndParams),
  write_command_low(I2cDevice, Backlight, CmdAndParams).


% write high half of command byte value, R/W = 0, RS = 0
write_command_high(I2cDevice, Backlight, Value) ->
  HighValue = ((Value band 16#F0) bor Backlight),
  write_value(I2cDevice, HighValue).


% write low half of command byte value, R/W = 0, RS = 0
write_command_low(I2cDevice, Backlight, Value) ->
  LowValue = ((Value bsl 4) bor Backlight),
  write_value(I2cDevice, LowValue).


write_data(I2cDevice, Backlight, Data) ->
  % Always operate in 4 bit mode when using an I2C interface
  % Write high nibble (bits 7-4) first, then low nibble (bits 3-0)
  write_data_high(I2cDevice, Backlight, Data),
  write_data_low(I2cDevice, Backlight, Data).


% write high half of data byte value, R/W = 0, RS = 1
write_data_high(I2cDevice, Backlight, Value) ->
  HighValue = (((Value band 16#F0) bor Backlight) bor ?RS_DATA),
  write_value(I2cDevice, HighValue).


% write low half of data byte value, R/W = 0, RS = 1
write_data_low(I2cDevice, Backlight, Value) ->
  LowValue = (((Value bsl 4) bor Backlight) bor ?RS_DATA),
  write_value(I2cDevice, LowValue).


write_value(I2cDevice, Value) ->
  % Toggle Enable pin high
  ValueEnableSet = (Value bor ?ENABLE_SET),
  i2c_utils:write(I2cDevice, <<ValueEnableSet>>),
  % Toggle enable pin low, don't change the 4 data bits, Backlight, RS, or R/~W lines
  ValueEnableClr = (Value band ?ENABLE_CLR),
  i2c_utils:write(I2cDevice, <<ValueEnableClr>>).


%% ====================================================================
%% Tests
%% ====================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

-include("block_io_test_gen.hrl").

test_sets() ->
  [
    {[{status, normal}]}
  ].

-endif.