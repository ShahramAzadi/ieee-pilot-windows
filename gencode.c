/*****************************************************************************

NAME
    gencode.c -- interpreter action code for IEEE PILOT

SYNOPSIS
   variable *makevar(int type, variable *var) -- intern a symbol with given type

   void gen_label(void)		-- LABEL entry

   void gen_type(void)		-- TYPE statement

   void gen_accept(void)	-- ACCEPT statement

   void gen_match(void)		-- MATCH statement

   void gen_jump(void)		-- JUMP statement

   void gen_use(void)		-- USE statement

   void gen_match(void)		-- MATCH statement

   void gen_file(void)		-- FILE statement

   void gen_graphic(void)	-- GRAPHIC statement

   void gen_end(void)		-- END statement

   void gen_problem(void)	-- PROBLEM statement

   void gen_wait(void)		-- WAIT statement

   void gen_link(void)		-- LINK statement

   void gen_typeh(void)		-- TYPEH statement

   void gen_clearhome(void)	-- CLEARHOME statement

   void gen_cursaddr(void)	-- CURSADDR statement

   void gen_clearline(void)	-- CLEARLINE statement

   void gen_clearend(void)	-- CLEAREND statement

   void gen_system(void)	-- SYSTEM statement

   void eolhook(void)		-- action to perform on newline

   void execfile(char *f)	-- interpret PILOT file

DESCRIPTION
   The guts of the IEEE PILOT interpreter/compiler.  The gen_* functions that
get called by the grammar actions live here.  The structure of this hack is
based on the fact that the lexer and grammar just build node trees; they
neither know nor care whether interpretation or compilation is going on.
   The gen_* functions either interpret PILOT or translate it to C depending
on the value of the compile switch.  The compilation code calls the C
compiler as a back end.

******************************************************************************/

#ifdef _WIN32
#include <process.h>
#endif

/*LINTLIBRARY*/
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#ifndef _WIN32
#include <sys/wait.h>
#endif

#include "pilot.h"

#include "gencode.h"

extern FILE *yyin;   /* the program text file descriptor */
extern int yylineno; /* the current source line count */

int verbose;   /* verbosity level of interpreter */
bool pedantic; /* insist on strict IEEE 1154-1991 conformance */
char *echo;    /* echo input (undocumented) */

/*******************************************************************
 *
 * User messages, collected here for internationalization
 *
 ******************************************************************/

#define BADCONT "can't continue the previous command\n"
#define BADEXT "source file has incorrect extension\n"
#define BADUSE "use statements are too deeply nested\n"
#define BADNODE "internal error, bad type in node\n"
#define BADRET "invalid %return index %d\n"
#define INVLAB "invalid label \"*%s\"\n"
#define INTERR "internal error, bad type %d in element %d text list\n"
#define JUMPERR "invalid special jump type\n"
#define NOJUMP "can't perform JUMP or USE in interactive mode.\n"
#define NOSTDIN "source file must be specified in order to compile\n"
#define NOTMP "can't open temp file %s\n"
#define PASS2 "beginning compilation pass 2\n"
#define PROBNG "PROBLEM has non-portable side-effects in some PILOTS\n"
#define TEXTLONG "text too long; truncated\n"
#define TOOLONG "id \"%s\" is too long!\n"
#define TOOMANY "too many variables\n"
#define PATHLONG "path too long: %s\n"
#define BADEND "EOF encountered before final END\n"
#define CANTOPN "can't open file %s\n"
#define CANTLOG "can't open log file %s\n"
#define SYNERR "(line %d) %s\n"
#define SYSVAR "internal error referencing system variable %s\n"
#define UNUSED "label %s never JUMPed to or USEd.\n"
#define UNDEFED "label %s JUMPed to or USEd but never defined.\n"
#define USAGE "usage: pilot [-dcmpk] [-L logfile] [-v num[y]] [files...]\n"

/* location of PILOT library */
static char pilotdir[PATH_MAX] = PILOTDIR;

/* mode options */
static int compile; /* pass number of compile */
static bool keep;   /* don't nuke intermediate C file */

/* compilation globals */
static FILE *yyout;            /* where to send compilation output */
static int indent = 0;         /* current block-indent level */
static int maxret = 0;         /* count of generated return labels */
static int usecount = 0;       /* count of USE statements */
static int matchcount = 0;     /* count of MATCH statements */
static int acceptcount = 0;    /* count of ACCEPT statements */
static int problemcount = 0;   /* count of PROBLEM statements */
static bool needclose = FALSE; /* need closing '}' for this line */

/* the interpreter's variable table and allocation pointer */
variable variables[MAXVARS], *nextv = variables;

/* other interpretation globals */
static variable *lookfor; /* label to jump to */
static int specialjump;   /* for @ jumps */
static bool statedump;    /* show state after each command? */
static long startaddr;    /* where jump starts from */
static FILE *logfp;       /* log file for ACCEPT input */
static bool logheader;    /* log header already written? */

typedef struct {
	const char *name;
	char *loc;
} sysstring_t;

typedef struct {
	const char *name;
	int *loc;
} sysnum_t;

/* system variable lookup tables */
static sysstring_t sysstrings[] = {
    {"answer", sys_answer}, {"left", sys_left}, {"match", sys_match},
    {"right", sys_right},   {"text", sys_text}, {NULL, NULL}};

static sysnum_t sysnums[] = {{"expression", &sys_expression},
                             {"term", &sys_term},
                             {"factor", &sys_factor},
                             {"uselevel", &sys_uselevel},
                             {"nextstmt", &sys_nextstmt},
                             {"matched", &sys_matched},
                             {"satisfied", &sys_satisfied},
                             {"relation", &sys_relation},
                             {"status", &sys_status},
                             {NULL, NULL}};

static int return_index(const char *start) {
	long idx = strtol(start, (char **)NULL, 10);

	if (idx < 0 || idx >= MAXUSES) {
		yyerror(BADRET, (int)idx);
		return 0;
	}
	return (int)idx;
}

static int *sysnum_lookup(const char *name) {
	const char *np = name;
	sysnum_t *npp;

	if (np == NULL || np[0] != '%') {
		return (int *)NULL;
	}

	if (strncmp(np, "%return", 7) == 0) {
		return &sys_return[return_index(np + 7)];
	}

	np++;
	for (npp = sysnums; npp->name; npp++) {
		if (strcmp(npp->name, np) == 0) {
			return npp->loc;
		}
	}
	return (int *)NULL;
}

static bool append_str(char *dst, size_t cap, const char *src) {
	size_t len = strlen(dst);
	size_t src_len = strlen(src);
	size_t n = src_len;
	size_t space;

	if (len >= cap - 1) {
		return TRUE;
	}
	space = cap - 1 - len;
	if (n > space) {
		n = space;
	}
	memcpy(dst + len, src, n);
	dst[len + n] = '\0';
	return (n < src_len);
}

static bool append_char(char *dst, size_t cap, char c) {
	size_t len = strlen(dst);

	if (len + 1 >= cap) {
		return TRUE;
	}
	dst[len] = c;
	dst[len + 1] = '\0';
	return FALSE;
}

static bool append_fmt(char *dst, size_t cap, const char *fmt, ...) {
	size_t len = strlen(dst);
	int n;
	va_list ap;

	if (len >= cap - 1) {
		return TRUE;
	}

	va_start(ap, fmt);
	n = vsnprintf(dst + len, cap - len, fmt, ap);
	va_end(ap);

	if (n < 0) {
		return TRUE;
	}
	return ((size_t)n >= cap - len);
}

static void chomp_newline(char *s) {
	char *p = s;

	while (*p && *p != '\n') {
		p++;
	}
	if (*p == '\n') {
		*p = '\0';
	}
}

static int run_argv(char *const argv[])
{
    if (argv == NULL || argv[0] == NULL || argv[0][0] == '\0') {
        return 0;
    }

#ifdef _WIN32

    return _spawnvp(_P_WAIT, argv[0], (const char * const *)argv);

#else

    pid_t pid;
    int status;

    pid = fork();
    if (pid < 0) {
        return -1;
    }

    if (pid == 0) {
        execvp(argv[0], argv);
        _exit(127);
    }

    if (waitpid(pid, &status, 0) < 0) {
        return -1;
    }

    return status;

#endif
}

static void log_header(const char *prog) {
	if (logfp == (FILE *)NULL || logheader) {
		return;
	}
	(void)fprintf(logfp, "# for %s\n", prog ? prog : "stdin");
	(void)fflush(logfp);
	logheader = TRUE;
}

static void log_input(const char *line) {
	if (logfp == (FILE *)NULL) {
		return;
	}
	(void)fputs(line, logfp);
	(void)fflush(logfp);
}

/*******************************************************************
 *
 * Variable lookup and creation
 *
 ******************************************************************/

variable *makevar(int type, char *name) {
	/* create a new symbol with given name and type */
	variable *vp;

	if ((int)strlen(name) > MAXNAME) {
		yyerror(TOOLONG, name);
		exit(1);
	}

	for (vp = variables; vp < nextv; vp++) {
		if (vp->type == type && strcmp(vp->name, name) == 0) {
			return (vp);
		}
	}

	if (nextv < variables + MAXVARS) {
		nextv->type = type;
		(void)strncpy(nextv->name, name, MAXNAME);
		nextv->name[MAXNAME] = '\0';
	} else {
		yyerror(TOOMANY);
		exit(1);
	}

	if (type == LABEL) {
		nextv->v.label.addr = BAD_LABEL;
		nextv->v.label.lineno = yylineno;
	}

	initvar(nextv); /* see nonstd.c */

	return (nextv++);
}

/*******************************************************************
 *
 * Interpretation helpers
 *
 ******************************************************************/

static void dumpvars(int keyword) {
	/* show state of all system variables */
	(void)printf("%%satisfied = %s\n", sys_satisfied ? "TRUE" : "FALSE");

	if (sys_satisfied) {
		switch (keyword) {
		case TYPE:
		case KFILE:
		case GRAPHIC:
		case YES:
		case NO:
		case LINK:
			(void)printf("%%text = \"%s\"\n", sys_text);
			break;

		case ACCEPT:
			(void)printf("%%answer = \"%s\"\n", sys_answer);
			break;

		case MATCH:
			(void)printf("%%text = \"%s\"\n", sys_text);
			(void)printf("%%answer = \"%s\"\n", sys_answer);
			(void)printf("%%matched = %d\n", sys_matched);
			(void)printf("%%match = %s\n", sys_match);
			(void)printf("%%left = %s\n", sys_left);
			(void)printf("%%right = %s\n", sys_right);
			break;

		case USE:
			(void)printf("%%uselevel = %d\n", sys_uselevel);
			(void)printf("%%return%d = %d\n", sys_uselevel,
			             sys_nextstmt);
			/* FALL THROUGH */

		case JUMP:
			(void)printf("%%nextstmt = %d\n", sys_nextstmt);
			break;

		case COMPUTE:
			(void)printf("%%text = \"%s\"\n", sys_text);
			(void)printf("%%expression = %d\n", sys_expression);
			break;

		case END:
			(void)printf("%%uselevel = %d\n", sys_uselevel);
			(void)printf("%%nextstmt = %d\n",
			             sys_return[sys_uselevel + 1]);
			(void)printf("%%nextstmt = %d\n", sys_nextstmt);
			break;
		}
	}
}

void eolhook(void) {
	/* end-of-line actions for interpreter */
	char *cp = NULL;

	if (compile) {
		return;
	}

	/* if we have an unknown jump target to find, go do it */
	if ((keyword == JUMP || keyword == USE || keyword == JUMPMATCH) &&
	    (lookfor || specialjump)) {
		if (yyin == stdin) {
			yyerror(NOJUMP);
		} else if (lookfor && lookfor->v.label.addr != BAD_LABEL) {
			yylineno = lookfor->v.label.lineno;
			sys_nextstmt = lookfor->v.label.addr;
		} else {
			char buf[MAXSTR + 1];
			long acceptaddr = 0L;

			if (lookfor || specialjump == ACCEPT) {
				yyseek(0L);
				yylineno = 1;
			}

			while (fgets(buf, sizeof(buf) - 1, yyin) !=
			       (char *)NULL) {
				for (cp = buf; *cp && isspace(*cp); cp++) {
					continue;
				}
				strlwr(cp);
				if (lookfor) {
					if (cp[0] == '*' &&
					    !strncmp(lookfor->name, cp + 1,
					             strlen(lookfor->name)) &&
					    isspace(
					        cp[1 +
					           strlen(lookfor->name)])) {
						break;
					}
				} else if (specialjump == MATCH) {
					if (cp[0] == 'm') {
						break;
					}
				} else if (specialjump == PROBLEM) {
					if (cp[0] == 'p') {
						break;
					}
				} else if (specialjump == ACCEPT) {
					if (ftell(yyin) > startaddr &&
					    acceptaddr != 0L) {
						break;
					}
					if (cp[0] == 'a') {
						acceptaddr =
						    ftell(yyin) - strlen(cp);
					}
				} else {
					yyerror(JUMPERR);
				}

				yylineno++;
			}

			if (feof(yyin) || ferror(yyin)) /* fell through loop */
			{
				yyerror(INVLAB, lookfor->name);
				sys_nextstmt = BAD_LABEL;
			} else /* got here from break */
			{
				sys_nextstmt = ftell(yyin) - strlen(cp);
				if (lookfor) {
					sys_nextstmt +=
					    strlen(lookfor->name) + 1;
				}
			}
		}

		/* reset our jump-to marker and do the actual seek */
		if (verbose) {
			(void)fprintf(stderr, "Seeking to %d\n", sys_nextstmt);
		}
		yyseek(sys_nextstmt);
	}

	/* O.K, now that sys_nextsmt is calculated, we can do this... */
	if (statedump) {
		dumpvars(keyword);
	}
	sys_nextstmt = BAD_LABEL;
	lookfor = (variable *)NULL;
	specialjump = 0;
}

static char *evaltext(part *textparts, int tn) {
	/* fill sys_text with the results of evaluating the current text parts
	 */
	part *tp;
	bool truncated = FALSE;

	/* associate string system variable names with locations */
	sysstring_t *spp;

	/* associate numeric system variable names with locations */
	sysnum_t *npp;

	sys_text[0] = '\0';
	for (tp = textparts; tp < textparts + tn; tp++) {
		switch (tp->type) {
		case STRING:
			truncated |= append_str(sys_text, sizeof(sys_text),
			                        tp->part.string);
			break;

		case ALLOC:
			truncated |= append_str(sys_text, sizeof(sys_text),
			                        tp->part.string);
			free(tp->part.string);
			break;

		case NUMBER:
			truncated |= append_fmt(sys_text, sizeof(sys_text), "%d",
			                        tp->part.number);
			break;

		case CHAR:
			truncated |= append_char(sys_text, sizeof(sys_text),
			                         tp->part.number);
			break;

		case STRING_IDENT:
			if (tp->part.var->name[0] != '%') {
				truncated |= append_str(sys_text, sizeof(sys_text),
				                        tp->part.var->v.string);
			} else {
				for (spp = sysstrings; spp->name; spp++) {
					if (strcmp(spp->name,
					           tp->part.var->name + 1) ==
					    0) {
						truncated |=
						    append_str(sys_text,
						               sizeof(sys_text),
						               spp->loc);
						break;
					}
				}
				if (spp->name == (char *)NULL) {
					yyerror(SYSVAR, tp->part.var->name);
				}
			}
			break;

		case NUMERIC_IDENT:
			if (strncmp(tp->part.var->name, "%return", 7) == 0) {
				truncated |= append_fmt(
				    sys_text, sizeof(sys_text), "%d",
				    sys_return[return_index(
				        tp->part.var->name + 7)]);
			} else if (tp->part.var->name[0] != '%') {
				truncated |= append_fmt(sys_text, sizeof(sys_text),
				                        "%d",
				                        tp->part.var->v.number);
			} else {
				for (npp = sysnums; npp->name; npp++) {
					if (strcmp(npp->name,
					           tp->part.var->name + 1) ==
					    0) {
						truncated |= append_fmt(
						    sys_text, sizeof(sys_text),
						    "%d", *(npp->loc));
						break;
					}
				}
				if (npp->name == (char *)NULL) {
					yyerror(SYSVAR, tp->part.var->name);
				}
			}
			break;

		default:
			yyerror(INTERR, tp->type, tp - textparts);
			break;
		}
	}
	if (truncated) {
		yyerror(TEXTLONG);
	}

	return (sys_text);
}

static int eval(node *np) {
	/* evaluate a node tree */
	int left, right;
	const int *sysnum;

	/* null node corresponds to empty condition expression */
	if (np == (node *)NULL) {
		if (!continuation) {
			sys_satisfied = TRUE;
		}
		return (sys_satisfied);
	}

	/* if the node is an atom, return its value */
	if (np->type == NUMBER) {
		return (sys_factor = np->value.number);
	} else if (np->type == NUMERIC_IDENT) {
		sysnum = sysnum_lookup(np->value.var->name);
		if (sysnum != (int *)NULL) {
			return (sys_factor = *sysnum);
		}
		return (sys_factor = np->value.var->v.number);
	} else if (np->type == YES) {
		return (sys_satisfied = sys_matched);
	} else if (np->type == NO) {
		return (sys_satisfied = !sys_matched);
	}

	/* the magic recursion */
	left = eval(np->left);
	right = eval(np->right);

	switch (np->type) {
	case LESS:
		return (sys_relation = (left < right));
	case GREATER:
		return (sys_relation = (left > right));
	case EQUAL:
		return (sys_relation = (left == right));
	case NEQUAL:
		return (sys_relation = (left != right));
	case NOTGRT:
		return (sys_relation = (left <= right));
	case NOTLESS:
		return (sys_relation = (left >= right));
	case PLUS:
		return (sys_expression = (left + right));
	case MINUS:
		return (sys_expression = (left - right));
	case UMINUS:
		return (sys_term = (-right));
	case MULTIPLY:
		return (sys_term = (left * right));
	case DIVIDE:
		return (sys_term = (left / right));
	case MODULO:
		return (sys_term = (left % right));
	case ANDAND:
		return (left && right);

	default:
		yyerror(BADNODE);
		return (FALSE);
	}
}

/*******************************************************************
 *
 * Compilation helpers
 *
 ******************************************************************/

static void genindent(int n) {
	/* generate proper indent level */
	int i = 0;

	for (i = 0; i < n * 4; i++) {
		(void)fputc(' ', yyout);
	}
}

void solhook(char *s) {
	/* start-of-line actions for compiler */
	if (compile == 2) {
		if (needclose && (!continuation || s == (char *)NULL)) {
			genindent(--indent);
			(void)fputs("}\n", yyout);
			needclose = FALSE;
		}

		if (s && s[0] && s[0] != '\n') {
			variable *vp;
			char *cp;

			if (!keep) {
				(void)fprintf(yyout, "#line %d \"%s\"\n",
				              yylineno + 1, yyfile);
			}

			/* list the PILOT statement we're compiling */
			s[strlen(s) - 1] = '\0';
			(void)fprintf(yyout, "    /*-%s-*/\n", s);
			s[strlen(s)] = '\n';

			/* emit this statement's label if it has one */
			for (vp = variables; vp < nextv; vp++) {
				if (vp->type == LABEL &&
				    vp->v.label.addr <= ftell(yyin) &&
				    vp->v.label.addr >=
				        ftell(yyin) - (int)strlen(s)) {
					(void)fprintf(yyout, "plt_%s:\n",
					              vp->name);
				}
			}

			/* emit label for @[MAP] jumps */
			for (cp = s; *cp && isspace(*cp); cp++) {
				if (*cp == 'm') {
					(void)fprintf(yyout, "match_%d:\n",
					              matchcount++);
				} else if (*cp == 'a') {
					(void)fprintf(yyout, "accept_%d:\n",
					              acceptcount++);
				} else if (*cp == 'p') {
					(void)fprintf(yyout, "problem_%d:\n",
					              problemcount++);
				}
			}

			if (continuation && keyword != TYPE &&
			    keyword != TYPEH && keyword != YES &&
			    keyword != NO && keyword != REMARK) {
				yyerror(BADCONT);
			}
		} else if (s) {
			(void)fputc('\n', yyout);
		}
	}
}

static void genexpr(node *); /* this is just a forward */

static void binop(node *np, const char *var, const char *op) {
	/* write expression wrapper for given binary op and system variable */
	(void)fputs("(", yyout);
	if (statedump) {
		(void)fprintf(yyout, "%s = ", var);
	}
	if (np->left) {
		genexpr(np->left);
	}
	(void)fputs(op, yyout);
	if (np->right) {
		genexpr(np->right);
	}
	(void)fputs(")", yyout);
}

static void genexpr(node *np) {
	/* prettyprint a PILOT expression in generated C */
	/* null node corresponds to empty condition expression */
	if (np == (node *)NULL) {
		return;
	} else if (np->type == NUMBER) {
		if (statedump) {
			(void)fprintf(yyout, "(sys_factor = %d)",
			              np->value.number);
		} else {
			(void)fprintf(yyout, "%d", np->value.number);
		}
	} else if (np->type == NUMERIC_IDENT) {
		const char *name = np->value.var->name;
		if (name[0] == '%') {
			if (strncmp(name, "%return", 7) == 0) {
				int idx = return_index(name + 7);
				if (statedump) {
					(void)fprintf(
					    yyout,
					    "(sys_factor = sys_return[%d])",
					    idx);
				} else {
					(void)fprintf(yyout,
					              "sys_return[%d]",
					              idx);
				}
			} else if (statedump) {
				(void)fprintf(yyout, "(sys_factor = sys_%s)",
				              name + 1);
			} else {
				(void)fprintf(yyout, "sys_%s", name + 1);
			}
		} else if (statedump) {
			(void)fprintf(yyout, "(sys_factor = num_%s)",
			              np->value.var->name);
		} else {
			(void)fprintf(yyout, "num_%s", np->value.var->name);
		}
	} else if (np->type == YES) {
		if (statedump) {
			(void)fprintf(yyout, "(sys_satisfied = sys_matched)");
		} else {
			(void)fprintf(yyout, "sys_matched");
		}
	} else if (np->type == NO) {
		if (statedump) {
			(void)fprintf(yyout, "(sys_satisfied = !sys_matched)");
		} else {
			(void)fprintf(yyout, "!sys_matched");
		}
	} else {
		switch (np->type) {
		case LESS:
			binop(np, "sys_relation", "<");
			break;
		case GREATER:
			binop(np, "sys_relation", ">");
			break;
		case EQUAL:
			binop(np, "sys_relation", "==");
			break;
		case NEQUAL:
			binop(np, "sys_relation", "!=");
			break;
		case NOTGRT:
			binop(np, "sys_relation", "<=");
			break;
		case NOTLESS:
			binop(np, "sys_relation", ">=");
			break;
		case PLUS:
			binop(np, "sys_expression", "+");
			break;
		case MINUS:
			binop(np, "sys_expression", "-");
			break;
		case MULTIPLY:
			binop(np, "sys_term", "*");
			break;
		case DIVIDE:
			binop(np, "sys_term", "/");
			break;
		case MODULO:
			binop(np, "sys_term", "%");
			break;
		case UMINUS:
			binop(np, "sys_term", "-");
			break;
		case ANDAND:
			binop(np, "sys_satisfied", "&&");
			break;
		default:
			(void)yyerror(BADNODE);
			break;
		}
	}
}

static void gencond(node *np) {
	/* generate C for a condition expression corresponding to the given node
	 */
	if (np != (node *)NULL && !continuation) {
		genindent(indent);
		(void)fprintf(yyout, "if (");
		genexpr(np);
		(void)fprintf(yyout, ") {\n");
		needclose = TRUE;
		indent++;
	} else if (statedump) {
		genindent(indent);
		(void)fputs("sys_satisfied = TRUE;\n", yyout);
	}
}

static void gentext(part *textparts, int tn) {
	/* generate sprintf to assemble text from current parts */
	char fmtbuf[MAXSTR * 2]; /* allow for escaped " and % */
	char argbuf[MAXSTR];
	part *tp;
	char *cp, *np;
	bool truncated = FALSE;

	fmtbuf[0] = argbuf[0] = '\0';
	for (tp = textparts; tp < textparts + tn; tp++) {
		switch (tp->type) {
		case STRING:
			for (cp = tp->part.string; *cp; cp++) {
				if (*cp == '"' || *cp == '\\') {
					truncated |= append_char(fmtbuf,
					                         sizeof(fmtbuf),
					                         '\\');
				} else if (*cp == '%') {
					truncated |= append_char(fmtbuf,
					                         sizeof(fmtbuf),
					                         '%');
				}
				truncated |= append_char(fmtbuf, sizeof(fmtbuf),
				                         *cp);
			}
			break;

		case ALLOC:
			for (cp = tp->part.string; *cp; cp++) {
				if (*cp == '"' || *cp == '\\') {
					truncated |= append_char(fmtbuf,
					                         sizeof(fmtbuf),
					                         '\\');
				} else if (*cp == '%') {
					truncated |= append_char(fmtbuf,
					                         sizeof(fmtbuf),
					                         '%');
				}
				truncated |= append_char(fmtbuf, sizeof(fmtbuf),
				                         *cp);
			}
			free(tp->part.string);
			break;

		case NUMBER:
			truncated |= append_fmt(fmtbuf, sizeof(fmtbuf), "%d",
			                        tp->part.number);
			break;

		case CHAR:
			if (tp->part.number == '"') {
				truncated |= append_char(fmtbuf, sizeof(fmtbuf),
				                         '\\');
			} else if (tp->part.number == '%') {
				truncated |= append_char(fmtbuf, sizeof(fmtbuf),
				                         '%');
			}
			truncated |=
			    append_char(fmtbuf, sizeof(fmtbuf), tp->part.number);
			break;

		case STRING_IDENT:
			truncated |= append_str(fmtbuf, sizeof(fmtbuf), "%s");
			if ((np = tp->part.var->name)[0] == '%') {
				truncated |= append_fmt(argbuf, sizeof(argbuf),
				                        ", sys_%s", ++np);
			} else {
				truncated |= append_fmt(argbuf, sizeof(argbuf),
				                        ", str_%s", np);
			}
			break;

		case NUMERIC_IDENT:
			truncated |= append_str(fmtbuf, sizeof(fmtbuf), "%d");
			if (strncmp(tp->part.var->name, "%return", 7) == 0) {
				truncated |= append_fmt(
				    argbuf, sizeof(argbuf), ", sys_return[%d]",
				    return_index(tp->part.var->name + 7));
			} else if ((np = tp->part.var->name)[0] == '%') {
				truncated |= append_fmt(argbuf, sizeof(argbuf),
				                        ", sys_%s", ++np);
			} else {
				truncated |= append_fmt(argbuf, sizeof(argbuf),
				                        ", num_%s", np);
			}
			break;

		default:
			yyerror(INTERR, tp->type, tp - textparts);
			break;
		}
	}

	genindent(indent);
	if (argbuf[0]) {
		(void)fprintf(
		    yyout, "(void) snprintf(sys_text, sizeof(sys_text), \"%s\"%s);\n",
		    fmtbuf, argbuf);
	} else {
		(void)fprintf(yyout,
		              "(void) snprintf(sys_text, sizeof(sys_text), \"%s\");\n",
		              fmtbuf);
	}
	if (truncated) {
		yyerror(TEXTLONG);
	}
}

/*******************************************************************
 *
 * Interpretation/compilation functions
 *
 ******************************************************************/

void gen_label(variable *v) {
	/* enter location of a LABEL */
	/* no longer necessary to do anything here */
}

void gen_type(node *cond, part *text, int pn) {
	/* perform TYPE statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("(void) puts(sys_text);\n", yyout);
	} else if (eval(cond)) {
		(void)puts(evaltext(text, pn));
	}
}

void gen_accept(node *cond, variable *var, int type) {
	/* perform ACCEPT statement */
	if (compile) {
		gencond(cond);
		genindent(indent);
		(void)fputs(
		    "if (fgets(sys_answer, sizeof(sys_answer), stdin) == "
		    "NULL) {\n",
		    yyout);
		genindent(indent + 1);
		(void)fputs("sys_answer[0] = '\\0';\n", yyout);
		genindent(indent);
		(void)fputs("} else {\n", yyout);
		genindent(indent + 1);
		(void)fputs("char *p = sys_answer;\n", yyout);
		genindent(indent + 1);
		(void)fputs("while (*p && *p != '\\n') p++;\n", yyout);
		genindent(indent + 1);
		(void)fputs("if (*p == '\\n') *p = '\\0';\n", yyout);
		genindent(indent);
		(void)fputs("}\n", yyout);
		if (var) {
			genindent(indent);
			if (var->type == STRING_IDENT) {
				(void)fprintf(
				    yyout,
				    "(void) strcpy(str_%s, sys_answer);\n",
				    var->name);
			} else {
				(void)fprintf(yyout,
				              "num_%s = numconv(sys_answer);\n",
				              var->name);
			}
		}
	} else if (eval(cond)) {
		if (fgets(sys_answer, sizeof(sys_answer), stdin) ==
		    (char *)NULL) {
			sys_answer[0] = '\0';
		} else {
			if (echo != NULL) {
				fputs(echo, stdout);
				fputs(sys_answer, stdout);
			}
			log_input(sys_answer);
			chomp_newline(sys_answer);
		}
		if (var != (variable *)NULL) {
			switch (type) {
			case STRING_IDENT:
				(void)strcpy(var->v.string, sys_answer);
				break;

			case NUMERIC_IDENT:
				var->v.number = numconv(sys_answer);
				break;
			}
		}
	}
}

void gen_match(node *cond, part *text, int pn) {
	/* perform MATCH statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("sys_matched = do_match(sys_text, sys_answer);\n",
		            yyout);
	} else if (eval(cond)) {
		sys_matched = do_match(evaltext(text, pn), sys_answer);
	}
}

void gen_jump(node *cond, variable *var, int target) {
	/* perform JUMP statement */
	if (var) {
		var->v.label.refcount++;
	}
	if (compile) {
		gencond(cond);
		genindent(indent);
		if (target == MATCH) {
			(void)fprintf(yyout, "goto match_%d;\n",
			              matchcount + 1);
		} else if (target == ACCEPT) {
			(void)fprintf(yyout, "goto accept_%d;\n", acceptcount);
		} else if (target == PROBLEM) {
			(void)fprintf(yyout, "goto problem_%d;\n",
			              problemcount + 1);
		} else {
			(void)fprintf(yyout, "goto plt_%s;\n", var->name);
		}
	} else if (eval(cond)) {
		if (target != LABEL) {
			startaddr = ftell(yyin);
			specialjump = target;
			lookfor = (variable *)NULL;
		} else {
			lookfor = var;
		}
	}
}

void gen_use(node *cond, variable *var) {
	/* perform USE statement */
	var->v.label.refcount++;
	if (compile) {
		gencond(cond);
		genindent(indent);
		(void)fputs(
		    "if (sys_uselevel >= MAXUSES) { (void)fputs(\"pilot: use "
		    "statements are too deeply nested\\n\", stderr); exit(1); }\n",
		    yyout);
		genindent(indent);
		(void)fprintf(yyout,
		              "sys_return[sys_uselevel++] = %d; goto plt_%s; "
		              "retlab%d:;\n",
		              maxret, var->name, maxret);
		++maxret;
	} else if (eval(cond)) {
		if (sys_uselevel >= MAXUSES) {
			yyerror(BADUSE);
		} else {
			sys_return[sys_uselevel++] = (int)ftell(yyin);
		}
		lookfor = var;
	}
}

void gen_compute(node *cond, variable *var, node *expr, part *text, int pn) {
	/* perform COMPUTE statement */
	if (compile) {
		gencond(cond);
		if (expr == (node *)NULL) {
			gentext(text, pn);
			genindent(indent);
			(void)fprintf(yyout,
			              "(void) strcpy(str_%s, sys_text);\n",
			              var->name);
		} else {
			genindent(indent);
			(void)fprintf(yyout, "num_%s = ", var->name);
			genexpr(expr);
			(void)fputs(";\n", yyout);
		}
	} else if (eval(cond)) {
		if (text != NULL) {
			(void)strncpy(var->v.string, evaltext(text, pn),
			              MAXSTR);
			var->v.string[MAXSTR] = '\0';
		} else {
			var->v.number = eval(expr);
		}
	}
}

void gen_file(node *cond, part *text, int pn) {
	/* perform FILE statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("(void) do_file(sys_text);\n", yyout);
	} else if (eval(cond)) {
		(void)do_file(evaltext(text, pn));
	}
}

void gen_graphic(node *cond, part *text, int pn) {
	/* perform GRAPHIC statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("(void) do_graphic(sys_text);\n", yyout);
	} else if (eval(cond)) {
		(void)do_graphic(evaltext(text, pn));
	}
}

void gen_end(node *cond, int val) {
	/* perform END statement */
	if (compile) {

		/*
		 * I puke, big time, whenever I think about the code this
		 * generates.
		 */
		gencond(cond);
		genindent(indent);
		(void)fprintf(yyout, "if (sys_uselevel-- == 0) exit(%d);\n",
		              val);
		genindent(indent);
		if (usecount == 0) {
			(void)fputs("exit(0);\n", yyout);
		} else {
			int i;
			(void)fputs("switch(sys_return[sys_uselevel]) {\n",
			            yyout);
			for (i = 0; i < usecount; i++) {
				genindent(indent);
				/*
				 * There is potential for optimization here.  If
				 * the first pass kept information on the
				 * location and targets of all JUMPs and USEs, a
				 * fairly simple graph-coloring album could be
				 * used to compute which USEs could lead to any
				 * given END.  Then, only those would need to be
				 * included in the case list for that END.
				 */
				(void)fprintf(
				    yyout, "case %d: goto retlab%d;\n", i, i);
			}
			genindent(indent);
			(void)fputs("default: exit(0);\n", yyout);
			genindent(indent);
			(void)fputs("}\n", yyout);
		}
	} else if (eval(cond)) {
		if (sys_uselevel == 0) {
			exit(0);
		} else {
			--sys_uselevel;
		}
		(void)fseek(yyin, sys_return[sys_uselevel], 0);
	}
}

void gen_problem(node *cond, part *text, int pn) {
	/* perform PROBLEM statement */
	if (pedantic) {
		yyerror(PROBNG);
	}
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("(void) do_problem(sys_text);\n", yyout);
	} else if (eval(cond)) {
		(void)do_problem(evaltext(text, pn));
	}
}

void gen_pause(node *cond, node *val) {
	/* perform PAUSE statement */
	if (compile) {
		gencond(cond);
		genindent(indent);
		(void)fprintf(yyout, "do_pause(");
		genexpr(val);
		(void)fputs(");\n", yyout);
	} else if (eval(cond)) {
		do_pause(eval(val));
	}
}

void gen_link(node *cond, part *text, int pn) {
	/* perform LINK statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("do_link(sys_text);\n", yyout);
	} else if (eval(cond)) {
		/*
		 * Ideally, we'd call do_link() here.  Trouble is, we don't want
		 * to recurse the interpreter every time it does a link; the
		 * idea is to simulate textual inclusion.
		 */
		sys_status = execfile(evaltext(text, pn));
	}
}

void gen_jumpmatch(node *cond, int njumps, variable *jumpvec[]) {
	/* perform JUMPMATCH statement */
	int i;

	for (i = 0; i < njumps; i++) {
		jumpvec[i]->v.label.refcount++;
	}
	if (compile) {
		gencond(cond);
		genindent(indent);
		(void)fprintf(yyout, "switch(sys_matched) {\n");

		for (i = 0; i < njumps; i++) {
			genindent(indent);
			(void)fprintf(yyout, "case %d: ", i + 1);
			if (jumpvec[i]->type == MATCH) {
				(void)fprintf(yyout, "goto match_%d;\n",
				              matchcount + 1);
			} else if (jumpvec[i]->type == ACCEPT) {
				(void)fprintf(yyout, "goto accept_%d;\n",
				              acceptcount);
			} else if (jumpvec[i]->type == PROBLEM) {
				(void)fprintf(yyout, "goto problem_%d;\n",
				              problemcount + 1);
			} else {
				(void)fprintf(yyout, "goto plt_%s;\n",
				              jumpvec[i]->name);
			}
		}

		genindent(indent);
		(void)fputs("}\n", yyout);
	} else if (sys_matched > 0 && sys_matched <= njumps) {
		gen_jump(cond, jumpvec[sys_matched - 1],
		         jumpvec[sys_matched - 1]->type);
	}
}

void gen_typeh(node *cond, part *text, int pn) {
	/* perform TYPEH statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("(void) fputs(sys_text, stdout);\n", yyout);
	} else if (eval(cond)) {
		(void)fputs(evaltext(text, pn), stdout);
	}
}

void gen_clearhome(node *cond) {
	/* perform CLEARHOME statement */
	if (compile) {
		gencond(cond);
		(void)fprintf(yyout, "do_clearhome();\n");
	} else if (eval(cond)) {
		do_clearhome();
	}
}

void gen_cursaddr(node *cond, int y, int x) {
	/* perform CURSADDR statement */
	if (compile) {
		gencond(cond);
		(void)fprintf(yyout, "do_cursaddr(%d, %d);\n", y, x);
	} else if (eval(cond)) {
		do_cursaddr(y, x);
	}
}

void gen_clearline(node *cond) {
	/* perform CLEARLINE statement */
	if (compile) {
		gencond(cond);
		(void)fprintf(yyout, "do_clearline();\n");
	} else if (eval(cond)) {
		do_clearline();
	}
}

void gen_clearend(node *cond) {
	/* perform CLEAREND statement */
	if (compile) {
		gencond(cond);
		(void)fprintf(yyout, "do_clearend();\n");
	} else if (eval(cond)) {
		do_clearend();
	}
}

void gen_system(node *cond, part *text, int pn) {
	/* perform SYSTEM statement */
	if (compile) {
		gencond(cond);
		gentext(text, pn);
		genindent(indent);
		(void)fputs("sys_status = do_system(sys_text);\n", yyout);
	} else if (eval(cond)) {
		sys_status = do_system(evaltext(text, pn));
	}
}

/*******************************************************************
 *
 * Sequencing
 *
 ******************************************************************/

void options(char *str) {
	/* interpret options string */
	char *p = str;
	int enable = FALSE;

	while (*p) {
		if (isspace((unsigned char)*p)) {
			p++;
			continue;
		}
		if (*p == '-') {
			enable = TRUE;
			p++;
			continue;
		}
		if (*p == '+') {
			enable = FALSE;
			p++;
			continue;
		}

		switch (*p) {
		case 'c':
		case 'm':
			multerr = enable;
			p++;
			break;
		case 'd':
			statedump = enable;
			p++;
			break;
		case 'k':
			keep = enable;
			p++;
			break;
		case 'p':
			pedantic = enable;
			p++;
			break;
		case 'v':
			p++;
			if (enable) {
				if (isdigit((unsigned char)*p)) {
					verbose = atoi(p);
					while (isdigit((unsigned char)*p)) {
						p++;
					}
				} else {
					verbose = 1;
				}
			} else {
				verbose = 0;
			}
#if YYDEBUG
			if (*p == 'y') {
				yydebug = enable;
				p++;
			}
#endif /* YYDEBUG */
			break;
		default:
			p++;
			break;
		}
	}
}

int execfile(char *t) {
	/* execute or compile a PILOT file in the current directory */
	FILE *oldyyin = yyin;
	char oldyyfile[PATH_MAX];
	char stem[PATH_MAX], source[PATH_MAX], outfile[PATH_MAX];
	int pass2level;
	variable *cvp;

	(void)strncpy(oldyyfile, yyfile, sizeof(oldyyfile) - 1);
	oldyyfile[sizeof(oldyyfile) - 1] = '\0';

	if (t) {
		if (!namefile(t, stem, source)) {
			yyerror(BADEXT);
		}
		if ((yyin = fopen(source, "r")) == (FILE *)NULL) {
			(void)fprintf(stderr, CANTOPN, t);
			return (1);
		}
	}

	log_header(t ? t : "stdin");

	if (!compile) {
		do_scrinit();
	} else {
		int class;

		if (t == (char *)NULL) {
			yyerror(NOSTDIN);
		}

		if (snprintf(outfile, sizeof(outfile), "%s.c", stem) >=
		    (int)sizeof(outfile)) {
			yyerror(PATHLONG, stem);
			if (t) {
				(void)fclose(yyin);
			}
			yyin = oldyyin;
			(void)strncpy(yyfile, oldyyfile, sizeof(yyfile) - 1);
			yyfile[sizeof(yyfile) - 1] = '\0';
			return (1);
		}
		if ((yyout = fopen(outfile, "w")) == (FILE *)NULL) {
			yyerror(NOTMP, t);
		}

		/*
		 * First pass -- accumulate symbol table, label, and jump info.
		 * To avoid parser overhead, we only do lexical analysis.
		 */
		yyinit(source);
		pass2level = verbose;
		usecount = 0;
		if (verbose == 1) {
			verbose = 0;
		}
		while ((class = yylex()) != 0) {
			if (class == USE) {
				usecount++;
			}
		}
		verbose = pass2level;

		/* check for undefined labels */
		for (cvp = variables; cvp < nextv; cvp++) {
			if (cvp->type == LABEL &&
			    cvp->v.label.addr == BAD_LABEL) {
				yylineno = cvp->v.label.lineno;
				yyerror(UNDEFED, cvp->name);
			}
		}

		(void)fprintf(yyout, "/* %s -- generated C code for %s */\n",
		              outfile, source);
		(void)fputs("#include <stdio.h>\n", yyout);
		(void)fputs("#include \"pilot.h\"\n", yyout);

		/* generate declarations for all non-system variables */
		for (cvp = variables; cvp < nextv; cvp++) {
			if (cvp->name[0] != '%') {
				switch (cvp->type) {
				case NUMERIC_IDENT:
					(void)fprintf(yyout,
					              "static int num_%s;\n",
					              cvp->name);
					break;

				case STRING_IDENT:
					(void)fprintf(
					    yyout,
					    "static char str_%s[MAXSTR + 1];\n",
					    cvp->name);
					break;
				}
			}
		}

		compile = 2;
		yyseek(0L);

		if (verbose) {
			(void)fputs(PASS2, stderr);
		}

		(void)fputs("\nmain()\n{\n    do_scrinit();\n", yyout);
		indent = 1;
	}

	yyinit(t ? source : t);
	yyparse();
	solhook((char *)NULL);

	if (sys_uselevel != 0) {
		(void)fprintf(stderr, BADEND);
	}

	/* check for unreferenced labels */
	for (cvp = variables; cvp < nextv; cvp++) {
		if (cvp->type == LABEL && cvp->v.label.refcount == 0) {
			yylineno = cvp->v.label.lineno;
			yyerror(UNUSED, cvp->name);
		}
	}

	if (!compile) {
		do_scrend();
	} else {
		(void)fputs("    do_scrend();\n}\n", yyout);
		(void)fprintf(yyout,
		              "\n/* Generated code for %s ends here */\n", t);
		(void)fclose(yyout);
	}

	if (sys_uselevel) {
		(void)fprintf(stderr, BADEND);
	}

	if (t) {
		(void)fclose(yyin);
	}

	if (compile && yyerrors == 0) {
		char incdir[PATH_MAX + 3];
		char libdir[PATH_MAX + 3];
		char srcfile[PATH_MAX];
		char *argv[10];
		int argc = 0;

		if (snprintf(incdir, sizeof(incdir), "-I%s", pilotdir) >=
		    (int)sizeof(incdir) ||
		    snprintf(libdir, sizeof(libdir), "-L%s", pilotdir) >=
		    (int)sizeof(libdir) ||
		    snprintf(srcfile, sizeof(srcfile), "%s.c", stem) >=
		    (int)sizeof(srcfile)) {
			yyerror(PATHLONG, stem);
			goto compile_done;
		}

		argv[argc++] = "cc";
		argv[argc++] = "-I.";
		argv[argc++] = incdir;
		argv[argc++] = libdir;
		argv[argc++] = srcfile;
		argv[argc++] = "-lpilot";
		argv[argc++] = "-ltermcap";
		argv[argc++] = "-o";
		argv[argc++] = stem;
		argv[argc] = NULL;

		if (verbose) {
			int i;
			for (i = 0; argv[i]; i++) {
				(void)fprintf(stderr, "%s%s",
				              i ? " " : "", argv[i]);
			}
			(void)fputc('\n', stderr);
		}

		if (run_argv(argv) == 0 && !keep) {
			char delpath[PATH_MAX];

			if (snprintf(delpath, sizeof(delpath), "%s.c", stem) >=
			    (int)sizeof(delpath)) {
				yyerror(PATHLONG, stem);
			} else {
				(void)unlink(delpath);
			}
		}
	}
compile_done:

	yyin = oldyyin;
	(void)strncpy(yyfile, oldyyfile, sizeof(yyfile) - 1);
	yyfile[sizeof(yyfile) - 1] = '\0';
	return (0);
}

int main(int argc, char *argv[]) {
	extern int optind;   /* getopt() sets this */
	extern char *optarg; /* and this */
	extern char *getenv();
	int c;
	int status = 0;
	const char *logfile = (char *)NULL;

	if ((optarg = getenv("PILOTDIR")) != NULL) {
		(void)strncpy(pilotdir, optarg, sizeof(pilotdir) - 1);
		pilotdir[sizeof(pilotdir) - 1] = '\0';
	}

	while ((c = getopt(argc, argv, "ce:kmdpv:L:")) != EOF) {
		switch (c) {
		case 'c':
			compile = 1; /* start them on compilation pass 1 */
			multerr = TRUE;
			break;
		case 'e':
			echo = optarg;
			break;

		case 'm':
			multerr = TRUE;
			break;

		case 'd':
			statedump = TRUE;
			break;

		case 'k':
			keep = TRUE;
			break;

		case 'p':
			pedantic = TRUE;
			break;

		case 'L':
			logfile = optarg;
			break;

		case 'v':
			verbose = atoi(optarg);
#if YYDEBUG
			if (strchr(optarg, 'y')) {
				yydebug = 1;
			}
#endif /* YYDEBUG */
			break;

		default:
			(void)fprintf(stderr, USAGE);
			break;
		}
	}

	if (logfile) {
		logfp = fopen(logfile, "w");
		if (logfp == (FILE *)NULL) {
			(void)fprintf(stderr, CANTLOG, logfile);
			return (1);
		}
	}

	if (optind == argc) {
		status = execfile((char *)NULL);
	} else {
		for (; optind < argc; optind++) {
			if ((status = execfile(argv[optind])) != 0) {
				break;
			}
		}
	}

	if (logfp) {
		(void)fclose(logfp);
	}

	return status;
}

/* gencode.c ends here */
