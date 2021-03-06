
%%% @doc 
%%% BLOCKTYPE
%%% Minimum On Time
%%% DESCRIPTION
%%% Block output will follow block binary input value but 
%%% will remain true (on) for the minimum specified amount of time
%%% LINKS              
%%% @end 

-module(lblx_timer_min_on).  
  
-author("Mark Sebald").

-include("../block_state.hrl"). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0, version/0]). 
-export([create/2, create/4, create/5, upgrade/1, initialize/1, execute/2, delete/1]).
-export([handle_info/2]).

groups() -> [timing].

version() -> "0.1.0".


%% Merge the block type specific, Config, Input, and Output attributes
%% with the common Config, Input, and Output attributes, that all block types have
 
-spec default_configs(BlockName :: block_name(),
                      Description :: string()) -> config_attribs().

default_configs(BlockName, Description) -> 
  attrib_utils:merge_attribute_lists(
    block_common:configs(BlockName, ?MODULE, version(), Description), 
    [
    ]). 


-spec default_inputs() -> input_attribs().

default_inputs() -> 
  attrib_utils:merge_attribute_lists(
    block_common:inputs(),
    [
      {min_on_time, {1000, {1000}}}, %| int | 1000 | 1..max int |
      {input, {empty, {empty}}} %| bool | empty | true, false |
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

  Private1 = attrib_utils:add_attribute(Private, {min_on_timer_ref, {empty}}),
  
  % No config values to check
 
  Outputs1 = output_utils:set_value_status(Outputs, null, initialed),

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

  % Timer reference shows block is in min time on mode)
  {ok, MinOnTimerRef} = attrib_utils:get_value(Private, min_on_timer_ref),
  {ok, CurrValue} = attrib_utils:get_value(Outputs, value),

  case input_utils:get_integer_greater_than(Inputs, min_on_time, -1) of
    {ok, MinOnTime} ->

      case input_utils:get_boolean(Inputs, input) of

        % If input is true, start min on time timer if not started already
        % Set output to true if input is true
        {ok, true} ->
          Value = true, Status = normal, 
          case MinOnTimerRef of
            empty -> 
              BlockName = config_utils:name(Config),
              if (is_integer(MinOnTime) andalso (MinOnTime > 0)) ->
                NewTimerRef = set_min_on_timer(BlockName, MinOnTime), 
                {ok, Private1} = attrib_utils:set_value(Private, min_on_timer_ref, NewTimerRef);
              true -> 
                Private1 = Private
              end;
            _Pid -> 
                Private1 = Private
          end;

        % Input is null or false, if min-on timer has expired, set output to null or false
        % Otherwise leave output unchanged
        {ok, NullFalse} ->
          case MinOnTimerRef of
            empty -> 
              Value = NullFalse, Status = normal;
            _Pid -> 
              Value = CurrValue, Status = normal
          end,
          Private1 = Private;

        {error, Reason} ->
          input_utils:log_error(Config, input, Reason),
          Value = null, Status = input_err,
          Private1 = Private
      end;
    {error, Reason} ->
        input_utils:log_error(Config, min_on_time, Reason),
        Value = null, Status = input_err,
        Private1 = Private
  end,
      
  Outputs1 = output_utils:set_value_status(Outputs, Value, Status),

  % Return updated block state
  {Config, Inputs, Outputs1, Private1}.


%% 
%%  Delete the block
%%	
-spec delete(BlockState :: block_state()) -> block_defn().

delete({Config, Inputs, Outputs, Private}) -> 

  % Cancel min on timer if it exists
  case attrib_utils:get_value(Private, min_on_timer_ref) of
    {ok, empty}      -> ok;
    {ok, TimerRef}   -> erlang:cancel_timer(TimerRef);
    {error, _Reason} -> ok  % Don't care if timer_ref doesn't exist
  end,
  
  {Config, Inputs, Outputs}.


%% 
%% Info message, from min on timer expiring
%% 
-spec handle_info(Info :: term(), 
                  BlockState :: block_state()) -> {noreply, block_state()}.

handle_info(min_on_timer, {Config, Inputs, Outputs, Private}) ->
  
  % Indicate min on timer has expired by clearing timer reference
  {ok, Private1} = attrib_utils:set_value(Private, min_on_timer_ref, empty),
  % Execute the block 
  NewBlockState = block_common:execute({Config, Inputs, Outputs, Private1}, timer),
  {noreply, NewBlockState};

handle_info(Info, BlockState) ->

  {BlockName, BlockModule} = config_utils:name_module(BlockState),
  m_logger:warning(block_type_name_unknown_info_msg, [BlockModule, BlockName, Info]),
  {noreply, BlockState}.


%% ====================================================================
%% Internal functions
%% ====================================================================

%%
%% Set minimum on time, timer
%% 
-spec set_min_on_timer(BlockName :: block_name(),
                       MinOnTime :: pos_integer()) -> reference().

set_min_on_timer(BlockName, MinOnTime) ->
  erlang:send_after(MinOnTime, BlockName, min_on_timer).


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
