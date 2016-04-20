%%% @doc 
%%% Block Type:  MCP9808 Temperature Sensor
%%% Description: Microchip MCP9808 precision temperature sensor with I2C interface   
%%%               
%%% @end 

-module(lblx_mcp9808_temp).  

-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([type_name/0, description/0, version/0]). 
-export([create/2, create/4, create/5, initialize/1, execute/1, delete/1]).


type_name() -> "mcp9808_temp".

version() -> "0.1.0".

description() -> "MCP9808 precision temp sensor with I2C interface".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: atom(),
                      Comment :: string()) -> list().

default_configs(BlockName, Comment) -> 
  block_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, Comment, type_name(), version(), description()), 
    [
      {i2c_device, "i2c-1"},
      {i2c_addr, 16#18},
      {deg_f, true},
      {offset, 0.0}
    ]). 


-spec default_inputs() -> list().

default_inputs() -> 
  block_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {input, 0, ?EMPTY_LINK} 
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
             Comment :: string()) -> block_defn().

create(BlockName, Comment) -> 
  create(BlockName, Comment, [], [], []).

-spec create(BlockName :: atom(),
             Comment :: string(),  
             InitConfig :: list(), 
             InitInputs :: list()) -> block_defn().
   
create(BlockName, Comment, InitConfig, InitInputs) -> 
  create(BlockName, Comment, InitConfig, InitInputs, []).

-spec create(BlockName :: atom(),
             Comment :: string(), 
             InitConfig :: list(), 
             InitInputs :: list(), 
             InitOutputs :: list()) -> block_defn().

create(BlockName, Comment, InitConfig, InitInputs, InitOutputs)->

  %% Update Default Config, Input, Output, and Private attribute values 
  %% with the initial values passed into this function.
  %%
  %% If any of the intial attributes do not already exist in the 
  %% default attribute lists, merge_attribute_lists() will create them.
  %% (This is useful for block types where the number of attributes is not fixed)
    
  Config = block_utils:merge_attribute_lists(default_configs(BlockName, Comment), InitConfig),
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
  
  % Get the the I2C Address of the sensor 
  % TODO: Check for valid I2C Address
  I2cDevice = block_utils:get_value(Config, i2c_device),
  I2cAddr = block_utils:get_value(Config, i2c_addr),
	    
  case i2c:start_link(I2cDevice, I2cAddr) of
    {ok, I2cRef} ->
      Private2 = block_utils:set_value(Private1, i2c_ref, I2cRef),
      
      
      DegF = block_utils:get_value(Config, deg_f),
      Offset = block_utils:get_value(Config, offset),
  
      % Read the ambient temperature
      case read_ambient(I2cRef, DegF, Offset) of
        {error, Reason} ->
          error_logger:error_msg("Error: ~p Reading temperature sensor~n", 
                              [Reason]),
          Status = proc_error,
          Value = not_active;
          
       Value ->
          Status = initialed
      end;
      
    {error, Reason} ->
      error_logger:error_msg("Error: ~p intitiating I2C Address: ~p~n", 
                              [Reason, I2cAddr]),
      Status = proc_error,
      Value = not_active,
      Private2 = Private1
  end,	
   
  Outputs1 = block_utils:set_value_status(Outputs, Value, Status),

  % This is the block state
  {Config, Inputs, Outputs1, Private2}.


%%
%%  Execute the block specific functionality
%%
-spec execute(block_state()) -> block_state().

execute({Config, Inputs, Outputs, Private}) ->

  % TODO: Check flag bits?
  %  Do we need to do this? Easy to implement in block code.
  % Critical temp trips hw interrupt on chip, may need to implement that
  % if ((UpperByte & 0x80) == 0x80){ //TA > TCRIT }
  % if ((UpperByte & 0x40) == 0x40){ //TA > TUPPER }
  % if ((UpperByte & 0x20) == 0x20){ //TA < TLOWER }
  
  I2cRef = block_utils:get_value(Private, i2c_ref),
  DegF = block_utils:get_value(Config, deg_f),
  Offset = block_utils:get_value(Config, offset),
  
  % Read the ambient temperature
  case read_ambient(I2cRef, DegF, Offset) of
    {error, Reason} ->
      error_logger:error_msg("Error: ~p Reading temperature sensor~n", 
                              [Reason]),
      Status = proc_error,
      Value = not_active;
  
    Value ->
      Status = normal
  end,
   
  Outputs1 = block_utils:set_value_status(Outputs, Value, Status),

  % Return updated block state
  {Config, Inputs, Outputs1, Private}.


%% 
%%  Delete the block
%%	
-spec delete(block_state()) -> ok.

delete({_Config, _Inputs, _Outputs, Private}) -> 
  % Close the I2C Channel
  I2cRef = block_utils:get_value(Private, i2c_ref), 
  i2c:stop(I2cRef),
  ok.



%% ====================================================================
%% Internal functions
%% ====================================================================

-define(AMBIENT_TEMP_REG, 16#05). 
-define(NEGATIVE_TEMP_FLAG, 16#10).
-define(LOW_TEMP_FLAG, 16#20).
-define(HIGH_TEMP_FLAG, 16#40).
-define(CRITICAL_TEMP_FLAG, 16#80).
-define(HIGH_BYTE_TEMP_MASK, 16#0F).

%
% Read the ambient temperature.
%
-spec read_ambient(I2cRef :: pid(),
                   DegF :: boolean(),
                   Offset :: float()) -> float() | {error, term()}.
                   
read_ambient(I2cRef, DegF, Offset) ->

  % Read two bytes from the ambient temperature register  
  case i2c:write_read(I2cRef, <<?AMBIENT_TEMP_REG>>, 2) of
    {error, Reason} -> {error, Reason};
  
    Result ->
      RawBytes = binary:bin_to_list(Result),
      UpperByte = lists:nth(1, RawBytes),
      LowerByte = lists:nth(2, RawBytes),
  
      % Strip sign and alarm flags from upper byte
      UpperTemp = (UpperByte band ?HIGH_BYTE_TEMP_MASK),
       
      if (UpperByte band ?NEGATIVE_TEMP_FLAG) == ?NEGATIVE_TEMP_FLAG ->  
        % temp < 0
        TempDegC = 256 - (UpperTemp * 16 + LowerByte / 16);
      true -> 
        % temp >= 0 
        TempDegC = (UpperTemp * 16 + LowerByte / 16)
      end,

      case DegF of
        true  -> ((TempDegC * 9) / 5 + 32) + Offset;
        false -> TempDegC + Offset
      end
  end.
