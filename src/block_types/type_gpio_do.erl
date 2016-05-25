%%% @doc 
%%% Block Type: GPIO Digital Output
%%% Description: Configure a GPIO Pin as a Digital Output block
%%%               
%%% @end 

-module(type_gpio_do).

-author("Mark Sebald").

-include("../block_state.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([type_name/0, description/0, version/0]). 
-export([create/2, create/4, create/5, initialize/1, execute/1, delete/1]).


type_name() -> "gpio_do". 

description() -> "GPIO digital output". 

version() -> "0.1.0". 

%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: block_name(),
                      Description :: string()) -> list(config_attr()).

default_configs(BlockName, Description) -> 
  attrib_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
      {gpio_pin, {0}}, 
      {default_value, {false}},
      {invert_output, {false}}
    ]).


-spec default_inputs() -> list(input_attr()).

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {input, {empty, ?EMPTY_LINK}}
    ]). 


-spec default_outputs() -> list(output_attr()).
                            
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
             InitConfig :: list(config_attr()), 
             InitInputs :: list(input_attr())) -> block_defn().
   
create(BlockName, Description, InitConfig, InitInputs) -> 
  create(BlockName, Description, InitConfig, InitInputs, []).

-spec create(BlockName :: block_name(),
             Description :: string(), 
             InitConfig :: list(config_attr()), 
             InitInputs :: list(input_attr()), 
             InitOutputs :: list(output_attr())) -> block_defn().

create(BlockName, Description, InitConfig, InitInputs, InitOutputs)->

  %% Update Default Config, Input, Output, and Private attribute values 
  %% with the initial values passed into this function.
  %%
  %% If any of the intial attributes do not already exist in the 
  %% default attribute lists, merge_attribute_lists() will create them.
  %% (This is useful for block types where the number of attributes is not fixed)
    
  Config = attrib_utils:merge_attribute_lists(default_configs(BlockName, Description), InitConfig),
  Inputs = attrib_utils:merge_attribute_lists(default_inputs(), InitInputs), 
  Outputs = attrib_utils:merge_attribute_lists(default_outputs(), InitOutputs),

  % This is the block definition, 
  {Config, Inputs, Outputs}.


%%
%% Initialize block values before starting execution
%% Perform any setup here as needed before starting execution
%%
-spec initialize(block_state()) -> block_state().

initialize({Config, Inputs, Outputs, Private}) ->

  Private1 = attrib_utils:add_attribute(Private, {gpio_pin_ref, {empty}}),
  
  % Get the GPIO Pin number used for digital outputs 
  {ok, PinNumber} = attrib_utils:get_value(Config, gpio_pin),
  % TODO: Check if Pin Number is an integer, and range
    
  {ok, DefaultValue} = attrib_utils:get_value(Config, default_value),
  {ok, InvertOutput} = attrib_utils:get_value(Config, invert_output),
	    
  case gpio:start_link(PinNumber, output) of
    {ok, GpioPinRef} ->
      Status = initialed,
      Value = DefaultValue,
 	    {ok, Private2} = attrib_utils:set_value(Private1, gpio_pin_ref, GpioPinRef),
      set_pin_value_bool(GpioPinRef, DefaultValue, InvertOutput);
            
    {error, ErrorResult} ->
      error_logger:error_msg("Error: ~p intitiating GPIO pin; ~p~n", 
                              [ErrorResult, PinNumber]),
      Status = proc_error,
      Value = not_active,
      Private2 = Private1
    end,	
  
    Outputs1 = output_utils:set_value_status(Outputs, Value, Status),
    
    {Config, Inputs, Outputs1, Private2}.


%%
%%  Execute the block specific functionality
%%
-spec execute(block_state()) -> block_state().

execute({Config, Inputs, Outputs, Private}) ->

  
  {ok, GpioPin} = attrib_utils:get_value(Private, gpio_pin_ref),
  {ok, DefaultValue} = attrib_utils:get_value(Config, default_value),
  {ok, InvertOutput} = attrib_utils:get_value(Config, invert_output),
     
  {ok, Input} = attrib_utils:get_value(Inputs, input),
 	
  % Set Output Val to input and set the actual GPIO pin value too
  case Input of
    empty -> 
      PinValue = DefaultValue, % TODO: Set pin to default value or input? 
      Value = not_active,
      Status = no_input;
					
	  not_active ->
      PinValue = DefaultValue, % TODO: Set pin to default value or input? 
      Value = not_active,
      Status = normal;
					
	  true ->  
      PinValue = true, 
      Value = true,
      Status = normal;
					
    false ->
      PinValue = false,
      Value = false,
      Status = normal;

		Other ->
      BlockName = config_utils:name(Config),
      error_logger:error_msg("~p Error: Invalid input value: ~p~n", 
                             [BlockName, Other]),
			PinValue = DefaultValue, % TODO: Set pin to default value or input? 
		  Value = not_active,
      Status = input_error
	end,
  set_pin_value_bool(GpioPin, PinValue, InvertOutput),
 
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),     
 
  {Config, Inputs, Outputs1, Private}.


%% 
%%  Delete the block
%%	
-spec delete(block_state()) -> ok.

delete({_Config, _Inputs, _Outputs, _Private}) -> 
  % Release the GPIO pin?
  ok.


%% ====================================================================
%% Internal functions
%% ====================================================================

% Set the actual value of the GPIO pin here
set_pin_value_bool(GpioPin, Value, Invert) ->
  if Value -> % Value is true/on
    if Invert -> % Invert pin value 
      gpio:write(GpioPin, 0); % turn output off
    true ->      % Don't invert_output output value
      gpio:write(GpioPin, 1) % turn output on
    end;
  true -> % Value is false/off
    if Invert -> % Invert pin value
      gpio:write(GpioPin, 1); % turn output on
    true ->      % Don't invert_output output value
      gpio:write(GpioPin, 0)  % turn output off
    end
  end.