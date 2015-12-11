-module(wiregate).

-export([test/2]).

-define(SCHEMA_ID, 1).
-define(WG_VERSION, 1).

-define(CRED_SIZE, 20).

-define(INT64_NULL, 18446744073709551615).

-define(WG_ESTABLISH, 5000).
-define(WG_ESTABLISH_ACK, 5001).
-define(WG_SEQUENCE, 5006).

send_pkt(TmplId, BinPkt, Socket) ->
	Size = byte_size(BinPkt),
	PktWithHdr = <<Size:16/little, TmplId:16/little, (?SCHEMA_ID):16/little, (?WG_VERSION):16/little, BinPkt/binary >>,
	io:format("~p~n", [PktWithHdr]),
	ok = gen_tcp:send(Socket, PktWithHdr).


gen_establish(Hbt, Cred) ->
	Timestamp = 0, %TODO
	CredLength = length(Cred),
	BinCred = list_to_binary(Cred ++ lists:duplicate(?CRED_SIZE - CredLength, 0)),
	<< Timestamp:64/little, Hbt:32/little, BinCred/binary>>.


gen_sequence(NextSeqNo) ->
	<< NextSeqNo:64/little >>.

gen_hbt() ->
	gen_sequence(?INT64_NULL).

read_hdr(Socket) ->
	{ok, <<Size:16/little, TmplId:16/little, SchemaId:16/little, Version:16/little>>} = gen_tcp:recv(Socket, 8),
	{Size, TmplId, SchemaId, Version}.

read_pkt(Socket) ->
	{Size, TmplId, ?SCHEMA_ID, ?WG_VERSION} = read_hdr(Socket),
	{ok, BinPkt} = gen_tcp:recv(Socket, Size),
	{TmplId, BinPkt}.


parse_pkt({?WG_ESTABLISH_ACK, BinPkt}) ->
	<< Timestamp:64/little, Hbt:32/little, NextSeqNo:64/little>> = BinPkt,
	{establish_ack, Timestamp, Hbt, NextSeqNo};
parse_pkt({?WG_SEQUENCE, BinPkt}) ->
	<< NextSeqNo:64/little>> = BinPkt,
	{sequence, NextSeqNo};
parse_pkt({TmplId, BinPkt}) ->
	{raw, TmplId, BinPkt}.


test(Host, Port) ->
	{ok, Socket} = gen_tcp:connect(Host, Port, [binary, {packet, 0}, {active, false}]),
	EstPkt = gen_establish(1000, "xxx"),
	send_pkt(?WG_ESTABLISH, EstPkt, Socket),
	{establish_ack, _, _, NextSeqNo} = parse_pkt(read_pkt(Socket)),
	send_pkt(?WG_SEQUENCE, gen_sequence(NextSeqNo), Socket),
	parse_pkt(read_pkt(Socket)).





