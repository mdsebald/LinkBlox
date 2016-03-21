%%%
%%% @doc 
%%% User Interface for LinkBlox app.
%%% @end
%%%

-module(lblx_ui_main).

-author("Mark Sebald").

-include("../block_state.hrl"). 


%% ====================================================================
%% API functions
%% ====================================================================
-export([block_names/0, block_status/0, ui_loop/0]).


%%
%%  UI input loop
%%

ui_loop() ->
    Raw1 = io:get_line("LinkBlox> "),
    Raw2 = string:strip(Raw1, right, 10), % Remove new line char
    Raw3 = string:strip(Raw2), % Remove leading and trailing whitespace
    
    % Split up the string into command and parameter words
    CmdAndParams = string:tokens(Raw3, " "),  
    
    if 0 < length(CmdAndParams) ->
        [Cmd | Params] = CmdAndParams,
        CmdLcase = string:to_lower(Cmd),
        
        case CmdLcase of
            "create"    -> ui_create_block(Params);
            "execute"   -> ui_execute_block(Params);
            "delete"    -> ui_delete_block(Params);
            "disable"   -> ui_disable_block(Params);
            "enable"    -> ui_enable_block(Params);
            "freeze"    -> ui_freeze_block(Params);
            "thaw"      -> ui_thaw_block(Params);
            "set"       -> ui_set_value(Params);
            "link"      -> ui_link_blocks(Params);
            "status"    -> ui_status(Params);
            "types"     -> ui_block_types(Params);
            "load"      -> ui_load_blocks(Params);
            "save"      -> ui_save_blocks(Params);
            "help"      -> ui_help(Params);
            "exit"      -> ui_exit(Params);
            
            _Unknown    -> io:format("Error: Unknown command: ~p~n", [Raw3])
        end;
    true -> ok
    end,
    ui_loop().

% Process block create command
ui_create_block(Params) ->
   case length(Params) of  
        0 -> io:format("Error: Enter block type and name~n");
        1 -> io:format("Error: Enter block type and name~n");
        2 -> 
            [BlockTypeStr, BlockNameStr] = Params,
            BlockName = list_to_atom(BlockNameStr),
            case is_block_type(BlockTypeStr) of
                true ->
                    BlockModule = lblx_types:block_type_to_module(BlockTypeStr), 
                    case is_block_name(BlockName) of
                        false ->
                            BlockValues = BlockModule:create(BlockName),
                            case block_supervisor:create_block(BlockValues) of
                                {ok, _Pid} -> 
                                    io:format("Block ~s:~s Created~n", [BlockTypeStr, BlockNameStr]);
                                {error, Reason} -> 
                                    io:format("Error: ~p creating block ~s:~s ~n", [Reason, BlockTypeStr, BlockNameStr])
                            end;
                        true ->
                            io:format("Error: Block ~s already exists~n", [BlockNameStr])
                    end;
                false -> io:format("Error: Block type ~s is not a valid block type~n", [BlockTypeStr])
            end;
        _ -> io:format("Error: Too many parameters~n")
    end.    


% Process manual block execute command
 ui_execute_block(Params) ->
    case validate_block_name(Params) of
        error     -> ok;  % Params was not a block name
        BlockName ->
             block_server:execute(BlockName),
            ok
    end.


% Process block delete command
 ui_delete_block(Params) ->
    case validate_block_name(Params) of
        error     -> ok;  % Params was not a block name
        BlockName ->
            % TODO: Ask the user if they really want to delete
            block_server:delete(BlockName),
            block_utils:sleep(1000),
            case block_supervisor:delete_block(BlockName) of
                ok -> 
                    io:format("~p Deleted~n", [BlockName]),
                    ok;
            
                {error, Reason} ->
                    io:format("Error: ~p deleting ~p~n", [Reason, BlockName]) 
            end
    end.
    
    
% Process disable block command
ui_disable_block(Params) ->
    case validate_block_name(Params) of
        error     -> ok;  % Params was not a block name
        BlockName ->  
            block_server:set_value(BlockName, disable, true),
            ok
    end. 


% Process enable block command
ui_enable_block(Params) ->
    case validate_block_name(Params) of
        error     -> ok;  % Params was not a block name
        BlockName ->  
            block_server:set_value(BlockName, disable, false),
            ok
    end. 
    
    
% Process freeze block command
ui_freeze_block(Params) ->
    case validate_block_name(Params) of
        error     -> ok;  % Params was not a block name
        BlockName ->  
            block_server:set_value(BlockName, freeze, true),
            ok
    end. 

    
% Process thaw block command
ui_thaw_block(Params) ->
    case validate_block_name(Params) of
        error     -> ok;  % Params was not a block name
        BlockName ->  
            block_server:set_value(BlockName, freeze, false),
            ok
    end. 


% Process block status command
ui_status(Params) ->
    case length(Params) of  
        0 -> block_status();
        
        _ -> io:format("Error: Too many parameters~n")
    end.
 
 
% Process the set value command
ui_set_value(Params) ->
    case length(Params) of  
        0 -> io:format("Error: Enter block name, attribute name, and value~n");
        1 -> io:format("Error: Enter block name, attribute name, and value~n");
        2 -> io:format("Error: Enter block name, attribute name, and value~n");
        3 -> 
            [BlockNameStr, ValueNameStr, ValueStr] = Params,
            BlockName = list_to_atom(BlockNameStr),
            
            case is_block_name(BlockName) of
                true -> 
                    ValueName = list_to_atom(ValueNameStr),
                    case block_server:get_value(BlockName, ValueName) of
                        not_found ->
                            io:format("Error: ~s is not a value of block ~s~n", 
                                      [ValueNameStr, BlockNameStr]);
                        _CurrentValue ->
                            NewValue = list_to_atom(ValueStr),
                            block_server:set_value(BlockName, ValueName, NewValue)        
                    end;
                false -> 
                    io:format("Error: Block ~s does not exist~n", [BlockNameStr])
            end;
        _ -> io:format("Error: Too many parameters~n")
    end.    


% Process link blocks command
ui_link_blocks(_Params) ->
    io:format("Not Implemented~n").


% Process the load blocks command
ui_load_blocks(_Params) ->
    io:format("Not Implemented~n").


% Process the save blocks command
ui_save_blocks(_Params) ->
    io:format("Not Implemented~n").


% Process the help command
ui_help(_Params) ->
    io:format("Not Implemented~n").


% Process exit command
ui_exit(_Params) ->
    io:format("Not Implemented~n").


%%
%% Display status off each running block
%%
block_status() ->
    io:fwrite("~n~-16s ~-16s ~-12s ~-12s ~-12s ~-15s~n", 
                  ["Block Type", "Block Name", "Output", "Status", "Exec Method", "Last Exec"]),
    io:fwrite("~16c ~16c ~12c ~12c ~12c ~15c~n", [$-, $-, $-, $-, $-, $-] ), 
    block_status(block_names()).
    
block_status([]) ->
    io:format("~n"), 
    ok;

block_status([BlockName | RemainingBlockNames]) ->
    BlockType = block_server:get_value(BlockName, block_type),
    Value = block_server:get_value(BlockName, value),
    Status = block_server:get_value(BlockName, status),
    ExecMethod = block_server:get_value(BlockName, exec_method),
    {Hour, Minute, Second, Micro} = block_server:get_value(BlockName, last_exec),
    
    LastExecuted = io_lib:format("~2w:~2..0w:~2..0w.~6..0w", [Hour,Minute,Second,Micro]),
    
    io:fwrite("~-16s ~-16s ~-12w ~-12w ~-12w ~-15s~n", 
              [string:left(BlockType, 16), 
               string:left(io_lib:write(BlockName), 16), 
               Value, Status, ExecMethod, LastExecuted]),
    block_status(RemainingBlockNames).


% validate Params is one valid block name
validate_block_name(Params) ->
    case length(Params) of
        1 ->
            [BlockNameStr] = Params,
            BlockName = list_to_atom(BlockNameStr),
            % check if block name is an existing block
            case is_block_name(BlockName) of
                true  -> BlockName;
                false ->
                    io:format("Error: Block ~p does not exist~n", [BlockName]),
                    error
             end;
        0 ->
            io:format("Error: No block name specified~n"),
            error;
        _ ->
            io:format("Error: Too many parameters~n"),
            error
    end.


% Is block name  an existing block
is_block_name(BlockName) -> lists:member(BlockName, block_names()).

% Is block type an existing block type
is_block_type(BlockTypeStr) -> 
    lists:member(BlockTypeStr, lblx_types:block_type_names()).


%% 
%% Get the block names of currently running processes
%%
block_names() -> 
    block_names(block_supervisor:block_processes(), []).    
    
block_names([], BlockNames) -> 
    BlockNames;
    
block_names([BlockProcess | RemainingProcesses], BlockNames) ->
    % Only return block names of processes that are running
    case element(2, BlockProcess) of
        restarting -> NewBlockNames = BlockNames;
        undefined  -> NewBlockNames = BlockNames;
        _Pid       ->
            BlockName = element(1, BlockProcess),
            NewBlockNames = [BlockName | BlockNames]
    end,
    block_names(RemainingProcesses, NewBlockNames).


%%
%% Get list of the block type names and versions
%%
ui_block_types(_Params) ->
   BlockTypes = lblx_types:block_types_info(),
   
   % Print the list of type names version
   io:fwrite("~n~-16s ~-8s ~-60s~n", 
                  ["Block Type", "Version", "Description"]),
   io:fwrite("~16c ~8c ~60c~n", [$-, $-, $-] ), 
   
   lists:map( fun({TypeName, Version, Description}) -> 
              io:fwrite("~-16s ~-8s ~-60s~n", 
                         [string:left(TypeName, 16), 
                          string:left(Version, 8),
                          string:left(Description, 60)]) end, 
                      BlockTypes),
   io:format("~n").
        
    
    
%get_module_attribute(Module,Attribute) ->
%
%    case beam_lib:chunks(Module, [attributes]) of
%
%        { ok, { _, [ {attributes,Attributes} ] } } ->
%            case lists:keysearch(Attribute, 1, Attributes) of
%                { value, {Attribute,[Value]} } -> Value;
%                false                          -> { error, no_such_attribute }
%            end;
%
%        { error, beam_lib, { file_error, _, enoent} } ->
%            { error, no_such_module }
%
%    end.     

