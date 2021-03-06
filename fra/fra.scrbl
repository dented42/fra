#lang scribble/doc
@(require (for-label racket/set
                     "main.rkt"
                     racket/base)
          scribble/manual)

@title{Functional Relational Algebra}
@author{@(author+email "Jay McCarthy" "jay@racket-lang.org")}

@defmodule[fra]

This package provides a purely functional implementation of @link["http://en.wikipedia.org/wiki/Relational_algebra"]{Relational Algebra} in Racket.

@section{Examples}

@(require scribble/eval)
@(define the-eval
  (let ([the-eval (make-base-eval)])
    (the-eval `(require racket/base
                        fra))
    the-eval))

In this example, we will build a relational database for a university grade book. First, we define a database with a few relations:

@racketblock+eval[#:eval the-eval
 (define GradebookDB
   (Database
    [Students
     [StudentId Name Course]
     (0 "Jonah" 'CS330)
     (1 "Aidan" 'CS142)
     (2 "Sarah" 'CS630)]
    [Projects
     [ProjectId Course Title]
     (0 'CS330 "Garbage Collectors")
     (1 'CS330 "Prolog")
     (2 'CS142 "UFO")
     (3 'CS630 "Theorem Prover")]
    [Grades
     [StudentId ProjectId Grade]
     [0 0 2/3]
     [1 2 99]
     [2 3 -inf.0]]))
 ]

At this point @racket[GradebookDB] is bound to a value obeying @racket[database/c] that contains three relations: @racket['Students], @racket['Projects], and @racket['Grades]. The first S-expression after each relation identifier is the @racket[schema/c] for that relation. Each S-expression after that is a @racket[Tuple] that is in the relation. As you can see, any Scheme value can be included in a tuple.

Let's do some queries!

@defs+int[#:eval the-eval
 ((require racket/set)
  (define (print-relation r)
    (for ([c (in-list (relation-schema r))])
      (printf "~a\t" c))
    (printf "~n")
    (for ([t (in-set (relation-tuples r))])
      (for ([i (in-range 0 (tuple-length t))])
        (printf "~a\t" (tuple-ref t i)))
      (printf "~n"))))
 (with-database GradebookDB
  (print-relation 
   (execute-query
    (query-relation 'Students))))
]

As you can see from this interaction, a relation is just a set of tuples, which are a vector-like abstraction. Now for some more interesting queries:

@defs+int[#:eval the-eval
 ((define (>30 n)
    (> 30 n)))
 (with-database GradebookDB
  (print-relation 
   (execute-query
    (query-selection 
     (Proposition (>30 Grade))
     (query-relation 'Grades)))))
]

Proposition can be any Scheme value that may be applied.

Suppose that we attempted to use that proposition on a relation that did not have @racket['Grade] in its schema?

@interaction[#:eval the-eval
 (with-database GradebookDB
  (query-selection 
   (Proposition (>30 Grade))
   (query-relation 'Students)))
]

As you can see, the error is detected before the query is ever run.

Now, let's have some joins:

@interaction[#:eval the-eval
 (with-database GradebookDB
  (print-relation
   (execute-query
    (query-rename
     'Title 'Project
     (query-projection
      '(Name Course Title Grade)
      (query-natural-join
       (query-relation 'Projects)
       (query-natural-join
        (query-relation 'Grades)
        (query-relation 'Students))))))))
]

Finally, some functional database modification:

@interaction[#:eval the-eval
 (with-database GradebookDB
  (print-relation
   (execute-query (query-relation 'Students))))
 (define GradebookDB+1
   (database-insert 
    GradebookDB 'Students
    (Tuple 3 "Omega" (lambda () ((lambda (x) (x x)) (lambda (x) (x x)))))))
 (with-database GradebookDB+1
  (print-relation
   (execute-query (query-relation 'Students))))
 (define GradebookDB+2
   (database-delete
    GradebookDB+1 'Students
    (Tuple 0 "Jonah" 'CS330)))
 (with-database GradebookDB+2
  (print-relation
   (execute-query (query-relation 'Students))))
]

@section{API}

This section documents the APIs of the package.

@subsection{Schemas}

Schemas are defined as lists of symbols.

@defthing[schema/c contract?]{
 Equivalent to @racket[(listof symbol?)].
}

@subsection{Propositions}

Propositions are used by @racket[query-selection] to compute sub-relations.

@defproc[(prop? [v any/c])
         boolean?]{
 Returns @racket[#t] if @racket[v] is a proposition, @racket[#f] otherwise.
}
                  
@defproc[(make-prop:or [lhs prop?] [rhs prop?]) prop?]
@defproc[(make-prop:and [lhs prop?] [rhs prop?]) prop?]
@defproc[(make-prop:not [p prop?]) prop?]
@defproc[(make-prop:op [op procedure?] [cols (listof symbol?)]) prop?]

Propositions constructors.
                  
@defform/subs[#:literals (not or and) (Proposition p)
                         ([p (not p)
                             (and p p)
                             (or p p)
                             (proc attribute ...)])
                         #:contracts
                         ([proc procedure?]
                          [attribute identifier?])]{
 Returns a proposition. The interpretation of @racket[not], @racket[and], and @racket[or] is standard.
 When a procedure is included in a proposition, the values of the named attributes are extracted from the tuple
 and applied to the procedure value; if it returns @racket[#t], then the tuple is selected, otherwise it is rejected.
}

@subsection{Queries}

Queries are used by @racket[execute-query] to run relational queries.

@defproc[(query? [v any/c])
         boolean?]{
 Returns @racket[#t] if @racket[v] is a query, @racket[#f] otherwise.
}
                  
@defthing[database-schema/c contract?]{
 Equivalent to @racket[(-> symbol? schema/c)].
}

@defthing[current-database-schema (parameter/c database-schema/c)]{
 Used by @racket[query-schema] to determine the schema of @racket[query-relation] queries.
}

@defproc[(query-schema [q query?])
         schema/c]{
 Returns the schema of the relation @racket[q] computes.
}
                  
@defproc[(query-relation [rid symbol?])
         query?]{
 Query of the relation @racket[rid].
}
                
@deftogether[
 [@defproc[(query-union [q1 query?] [q2 query?]) query?]
 @defproc[(query-difference [q1 query?] [q2 query?]) query?]
 @defproc[(query-intersection [q1 query?] [q2 query?]) query?]
 @defproc[(query-product [q1 query?] [q2 query?]) query?]
 @defproc[(query-projection [s schema/c] [q query?]) query?]
 @defproc[(query-selection [p prop?] [q query?]) query?]
 @defproc[(query-rename [old-attr symbol?] [new-attr symbol?] [q query?]) query?]
 @defproc[(query-rename* [renaming (hash/c symbol? symbol?)] [q query?]) query?]
 @defproc[(query-natural-join [q1 query?] [q2 query?] [equal? (any/c any/c . -> . boolean?) equal?]) query?]
 @defproc[(query-theta-join [p prop?] [q1 query?] [q2 query?]) query?]
 @defproc[(query-semi-join [q1 query?] [q2 query?]) query?]
 @defproc[(query-anti-join [q1 query?] [q2 query?]) query?]
 @defproc[(query-division [q1 query?] [q2 query?]) query?]
 @defproc[(query-left-outer-join [q1 query?] [q2 query?]) query?]
 @defproc[(query-right-outer-join [q1 query?] [q2 query?]) query?]
 @defproc[(query-outer-join [q1 query?] [q2 query?]) query?]]
]{
  These construct queries represent the basic operations of @link["http://en.wikipedia.org/wiki/Relational_algebra"]{relational algebra}.
        
  @racket[query-rename*] applies multiple renamings at once using the dictionary to map old names to new names.
  
  @racket[query-natural-join] takes an optional @racket[equal?] argument to compare attribute values for equality.
}

@subsection{Tuples}

Tuples are the contents of relations.

@defproc[(tuple? [v any/c])
         boolean?]{
 Returns @racket[#t] if @racket[v] is a tuple, @racket[#f] otherwise.
}
                  
@defproc[(tuple-length [t tuple?])
         exact-nonnegative-integer?]{
 Returns the length of @racket[t].
}
                                    
@defproc[(tuple-ref [t tuple?]
                    [i exact-nonnegative-integer?])
         any/c]{
 Returns the @racket[i]th element of @racket[t].
}
      
@defproc[(tuple [elem any/c] ...)
         tuple?]{
 Returns a tuple that contains all the @racket[elem]s.
}
                        
@defform[(Tuple elem ...)
         #:contracts
         ([elem any/c])]{
 Returns a tuple that contains all the @racket[elem]s.
}

@subsection{Relations}

Relations are the contents of databases and the results of queries.

@defproc[(relation? [v any/c])
         boolean?]{
 Returns @racket[#t] if @racket[v] is a relation, @racket[#f] otherwise.
}

@defproc[(relation-schema [r relation?]) schema/c]{
 Returns @racket[r]'s schema.
}

@defproc[(relation-tuples [r relation?]) (set? tuple?)]{
 Returns the set of tuples comprising the relation @racket[r].
}

@defform[(Relation [attribute ...]
                   (elem ...)
                   ...)
         #:contracts
         ([attribute identifier?]
          [elem any/c])]{
 Returns a relation with @racket['(attribute ...)] as its schema that contains each @racket[(Tuple elem ...)] as its tuples.
}

@subsection{Database}

@defthing[database/c contract?]{
 Equivalent to @racket[(hash/c symbol? relation? #:immutable #t)].
}

@defproc[(database-insert [db database/c] [rid symbol?] [t tuple?])
         database/c]{
 Returns a database that is identical to @racket[db], except @racket[t] is in the relation @racket[rid].
}

@defproc[(database-delete [db database/c] [rid symbol?] [t tuple?])
         database/c]{
 Returns a database that is identical to @racket[db], except @racket[t] is @emph{not} in the relation @racket[rid].
}

@defproc[(call-with-database [db database/c] [thnk (-> any)])
         any]{
 Executes @racket[(thnk)] with @racket[db] as the current database.
}
                           
@defform[(with-database db e ...)
         #:contracts
         ([db database/c])]{
 Executes @racket[(begin e ...)] with @racket[db] as the current database.
}
                           
@defproc[(execute-query [q query?])
         relation?]{
 Computes the relation specified by @racket[q] using the current database (chosen by @racket[with-database]).
}
                   
@defthing[NULL any/c]{
 The NULL value that is inserted by the evaluation of @racket[query-left-outer-join], @racket[query-right-outer-join], or @racket[query-outer-join].
}
                   
@defform[(Database
          [relation
           [attribute ...]
           (elem ...)
           ...]
          ...)
         #:contracts
         ([relation identifier?]
          [attribute identifier?]
          [elem any/c])]{
 Returns a database with each @racket['relation] specified as 
 @racketblock[
 (Relation [attribute ...]
           (elem ...)
           ...)
 ]
}

@section{Implementation Notes}

The current implementation uses immutable hashes as relations, vectors as tuples (except that they can be efficient appended), and lists as schemas.
Propositions are structures, but are compiled to procedures (with attribute identifiers resolved to tuple positions) prior to query execution.

@racket[execute-query] uses a @link["http://en.wikipedia.org/wiki/Relational_algebra#Use_of_algebraic__properties_for_query_optimization"]{simple query optimizer}.
It has two passes: first it tries to push selection operations to the leaves of the query to reduce relation sizes prior to products, then it pulls selection operations towards the root (but not passed products) to reduce the number of iterations over all the elements of a tuple. During both passes, some simplifications are performed, such as merging adjacent renamings, projections, and identical (or trivial) selections. This optimization happens independent of any statistics about relation sizes, etc.
