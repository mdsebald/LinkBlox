%% @doc 
%%% Handle block links     
%%%               
%%% @end 

-module(link_utils).

-author("Mark Sebald").

-include("block_state.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([
          set_link/4,
          link_blocks/2,
          evaluate_link/5, 
          unlink_inputs/2,
          empty_linked_inputs/1,
          unlink_input/3,
          unlink_output/3,
          add_ref/3,
          delete_ref/3,
          update_linked_input_values/3
]).


%%
%% Set the Link in input attribute: ValueId
%%
-spec set_link(BlockName :: block_name(),
               Inputs :: list(input_attr()), 
               ValueId :: value_id(), 
               Link :: input_link()) -> {ok, list(input_attr())} | attrib_errors().
              
set_link(BlockName, Inputs, ValueId, Link)->
  case attrib_utils:get_attribute(Inputs, ValueId) of
    {error, not_found} -> 
      {error, not_found};
    
    % Non-array Input value
    {ok, {ValueName, {_OldValue, OldLink}}} ->
      % Unlink current link on this input (if any)
      unlink_input(BlockName, ValueId, OldLink),

      % Default the input value to 'empty'  
      NewAttribute = {ValueName, {empty, Link}},
      NewInputs = attrib_utils:replace_attribute(Inputs, ValueName, NewAttribute),
      {ok, NewInputs};
      
    % Assume this is an array value
    {ok, {ValueName, ArrayValue}} ->
      case ValueId of 
        % if this is an array value, the ValueName from get_attribute()
        % will match ValueName in the ValueId tuple
        {ValueName, ArrayIndex} ->
          if (0 < ArrayIndex) andalso (ArrayIndex =< length(ArrayValue)) ->
            {_OldValue, OldLink} = lists:nth(ArrayIndex, ArrayValue),
            unlink_input(BlockName, ValueId, OldLink),
            NewArrayValue = attrib_utils:replace_array_value(ArrayValue, ArrayIndex, {empty, Link}),
            NewInputs = attrib_utils:replace_attribute(Inputs, ValueName, 
                                                       {ValueName, NewArrayValue}),
            {ok, NewInputs};
          true ->
            {error, invalid_index}
          end;
        _InvalidValue -> 
          {error, invalid_value}
      end
  end.


%%
%% Send a link message to each block linked to the inputs of this block
%%
-spec link_blocks(BlockName :: block_name(),
                  Inputs :: list(input_attr())) -> list(input_attr()).

link_blocks(BlockName, Inputs)->
  link_blocks(BlockName, Inputs, Inputs).

link_blocks(_BlockName, [], UpdatedInputs)->
  UpdatedInputs;

link_blocks(BlockName, [Input | RemainingInputs], UpdatedInputs) ->

  case Input of
    % Non-array value
    {ValueName, {Value, Link}} ->
      NewUpdatedInputs = evaluate_link(BlockName, ValueName, Value, Link, UpdatedInputs);
      
    % Array value  
    {ValueName, ArrayValues} ->
      NewUpdatedInputs = 
          process_array_input(BlockName, ValueName, 1, ArrayValues, UpdatedInputs)
  end,                 
  link_blocks(BlockName, RemainingInputs, NewUpdatedInputs).


%%
%%  Check the link on each value of an input array value
%%
-spec process_array_input(BlockName :: block_name(),
                          ValueName :: value_name(),
                          ArrayIndex :: pos_integer(),
                          ArrayValues :: attr_value_array(),
                          UpdatedInputs :: list(input_attr())) -> list(input_attr()).

process_array_input(_BlockName, _ValueName, _ArrayIndex, [], UpdatedInputs) ->
  UpdatedInputs;
  
process_array_input(BlockName, ValueName, ArrayIndex, [ArrayValue| RemainingArrayValues], Inputs) ->
  {Value, Link} = ArrayValue,
  UpdatedInputs = evaluate_link(BlockName, {ValueName, ArrayIndex}, Value, Link, Inputs),
  process_array_input(BlockName, ValueName, (ArrayIndex+1), RemainingArrayValues, UpdatedInputs).


%%
%% Evaluate the link on this input attribute, and decide what to do
%%
-spec evaluate_link(BlockName ::block_name(), 
                    ValueId :: value_id(),
                    Value :: value(),
                    Link :: input_link(), 
                    Inputs :: list(input_attr())) -> list(input_attr()).
                  
evaluate_link(BlockName, ValueId, Value, Link, Inputs) ->

  case Link of
    ?EMPTY_LINK ->
      % Input is not linked to another block, nothing to do
      Inputs;
        
    {_LinkValueId} ->
      % Input is linked to an output of its own block  
      % TODO need to link to output without using messages or we will have deadlock?
      Inputs;
      
    {LinkBlockName, LinkValueId} ->
      % Input is linked to the output of another block on this node
      case block_utils:is_block(LinkBlockName) of
        true ->
          % Linked block exists,
          % if the block input value is empty, 
        case Value of
          empty ->
            % send a link message to the linked block, get current linked value back
            UpdatedValue = block_server:link(LinkBlockName, LinkValueId, {BlockName, ValueId}),
            
            
            case attrib_utils:set_value(Inputs, ValueId, UpdatedValue) of
              {ok, UpdatedInputs} -> 
                log_server:info(block_input_linked_to_block_output, 
                        [BlockName, ValueId, LinkBlockName, LinkValueId]),
                        
                UpdatedInputs;

              _ ->
                % Set value failed, return Inputs, unchanged
                Inputs 
            end;

          _ ->
            % Value is not empty, link must already be established, nothing to do
            Inputs
          end;

        _ ->
          % Log warning, block doesn't exist 
          % or user may have misspelled the Linked block name
          log_server:warning(linked_block_does_not_exist, [LinkBlockName]),

          % If linked block does not exist, input value should be empty
          case attrib_utils:set_value(Inputs, ValueId, empty) of
            {ok, UpdatedInputs} -> 
              UpdatedInputs;

            _ ->
              % Set value failed, return Inputs, unchanged
              Inputs
          end
      end;
         
    {NodeName, LinkBlockName, LinkValueId} ->
      % Input is linked the output of a block on another node 
      case net_kernel:connect_node(NodeName) of
        true ->
          % Connected to remote node
          case linkblox_api:is_block_name(NodeName, LinkBlockName) of
            true ->
              % Linked block exists,

              case Value of
                empty ->
                  % block input value is empty, 
                  % send a link message to the linked block, get current linked value back
                  UpdatedValue = linkblox_api:link(NodeName, LinkBlockName, LinkValueId, {node(), BlockName, ValueId}),
            
                  case attrib_utils:set_value(Inputs, ValueId, UpdatedValue) of
                    {ok, UpdatedInputs} -> 
                      log_server:info(block_input_linked_to_node_block_output, 
                                  [BlockName, ValueId, NodeName, LinkBlockName, LinkValueId]),
                      UpdatedInputs;

                    _ ->
                      % Set value failed, return Inputs, unchanged
                      Inputs 
                  end;

                _ ->
                  % Value is not empty, link must already be established, nothing to do
                  Inputs
              end;
         
            _ ->
              % Log warning, block doesn't exist 
              % or user may have misspelled the Linked block name
              log_server:warning(linked_node_block_does_not_exist, [NodeName, LinkBlockName]),

              % If linked block does not exist, input value should be empty
              case attrib_utils:set_value(Inputs, ValueId, empty) of
                {ok, UpdatedInputs} -> 
                  UpdatedInputs;

                _ ->
                  % Set value failed, return Inputs, unchanged
                  Inputs 
              end
          end;  
        _ -> 
          % Unable to connect to node, return Inputs unchanged
          log_server:warning(unable_to_connect_to_node, [NodeName]),
          Inputs 
      end;
    _ ->
      % Urecognized link return Inputs, unchanged
      log_server:error(err_unrecognized_link, [Link]),
      Inputs 
  end.


%%
%% Send an unlink message to each block linked to the inputs of this block
%%
-spec unlink_inputs(BlockName :: block_name(),
                    Inputs :: list(input_attr())) -> ok.

unlink_inputs(_BlockName, [])-> ok;

unlink_inputs(BlockName, [Input | RemainingInputs])->

  case Input of
    % Non-array value
    {ValueName, {_Value, Link}} ->
      % Note ValueName == ValueId for non-arry values
      unlink_input(BlockName, ValueName, Link);
      
    % Array value  
    {ValueName, ArrayValues} ->
      unlink_array_input(BlockName, ValueName, ArrayValues)
  end,

  unlink_inputs(BlockName, RemainingInputs).


%%
%%  Unlink each value of an input array value
%%
-spec unlink_array_input(BlockName :: block_name(),
                         ValueName :: value_name(),
                         ArrayValues :: attr_value_array()) -> ok.

unlink_array_input(BlockName, ValueName, ArrayValues) ->
  lists:foldl(fun(ArrayValue, Index) -> 
                {_Value, Link} = ArrayValue,
                % ValueName and Index form a ValueId
                unlink_input(BlockName, {ValueName, Index}, Link),
                Index+1 
                end, 
                1, ArrayValues),
  ok.

  
%%
%% Unlink one input value link
%%
-spec unlink_input(BlockName :: block_name(),
                   ValueId :: value_id(),
                   Link :: input_link()) -> ok.  
  
unlink_input(BlockName, ValueId, Link) ->

  case Link of
    ?EMPTY_LINK ->
      % Input is not linked, do nothing
      ok;

    {_LinkValueId} ->
      % TODO: Handle reference to self block
      ok;  
       
    {LinkBlockName, LinkValueId} ->
      % Input is linked to the output of another block on this node
      case block_utils:is_block(LinkBlockName) of
        true ->
          block_server:unlink(LinkBlockName, LinkValueId, {BlockName, ValueId}),
          log_server:info(block_input_unlinked_from_block_output, 
                            [BlockName, ValueId, LinkBlockName, LinkValueId]),
          ok;

        _ ->
          log_server:warning(unlink_input_linked_block_does_not_exist,[LinkBlockName]),
          ok
      end;

    {NodeName, LinkBlockName, LinkValueId} ->
      % Input is linked the output of a block on another node 
      case net_kernel:connect_node(NodeName) of
        true ->
           % Connected to remote node
          case linkblox_api:is_block_name(NodeName, LinkBlockName) of
            true ->
              % Linked block exists,
              linkblox_api:unlink(NodeName, LinkBlockName, LinkValueId, {node(), BlockName, ValueId}),
              log_server:info(block_input_unlinked_from_node_block_output, 
                            [BlockName, ValueId, NodeName, LinkBlockName, LinkValueId]),
              ok;

            _ ->
              log_server:warning(unlink_input_linked_node_block_does_not_exist, 
                                    [NodeName, LinkBlockName]),
              ok
          end;

        _ -> 
          % Unable to connect to node, do nothing
          log_server:warning(unable_to_connect_to_node, [NodeName]),
          ok
      end;

    _ ->
      % Urecognized link, nothing to do
      log_server:error(err_unrecognized_link, [Link]),
      ok
  end.


%%
%% Set the value of each input linked to another block, to 'empty'
%%
-spec empty_linked_inputs(Inputs :: list(input_attr())) -> list(input_attr()).

empty_linked_inputs(Inputs) ->
  lists:map(
    fun(Input) ->
      case Input of 
        {ValueName, {Value, Link}} ->
          case Link of
            ?EMPTY_LINK   -> {ValueName, {Value, Link}};
            _NonEmptyLink -> {ValueName, {empty, Link}}
          end;
        {ValueName, ArrayValues} ->
          {ValueName, empty_array_values(ArrayValues)}      
      end  
    end,
    Inputs).


%%
%% Set the value of each linked input in ArrayValues, to empty
%%
-spec empty_array_values(ArrayValues :: list({value(), input_link()})) -> 
                          list({value(), input_link()}).
                                
empty_array_values(ArrayValues) ->
  lists:map(
    fun({Value, Link}) -> 
      case Link of
        ?EMPTY_LINK   -> {Value, Link};
        _NonEmptyLink -> {empty, Link}
      end
    end, 
    ArrayValues).



%%
%% Set all input values linked to this output to 'empty'
%%
-spec unlink_output(BlockName :: block_name(),
                    ValueName :: value_name(),
                    Refs :: link_refs()) -> ok.  
  
unlink_output(BlockName, ValueName, Refs) ->

  block_common:update_linked_inputs(BlockName, ValueName, empty, Refs).
 

%%
%% Add Reference to the list of referenced block inputs 
%% in the ValueId output attribute
%%
-spec add_ref(Outputs :: list(output_attr()), 
              ValueId :: value_id(), 
              Reference :: link_ref()) -> list(output_attr()).

add_ref(Outputs, ValueId, Reference) ->

  case attrib_utils:get_attribute(Outputs, ValueId) of

    {error, not_found} ->
      % This block doesn't have an output 'ValueId'
      % Just return the original Outputs list
      log_server:error(add_ref_err_doesnt_exist_for_this_block, [ValueId]),
      Outputs;

    % Non-array value
    {ok, {ValueName, {Value, References}}} ->

      % Add Reference to list of block references for this output
      % If not already added, Return updated Outputs list
      case lists:member(Reference, References) of 
        false ->
          NewRefs = [Reference | References],
          NewOutput = {ValueName, {Value, NewRefs}},
          attrib_utils:replace_attribute(Outputs, ValueName, NewOutput);
        true ->
          Outputs
      end;

    % Array value
    {ok, {ValueName, ArrayValues}} ->
      % if this is an array value, the ValueName from get_attribute()
      % will match ValueName in the ValueId tuple
      {ValueName, ArrayIndex} = ValueId,
      if (0 < ArrayIndex) andalso (ArrayIndex =< length(ArrayValues)) ->
        {Value, References} = lists:nth(ArrayIndex, ArrayValues),
        % Add Reference to list of block references for this output
        % If not already added, Return updated Outputs list
        case lists:member(Reference, References) of
          false ->
            NewRefs = [Reference | References],
            NewArrayValue = {Value, NewRefs},
            NewArrayValues = attrib_utils:replace_array_value(ArrayValues, ArrayIndex, NewArrayValue),
            NewOutput = {ValueName, NewArrayValues}, 
            attrib_utils:replace_attribute(Outputs, ValueName, NewOutput);
          true ->
            Outputs
        end;
      true ->
        log_server:error(add_ref_err_invalid_array_index, [ValueId]),
        Outputs
      end
  end.


%%
%% Delete Reference from the list of References to linked blocks 
%% in the ValueId output attribute
%%
-spec delete_ref(Outputs :: list(output_attr()), 
                 ValueId :: value_id(), 
                 Reference :: link_ref()) -> list(output_attr()).

delete_ref(Outputs, ValueId, Reference) ->

  case attrib_utils:get_attribute(Outputs, ValueId) of

    {error, not_found} ->
      % This block doesn't have an output 'ValueId'
      % Just return the original Outputs list
      log_server:error(delete_ref_err_doesnt_exist_for_this_block, [ValueId]),
      Outputs;

    % Non-Array value
    {ok, {ValueName, {Value, References}}} ->  
      % Delete the Reference from the list of References to linked blocks, if it exists
      NewRefs = lists:delete(Reference, References),
      NewOutput = {ValueName, {Value, NewRefs}},
      attrib_utils:replace_attribute(Outputs, ValueName, NewOutput);

    % Array value  
    {ok, {ValueName, ArrayValues}} ->
      % if this is an array value, the ValueName from get_attribute()
      % will match ValueName in the ValueId tuple
      {ValueName, ArrayIndex} = ValueId,
      if (0 < ArrayIndex) andalso (ArrayIndex =< length(ArrayValues)) ->
        {Value, References} = lists:nth(ArrayIndex, ArrayValues),
        % Delete the Reference from the list of References to linked blocks, if it exists
        NewRefs = lists:delete(Reference, References),
        NewArrayValue = {Value, NewRefs},
        NewArrayValues = attrib_utils:replace_array_value(ArrayValues, ArrayIndex, NewArrayValue),
        NewOutput = {ValueName, NewArrayValues}, 
        attrib_utils:replace_attribute(Outputs, ValueName, NewOutput);
      true ->
        log_server:error(delete_ref_err_invalid_array_index, [ValueId]),
        Outputs
      end
  end.


%%    
%% Update the value of every input in this block linked to the 
%% 'NodeName:FromBlockName:ValueName' output value
%%
-spec update_linked_input_values(Inputs :: list(input_attr()),
                                 TargetLink :: input_link(),
                                 NewValue :: input_value()) -> list(input_attr()).

update_linked_input_values(Inputs, TargetLink, NewValue) ->

  % Update the value of each input record pointing at the given value 
  lists:map(
    fun(Input) -> 
      case Input of
        % Non-array value
        {ValueName, {_Value, Link}} ->
          case Link =:= TargetLink of
            % Matching links, update the input attribute value
            true  -> {ValueName, {NewValue, Link}};
            % Links don't match don't change the input value 
            false -> Input
          end;
        % Array value  
        {ValueName, ArrayValues} ->
          {ValueName, 
           update_linked_array_values(ArrayValues, TargetLink, NewValue)}
      end
    end, 
    Inputs).


%%
%% Update array values with a link matching TargetLink
%%
-spec  update_linked_array_values(ArrayValues :: list(), 
                                  TargetLink :: input_link(), 
                                  NewValue :: value()) -> list(). 
                                  
update_linked_array_values(ArrayValues, TargetLink, NewValue) ->
  lists:map(
    fun({Value, Link}) ->
      case Link =:= TargetLink of
        % Matching links, update the value
        true  -> {NewValue, Link};
        % Links don't match, don't change the array value
        false -> {Value, Link}
      end
    end,
    ArrayValues).


%% ====================================================================
%% Tests
%% ====================================================================

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

% ====================================================================
% Test set_link()
% 
%   Test set_link() non-array input ok
set_link_non_array_ok_test() ->
  InputAttribs = test_data:attrib_utils_input_attribs1(),
  InputValueId = number_in,
  Link = {node_name, link_block, link_output},
  ExpectedResult = {number_in, {empty, {node_name, link_block, link_output}}},
  
  {ok, NewInputAttribs} = set_link(unit_test, InputAttribs, InputValueId, Link),
  {ok, Result} = attrib_utils:get_attribute(NewInputAttribs, InputValueId), 
  ?assertEqual(ExpectedResult, Result).

% Test set_link() non-array input ok
set_link_non_array_bad_test() ->
  InputAttribs = test_data:attrib_utils_input_attribs1(),
  InputValueId = invalid_input_name,
  Link = {node_name, link_block, link_output},
  ExpectedResult = {error, not_found},
  
  Result = set_link(unit_test, InputAttribs, InputValueId, Link),
  ?assertEqual(ExpectedResult, Result).

  %   Test set_link() array input ok
set_link_array_ok_test() ->
  InputAttribs = test_data:attrib_utils_input_attribs1(),
  InputValueId = {integer_array_in, 3},
  Link = {node_name, link_block, link_output},
  ExpectedResult = {integer_array_in, [{234,{}}, {456,{}}, 
                                     {empty,{node_name, link_block, link_output}}]},
  
  {ok, NewInputAttribs} = set_link(unit_test, InputAttribs, InputValueId, Link),
  {ok, Result} = attrib_utils:get_attribute(NewInputAttribs, InputValueId), 
  ?assertEqual(ExpectedResult, Result).

% Test set_link() array input bad
set_link_array_bad_test() ->
  InputAttribs = test_data:attrib_utils_input_attribs1(),
  InputValueId = {bool_array_in, 0}, % valid input name, invalid index
  Link = {node_name, link_block, link_output},
  ExpectedResult = {error, invalid_index},
  
  Result = set_link(unit_test, InputAttribs, InputValueId, Link),
  ?assertEqual(ExpectedResult, Result).



-endif.