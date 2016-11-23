%%% @doc 
%%% Common Block utility functions     
%%%               
%%% @end 

-module(block_utils).

-author("Mark Sebald").

-include("block_state.hrl").

%% ====================================================================
%% API functions
%% ====================================================================

-export([
          is_block/1,
          sleep/1,
          char_to_segments/2,
          get_blocks_to_save/0,
          save_blocks_to_file/2,
          load_blocks_from_file/1,
          create_blocks/1,
          create_block/1,
          get_blocks_from_file/1
]). 

%%
%% Is BlockName a valid block?
%%
-spec is_block(BlockName :: block_name())-> boolean().

is_block(BlockName)->
  lists:member(BlockName, block_supervisor:block_names()).

%%
%% common delay function
%%
-spec sleep(T :: pos_integer()) -> ok.

sleep(T) ->
  receive
  after T -> ok
  end.


%%
%% Convert a character to a byte indicating which segments
%% of a 7 segment display should be turned on.
%% Set the 0x80 bit of the segments byte, 
%% if the decimal point should be turned on. 
%%
-spec char_to_segments(Char:: char(), 
                       DecPnt :: boolean()) -> byte().

char_to_segments(Char, DecPnt) ->

  % -------------------------------------------------------
  % LED Segment ON:  a  |  b |  c | d  |  e |  f |  g | dp  
  % Segments Value: 0x01|0x02|0x04|0x08|0x10|0x20|0x40|0x80
  % --------------------------------------------------------
  
  CharToSegs = 
   [{$0,16#3F}, {$1,16#06}, {$2,16#5B}, {$3,16#4F}, {$4,16#66}, {$5,16#6D}, 
    {$6,16#7D}, {$7,16#07}, {$8,16#7F}, {$9,16#6F}, 
    {$A,16#77}, {$b,16#7C}, {$C,16#39}, {$d,16#5E}, {$E,16#79}, {$F,16#71},
    {32,16#00}, {$-,16#40}],
  
  case DecPnt of
    true -> DecPntSeg = 16#80;
    false -> DecPntSeg = 16#00
  end,
  
  case lists:keyfind(Char, 1, CharToSegs) of
    false -> % No character match found, just return the decimal point segment
      DecPntSeg; 
    {Char, Segments} -> % Combine the 7 segments with the decimal point segment
      (Segments bor DecPntSeg)
  end.


%%
%% Get the block values for all of the blocks 
%% Format to make the values suitable for saving to a file 
%% i.e. Strip private and calculated data
%% 

% TODO:  Add LinkBlox specific header (and checksum?) to config file
-spec get_blocks_to_save() -> term(). 

get_blocks_to_save() -> 
  BlockValuesList = block_values(),
  
  Clean = fun(BlockValues) -> clean_block_values(BlockValues) end,
  CleanedBlockValuesList = lists:map(Clean, BlockValuesList),
  
  Format = fun(Term) -> io_lib:format("~tp.~n", [Term]) end,
  lists:map(Format, CleanedBlockValuesList).


-ifdef(STANDALONE).
% Embedded version, load or save file in "/root" partition
-define(CONFIG_FOLDER, "/root/").

-else.
% Hosted version, load or save file in the default app folder
% TODO: Look at options for manipulating file name in the Erlang filename library
-define(CONFIG_FOLDER, "").

-endif.


%%
%% Save the formatted list of block values to a file
%% Block data must be from the get_blocks_to_save() function
%%
-spec save_blocks_to_file(FileName :: string(),
                          BlockData :: term()) -> ok | {error, atom()}.

save_blocks_to_file(FileName, BlockData) ->
  TargetFileName = ?CONFIG_FOLDER ++ FileName,
  case filelib:ensure_dir(TargetFileName) of
    ok ->       
      case file:write_file(FileName, BlockData) of
        ok ->
          error_logger:info_msg("Block config saved to file: ~s~n", [TargetFileName]),
          ok;

        {error, Reason} -> 
          error_logger:error_msg(" ~p saving block config file: ~s~n", [Reason, TargetFileName]),
          {error, Reason}
      end;
    {error, Reason} ->
      error_logger:error_msg(" ~p saving block config file: ~s~n", [Reason, TargetFileName]),
      {error, Reason}
  end.


%%
%% Load the blocks in Filename, on this node, onto this node
%%
-spec load_blocks_from_file(FileName :: string) -> ok | {error, atom()}.

load_blocks_from_file(FileName) ->
  case get_blocks_from_file(FileName) of
    {ok, BlockDefnList} ->
      create_blocks(BlockDefnList),
      ok;
    {error, Reason} ->
      {error, Reason}
  end.


%%
%% Get the formatted list of block values from a file
%%
% TODO: Check header and checksum, when implemented

-spec get_blocks_from_file(FileName :: string()) -> {ok, term()} | {error, atom()}.

get_blocks_from_file(FileName) ->
  TargetFileName = ?CONFIG_FOLDER ++ FileName,

  % file:consult() turns a text file into a set of Erlang terms
  case file:consult(TargetFileName) of
    {ok, BlockDefnList} ->
      error_logger:info_msg("Opening block Values config file: ~p~n", [TargetFileName]),
      {ok, BlockDefnList};
 
    {error, Reason} ->
      error_logger:error_msg("~p error, reading block config file: ~p~n", [Reason, TargetFileName]),
      {error, Reason}
  end.

%%
%% Create blocks from a list of block values
%%
-spec create_blocks(BlockDefnList :: list(block_defn())) -> ok.

create_blocks([]) -> ok;

create_blocks(BlockDefnList) ->
  [BlockDefn | RemainingBlockDefnList] = BlockDefnList,
  {Config, _Inputs, _Outputs} = BlockDefn,
  BlockName = config_utils:name(Config),
  case create_block(BlockDefn) of
    ok -> 
      error_logger:info_msg("Block ~p Created~n", [BlockName]);
    {error, Reason} -> 
      error_logger:error_msg("Error: ~p creating block ~p~n", [Reason, BlockName])
  end,
  create_blocks(RemainingBlockDefnList). 


%%
%% Create a block from the given BlockDefn
%%
-spec create_block(BlockDefn :: block_defn()) -> ok | {error, atom()}.

create_block(BlockDefn) ->
  case BlockDefn of
    {Config, _Inputs, _Outputs} ->
      % TODO: Check the BlockDefn version against the local block module code version
      {BlockName, BlockModule, _Version} = config_utils:name_module_version(Config),
      % Check if this block type, exists on this node
      case lists:member(BlockModule, block_types:block_type_modules()) of
        true ->
          case block_utils:is_block(BlockName) of
            false ->
              case block_supervisor:start_block(BlockDefn) of
                {ok, _Pid} -> 
                  ok;
                {error, Reason} -> 
                  {error, Reason}
              end;
            _ ->
              {error, block_exists}
          end;
        _ ->
          {error, invalid_block_type}
      end;
    _ ->
      {error, invalid_block_values}
  end.


%% ====================================================================
%% Internal functions
%% ====================================================================

%%
%% Get the list of block values for all of the blocks currently created
%%
block_values() ->
  block_values(block_supervisor:block_names(), []).
    
block_values([], BlockValuesList) -> 
  BlockValuesList;
 
block_values(BlockNames, BlockValuesList) ->
  [BlockName | RemainingBlockNames] = BlockNames,
  {Config, Inputs, Outputs, _Private} = block_server:get_block(BlockName),
  BlockValues = {Config, Inputs, Outputs},
  block_values(RemainingBlockNames, [BlockValues | BlockValuesList]).


%%
%% Clean block values of linked Input and calculated Output values,
%% to make the block values suitable for saving to a file 
%%
clean_block_values({Config, Inputs, Outputs}) ->
  EmptyInputs = link_utils:empty_linked_inputs(Inputs),
  EmptyOutputs = output_utils:update_all_outputs(Outputs, empty, empty),
  EmptyOutputs1 = output_utils:clear_output_refs(EmptyOutputs),
 
  % Cleaned block values
  {Config, EmptyInputs, EmptyOutputs1}.
