/*  $Id$

    Part of SWI-Prolog RDF parser

    Author:  Jan Wielemaker
    E-mail:  jan@swi.psy.uva.nl
    WWW:     http://www.swi.psy.uva.nl/projects/SWI-Prolog/
    Copying: LGPL-2.  See the file COPYING or http://www.gnu.org

    Copyright (C) 1990-2000 SWI, University of Amsterdam. All rights reserved.
*/

:- module(rdf_triple,
	  [ rdf_triples/2,		% +Parsed, -Tripples
	    rdf_triples/3,		% +Parsed, -Tripples, +Tail
	    rdf_reset_ids/0		% Reset gensym id's
	  ]).
:- use_module(library(gensym)).


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Convert the output of xml_to_rdf/3  from   library(rdf)  into  a list of
triples of the format described   below. The intermediate representation
should be regarded a proprietary representation.

	rdf(Subject, Predicate, Object).

Where `Subject' is

	# Atom
	The subject is a resource
	
	# each(URI)
	URI is the URI of an RDF Bag
	
	# prefix(Pattern)
	Pattern is the prefix of a fully qualified Subject URI

And `Predicate' is

	# rdf:Predicate
	RDF reserved predicate of this name

	# Namespace:Predicate
	Predicate inherited from another namespace

	# Predicate
	Unqualified predicate

And `Object' is

	# Atom
	URI of Object resource

	# rdf:URI
	URI section in the rdf namespace (i.e. rdf:'Bag').

	# literal(Value)
	Literal value (Either a single atom or parsed XML data)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%	rdf_triples(+Term, -Tripples[, +Tail])
%
%	Convert an object as parsed by rdf.pl into a list of rdf/3
%	triples.  The identifier of the main object created is returned
%	by rdf_triples/3.
%
%	Input is the `content' of the RDF element in the format as
%	generated by load_structure(File, Term, [dialect(xmlns)]).
%	rdf_triples/3 can process both individual descriptions as
%	well as the entire content-list of an RDF element.  The first
%	mode is suitable when using library(sgml) in `call-back' mode.

rdf_triples(RDF, Tripples) :-
	rdf_triples(RDF, Tripples, []).

rdf_triples([]) --> !,
	[].
rdf_triples([H|T]) --> !,
	rdf_triples(H),
	rdf_triples(T).
rdf_triples(Term) -->
	triples(Term, _).

%	triples(-Tripples, -Id, +In, -Tail)
%
%	DGC set processing the output of xml_to_rdf/3.  In Id, the identifier
%	of the main description or container is returned.

triples(container(Type, Id, Elements), Id) --> !,
	{ container_id(Type, Id)
	},
	[ rdf(Id, rdf:type, rdf:Type)
	],
	container(Elements, 1, Id).
triples(description(Type, IdAbout, BagId, Props), Id) -->
	{ nonvar(BagId), !,
	  phrase(triples(description(Type, IdAbout, _, Props), Id), Triples)
	},
	list(Triples),
	reinify(Triples, BagId).
triples(description(description, IdAbout, _, Props), Subject) --> !,
	{ description_id(IdAbout, Subject)
	},
	properties(Props, 1, Subject).
triples(description(Type, IdAbout, _, Props), Subject) -->
	{ description_id(IdAbout, Subject),
	  name_to_type_uri(Type, TypeURI)
	},
	[ rdf(Subject, rdf:type, TypeURI)
	],
	properties(Props, 1, Subject).
triples(unparsed(Data), Id) -->
	{ gensym('Error__', Id),
	  print_message(error, rdf(unparsed(Data)))
	},
	[].


name_to_type_uri(NS:Local, URI) :- !,
	atom_concat(NS, Local, URI).
name_to_type_uri(URI, URI).

		 /*******************************
		 *	    CONTAINERS		*
		 *******************************/

container([], _, _) -->
	[].
container([H0|T0], N, Id) -->
	li(H0, N, Id),
	{ NN is N + 1
	},
	container(T0, NN, Id).

li(li(Nid, V), _, Id) --> !,
	[ rdf(Id, rdf:Nid, V)
	].
li(V, N, Id) -->
	triples(V, VId), !,
	{ atom_concat('_', N, Nid)
	},
	[ rdf(Id, rdf:Nid, VId)
	].
li(V, N, Id) -->
	{ atom_concat('_', N, Nid)
	},
	[ rdf(Id, rdf:Nid, V)
	].
	
container_id(_, Id) :-
	nonvar(Id), !.
container_id(Type, Id) :-
	atom_concat(Type, '__', Base),
	gensym(Base, Id).


		 /*******************************
		 *	    DESCRIPTIONS	*
		 *******************************/

description_id(Id, Id) :-
	var(Id), !,
	gensym('Description__', Id).
description_id(about(Id), Id).
description_id(id(Id), Id).
description_id(each(Id), each(Id)).
description_id(prefix(Id), prefix(Id)).

properties([], _, _) -->
	[].
properties([H0|T0], N, Subject) -->
	property(H0, N, NN, Subject),
	properties(T0, NN, Subject).

%	property(Pred = Object, N, NN, Subject)
%	property(id(Id, Pred = Object), N, NN, Subject)
%	
%	Generate triples for {Subject, Pred, Object}. In the second
%	form, reinify the statement.  Also generates triples for Object
%	if necessary.

property(Pred0 = Object, N, NN, Subject) --> % inlined object
	triples(Object, Id), !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	[ rdf(Subject, Pred, Id)
	].
property(Pred0 = Object, N, NN, Subject) --> !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	[ rdf(Subject, Pred, Object)
	].
%property(id(Id, Pred0 = Object), N, NN, Subject) -->
%	{ phrase(triples(Object, ObjectId), ObjectTriples), !,
%	  li_pred(Pred0, Pred, N, NN)
%	},
%	list(ObjectTriples),
%	[ rdf(Subject, Pred, ObjectId)
%	],
%	reinify(ObjectTriples, Id),
%	[ rdf(Subject, Pred, Id)
%	].
property(id(Id, Pred0 = Object), N, NN, Subject) -->
	triples(Object, ObjectId), !,
	{ li_pred(Pred0, Pred, N, NN)
	},
	[ rdf(Subject, Pred, ObjectId),
	  rdf(Id, rdf:type, rdf:'Statement'),
	  rdf(Id, rdf:subject, Subject),
	  rdf(Id, rdf:predicate, Pred),
	  rdf(Id, rdf:object, ObjectId)
	].
property(id(Id, Pred0 = Object), N, NN, Subject) -->
	{ li_pred(Pred0, Pred, N, NN)
	},
	[ rdf(Subject, Pred, Object),
	  rdf(Id, rdf:type, rdf:'Statement'),
	  rdf(Id, rdf:subject, Subject),
	  rdf(Id, rdf:predicate, Pred),
	  rdf(Id, rdf:object, Object)
	].

%	li_pred(+Pred, -Pred, +Nth, -NextNth)
%	
%	Transform rdf:li predicates into _1, _2, etc.

li_pred(rdf:li, rdf:Pred, N, NN) :- !,
	NN is N + 1,
	atom_concat('_', N, Pred).
li_pred(Pred, Pred, N, N).
	

		 /*******************************
		 *	   REINIFICATION	*
		 *******************************/

reinify(Triples, BagId) -->
	{ container_id('Bag', BagId)
	},
	[ rdf(BagId, rdf:type, rdf:'Bag')
	],
	reinify_elements(Triples, 1, BagId).

reinify_elements([], _, _) -->
	[].
reinify_elements([rdf(Subject, Pred, Object)|T], N, BagId) -->
	{ statement_id(Id),
	  atom_concat('_', N, ElAttr),
	  NN is N + 1
	},
	[ rdf(Id, rdf:type, rdf:'Statement'),
	  rdf(Id, rdf:subject, Subject),
	  rdf(Id, rdf:predicate, Pred),
	  rdf(Id, rdf:object, Object),
	  rdf(BagId, rdf:ElAttr, Id)
	],
	reinify_elements(T, NN, BagId).


statement_id(Id) :-
	nonvar(Id), !.
statement_id(Id) :-
	gensym('Statement__', Id).


		 /*******************************
		 *	     DCG BASICS		*
		 *******************************/

list(Elms, List, Tail) :-
	append(Elms, Tail, List).


		 /*******************************
		 *	       UTIL		*
		 *******************************/

%	rdf_reset_ids
%
%	Utility predicate to reset the gensym counters for the various
%	generated identifiers.  This simplifies debugging and matching
%	output with the stored desired output (see rdf_test.pl).

rdf_reset_ids :-
	reset_gensym('Bag__'),
	reset_gensym('Seq__'),
	reset_gensym('Alt__'),
	reset_gensym('Description__'),
	reset_gensym('Statement__').
