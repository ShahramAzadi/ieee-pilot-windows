%{
/*****************************************************************************

NAME
    pilot.l -- lexical analysis for IEEE PILOT

DESCRIPTION
   This module provides a yylex() suitable for a PILOT interpreter or
compiler.  Before the first call to yylex(), the initialization
function yyinit() should be invoked.

   It expects to be able to call a makevar() routine that enders an ID
of a given type in a symbol table.  It also expects to be able to call
an options() function to interpret directives.

LICENSE
  SPDX-License-Identifier: BSD-2-Clause

******************************************************************************/

/*LINTLIBRARY*/
#include <ctype.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>

#include "pilot.h"
#include "gencode.h"

#define NOMEM	"out of memory\n"
#define BADCHAR	"lexical error, token buffer is: "
#define NOCONT	"colon continuation is not supported in IEEE 1154-1991\n"
#define SYNERR	"syntax or lexical error in %s\n"

#define NONSTANDARD	if (pedantic) REJECT
#define SYSVAR(n)	yylval.var = makevar(n, yytext); return(n)

#define YY_USE_PROTOS	/* for FLEX */

/*******************************************************************
 *
 * Lexical analysis
 *
 ******************************************************************/

extern int verbose;		/* compiler verbosity level */

bool	multerr;		/* allow multiple errors per parse? */

/* used for error tracking */
int yyerrors;			/* error count */
int yylineno;			/* source line count */
char yyfile[PATH_MAX];		/* current source file */

/*
 * These funky state variables are necessary because PILOT isn't
 * really a free-format, token-based language.
 *
 * In order to handle the continuation syntax properly, the lexer needs to
 * con the parser into thinking it sees the last keyword when none is 
 * supplied.
 */
int keyword;			/* last keyword processed */
bool continuation;		/* syntactic continuation? */

static bool lexcont = TRUE;	/* seen a command keyword on this line? */

/* used for label tracking */
static long lineaddr;

static int grabline(char *, int);	/* use to get input lines */
static void pushlex(int class);		/* push a lexical state for processing */

#define YY_INPUT(buf, res, len)		res = grabline(buf, len)
#define YY_DECL 			int gettok(void)

char *strlwr(char *s)
{
    register char *cp;

    for (cp = s; *cp; cp++)
        *cp = tolower(*cp);

    return s;
}

/*
 * The production for the second form of string identifier token should
 * really have been written {ID}\$, but this tickles some obscure bug
 * in lex.  We settle for [a-zA-Z][A-Za-z0-9]+\$ instead.
 */

extern void dump_string(char *, FILE *);
extern variable *makevar();
extern char *strsave();

/* actions to take on encountering a keyword */
#define KEYWORD(n)	{lexcont = FALSE; return(keyword = n);}

static void goto_state(int state, const char *explanation)
{
    BEGIN state;
    if (yy_flex_debug)
	(void)fprintf(stderr, "--entering lexer state %s\n", explanation);
}

static const char *state_name(int state);

static void after_colon(void);

#define GOTO_STATE(_State)	goto_state((_State), state_name((_State)))

static int afterneststate;	/* State after outmost nested paremtheses. */
static int nestlevel = 0;	/* Level of parenthesis nesting. */

static int aftercolstate;	/* State after colon. */

static int assignstate;		/* State after COMPUTE asssignment. */
static bool eqisassign;		/* "=" sign after colon is assignment */

%}


%s	start expression literal skiptoend

ID		[a-zA-Z][a-zA-Z0-9]*	
NONSPECIALS	[ "&';@A-Z^_`a-z{}~-]+	

%%

<start>^[ \t]*:			{
    if (pedantic)
	yyerror(NOCONT);
    continuation = TRUE;
    lexcont = FALSE;
    pushlex(':');
    after_colon();
    return(keyword);
}
<start>^[ \t]+			{}

<start>t|type|T|TYPE		{aftercolstate = literal; KEYWORD(TYPE);}
<start>a|accept|A|ACCEPT	{aftercolstate = expression; KEYWORD(ACCEPT);}
<start>m|match|M|MATCH		{aftercolstate = literal; KEYWORD(MATCH);}
<start>j|jump|J|JUMP		{aftercolstate = expression; KEYWORD(JUMP);}
<start>u|use|U|USE		{aftercolstate = expression; KEYWORD(USE);}
<start>c|compute|C|COMPUTE	{aftercolstate = expression; KEYWORD(COMPUTE);}
<start>g|graphic|G|GRAPHIC	{aftercolstate = literal; KEYWORD(GRAPHIC);}
<start>f|file|F|FILE		{aftercolstate = literal; KEYWORD(KFILE);}
<start>r|remark|R|REMARK	{aftercolstate = literal; KEYWORD(REMARK);}
<start>e|end|E|END		{aftercolstate = expression; KEYWORD(END);}

<start>y|yes|Y|YES	{
    if (!lexcont)		/* Y command */
	return(YES);
    else
    {
	pushlex(YES);
	lexcont = FALSE;
	aftercolstate = literal;
	return(TYPE);	/* equivalent to TY */
    }
}
<start>n|no|N|NO	{
    if (!lexcont)		/* N command */
	return(NO);
    else
    {
	pushlex(NO);
	lexcont = FALSE;
	aftercolstate = literal;
	return(TYPE);	/* equivalent to TN */
    }
}

<start>pa|pause|PA|PAUSE		{aftercolstate = expression; KEYWORD(PAUSE);}
<start>pr|problem|PR|PROBLEM		{aftercolstate = literal; KEYWORD(PROBLEM);}
<start>l|link|L|LINK			{aftercolstate = literal; KEYWORD(LINK);}
<start>ch|clearhome|CH|CLEARHOME	{aftercolstate = expression; KEYWORD(CLEARHOME);}
<start>ca|cursaddr|CA|CURSADDR		{aftercolstate = expression; KEYWORD(CURSADDR);}
<start>cl|clearline|CL|CLEARLINE	{aftercolstate = expression; KEYWORD(CLEARLINE);}
<start>ce|clearend|CE|CLEAREND		{aftercolstate = expression; KEYWORD(CLEAREND);}
<start>jm|jumpmatch|JM|JUMPMATCH	{aftercolstate = expression; KEYWORD(JUMPMATCH);}
<start>th|typehang|TH|TYPEHANG		{aftercolstate = literal; KEYWORD(TYPEH);}
<start>xs|system|XS|SYSTEM		{aftercolstate = literal; KEYWORD(SYSTEM);}

<expression>[0-9]+		{yylval.number = atoi(yytext); return(NUMBER);}

<start,expression>\*{ID}	{
    strlwr(yytext);
    yylval.var = makevar(LABEL, yytext + 1);
    if (YYSTATE == start)
    {
	yylval.var->v.label.addr = lineaddr;
	yylval.var->v.label.lineno = yylineno;
    }
    return(LABEL);
}

<expression>{ID}	{
    strlwr(yytext);
    if (keyword == COMPUTE)
    {
	assignstate = expression;
    }
    if (keyword == JUMPMATCH && YYSTATE == expression)
    {
	yylval.var = makevar(LABEL, yytext);
	return(LABEL);
    }
    else
    {
	yylval.var = makevar(NUMERIC_IDENT, yytext);
	return(NUMERIC_IDENT);
    }
}

<start,expression>:	{
    after_colon();
    if (lexcont)	/* no keyword seen on this line; return last one */
    {
	if (pedantic)
	    yyerror(NOCONT);
	continuation = TRUE;
	lexcont = FALSE;
	pushlex(':');
	return(keyword);
    }
    else		/* we may need to begin literal parsing */
    {
	return(':');
    }
}
<expression>=		{
    if (eqisassign)
    {
	GOTO_STATE(assignstate);
	eqisassign = FALSE;
    }
    return(yytext[0]);
}

<start,expression>[\ \t]	;

<start,expression>\(		{
    if (nestlevel++ == 0) {
    	if (start == YYSTATE) {
    	    afterneststate = start;
	    goto_state(expression, "expression");
	}
    	else {
    	    afterneststate = expression;
	}
    }
    return(yytext[0]);
}
<expression>\)			{
    if (nestlevel > 0 && --nestlevel == 0 && (afterneststate != YYSTATE))
    	GOTO_STATE(afterneststate);
    return(yytext[0]);
}

<start,expression>[*/<>%+-]	{return(yytext[0]);}

<start>^\?	{
    NONSTANDARD
    if (yyin == stdin)
	do_help();
    else
	REJECT
}

<start>^!.*\n	{
    NONSTANDARD
    if (yyin == stdin)
        (void)do_system(yytext + 1);
    else
	REJECT
}

<start>^#.*\n	{NONSTANDARD options(yytext + 1);}

<expression>@[mM]	{NONSTANDARD yylval.number = MATCH; return(SPECIAL);}
<expression>@[aA]	{NONSTANDARD yylval.number = ACCEPT; return(SPECIAL);}
<expression>@[pP]	{NONSTANDARD yylval.number = PROBLEM; return(SPECIAL);}

<start,expression>\,	{return(',');}

<start,expression>.	{
    yyerror(BADCHAR);
    yytext[1] = '\0';
    dump_string(yytext, stderr);
    (void) fputc('\n', stderr);
    goto_state(skiptoend, "skiptoend");
    return(LEXERR);
}

<skiptoend>.*\n

%expression	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%term		{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%factor		{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%uselevel	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%maxuses	{NONSTANDARD; yylval.number = MAXUSES; return(NUMBER);}
%nextstmt	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%return[0-9]+	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%answer		{NONSTANDARD; SYSVAR(STRING_IDENT);}
%matched	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%left		{NONSTANDARD; SYSVAR(STRING_IDENT);}
%match		{NONSTANDARD; SYSVAR(STRING_IDENT);}
%right		{NONSTANDARD; SYSVAR(STRING_IDENT);}
%satisfied	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%relation	{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}
%text		{NONSTANDARD; SYSVAR(STRING_IDENT);}
%status		{NONSTANDARD; SYSVAR(NUMERIC_IDENT);}

\${ID}	{
    strlwr(yytext);
    if (keyword == COMPUTE)
    {
	assignstate = literal;
    }
    yylval.var = makevar(STRING_IDENT, yytext + 1);
    return(STRING_IDENT);
}
[a-zA-Z][A-Za-z0-9]+\$		{
    strlwr(yytext);
    if (keyword == COMPUTE)
    {
	assignstate = literal;
    }
    yytext[strlen(yytext) - 1] = '\0';
    yylval.var = makevar(STRING_IDENT, yytext);
    return(STRING_IDENT);
}
#{ID}	{
    strlwr(yytext);
    if (keyword == COMPUTE)
    {
	assignstate = expression;
    }
    yylval.var = makevar(NUMERIC_IDENT, yytext+1);
    return(NUMERIC_IDENT);
}

<literal>\\n		{NONSTANDARD yylval.number = '\n'; return(CHAR);}
<literal>\\t		{NONSTANDARD yylval.number = '\t'; return(CHAR);}
<literal>\\b		{NONSTANDARD yylval.number = '\b'; return(CHAR);}
<literal>\\r		{NONSTANDARD yylval.number = '\r'; return(CHAR);}
<literal>\\a		{NONSTANDARD yylval.number = '\007'; return(CHAR);}
<literal>\\x[0-9][0-9]	{NONSTANDARD yylval.number=(16*yytext[2]+yytext[3]); return(CHAR);}
<literal>\\^.		{NONSTANDARD yylval.number = yytext[2] & 0x1f; return(CHAR);}
<literal>\\.		{NONSTANDARD yylval.number = yytext[1]; return(CHAR);}
<literal>{NONSPECIALS}	{yylval.string = strsave(yytext); return(ALLOC);}
<literal>.		{yylval.number = yytext[0]; return(CHAR);}

[ \t]*\/\/.*		{NONSTANDARD}

\n	{
    /* reset all error-tracking and syntax-state variables */
    lexcont = TRUE;		/* so we catch omitted keyword */
    goto_state(start, "START");	/* start next line in tokenizing state */
    return(NEWLINE);
}

%%
#include <ctype.h>

void yyinit(char *file)
/* make sure the lexer begins in tokenizing state */
{
    if (file)
	(void) strcpy(yyfile, file);	
    goto_state(start, "start");
    yylineno = 0;
}

/*******************************************************************
 *
 * lex(1) library surrogates
 *
 ******************************************************************/

static int nextclass;

void pushlex(int class)
/* push a lexical state for processing */
{
    nextclass = class;
}

#undef yylex
int yylex(void)
/* sneaky way of adding instrumentation and a token pushback stack ... */
{
    int	class;

    if (nextclass)
    {
	class = nextclass;
	nextclass = 0;
    }
    else
	class = gettok();

    if (verbose > 1)
    {
	switch (class)
	{
	case TYPE:	(void) printf("TYPE keyword"); break;
	case ACCEPT:	(void) printf("ACCEPT keyword"); break;
	case MATCH:	(void) printf("MATCH keyword"); break;
	case JUMP:	(void) printf("JUMP keyword"); break;
	case USE:	(void) printf("USE keyword"); break;
	case COMPUTE:	(void) printf("COMPUTE keyword"); break;
	case GRAPHIC:	(void) printf("GRAPHIC keyword"); break;
	case KFILE:	(void) printf("FILE keyword"); break;
	case REMARK:	(void) printf("REMARK keyword"); break;
	case END:	(void) printf("END keyword"); break;
	case YES:	(void) printf("YES keyword"); break;
	case NO:	(void) printf("NO keyword"); break;
	case JUMPMATCH:	(void) printf("JUMPMATCH keyword"); break;
	case TYPEH:	(void) printf("TYPEH keyword"); break;
	case PROBLEM:	(void) printf("PROBLEM keyword"); break;
	case PAUSE:	(void) printf("PAUSE keyword"); break;
	case LINK:	(void) printf("LINK keyword"); break;
	case CLEARHOME:	(void) printf("CLEARHOME keyword"); break;
	case CURSADDR:	(void) printf("CURSADDR keyword"); break;
	case CLEARLINE:	(void) printf("CLEARLINE keyword"); break;
	case CLEAREND:	(void) printf("CLEAREND keyword"); break;
	case SYSTEM:	(void) printf("SYSTEM keyword"); break;

	case LABEL:
	    (void) printf("LABEL: %s, line %ld",
			  yylval.var->name, yylval.var->v.label.lineno);
	    break;

	case NUMBER:
	    (void) printf("NUMBER: %d", yylval.number);
	    break;

	case CHAR:
	    (void) printf("CHAR: '%c'", yylval.number);
	    break;

	case STRING:
	    (void) printf("STRING: \"%s\"", yylval.string);
	    break;

	case ALLOC:
	    (void) printf("ALLOC: \"%s\"", yylval.string);
	    break;

	case NUMERIC_IDENT:
	    (void) printf("NUMERIC_IDENT: %s", yylval.var->name);
	    break;

	case STRING_IDENT:
	    (void) printf("STRING_IDENT: %s", yylval.var->name);
	    break;

	case NEWLINE:
	    (void) printf("NEWLINE");
	    break;

	case COLON:
	    (void) printf("COLON");
	    break;

	case LEXERR:
	    (void) printf("LEXERR");
	    break;

	default:
	    (void) printf("Randomness (class %d): \"%c\"", class, class);
	    break;
	}

	if (nextclass)
	    printf(" (from pushback)\n");
	else
	    putchar('\n');
    }

    return(class);
}

int grabline(char *buf, int len)
/* use to get input lines, in flex's YY_INPUT definition */
{
    lineaddr = ftell(yyin);
    if (fgets(buf, len, yyin) == (char *)NULL)
    {
	return(YY_NULL);
    }
    else
    {
	if (verbose >= 1 && yyin != stdin)
	    (void) fprintf(stderr, "%03d: %s", yylineno+1, buf);

	/* detect continuation lines early for solhook()/compiler use */
	continuation = FALSE;
	if (buf) {
	    char *cp = buf;
	    while (*cp && isspace((unsigned char)*cp))
		cp++;
	    if (*cp == ':' || *cp == '(')
		continuation = TRUE;
	}

	solhook(buf);
	yylineno++;
	return(strlen(buf));
    }
}

int yyseek(long offset)
/* seek in the source file, nuking the pushback buffer */
{
    YY_FLUSH_BUFFER;
    return(fseek(yyin, offset, 0));
}

void yyerror(const char *message, ...)
/* emit syntax error message */
{
    yyerrors++;
    if (yyin == stdin)
    {
	(void) fprintf(stderr, "pilot: ");
    }
    else
	(void) fprintf(stderr, "%s:%d: ", yyfile, yylineno);
    if (strcmp(message, "syntax error"))
    {
	va_list ap;

	va_start(ap, message);
	(void) vfprintf(stderr, message, ap);
	va_end(ap);
    }
    else
	(void) fprintf(stderr, SYNERR,
	       (YYSTATE==start) ? "keyword part" : (YYSTATE==expression) ? "expression" : "literal");
    if (!multerr)
	exit(0);
}

int yywrap()
{
    if (yyin == stdin)
	(void) putchar('\n');
    return(EOF);
}

char *strsave(char *s)
/* save an allocated copy of a string */
{
    char	*m = malloc(strlen(s) + 1);

    if (m == (char *)NULL)
    {
	(void) fprintf(stderr, NOMEM);
	exit(1);
    }
    else
    {
	(void) strcpy(m, s);
	return(m);
    }
}

/*******************************************************************
 *
 * Error reporting
 *
 ******************************************************************/

void dump_string(char *str, FILE *fp)
{
    register char *cp;

    for (cp = str; *cp; cp++)
	if (isprint(*cp))
	    (void) putchar(*cp);
	else if (*cp == '"')
	    (void) fputs("\\\"", fp);
	else if (*cp == '\b')
	    (void) fputs("\\b", fp);
	else if (*cp == '\033')
	    (void) fputs("\\e", fp);
	else if (*cp == '\n')
	    (void) fputs("\\n", fp);
	else if (*cp == '\r')
	    (void) fputs("\\r", fp);
	else if (*cp == '\t')
	    (void) fputs("\\t", fp);
	else if (*cp == '\v')
	    (void) fputs("\\v", fp);
	else
	    (void) fprintf(fp, "\\x%02x", *cp);
}

const char *state_name(int state)
{
    switch (state)
    {
    #undef SWITCH_CASE
    #define SWITCH_CASE(_State) case _State: return #_State;
    SWITCH_CASE(start)
    SWITCH_CASE(expression)
    SWITCH_CASE(literal)
    SWITCH_CASE(skiptoend)
    default: return "Invalid";
    }
}

void after_colon()
{
    GOTO_STATE(aftercolstate);
    if (keyword == COMPUTE)
    {
    	eqisassign = TRUE;
    }
}

/*
 The following sets edit modes for GNU EMACS
 Local Variables:
 mode:c
 End:
*/
/* pilot.l ends here */
