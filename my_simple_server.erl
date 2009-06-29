-module(my_simple_server).

-import(elib1_webkit, [pre/1, mime/1, forever/0,get_file/1,classify/1]).
-import(lists, [reverse/1,sort/1]).

-compile(export_all).

start([AP,AD]) ->
    Port = list_to_integer(atom_to_list(AP)),
    Dir = atom_to_list(AD),
    Env = [],
    elib1_webkit:
	start_fold_server(2068,
			  fun(Tag, Uri, Args, State) ->
				  io:format("handle:~p ~p ~p~n",[Tag,Uri,Args]),
				  handle(Tag, Uri, Args, Dir, State)
			  end,
			  Env),
    forever().

is_prefix([], _) -> true;
is_prefix([H|T1], [H|T2]) -> is_prefix(T1, T2);
is_prefix(_, _) -> false.

version_list(Id, Dir) ->    
    {ok, L} = file:list_dir(Dir),
    L1 = order([filename:rootname(I) || I <- L, is_prefix(Id, I)]),
    [H|L2] = reverse(L1),
    [load_content(H)| [load_content(I) || I <- L2]].
   
order(L) ->
    L1 = sort([{guid_to_list(I),I}||I <- L]),
    [J || {_,J} <- L1].

next_rev(X) ->
    [Doc,RevStr] = string:tokens(X,"v"),
    Rev = list_to_integer(RevStr),
    Doc  ++ "v" ++ integer_to_list(Rev + 1).

document(X) ->
    [Doc|_] = string:tokens(X, "d"),
    Doc.

guid_to_list(L) ->
    [list_to_integer(I) || I <- string:tokens(L, "_vd")].

load_content(I) ->
    ["<a href='#' onclick=\"load_content('",I,"');\">",
     I,"</a><br>"].

handle(_, "/get_versions", [{"id",Id}], Dir, E) -> 
    %% return a list of all filenames with this prefix
    H = version_list(Id, Dir),
    {response, html, H, E};
handle(_, "/load_content", [{"id",Id}], Dir, E) -> 
    {ok, Bin} = file:read_file(Full = Id ++ ".html"),
    M = io_lib:format("~p", [filelib:last_modified(Full)]),
    %% check if the next version is free
    Id1 = next_rev(Id),
    io:format("Id=~p next=~p~n",[Id,Id1]),
    Edit = not filelib:is_file(Id1 ++ ".html"),
    Ret = rfc4627:encode({obj,[{"guid",list_to_binary(Id)},
			       {"edit", Edit},
			       {"mod", list_to_binary(M)},
			       {"val",Bin}]}),
    {response, json, Ret, E};

handle(_, "/save_content", [{"id",Id},{"value",Val}], Dir, E) -> 
    Id1 = next_rev(Id),
    Full = Id1 ++ ".html",
    Ret = case filelib:is_file(Full) of
	      false ->
		  io:format("Saving to:~p~n",[Full]),
		  file:write_file(Full, [Val]),
		  M = io_lib:format("~p",[filelib:last_modified(Full)]),
		  
		  Stem = document(Id1),
		  Vsns = version_list(Stem, Dir),
		  rfc4627:encode({obj,[{"guid",list_to_binary(Id1)},
				       {"versions", list_to_binary(Vsns)},
				       {"edit", true},
				       {"mod", list_to_binary(M)},
				       {"val",list_to_binary(Val)}]});
	      true ->
		  %% nned to create a cloan ..
		  rfc4627:encode({obj,[{"guid",<<"error">>},
				       {"val",<<"cloan">>}]})
	  end,
    {response, json, Ret, E};
handle(Op, File, Args, _, S) ->
    io:format("Op=~p File=~p Args=~p~n",[Op, File, Args]),
    case elib1_webkit:serve_static_file_report_error("." ++ File) of
	{response,Type,Val} ->
	    {response,Type,Val,S};
	{error, C} ->
	    {error, C, S}
    end.

