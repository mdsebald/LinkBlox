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
          %is_block/1,
          is_string/1,
          sleep/1,
          char_to_segments/2,
          get_blocks_to_save/0,
          save_blocks_to_file/2,
          load_blocks/1,
          load_blocks_from_file/1,
          create_blocks/1,
          create_block/1,
          get_blocks_from_file/1,
          update_all_blocks/0
]). 


%%
%% Is BlockName a valid block?
%%
% -spec is_block(BlockName :: block_name()) -> boolean().

% is_block(BlockName)->
%   lists:member(BlockName, block_supervisor:block_names()).


%%
%% Is list a printable string?
%%
-spec is_string(List :: list()) -> boolean().

is_string([]) -> true;
is_string(List) when is_list(List) -> lists:all(fun isprint/1, List);
is_string(_) -> false.

isprint(X) when X >= 32, X < 127 -> true;
isprint(_) -> false.


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
       _ -> DecPntSeg = 16#00
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
-spec get_blocks_to_save() -> [any()]. 

get_blocks_to_save() -> 
  BlockValuesList = block_values(),
  
  Clean = fun(BlockState) -> clean_block_values(BlockState) end,
  CleanedBlockValuesList = lists:map(Clean, BlockValuesList),
  
  Format = fun(Term) -> io_lib:format("~tp.~n", [Term]) end,
  lists:map(Format, CleanedBlockValuesList).


-ifdef(STANDALONE).
% Embedded version, load or save file in "/root" folder
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
      case file:write_file(TargetFileName, BlockData) of
        ok ->
          m_logger:info(block_config_saved_to_file, [TargetFileName]),
          ok;

        {error, Reason} -> 
          m_logger:error(err_saving_block_config_file, [Reason, TargetFileName]),
          {error, Reason}
      end;
    {error, Reason} ->
      m_logger:error(err_no_directory_saving_block_config_file, [Reason, TargetFileName]),
      {error, Reason}
  end.


%%
%% Load the blocks definitions onto this node
%%
-spec load_blocks(BlockDefnList :: list(block_defn())) -> ok.

load_blocks(BlockDefnList) ->
  create_blocks(BlockDefnList),
  ok.


%%
%% Load the blocks in Filename, on this node, onto this node
%%
-spec load_blocks_from_file(FileName :: string()) -> ok | {error, atom()}.

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
      m_logger:info(opening_block_values_config_file, [TargetFileName]),
      {ok, BlockDefnList};
 
    {error, Reason} ->
      m_logger:error(err_reading_block_config_file, [Reason, TargetFileName]),
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
      m_logger:info(block_created, [BlockName]);
    {error, Reason} -> 
      m_logger:error(err_creating_block, [Reason, BlockName])
  end,
  create_blocks(RemainingBlockDefnList). 


%%
%% Create a block from the given BlockDefn
%%
-spec create_block(BlockDefn :: block_defn()) -> ok | {error, atom()}.

create_block(BlockDefn) ->
  case BlockDefn of
    {Config, _Inputs, _Outputs} ->
      {BlockName, BlockModule, Version} = config_utils:name_module_version(Config),
      % Check if this block type, exists on this node
      case type_utils:module_exists(BlockModule) of
        true ->
          % Check if a block with this name is already created on this node
          case block_supervisor:is_block(BlockName) of
            false ->
              % Compare the block code and block data versions, upgrade if different
              case BlockModule:version() /= Version of 
                true ->
                  case BlockModule:upgrade(BlockDefn) of
                    {ok, UpdBlockDefn} ->
                      case block_supervisor:start_block(UpdBlockDefn) of
                        {ok, _Pid}      -> ok;
                        {error, Reason} -> {error, Reason}
                      end;
                    {error, Reason} -> {error, Reason}
                  end;
                false ->
                  % Block code and block data versions are the same, just start the block
                  case block_supervisor:start_block(BlockDefn) of
                    {ok, _Pid}      -> ok;
                    {error, Reason} -> {error, Reason}
                  end
              end;
            _ -> {error, block_exists}
          end;
        _ -> {error, invalid_block_type}
      end;
    _ -> {error, invalid_block_values}
  end.


%%
%% Send an update message to each block on this node
%%
-spec update_all_blocks() -> ok.

update_all_blocks() ->
  BlockNames = block_supervisor:block_names(),
  lists:foreach(fun(BlockName) ->
                  block_server:update(BlockName)
                end, BlockNames).


%% ====================================================================
%% Internal functions
%% ====================================================================

%
% Get the list of block values for all of the blocks currently created
%
block_values() ->
  block_values(block_supervisor:block_names(), []).
    
block_values([], BlockValuesList) -> 
  BlockValuesList;
 
block_values(BlockNames, BlockValuesList) ->
  [BlockName | RemainingBlockNames] = BlockNames,
  {Config, Inputs, Outputs, _Private} = block_server:get_block(BlockName),
  BlockState = {Config, Inputs, Outputs},
  block_values(RemainingBlockNames, [BlockState | BlockValuesList]).


%
% Make block values suitable for saving to a file 
%
clean_block_values({Config, Inputs, Outputs}) ->
  % Clean block values of calculated Output values
  EmptyOutputs = output_utils:update_all_outputs(Outputs, empty, no_input),
 
  % Reset input values to their default values.  
  % Current values could be from links, i.e. dynamic, and should not be saved.
  DefaultInputs = input_utils:set_to_defaults(Inputs),

  % Cleaned block values
  {Config, DefaultInputs, EmptyOutputs}.
