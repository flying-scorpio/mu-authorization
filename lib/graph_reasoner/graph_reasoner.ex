defmodule GraphReasoner do
  @non_graph_symbols [:Prologue,
                      :SelectClause,
                      :DatasetClause, # When everything is moved to
                                      # specific grahps, the
                                      # DatasetClause will have no
                                      # impact, hence it may be
                                      # considered a non_graph_symbol
                      :SolutionModifier,
                      :ValuesClause]
  @accepted_symbols [:Sparql,
                     :QueryUnit,
                     :Query,
                     # Query
                     {:Prologue,:deep},
                     :SelectQuery,
                     {:ValuesClause,:deep}, # Can only supply data, not request it
                     # SelectQuery
                     {:SelectClause,:deep}, # Will change when we start introducing new variables
                     {:DatasetClause,:deep}, # Will not impact when we discovered everything
                     :WhereClause,
                     {:SolutionModifier,:deep},
                     # WhereClause
                     :GroupGraphPattern,
                     :GroupGraphPatternSub, # We drop subselect
                     :TriplesBlock, # We drop GraphPatternNotTriples for now
                     :TriplesSameSubjectPath, # We may need to constrain the simplicity of TriplesBlock and TriplesSameSubjectPath
                     {:VarOrTerm,:deep}, # We will inspect what we understand of this as we develop, but drop TriplesNodePath
                     :PropertyListPathNotEmpty, # We will only accept a single statement for now
                     # PropertyListPathNotEmpty,
                     {:VerbSimple,:deep}, # these are variables
                     {:VerbPath,:deep}, # we will not accept complex paths, but this is simply a deep structure on which we mostly need to place cardinality constraints
                     :ObjectList,:Object,:GraphNode,:VarOrTerm, # We drop TriplesNode
                     :ObjectListPath,:ObjectPath,:GraphNodePath,#:VarOrTerm <- we already have this one
                    ]

  @moduledoc """
  Combines the parsed SELECT query with access rights and figures out
  where GRAPH statements can be used to simplify the posed query.

  Keeps track of which elements could be converted and is able to
  report back this information.  This allows us to know which queries
  could be fully dismantled, helping us identify which ACL
  configuration helped answer the query and which didn't.
  """

  @doc """
  Verifies whether or not the query is valid.  Yields truethy iff the
  query may be processed by the GraphReasoner.  If this does not yield
  truethy, the query contain content which is not understood yet.
  """
  def is_acceptable_query( match ) do
    case Manipulators.Basics.map_matches( match, fn (item) ->
          case item do
            %InterpreterTerms.SymbolMatch{ symbol: symbol } ->
              case Enum.find_value( @accepted_symbols, fn (accepted_symbol) ->
                    case accepted_symbol do
                      { ^symbol, :deep } ->
                        IO.inspect( accepted_symbol, label: "Skipping for this symbol" )
                        { :skip }
                      ^symbol ->
                        IO.inspect( accepted_symbol, label: "Continuing on this symbol" )
                        { :continue }
                      _ ->
                        false
                    end
                  end )
                do
                nil ->
                  IO.inspect( symbol, label: "Could not find this symbol in accepted_symbols" )
                  { :exit, false } # we did not find a match in the accepted_symbols
                map_matches_command -> map_matches_command
              end
            _ ->
              # It is not a SymbolMatch, hence we should continue
              { :continue }
          end
        end )
      do
      { :exit, value } -> value # the value here should always be false
      _ -> true
    end
  end

  defp mark_non_graph_clauses( match ) do
    Manipulators.Basics.map_matches match, fn (item) ->
      case item do
        # TODO YOU WERE DEVVING HERE, ADD THE NON-GRAPH SYMBOLS
        %InterpreterTerms.SymbolMatch{ symbol: symbol } when symbol in @non_graph_symbols ->
          new_item = ExternalInfo.put symbol, GraphReasoner, :non_graph_clause, true
          { :replace_and_traverse, new_item }
        _ -> { :continue }
      end
    end
  end

  defp may_be_graph_clause_p( match )do
    # We only know this can't be a graph clause if we have explicitly
    # determined it to be so.
    if ExternalInfo.has_var?( match, GraphReasoner, :non_graph_clause ) do
      not ExternalInfo.get( match, GraphReasoner, :non_graph_clause )
    else
      true
    end
  end

end
