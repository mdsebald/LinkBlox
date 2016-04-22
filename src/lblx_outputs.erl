%%% @doc 
%%% Get and Set Block Output values   
%%%               
%%% @end 

-module(lblx_outputs).

-author("Mark Sebald").

-include("block_state.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([set_value_status/3, set_value_normal/2, set_status/2]).
-export([create_output_array/4]).
-export([log_error/3]).


%%
%% Set block output value and status
%% Block output value and status attributes are often set at the same time.
%% This is a shortcut to do that.
%% 
-spec set_value_status(Outputs :: list(), 
                       Value :: term(), 
                       Status :: block_status()) -> list().

set_value_status(Outputs, Value, Status) ->
  block_utils:set_values(Outputs, [{value, Value}, {status, Status}]).
  
%%
%% Set block output value and set status to normal
%% When setting the output value block status is usually normal.
%% This is a shortcut to do that.
%% 
-spec set_value_normal(Outputs :: list(), 
                       Value :: term()) -> list().

set_value_normal(Outputs, Value) ->
  block_utils:set_values(Outputs, [{value, Value}, {status, normal}]).

%%
%% Set status output value
%% 
-spec set_status(Outputs :: list(), 
                 Status :: block_status()) -> list().

set_status(Outputs, Status) ->
  block_utils:set_value(Outputs, status, Status).
  

%%
%% Create an array of inputs, with a common base ValueName plus index number
%% Set value to DefaultValue with an EMPTY LINK
%%
-spec create_output_array(Outputs :: list(),
                         Quant :: integer(),
                         BaseValueName :: atom(),
                         DefaultValue :: term()) -> list().
                              
create_output_array(Outputs, 0, _BaseValueName, _DefaultValue) ->
  lists:reverse(Outputs);
  
create_output_array(Outputs, Quant, BaseValueName, DefaultValue) ->
  ValueNameStr = iolib:format("~s_~2..0w", BaseValueName, Quant),
  ValueName = list_to_atom(ValueNameStr),
  Output = {ValueName, DefaultValue, []},
  create_output_array([Output | Outputs], Quant - 1, BaseValueName, DefaultValue).
  
  
%%
%% Log output value error
%%
-spec log_error(Config :: list(),
                ValueName :: atom(),
                Reason :: atom()) -> ok.
                  
log_error(Config, ValueName, Reason) ->
  BlockName = lblx_configs:name(Config),
  error_logger:error_msg("~p Invalid '~p' input value: ~p~n", 
                            [BlockName, ValueName, Reason]),
  ok.
  
  
%% ====================================================================
%% Internal functions
%% ====================================================================



%% ====================================================================
%% Tests
%% ====================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

% Test input value list
test_outputs() ->
  [ {float_good, 123.45, {null, block1, value}},
    {float_bad, xyz, ?EMPTY_LINK}
    {integer_good, 12345, {null, block2, value}},
    {integer_bad, "bad", ?EMPTY_LINK},
    {boolean_good, true, ?EMPTY_LINK},
    {boolean_bad, 0.0, ?EMPTY_LINK},
    {not_active_good, not_active, ?EMPTY_LINK},
    {empty_good, empty, ?EMPTY_LINK},
    {empty_bad, empty, {knot, empty, link}},
    {not_input, 123, [test1,test2]}
  ].
  
  
get_value_test() ->
  TestInputs = test_inputs().
    


-endif.