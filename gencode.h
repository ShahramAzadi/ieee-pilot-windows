/* gencode.h  -- interface to interpreter/compiler action functions */

/* this structure represents a PILOT variable */
typedef struct rav {
	char name[MAXNAME + 1]; /* name of variable */
	int type;               /* type (syntax class) */
	union {
		int number; /* numeric value */
		struct {
			long lineno;  /* source line number */
			long addr;    /* label seek offset */
			int refcount; /* count of JUMPS and USES to it */
		} label;
#define BAD_LABEL -1L                    /* out-of-band labeladdr value */
		char string[MAXSTR + 1]; /* string value */
	} v;
} variable;

/* pilot.l:  lexical analysis */
extern void yyinit(char *);   /* lexer initialization */
extern int yylex(void);       /* lexical analyzer */
extern int yyseek(long);      /* hop to it */
extern int yyerrors;          /* count of parsing errors */
extern char yyfile[PATH_MAX]; /* current source file name */
extern int keyword;           /* value of last keyword seen */
extern bool continuation;     /* seen a command keyword on this line? */
extern void options(char *);  /* process interpreter options */
extern bool multerr;          /* option: allow multiple errors? */

/* nonstd.c: functions with no standard definition */
extern void do_help(void);          /* HELP */
extern void initvar(variable *var); /* variable initialization */

/* pilot.y: parsing */
extern int yyparse(void); /* parse PILOT text on yyin */
extern int verbose;       /* option: parser/lexer verbosity level */
extern bool pedantic;     /* option: force strict conformance */

/* gencode.c: code generation */
extern int execfile(char *); /* interpret a PILOT file */

#include "grammar.h"

/*
 * Use this for lists of typed values and references,
 * each corresponding to a lexical item.
 */
typedef struct {
	int type;
	YYSTYPE part;
} part;

/*
 * This is the node structure for expression trees.
 */
typedef struct edon {
	int type; /* type of NODE if *left || *right */
	YYSTYPE value;
	struct edon *left;
	struct edon *right;
} node;

/* production functions */
extern variable *makevar(int, char *); /* intern a symbol with given type */
extern void gen_label(variable *);     /* make entry for label */
extern void gen_type(node *, part *, int);
extern void gen_accept(node *, variable *, int);
extern void gen_match(node *, part *, int);
extern void gen_jump(node *, variable *, int);
extern void gen_jumpmatch(node *, int, variable **);
extern void gen_use(node *, variable *);
extern void gen_compute(node *, variable *, node *, part *, int);
extern void gen_file(node *, part *, int);
extern void gen_graphic(node *, part *, int);
extern void gen_end(node *, int);
extern void gen_problem(node *, part *, int);
extern void gen_pause(node *, node *);
extern void gen_link(node *, part *, int);
extern void gen_typeh(node *, part *, int);
extern void gen_clearhome(node *);
extern void gen_cursaddr(node *, int, int);
extern void gen_clearline(node *);
extern void gen_clearend(node *);
extern void gen_system(node *, part *, int);
extern void solhook(char *); /* start-of-line hook */
extern void eolhook(void);   /* end-of-line hook */
//extern void strlwr(char *);  /* force string to lower case */

/* gencode.h ends here */
