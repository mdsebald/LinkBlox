 %%% @doc 
%%% BLOCKTYPE
%%% 4 Digit 7 Segment LED Display
%%% DESCRIPTION
%%% 4 digit LED Display with I2C Interface using HTK1633 Driver.
%%% The segments to display for each digit are specified by byte input values.
%%% LINKS              
%%% @end 

-module(lblx_i2c_ht16k33).  

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
      {i2c_bus, {"i2c-1"}},  %| string | "i2c-1" | N/A |
      {i2c_addr, {16#70}}  %| byte | 70h | 0..FFh |
    ]). 


-spec default_inputs() -> input_attribs().

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {display_on, {true, {true}}}, %| bool | true | true, false |
      {blink_rate, {0, {0}}}, %| int | 0 | 0..? |
      {brightness, {0, {0}}}, %| int | 0 | 0..? |
      {digit1, {16#FF, {16#FF}}}, %| byte | FFh | 0..FFh
      {digit2, {16#FF, {16#FF}}}, %| byte | FFh | 0..FFh
      {colon, {true, {true}}}, %| bool | true | true, false |
      {digit3, {16#FF, {16#FF}}}, %| byte | FFh | 0..FFh
      {digit4, {16#FF, {16#FF}}} %| byte | FFh | 0..FFh
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
      init_led_driver(I2cDevice),
      Status = initialed,
      Value = 0;
      
    {error, _Reason} ->
      Status = proc_err,
      Value = null,
      Private1 = Private
    end,
   
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

  % This is the block state
  {Config, Inputs, Outputs1, Private1}.

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
  
  case input_utils:get_boolean(Inputs, display_on) of
    {error, Reason} ->
      {Value, Status} = input_utils:log_error(Config, display_on, Reason);
 
    {ok, DisplayState} ->
      case input_utils:get_integer(Inputs, blink_rate) of
        {error, Reason} ->
          input_utils:log_error(Config, blink_rate, Reason),
          Value = null, Status = input_err;
        {ok, null} -> 
          Value = null, Status = normal;
        
        {ok, BlinkRate} ->
          % Display State and Blink Rate are write to the same byte 
          set_blink_rate(I2cDevice, DisplayState, BlinkRate),
          
          case input_utils:get_integer(Inputs, brightness) of
            {error, Reason} ->
              input_utils:log_error(Config, brightness, Reason),
              Value = null, Status = input_err;
              
            {ok, null} -> 
              Value = null, Status = normal;
                                
            {ok, Brightness} ->
              set_brightness(I2cDevice, Brightness),
              
              case input_utils:get_integer(Inputs, digit1) of
                {error, Reason} ->
                  input_utils:log_error(Config, digit1, Reason),
                  Value = null, Status = input_err;
                  
                {ok, null} -> 
                  Value = null, Status = normal;
                     
                {ok, Segments1} ->
                  write_segments(I2cDevice, 1, Segments1),
                  
                  case input_utils:get_integer(Inputs, digit2) of
                    {error, Reason} ->
                      input_utils:log_error(Config, digit2, Reason),
                      Value = null, Status = input_err;
                      
                    {ok, null} -> 
                      Value = null, Status = normal;
                      
                    {ok, Segments2} ->
                      write_segments(I2cDevice, 2, Segments2),
                      
                      case input_utils:get_boolean(Inputs, colon) of
                        {error, Reason} ->
                          input_utils:log_error(Config, colon, Reason),
                          Value = null, Status = input_err;
                          
                        {ok, null} -> 
                          Value = null, Status = normal;
                   
                        {ok, ColonState} ->
                          set_colon(I2cDevice, ColonState),
                           
                          case input_utils:get_integer(Inputs, digit3) of
                            {error, Reason} ->
                              input_utils:log_error(Config, digit3, Reason),
                              Value = null, Status = input_err;
                              
                            {ok, null} -> 
                              Value = null, Status = normal;

                            {ok, Segments3} ->
                              write_segments(I2cDevice, 3, Segments3),
                              
                              case input_utils:get_integer(Inputs, digit4) of
                                {error, Reason} ->
                                  input_utils:log_error(Config, digit4, Reason),
                                  Value = null, Status = input_err;
                                  
                                {ok, null} -> 
                                  Value = null, Status = normal;

                                {ok, Segments4} ->
                                  write_segments(I2cDevice, 4, Segments4),
                                  Value = 0, Status = normal
                              end
                          end
                      end
                  end
              end
          end
      end
  end,
  
  % Block value output really doesn't have any useful info right now
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
      % Turn off the display 
      shutdown_led_driver(I2cDevice),  
      % Close the I2C Channel
      {I2cRef, _I2cAddr} = I2cDevice,
      i2c_utils:close(I2cRef);
      
    _ -> ok
  end,
  {Config, Inputs, Outputs}.


%% ====================================================================
%% Internal functions
%% ====================================================================


% HT16K33 LED Driver Registers
-define(DISPLAY_OSCILLATOR_OFF, 16#20).
-define(DISPLAY_OSCILLATOR_ON, 16#21).

-define(DISPLAY_BLANK, 16#80).
-define(DISPLAY_ON, 16#81).

-define(BRIGHTNESS_REGISTER, 16#E0).

%  Blink rates
-define(BLINK_RATE_OFF, 16#00).
-define(BLINK_RATE_2HZ, 16#01).
-define(BLINK_RATE_1HZ, 16#02).
-define(BLINK_RATE_HALFHZ, 16#03).

-define(MAX_BRIGHTNESS, 15).
-define(MIN_BRIGHTNESS, 0).

-define(COLON_ADDRESS, 16#04).
-define(COLON_SEGMENT_ON, 16#02).
-define(COLON_SEGMENT_OFF, 16#00).


%%
%% Initialize the LED driver 
%%
-spec init_led_driver(I2cDevice :: lb_types:i2c_device()) -> ok.
                      
init_led_driver(I2cDevice) ->
  i2c_utils:write(I2cDevice, <<?DISPLAY_OSCILLATOR_ON>>),
  i2c_utils:write(I2cDevice, <<?DISPLAY_BLANK>>),
  i2c_utils:write(I2cDevice, <<(?BRIGHTNESS_REGISTER bor ?MAX_BRIGHTNESS)>>),
  
  % Clear the display buffer (clears the screen)
  clear(I2cDevice),
  ok.

 
%%
%% Shutdown the LED driver
%% 
-spec shutdown_led_driver(I2cDevice :: lb_types:i2c_device()) -> ok | {error, atom()}.

shutdown_led_driver(I2cDevice) ->
  clear(I2cDevice),
  i2c_utils:write(I2cDevice, <<?DISPLAY_BLANK>>),
  i2c_utils:write(I2cDevice, <<?DISPLAY_OSCILLATOR_OFF>>).
      
  
%%
%% Clear the display and buffer
%%
-spec clear(I2cDevice :: lb_types:i2c_device()) -> ok | {error, atom()}.

clear(I2cDevice) ->
  % 2 digits, colon, and 2 digits, requrires 10 bytes of buffer storage
  % Only first byte (even bytes, index: 0, 2, 4, 6, and 8) are significant
  % Clear out all 16 bytes of the display buffer, regardless
  Buffer = <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
  
  % clear the display buffer, starting at register 0
  i2c_utils:write(I2cDevice, <<16#00, Buffer/binary>>).


%%
%% Set the blink rate
%%
-spec set_blink_rate(I2cDevice :: lb_types:i2c_device(),
                     DisplayState :: boolean(), 
                     BlinkRate :: integer()) -> ok | {error, atom()}.

set_blink_rate(I2cDevice, DisplayState, BlinkRate) ->
  case DisplayState of
    true  -> DisplaySetup = (?DISPLAY_ON    bor (BlinkRate*2));
    false -> DisplaySetup = (?DISPLAY_BLANK bor (BlinkRate*2))
  end,
  i2c_utils:write(I2cDevice, <<DisplaySetup>>).
   

%%
%% Set the brightness level
%%
-spec set_brightness(I2cDevice :: lb_types:i2c_device(),
                     Brightness :: integer()) -> ok | {error, atom()}.

set_brightness(I2cDevice, Brightness) ->
  i2c_utils:write(I2cDevice, <<(?BRIGHTNESS_REGISTER bor Brightness)>>).
  
%%
%% Set the the colon segment state
%%
-spec set_colon(I2cDevice :: lb_types:i2c_device(),
                ColonState :: boolean()) -> ok | {error, atom()}.

set_colon(I2cDevice, ColonState) ->
  case ColonState of
    true  -> ColonSegment = ?COLON_SEGMENT_ON;
    false -> ColonSegment = ?COLON_SEGMENT_OFF
  end,
  i2c_utils:write(I2cDevice, <<?COLON_ADDRESS, ColonSegment>>). 


%%
%% Turn on the designated segments for the given digit  
%% -------------------------------------------------------
%% LED Segment ON:  a  |  b |  c | d  |  e |  f |  g | dp  
%% Segments Value: 0x01|0x02|0x04|0x08|0x10|0x20|0x40|0x80
%% --------------------------------------------------------
%%
-spec write_segments(I2cDevice :: lb_types:i2c_device(),
                     Digit :: integer(),
                     Segments :: byte()) -> ok | {error, atom()}.

write_segments(I2cDevice, Digit, Segments) ->
  BufferAddress = lists:nth(Digit, [16#00, 16#02, 16#06, 16#08]),
  i2c_utils:write(I2cDevice, <<BufferAddress, Segments>>).
  

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