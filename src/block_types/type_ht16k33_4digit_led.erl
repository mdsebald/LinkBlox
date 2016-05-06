%%% @doc 
%%% Block Type:  4 Digit 7 Segment LED Display
%%% Description: LED Display with I2C Interface HTK1633 Driver   
%%%               
%%% @end 

-module(type_ht16k33_4digit_led).  

-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([type_name/0, description/0, version/0]). 
-export([create/2, create/4, create/5, initialize/1, execute/1, delete/1]).


type_name() -> "ht16k33_4digit_led".

version() -> "0.1.0".

% INSTRUCTIONS String describing block function
description() -> "4 digit 7 segment LED display with I2C interface".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: atom(),
                      Description :: string()) -> list().

default_configs(BlockName, Description) -> 
  block_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
      {i2c_device, "i2c-1"},
      {i2c_addr, 16#70}                 
    ]). 


-spec default_inputs() -> list().

default_inputs() -> 
  block_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {display_on, true, ?EMPTY_LINK},
      {blink_rate, 0, ?EMPTY_LINK},
      {brightness, 0, ?EMPTY_LINK},
      {seven_segs_1, 16#FF, ?EMPTY_LINK},
      {seven_segs_2, 16#FF, ?EMPTY_LINK},
      {colon, true, ?EMPTY_LINK},
      {seven_segs_3, 16#FF, ?EMPTY_LINK},
      {seven_segs_4, 16#FF, ?EMPTY_LINK}
    ]). 


-spec default_outputs() -> list().
                            
default_outputs() -> 
  block_utils:merge_attribute_lists(
    block_common:outputs(),
    [
     
    ]). 

%%  
%% Create a set of block attributes for this block type.  
%% Init attributes are used to override the default attribute values
%% and to add attributes to the lists of default attributes
%%
-spec create(BlockName :: atom(),
             Description :: string()) -> block_defn().

create(BlockName, Description) -> 
  create(BlockName, Description, [], [], []).

-spec create(BlockName :: atom(),
             Description :: string(),  
             InitConfig :: list(), 
             InitInputs :: list()) -> block_defn().
   
create(BlockName, Description, InitConfig, InitInputs) -> 
  create(BlockName, Description, InitConfig, InitInputs, []).

-spec create(BlockName :: atom(),
             Description :: string(), 
             InitConfig :: list(), 
             InitInputs :: list(), 
             InitOutputs :: list()) -> block_defn().

create(BlockName, Description, InitConfig, InitInputs, InitOutputs)->

  %% Update Default Config, Input, Output, and Private attribute values 
  %% with the initial values passed into this function.
  %%
  %% If any of the intial attributes do not already exist in the 
  %% default attribute lists, merge_attribute_lists() will create them.
  %% (This is useful for block types where the number of attributes is not fixed)
    
  Config = block_utils:merge_attribute_lists(default_configs(BlockName, Description), InitConfig),
  Inputs = block_utils:merge_attribute_lists(default_inputs(), InitInputs), 
  Outputs = block_utils:merge_attribute_lists(default_outputs(), InitOutputs),

  % This is the block definition, 
  {Config, Inputs, Outputs}.

%%
%% Initialize block values
%% Perform any setup here as needed before starting execution
%%
-spec initialize(block_state()) -> block_state().

initialize({Config, Inputs, Outputs, Private}) ->

  Private1 = block_utils:add_attribute(Private, {i2c_ref, empty}),
  
  % Get the the I2C Address of the display 
  % TODO: Check for valid I2C Address
  {ok, I2cDevice} = block_utils:get_value(Config, i2c_device),
  {ok, I2cAddr} = block_utils:get_value(Config, i2c_addr),
	    
  case init_led_driver(I2cDevice, I2cAddr) of
    {ok, I2cRef} ->
      Status = initialed,
      Value = 0, 
      {ok, Private2} = block_utils:set_value(Private1, i2c_ref, I2cRef);
      
    {error, Reason} ->
      error_logger:error_msg("Error: ~p intitializing LED driver, I2C Address: ~p~n", 
                              [Reason, I2cAddr]),
      Status = proc_error,
      Value = not_active,
      Private2 = Private1
    end,
   
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

  % This is the block state
  {Config, Inputs, Outputs1, Private2}.

%%
%%  Execute the block specific functionality
%%
-spec execute(block_state()) -> block_state().

execute({Config, Inputs, Outputs, Private}) ->

  {ok, I2cRef} = block_utils:get_value(Private, i2c_ref),
  
  case lblx_inputs:get_boolean(Inputs, display_on) of
    {error, Reason} ->
      {Value, Status} = lblx_inputs:log_error(Config, display_on, Reason);
 
    {ok, DisplayState} ->
      case lblx_inputs:get_integer(Inputs, blink_rate) of
        {error, Reason} ->
          lblx_inputs:log_error(Config, blink_rate, Reason),
          Value = not_active, Status = input_err;
        {ok, not_active} -> 
          Value = not_active, Status = normal;
        
        {ok, BlinkRate} ->
          % Display State and Blink Rate are write to the same byte 
          set_blink_rate(I2cRef, DisplayState, BlinkRate),
          
          case lblx_inputs:get_integer(Inputs, brightness) of
            {error, Reason} ->
              lblx_inputs:log_error(Config, brightness, Reason),
              Value = not_active, Status = input_err;
              
            {ok, not_active} -> 
              Value = not_active, Status = normal;
                                
            {ok, Brightness} ->
              set_brightness(I2cRef, Brightness),
              
              case lblx_inputs:get_integer(Inputs, seven_segs_1) of
                {error, Reason} ->
                  lblx_inputs:log_error(Config, seven_segs_1, Reason),
                  Value = not_active, Status = input_err;
                  
                {ok, not_active} -> 
                  Value = not_active, Status = normal;
                     
                {ok, Segments1} ->
                  write_segments(I2cRef, 1, Segments1),
                  
                  case lblx_inputs:get_integer(Inputs, seven_segs_2) of
                    {error, Reason} ->
                      lblx_inputs:log_error(Config, seven_segs_2, Reason),
                      Value = not_active, Status = input_err;
                      
                    {ok, not_active} -> 
                      Value = not_active, Status = normal;
                      
                    {ok, Segments2} ->
                      write_segments(I2cRef, 2, Segments2),
                      
                      case lblx_inputs:get_boolean(Inputs, colon) of
                        {error, Reason} ->
                          lblx_inputs:log_error(Config, colon, Reason),
                          Value = not_active, Status = input_err;
                          
                        {ok, not_active} -> 
                          Value = not_active, Status = normal;
                   
                        {ok, ColonState} ->
                          set_colon(I2cRef, ColonState),
                           
                          case lblx_inputs:get_integer(Inputs, seven_segs_3) of
                            {error, Reason} ->
                              lblx_inputs:log_error(Config, seven_segs_3, Reason),
                              Value = not_active, Status = input_err;
                              
                            {ok, not_active} -> 
                              Value = not_active, Status = normal;

                            {ok, Segments3} ->
                              write_segments(I2cRef, 3, Segments3),
                              
                              case lblx_inputs:get_integer(Inputs, seven_segs_4) of
                                {error, Reason} ->
                                  lblx_inputs:log_error(Config, seven_segs_4, Reason),
                                  Value = not_active, Status = input_err;
                                  
                                {ok, not_active} -> 
                                  Value = not_active, Status = normal;

                                {ok, Segments4} ->
                                  write_segments(I2cRef, 4, Segments4),
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
-spec delete(block_state()) -> ok.

delete({_Config, _Inputs, _Outputs, Private}) ->
 
  {ok, I2cRef} = block_utils:get_value(Private, i2c_ref),
  % Turn off the display 
  shutdown_led_driver(I2cRef),  
  
  % Close the I2C Channel
  i2c:stop(I2cRef),
  ok.


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
-spec init_led_driver(I2cDevice :: string(),
                      I2cAddr :: integer()) -> {ok, pid()} | {error, atom()}.
                      
init_led_driver(I2cDevice, I2cAddr) ->
   case i2c:start_link(I2cDevice, (I2cAddr)) of
    {ok, I2cRef} ->
      i2c:write(I2cRef, <<?DISPLAY_OSCILLATOR_ON>>),
      i2c:write(I2cRef, <<?DISPLAY_BLANK>>),
      i2c:write(I2cRef, <<(?BRIGHTNESS_REGISTER bor ?MAX_BRIGHTNESS)>>),
      
      % Clear the display buffer (clears the screen)
      clear(I2cRef),
      {ok, I2cRef};
      
    {error, Reason} ->
      {error, Reason}
  end.

 
%%
%% Shutdown the LED driver
%% 
-spec shutdown_led_driver(I2cRef :: pid()) -> term().

shutdown_led_driver(I2cRef) ->
  clear(I2cRef),
  i2c:write(I2cRef, <<?DISPLAY_BLANK>>),
  i2c:write(I2cRef, <<?DISPLAY_OSCILLATOR_OFF>>).
      
  
%%
%% Clear the display and buffer
%%
-spec clear(I2cRef :: pid()) -> term().

clear(I2cRef) ->
  % 2 digits, colon, and 2 digits, requrires 10 bytes of buffer storage
  % Only first byte (even bytes, index: 0, 2, 4, 6, and 8) are significant
  % Clear out all 16 bytes of the display buffer, regardless
  Buffer = <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
  
  % clear the display buffer, starting at register 0
  i2c:write(I2cRef, <<16#00, Buffer/binary>>).


%%
%% Set the blink rate
%%
-spec set_blink_rate(I2cRef :: pid(),
                     DisplayState :: boolean(), 
                     BlinkRate :: integer()) -> term().

set_blink_rate(I2cRef, DisplayState, BlinkRate) ->
  case DisplayState of
    true  -> DisplaySetup = (?DISPLAY_ON    bor (BlinkRate*2));
    false -> DisplaySetup = (?DISPLAY_BLANK bor (BlinkRate*2))
  end,
  i2c:write(I2cRef, <<DisplaySetup>>).
   

%%
%% Set the brightness level
%%
-spec set_brightness(I2cRef :: pid(),
                     Brightness :: integer()) -> term().

set_brightness(I2cRef, Brightness) ->
  i2c:write(I2cRef, <<(?BRIGHTNESS_REGISTER bor Brightness)>>).
  
%%
%% Set the brightness level
%%
-spec set_colon(I2cRef :: pid(),
                ColonState :: boolean()) -> term().

set_colon(I2cRef, ColonState) ->
  case ColonState of
    true  -> ColonSegment = ?COLON_SEGMENT_ON;
    false -> ColonSegment = ?COLON_SEGMENT_OFF
  end,
  i2c:write(I2cRef, <<?COLON_ADDRESS, ColonSegment>>). 


%%
%% Turn on the designated segments for the given digit  
%% -------------------------------------------------------
%% LED Segment ON:  a  |  b |  c | d  |  e |  f |  g | dp  
%% Segments Value: 0x01|0x02|0x04|0x08|0x10|0x20|0x40|0x80
%% --------------------------------------------------------
%%
-spec write_segments(I2cRef :: pid(),
                     Digit :: integer(),
                     Segments :: byte()) -> term().

write_segments(I2cRef, Digit, Segments) ->
  BufferAddress = lists:nth(Digit, [16#00, 16#02, 16#06, 16#08]),
  i2c:write(I2cRef, <<BufferAddress, Segments>>).
  
