%%%
%%% @doc 
%%% LinkBlox Application Main Supervisor
%%% @end
%%%

-module(linkblox_supervisor).

-author("Mark Sebald").

-behaviour(supervisor).

-export([
          init/1,
          start_link/1
]).

%% ====================================================================
%% API functions
%% ====================================================================

start_link(BlockValuesFile) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, BlockValuesFile).

%% ====================================================================
%% Behavioural functions
%% ====================================================================

%% ====================================================================
%% init/1
%% ====================================================================
-spec init(Args :: term()) -> Result when
  Result :: {ok, {SupervisionPolicy, [ChildSpec]}} | ignore,
  SupervisionPolicy :: {RestartStrategy, MaxR :: non_neg_integer(), MaxT :: pos_integer()},
  RestartStrategy :: one_for_all
           | one_for_one
           | rest_for_one
           | simple_one_for_one,
  ChildSpec :: {Id :: term(), StartFunc, RestartPolicy, Type :: worker | supervisor, Modules},
  StartFunc :: {M :: module(), F :: atom(), A :: [term()] | undefined},
  RestartPolicy :: permanent
           | transient
           | temporary,
  Modules :: [module()] | dynamic.

init(BlockValuesFile) ->
  
  % Start the UI loop,
  % TODO: Is there a better way to do this?  Should this be controled by a config value?
  % TODO: Don't start local UI.  Work through SSH CLI, for now
  %  spawn(ui_main, init, []),

  % Start the SSH CLI UI
  % TODO: Should be configurable,
  %       SSH port number,
  %       system_dir,
  %       Dont' start on embedded (Nerves build) devices.
  %       Used because we get a nice shell UI experience, 
  %       (i.e command history, line editing, tab completion, etc)
  ui_ssh_cli:start(1111, [{system_dir, "/home/vagrant/ssh_host"}]),

  % API Server Spec
  ApiServerSpec = #{id => linkblox_api, 
                    restart => transient,
                    start => {linkblox_api, start, []},
                    type => worker},
  
  % Block Supervisor Spec
  BlockSupervisorSpec = #{id => block_supervisor, 
                          restart => transient,
                          start => {block_supervisor, start_link, [BlockValuesFile]},
                          type => supervisor},
                   
  SupFlags = #{strategy => one_for_one, intensity => 1, period => 5},
          
  {ok, {SupFlags, [ApiServerSpec, BlockSupervisorSpec]}}.


%% ====================================================================
%% Internal functions
%% ====================================================================
