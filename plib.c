/******************************************************************************

NAME
  plib.c -- implementation of non-IEEE primitives

SYNOPSIS
   void do_graphic(char *t)	-- semantic action for FILE statement

   void do_file(char *t)	-- semantic action for GRAPHIC statement

   void do_problem(char *t)	-- semantic action for PROBLEM statement

   void do_pause(int n)		-- semantic action for PAUSE statement

   void do_link(char *t)	-- semantic action for LINK statement

   void do_scrinit(void)	-- screen initialization

   void do_clearhome(void)	-- semantic action for CLEARHOME statement

   void do_cursaddr(int y, int x)	-- semantic action for CURSADDR
   statement int y, x;

   void do_clearline(void)	-- semantic action for CLEARLINE statement

   void do_clearend(void)	-- semantic action for CLEAREND statement

   void do_scrend(void)		-- screen de-initialization

   DESCRIPTION
   Code for some functions not specified by the IEEE PILOT standard
   1154-199 is concentrated here.  These are the ones that may be
   required by compiled code.  See also nonstd.c and numconv.c.

   LICENSE
   SPDX-License-Identifier: BSD-2-Clause

******************************************************************************/

/*LINTLIBRARY*/
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#ifdef TERMCAP
#define SYSV /* guard System V curses.h from brain death */
#include <ncurses/curses.h>
#include <term.h>
#endif /* TERMCAP */

#include "pilot.h"

#include <stdlib.h>
#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#endif

#define FILENG "pilot: the semantics of the FILE command is not defined\n"
#define GRAPHNG "pilot: the semantics of the GRAPHICS command is not defined\n"
#define MAXARGS 64

#ifdef _WIN32
#include <io.h>
#include <windows.h>

#define access _access
#define R_OK 4
#define sleep(x) Sleep((x) * 1000)

#endif
/*******************************************************************
 *
 * Filename interpretation
 *
 ******************************************************************/
#ifndef _WIN32
static int run_argv(char *const argv[]) {
	pid_t pid;
	int status;

	if (argv == NULL || argv[0] == NULL || argv[0][0] == '\0') {
		return 0;
	}

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
}
#else

static int run_argv(char *const argv[]) {
    return -1;
}

#endif
static int parse_argv(const char *cmd, char *buf, size_t bufsz,
                      char **argv, size_t argvsz) {
	size_t len;
	char *p;
	int argc = 0;

	if (cmd == NULL) {
		return -1;
	}

	len = strlen(cmd);
	if (len >= bufsz) {
		return -1;
	}
	memcpy(buf, cmd, len + 1);

	p = buf;
	while (*p) {
		char *out;
		int quote = 0;

		while (*p && isspace((unsigned char)*p)) {
			p++;
		}
		if (!*p) {
			break;
		}
		if ((size_t)argc + 1 >= argvsz) {
			return -1;
		}

		argv[argc++] = p;
		out = p;
		for (; *p; p++) {
			char c = *p;

			if (quote) {
				if (c == quote) {
					quote = 0;
					continue;
				}
				if (c == '\\' && quote == '"' && p[1]) {
					p++;
					c = *p;
				}
				*out++ = c;
				continue;
			}

			if (isspace((unsigned char)c)) {
				break;
			}
			if (c == '"' || c == '\'') {
				quote = c;
				continue;
			}
			if (c == '\\' && p[1]) {
				p++;
				c = *p;
			}
			*out++ = c;
		}
		if (quote) {
			return -1;
		}
		*out = '\0';
		if (*p) {
			*p = '\0';
			p++;
		}
	}

	argv[argc] = NULL;
	return argc;
}

bool namefile(char *whole, char *stem, char *source) {
	char *ep;
	const char *tp;
	int n;

	/* Set tp to the part after the directory path. */
	if ((tp = strrchr(whole, '/')) != NULL) {
		++tp;
	} else {
		tp = whole;
	}
	if ((ep = strrchr(tp, '.')) != NULL) {
		if (strcmp(ep, PLT)) {
			return (FALSE);
		} else {
			n = snprintf(source, PATH_MAX, "%s", whole);
			if (n < 0 || n >= PATH_MAX) {
				return (FALSE);
			}
			n = snprintf(stem, PATH_MAX, "%s", whole);
			if (n < 0 || n >= PATH_MAX) {
				return (FALSE);
			}
			ep = strrchr(stem, '.');
			if (ep != NULL) {
				*ep = '\0';
			}
		}
	} else {
		n = snprintf(stem, PATH_MAX, "%s", whole);
		if (n < 0 || n >= PATH_MAX) {
			return (FALSE);
		}
		n = snprintf(source, PATH_MAX, "%s%s", whole, PLT);
		if (n < 0 || n >= PATH_MAX) {
			return (FALSE);
		}
	}
	return (TRUE);
}

int psearch(char *whole, char *stem, char *source)
/* search for PILOT source or binary */
{
	/*
	 * The theory here is that we're looking for either a compiled
	 * PILOT binary or a source we can interpret.  We look either
	 * in the current directory or in the PILOT library
	 */
	if (!namefile(whole, stem, source)) {
		return (EOF);
	} else if (access(stem, R_OK) == 0) {
		return (FALSE);
	} else if (access(source, R_OK) == 0) {
		return (TRUE);
	} else {
		char withlib[PATH_MAX];

		int n = snprintf(withlib, sizeof(withlib), "%s%s", PILOTDIR,
		                 whole);
		if (n < 0 || n >= (int)sizeof(withlib)) {
			return (EOF);
		}
		namefile(withlib, stem, source);

		if (access(stem, R_OK) == 0) {
			return (FALSE);
		} else if (access(source, R_OK) == 0) {
			return (TRUE);
		} else {
			return (EOF);
		}
	}
}

/*******************************************************************
 *
 * Language primitives
 *
 ******************************************************************/

void do_graphic(char *t)
/* perform a GRAPHIC operation */
{
	(void)fprintf(stderr, GRAPHNG);
}

void do_file(char *t)
/* perform a FILE operation */
{
	(void)fprintf(stderr, FILENG);
}

void do_problem(char *t)
/* perform a PROBLEM operation */
{
	/* no-op */
}

void do_pause(int n)
/* perform a PAUSE operation */
{
	/* we assume n is in seconds */
	(void)sleep(n);
}

void do_link(char *t)
/* perform a LINK operation */
{
	char stem[PATH_MAX], source[PATH_MAX];
	char *argv[3];

	switch (psearch(t, stem, source)) {
	case TRUE:
		argv[0] = "pilot";
		argv[1] = source;
		argv[2] = NULL;
		sys_status = run_argv(argv);
		break;

	case FALSE:
		argv[0] = stem;
		argv[1] = NULL;
		sys_status = run_argv(argv);
		break;

	case EOF:
		sys_status = -1;
		break;
	}
}

int do_system(const char *cmd)
/* perform a SYSTEM operation without invoking a shell */
{
	char buf[MAXSTR * 4];
	char *argv[MAXARGS];

	if (parse_argv(cmd, buf, sizeof(buf), argv, MAXARGS) < 0) {
		return -1;
	}
	return run_argv(argv);
}

/*******************************************************************
 *
 * Screen-control primitives
 *
 ******************************************************************/

#ifdef TERMCAP
static char buf[256]; /* I hope this is big enough for BSD termcap */
#endif                /* TERMCAP */

void do_scrinit(void)
/* initialize screen I/O mode */
{
#ifdef TERMCAP
	const char *term;

	if ((term = getenv("TERM")) == NULL || tgetent(buf, term) == ERR) {
		(void)fputs("Sorry, I can't initialize this terminal.\n",
		            stderr);
		exit(2);
	}
#endif /* TERMCAP */
}

static int xputc(int c) { return (putchar(c)); }

void do_clearhome(void)
/* perform a CLEARHOME operation */
{
#ifdef TERMCAP
	/* second arg is only used for padding calculations */
	{
		char *cap = tgetstr("cl", NULL);
		if (cap) {
			tputs(cap, 24, xputc);
		} else {
			/* ANSI fallback for missing termcap entries */
			(void)printf("\033[H\033[2J");
		}
	}
#else
	/*
	 * Kluge time.  We just emit a form feed, hoping the output
	 * device is ANSI or VT100-like.
	 */
	(void)putchar('\014');
#endif /* TERMCAP */
}

void do_cursaddr(int y, int x)
/* perform a CURSADDR operation */
{
#ifdef TERMCAP
	/* second arg is only used for padding calculations */
	{
		char *cap = tgetstr("cm", NULL);
		if (cap) {
			tputs(tgoto(cap, x - 1, y - 1), 1, xputc);
		} else {
			/* ANSI fallback for missing termcap entries */
			(void)printf("\033[%d;%dH", y, x);
		}
	}
#else
	/*
	 * Kluge time.  We just emit an ANSI cursor-address sequence, hoping the
	 * output device is ANSI or VT100-like.
	 */
	(void)printf("\033[%d;%dH", y, x);
#endif /* TERMCAP */
}

void do_clearline(void)
/* perform a CLEARLINE operation */
{
#ifdef TERMCAP
	/* second arg is only used for padding calculations */
	{
		char *cap = tgetstr("ce", NULL);
		if (cap) {
			tputs(cap, 1, xputc);
		} else {
			/* ANSI fallback for missing termcap entries */
			(void)printf("\033[0K");
		}
	}
#else
	/*
	 * Kluge time.  We just emit an ANSI clear-to-eol sequence, hoping the
	 * output device is ANSI or VT100-like.
	 */
	(void)printf("\033[0K");
#endif /* TERMCAP */
}

void do_clearend(void)
/* perform a CLEAREND operation */
{
#ifdef TERMCAP
	/* second arg is only used for padding calculations */
	{
		char *cap = tgetstr("cd", NULL);
		if (cap) {
			tputs(cap, 24, xputc);
		} else {
			/* ANSI fallback for missing termcap entries */
			(void)printf("\033[0J");
		}
	}
#else
	/*
	 * Kluge time.  We just emit an ANSI clear-to-eos sequence, hoping the
	 * output device is ANSI or VT100-like.
	 */
	(void)printf("\033[0J");
#endif /* TERMCAP */
}

void do_scrend(void)
/* deinitialize screen I/O mode */
{
	/* no-op at present; reserved for future use */
}

/* plib.c ends here */
