/****************************************************************************

NAME
   pilot_y.y --- YACC description of PILOT parser

SYNOPSIS
   int yyparse()		-- parse PILOT on stdin

DESCRIPTION
    The parser.  Expects to be able to call initlex(), yylex() and gen_*
functions corresponding to each defined command.

    This parser doesn't evaluate expressions as it goes.  Instead, it builds
node trees which get passed the the gen_* functions.  This is so the same
code can be used for both compiler and interpreter.

LICENSE
  SPDX-License-Identifier: BSD-2-Clause

****************************************************************************/
%{
#include <stdio.h>
#include <string.h>
#include <setjmp.h>
#include "pilot.h"

extern int yylineno, cmd;
extern FILE *yyin;

#define NOMEM	"out of memory\n"
#define BADATOM	"internal error, bad type in atom\n"

#define NONSTD	"this operation is not supported in IEEE 1154-1991\n"
#define NONSTANDARD	if (pedantic) yyerror(NONSTD); else

#include "gencode.h"
/*
 * Hold the strings and substitutable IDs in a text part.  The reasoning
 * behind the dimension is that there can't hardly be more of these than
 * there are characters on a line.
 */
static part textparts[MAXSTR], *tp;

/*
 * Cons nodes for expression structures.  Similar logic here.
 */
static node nodes[MAXSTR], *new = nodes;

/*
 * Label storage for JUMPMATCH handling
 */
static int njumplabs;
static variable *jumplabs[MAXJUMPS];

node *atom(type, value, var)
/* make an expression node from a part value */
int	type;	/* type of new node */
int	value;	/* part to be encapulated */
variable	*var;
{
    /* get a node */
    if (new < nodes + MAXSTR)
	new++;
    else
	yyerror(NOMEM);

    switch(new->type = type)
    {
    case NUMERIC_IDENT:
	new->value.var = var;
	break;

    case NUMBER:
	new->value.number = value;
	break;

    case YES:	/* eval() or the compiler will munch these */
    case NO:
	break;

    default:
	yyerror(BADATOM);
	break;
    }

    return(new);
}

node *cons(op, left, right)
/* make a cons for a binary operation */
int	op;		/* opcode */
node	*left, *right;	/* child nodes */
{
    /* get a node */
    if (new < nodes + MAXSTR)
	new++;
    else
	yyerror(NOMEM);

    new->type = op;
    new->left = left;
    new->right = right;

    return(new);
}

%}
%start prog

%token TYPE ACCEPT MATCH JUMP USE COMPUTE GRAPHIC KFILE REMARK END YES NO
%token JUMPMATCH TYPEH PROBLEM PAUSE LINK
%token CLEARHOME CURSADDR CLEARLINE CLEAREND SYSTEM
%token <number> NUMBER CHAR SPECIAL
%token <string> STRING ALLOC
%token <var> NUMERIC_IDENT STRING_IDENT LABEL
%token NEWLINE	10
%token COLON	':'
%token LPAREN	')'
%token RPAREN	'('
%token PLUS	'+'
%token MINUS	'-'
%token MULTIPLY	'*'
%token DIVIDE	'/'
%token MODULO	'%'
%token EQUAL	'='
%token LESS	'<'
%token GREATER	'>'
%token BANG	'!'
%token ORBAR	'|'
%token COMMA	','
%token NEQUAL
%token NOTGRT
%token NOTLESS
%token UMINUS
%token ANDAND
%token LEXERR

%type <node> condition yescond rel_exp expression term factor lablist

%left <node> '+' '-'
%left <node> '*' '/' '%'

%union
{
    int		number;
    char	*string;
    struct rav	*var;
    struct edon	*node;
}
%%	/* beginning of rules section */

/* a program description consists of a sequence of statements */
prog	:    /* EMPTY */
	|    prog statement NEWLINE
		{eolhook(); new = nodes;}
	|    prog error NEWLINE
		{yyerrok;}
	|    prog NEWLINE
	;
/*
 * a statement consists of a help request,
 * or a label, or a label followed by an executable statement
 */
statement	:    LABEL		{gen_label($1);}
		|    exec
		|    LABEL exec		{gen_label($1);}
		;

/*
 * An executable statement begins with a keyword,
 * optionally followed by a cond part,
 * followed by a colon, followed by optional arguments
 *
 * The TYPE, MATCH, GRAPHIC, FILE, YES, and NO statements take as a trailing
 * string argument everything following the colon.  For TYPE, MATCH, YES,
 * and NO, the Standard considers this argument optional, but it isn't
 * lexically possible to distinguish an omitted string from a zero-length
 * one given PILOT's ... odd ... tokenization rules.
 */
exec	:    TYPE    condition ':' text
		{gen_type($2, textparts, tp - textparts);}

	|    ACCEPT  condition ':' STRING_IDENT
		{gen_accept($2, $4, STRING_IDENT);}
	|    ACCEPT  condition ':' NUMERIC_IDENT
		{gen_accept($2, $4, NUMERIC_IDENT);}
	|    ACCEPT  condition ':'
		{gen_accept($2, (variable *)NULL, 0);}

	|    MATCH   condition ':' text
		{gen_match($2, textparts, tp - textparts);}

	|    JUMP    condition ':' LABEL
		{gen_jump($2, $4, LABEL);}
	|    JUMP    condition ':' NUMERIC_IDENT
		{NONSTANDARD {$4->type = LABEL; gen_jump($2, $4, LABEL);}}
	|    JUMP    condition ':' SPECIAL
		{gen_jump($2, (variable *)NULL, $4);}
	|    USE     condition ':' LABEL
		{gen_use($2, $4);}
	|    USE     condition ':' NUMERIC_IDENT
		{NONSTANDARD {$4->type = LABEL; gen_use($2, $4);}}

	|    COMPUTE condition ':' STRING_IDENT '=' text
		{gen_compute($2, $4, (node *)NULL, textparts, tp - textparts);}
	|    COMPUTE condition ':' NUMERIC_IDENT '=' expression
		{gen_compute($2, $4, $6, (part *)NULL, 0);}

        |    GRAPHIC condition ':' text
		{gen_graphic($2, textparts, tp - textparts);}
	|    KFILE   condition ':' text
		{gen_file($2, textparts, tp - textparts);}

	|    REMARK  condition ':' text
		/* do nothing */

	|    END     condition ':' NUMBER
		{NONSTANDARD gen_end($2, $4);}
	|    END     condition ':'
		{gen_end($2, 0);}

	|    JUMPMATCH condition ':' lablist
		{NONSTANDARD gen_jumpmatch($2, njumplabs, jumplabs);}
	|    TYPEH   condition ':' text
		{NONSTANDARD gen_typeh($2, textparts, tp - textparts);}
	|    PROBLEM condition ':' text
		{NONSTANDARD gen_problem($2, textparts, tp - textparts);}
	|    PAUSE   condition ':' expression
		{NONSTANDARD gen_pause($2, $4);}
	|    LINK    condition ':' text
		{NONSTANDARD gen_link($2, textparts, tp - textparts);}
	|    CLEARHOME condition ':'
		{NONSTANDARD gen_clearhome($2);}
	|    CURSADDR condition ':' NUMBER ',' NUMBER
		{NONSTANDARD gen_cursaddr($2, $4, $6);}
	|    CLEARLINE condition ':'
		{NONSTANDARD gen_clearline($2);}
	|    CLEAREND condition ':'
		{NONSTANDARD gen_clearend($2);}
	|    SYSTEM  condition ':' text
		{NONSTANDARD gen_system($2, textparts, tp - textparts);}
	;

/* LABEL is defined in the lexical analyzer */
lablist	:    LABEL
		{njumplabs = 0; jumplabs[njumplabs++] = $1;}
	|    lablist ',' LABEL
		{jumplabs[njumplabs++] = $3;}
	;

/* process the guard parts of statements */
condition	:    /*EMPTY*/			{$$ = (node *)NULL;}
		|    yescond			{$$ = $1;}
		|    yescond '(' rel_exp ')'	{$$ = cons(ANDAND, $1, $3);}
		|    '(' rel_exp ')'		{$$ = $2;}
		;

yescond	:    YES		{$$ = atom(YES, 0, (variable *)NULL);}
	|    NO			{$$ = atom(NO, 0, (variable *)NULL);}
	;

rel_exp	:    NUMERIC_IDENT
		{$$ = atom(NUMERIC_IDENT, 0, $1);}
	|    expression '<' expression		{$$ = cons(LESS, $1, $3);}
	|    expression '>' expression		{$$ = cons(GREATER, $1, $3);}
	|    expression '=' expression		{$$ = cons(EQUAL, $1, $3);}
	|    expression '<' '>' expression	{$$ = cons(NEQUAL, $1, $4);}
	|    expression '<' '=' expression	{$$ = cons(NOTGRT, $1, $4);}
	|    expression '>' '=' expression	{$$ = cons(NOTLESS, $1, $4);}
	;

expression	:   term			{$$ = $1;}
		|   term '+' term		{$$ = cons(PLUS, $1, $3);}
		|   term '-' term		{$$ = cons(MINUS, $1, $3);}
		;

term	:   factor			{$$ = $1;}
	|   '-' factor	%prec '*'
		{NONSTANDARD cons(UMINUS, 0, $2);}
	|   factor '*' factor		{$$ = cons(MULTIPLY, $1, $3);}
	|   factor '/' factor		{$$ = cons(DIVIDE, $1, $3);}
	|   factor '%' factor
		{NONSTANDARD $$ = cons(MODULO, $1, $3);}
	;

factor	:   '(' expression ')'	{$$ = $2;}
	|   NUMERIC_IDENT	{$$ = atom(NUMERIC_IDENT, 0, $1);}
	|   NUMBER		{$$ = atom(NUMBER, $1, (variable *)NULL);}
	;

text	:   /* EMPTY */
		{tp = textparts;}
	|   text STRING
 		{tp->type = STRING; tp->part.string = $2; tp++;}
	|   text ALLOC
 		{tp->type = ALLOC; tp->part.string = $2; tp++;}
	|   text NUMBER
 		{tp->type = NUMBER; tp->part.number = $2; tp++;}
	|   text CHAR
 		{tp->type = CHAR; tp->part.number = $2; tp++;}
	|   text STRING_IDENT
 		{tp->type = STRING_IDENT; tp->part.var = $2; tp++;}
	|   text NUMERIC_IDENT
 		{tp->type = NUMERIC_IDENT; tp->part.var = $2; tp++;}
	;

%%

/* pilot.y ends here */
