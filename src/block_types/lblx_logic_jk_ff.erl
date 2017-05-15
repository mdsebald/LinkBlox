%%% @doc 
%%% Block Type: JK Flip-Flop
%%% Description: Implement asynchronous JK Flip-Flop
%%%               
%%% @end 

-module(lblx_logic_jk_ff).  

-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0, description/0, version/0]).
-export([create/2, create/4, create/5, upgrade/1, initialize/1, execute/2, delete/1]).

groups() -> [logic].

description() -> "JK Flip-Flop".

version() -> "0.1.0".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: block_name(),
                      Description :: string()) -> list(config_attr()).

default_configs(BlockName, Description) -> 
  attrib_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
      
    ]). 


-spec default_inputs() -> list(input_attr()).

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {input_j, {empty, ?EMPTY_LINK}}, % Binary input J value
      {input_k, {empty, ?EMPTY_LINK}} % Binary input K value
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
      log_server:info(block_type_upgraded_from_ver_to, 
                            [BlockName, BlockType, ConfigVer, ModuleVer]),
      {ok, {UpdConfig, Inputs, Outputs}};

    {error, Reason} ->
      log_server:error(err_upgrading_block_type_from_ver_to, 
                            [Reason, BlockName, BlockType, ConfigVer, ModuleVer]),
      {error, Reason}
  end.


%%
%% Initialize block values
%% Perform any setup here as needed before starting execution
%%
-spec initialize(BlockState :: block_state()) -> block_state().

initialize({Config, Inputs, Outputs, Private}) ->
 
  % No config values to check
 
  Outputs1 = output_utils:set_value_status(Outputs, null, initialed),  

  % This is the block state
  {Config, Inputs, Outputs1, Private}.


%%
%%  Execute the block specific functionality
%%
-spec execute(BlockState :: block_state(), 
              ExecMethod :: exec_method()) -> block_state().

execute({Config, Inputs, Outputs, Private}, _ExecMethod) ->

  % CurrValue can only be null, true, or false
  {ok, CurrValue} = attrib_utils:get_value(Outputs, value),

  case input_utils:get_boolean(Inputs, input_j) of

    {ok, null} -> Value = null, Status = no_input;
    
    {ok, InputJ} -> 
      case input_utils:get_boolean(Inputs, input_k) of

        {ok, null} -> Value = null, Status = no_input;
    
        {ok, InputK} -> 
          % If we are coming from a previous state, where the output was null
          % Default the current value to False.
          case CurrValue of 
            null     -> CurrValueNotNull = false;
            _NotNull -> CurrValueNotNull = CurrValue
          end,

          % Inplement JK Flip-Flop truth table
          case {InputJ, InputK} of
            {false, false} -> Value = CurrValueNotNull;
            {false, true}  -> Value = false;
            {true,  false} -> Value = true;
            {true,  true}  -> Value = not CurrValueNotNull
          end,
          Status = normal;
  
        {error, Reason} ->
          {Value, Status} = input_utils:log_error(Config, input, Reason)
      end;

    {error, Reason} ->
      {Value, Status} = input_utils:log_error(Config, input, Reason)
  end,

  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

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

block_test_() ->
  {"Input to Output tests for: " ++ atom_to_list(?MODULE),
   {setup, 
      fun setup/0, 
      fun cleanup/1,
      fun (BlockState) -> 
        {inorder,
        [
          test_io(BlockState)
        ]}
      end} 
  }.

setup() ->
  unit_test_utils:block_setup(?MODULE).

cleanup(BlockState) ->
  unit_test_utils:block_cleanup(?MODULE, BlockState).

test_io(BlockState) ->
  unit_test_utils:create_io_tests(?MODULE, input_cos, BlockState, test_sets()).

test_sets() ->
  [
    {[], [{status, no_input}, {value, null}]},
    {[{input_j, 1234}], [{status, input_err}, {value, null}]},
    {[{input_j, false}, {input_k, 1234}], [{status, input_err}, {value, null}]},
    {[{input_j, true},  {input_k, false}], [{status, normal}, {value, true}]},
    {[{input_j, false}, {input_k, false}], [{status, normal}, {value, true}]},
    {[{input_j, false}, {input_k, true}],  [{status, normal}, {value, false}]},
    {[{input_j, true},  {input_k, false}], [{status, normal}, {value, true}]},
    {[{input_j, true},  {input_k, true}],  [{status, normal}, {value, false}]}
  ].

-endif.