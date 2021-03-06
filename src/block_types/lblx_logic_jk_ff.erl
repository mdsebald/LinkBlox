%%% @doc 
%%% BLOCKTYPE
%%% JK Flip-Flop
%%% DESCRIPTION
%%% Implements asynchronous JK Flip-Flop
%%% LINKS              
%%% @end 

-module(lblx_logic_jk_ff).  

-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0, version/0]).
-export([create/2, create/4, create/5, upgrade/1, initialize/1, execute/2, delete/1]).

groups() -> [logic].

version() -> "0.1.0".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: block_name(),
                      Description :: string()) -> config_attribs().

default_configs(BlockName, Description) -> 
  attrib_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
      {initial_state, {false}} %| bool | false | true, false |
    ]). 


-spec default_inputs() -> input_attribs().

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {input_j, {empty, {empty}}}, %| bool | empty | true, false |
      {input_k, {empty, {empty}}} %| bool | empty | true, false |
    ]). 


-spec default_outputs() -> output_attribs().
                            
default_outputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:outputs(),
    [
      {active_true, {empty, []}}, %| bool | empty | true, null |
      {active_false, {empty, []}}%| bool | empty | false, null |
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
  
  case config_utils:get_boolean(Config, initial_state) of
    {ok, _InitState} -> 
      Value = null, Status = initialed;
    
    {error, Reason} ->
      {Value, Status} = config_utils:log_error(Config, initial_state, Reason)
  end,

  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),
  
  % This is the block state
  {Config, Inputs, Outputs1, Private}.


%%
%%  Execute the block specific functionality
%%
-spec execute(BlockState :: block_state(), 
              ExecMethod :: exec_method()) -> block_state().

execute({Config, Inputs, Outputs, Private}, disable) ->
  Outputs1 = output_utils:update_all_outputs(Outputs, null, disabled),
  {Config, Inputs, Outputs1, Private};

execute({Config, Inputs, Outputs, Private}, _ExecMethod) ->

  % CurrValue can only be null, true, or false
  {ok, CurrValue} = attrib_utils:get_value(Outputs, value),

  case input_utils:get_boolean(Inputs, input_j) of

    {ok, null} -> 
      InputId = input_j,  % Id doesn't matter, since input is not in error
      OutputVal = {ok, null};
    
    {ok, InputJ} -> 
      case input_utils:get_boolean(Inputs, input_k) of

        {ok, null} ->
          InputId = input_k,  % Id doesn't matter, since input is not in error
          OutputVal = {ok, null};

        {ok, InputK} -> 
          % If we are transitioning from a null state.
          % Set output to the intial state config value
          case CurrValue of 
            null ->
              {ok, CurrValueNotNull} = config_utils:get_boolean(Config, initial_state);

            _NotNull -> 
              CurrValueNotNull = CurrValue
          end,

          % Inplement JK Flip-Flop truth table
          case {InputJ, InputK} of
            {false, false} -> Value = CurrValueNotNull;
            {false, true}  -> Value = false;
            {true,  false} -> Value = true;
            {true,  true}  -> Value = not CurrValueNotNull
          end,
          InputId = input,  % Id doesn't matter, since input is not in error
          OutputVal = {ok, Value};

        {error, Reason} ->
          InputId = input_k,
          OutputVal = {error, Reason}
      end;

    {error, Reason} ->
      InputId = input_j,
      OutputVal = {error, Reason}
  end,
      
  Outputs1 = output_utils:set_tristate_outputs(InputId, OutputVal, Config, Outputs),

  % Return updated block state
  {Config, Inputs, Outputs1, Private}.


%% 
%%  Delete the block
%%	
-spec delete(BlockState :: block_state()) -> block_defn().

delete({Config, Inputs, Outputs, _Private}) -> 
  {Config, Inputs, Outputs}.


%% ====================================================================
%% Internal functions
%% ====================================================================


%% ====================================================================
%% Tests
%% ====================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

-include("block_io_test_gen.hrl").

test_sets() ->
  [
    {[{status, no_input}, {value, null}]},
    {[{input_j, 1234}], [{status, input_err}, {value, null}]},
    {[{input_j, false}, {input_k, 1234}], [{status, input_err}, {value, null}]},
    {[{input_j, true},  {input_k, false}], [{status, normal}, {value, true}]},
    {[{input_j, false}, {input_k, false}], [{status, normal}, {value, true}]},
    {[{input_j, false}, {input_k, true}],  [{status, normal}, {value, false}]},
    {[{input_j, true},  {input_k, false}], [{status, normal}, {value, true}]},
    {[{input_j, true},  {input_k, true}],  [{status, normal}, {value, false}]},
 
    {[{initial_state, true}], [], [{status, normal}, {value, false}]},
    {[{input_j, true},  {input_k, true}],  [{status, normal},   {value, true}]},
    {[{input_j, null}],                    [{status, no_input}, {value, null}]},
    {[{input_j, false}, {input_k, false}], [{status, normal},   {value, true}]}
  ].


-endif.