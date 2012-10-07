%%% Copyright (c) 2007, 2008, 2009 JackNyfe, Inc. <info@jacknyfe.net>.
%%% See the accompanying LICENSE file.

-module(perftest).
-export([comprehensive/2, sequential/2, sequentialTimings/2, parallel/3]).

comprehensive(Cycles, F) ->
	sequential(round(Cycles/10), F),	% Warming up 1
	sequential(round(Cycles/5), F),	% Warming up 2
	timer:sleep(500),
	A = sequential(Cycles, F),
	B = parallel(2, Cycles, F),
	C = parallel(4, Cycles, F),
	D = parallel(10, Cycles, F),
	E = parallel(100, Cycles, F),
	[A,B,C,D,E].

sequential(Cycles, F) ->
	perftest("Sequential", Cycles,
		fun () -> executeMultipleTimes(Cycles, F) end).

sequentialTimings(Cycles, F) ->
	[ begin S = now(), F(), E = now(), timer:now_diff(E, S) end || _ <- lists:seq(1, Cycles) ].

parallel(Parallel, Cycles, F) ->
	perftest("Parallel " ++ integer_to_list(Parallel), Cycles, fun () ->
		CyclesPerPid = round(Cycles/Parallel),
		DriverPid = self(),
		executeMultipleTimes(Parallel, fun() ->
			spawn_link(fun() ->
				executeMultipleTimes(CyclesPerPid, F),
				DriverPid ! finished
				end)
			end),
		collectMessages(Parallel, finished)
	end).

perftest(Name, Cycles, F) ->
	{_, StartSecs, StartMS} = now(),
	F(),
	{_, StopSecs, StopMS} = now(),
	MS = (StopSecs * 1000 + StopMS / 1000)
		- (StartSecs * 1000 + StartMS / 1000),
	CPS = round(1000 * Cycles / MS),
	io:format("~s ~p cycles in ~~~p seconds (~p cycles/s)~n",
		[Name, Cycles, round(MS / 1000), CPS]),
	CPS.

executeMultipleTimes(0, _F) -> ok;
executeMultipleTimes(N, F) -> F(), executeMultipleTimes(N - 1, F).

collectMessages(0, _) -> ok;
collectMessages(N, Msg) -> receive Msg -> collectMessages(N - 1, Msg) end.
