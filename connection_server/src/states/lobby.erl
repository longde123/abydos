-module(lobby).

% API
-export([
    event/2
    ]).

-include("protocol.hrl").

-include("char.hrl").
-record(state, {socket, account, charinfo}).
-record(charinfo, {id, pid}).

event(<<?GET_CHAR_LIST>>, State) ->
    {ok, CharSrv} = application:get_env(charsrv),
    CharList = rpc:call(CharSrv, charsrv, get_list, [State#state.account]),
    send_char_list(CharList, State),
    {noreply, lobby, State};

event(<<?CHAR_LOGIN, IdLen/integer, Id:IdLen/binary>>, State) ->
    Result = rpc:call(start_area@christian, libplayer.srv, login, 
        [self(), Id]),
    case Result of
        {ok, {pid, Pid}, {id, Id}} ->
            error_logger:info_report([{char_login_success, Id}]),
            CharInfo = #charinfo{id=Id, pid=Pid},
            NewState = State#state{charinfo=CharInfo},
            IdLen = byte_size(Id),
            {reply,<<?CHAR_LOGIN_SUCCESS, IdLen, Id/binary>> , playing, 
                NewState};
        {error, Reason} ->
            error_logger:error_report([{error, Reason}]),
            {reply, <<?CHAR_LOGIN_FAIL>>, lobby, State};
        Other ->
            error_logger:error_report([{unexpected_message, Other}])
    end;

event(<<?CHAR_LOGIN>>, State) ->
    %{ok, CharSrv} = application:get_env(charsrv),
    %{ok, CharData} = rpc:call(CharSrv, charsrv, retreive_char, 
	%	[{char_id, Id}]),
    %NewCharData = CharData#char{conn=self()},
    %Result = rpc:call(NewCharData#char.area, libplayer.player_funs, login, 
    %    [NewCharData]),

    {ok, DefaultAreaSrv} = application:get_env(default_areasrv),
    Result = rpc:call(DefaultAreaSrv, libplayer.srv, create, 
        [self()]),
    case Result of
        {ok, {pid, Pid}, {id, Id}} ->
            error_logger:info_report([{char_login_success, Id}]),
            CharInfo = #charinfo{id=Id, pid=Pid},
            NewState = State#state{charinfo=CharInfo},
            IdLen = byte_size(Id),
            {reply,<<?CHAR_LOGIN_SUCCESS, IdLen, Id/binary>> , playing, 
                NewState};
        {error, Reason} ->
            error_logger:error_report([{error, Reason}]),
            {reply, <<?CHAR_LOGIN_FAIL>>, lobby, State};
        Other ->
            error_logger:error_report([{unexpected_message, Other}])
    end;

event(Event, State) ->
    error_logger:info_report([{unknown_event, Event}]),
    {reply, unknown_command, lobby, State}.

send_char_list([], _State) ->
    done;

send_char_list([{Id, Name} | CharList], #state{socket=Socket} = State) ->
    % CharId must be a binary.
    IdLen = byte_size(Id),
    NameLen = byte_size(Name),
    connection:socket_send(Socket, <<?NOTIFY_CHAR_AVAILABLE,
        IdLen, Id/binary, NameLen, Name/binary>>),
    send_char_list(CharList, State).

