R :Interactive tutorial program for IEEE PILOT; run with `pilot tutor.p'.
  :
  :Also intended to serve as a test load; if your port or implementation
  :can execute and compile this without errors, you can be reasonably sure
  :it conforms to Standard 1154-1991 (and then some).
  :
  :Designed and written by Eric S. Raymond <esr@thyrsus.com>.
  :This tutorial is copyright 1991 by the author for distribution under the
  :same terms as the rest of the implementation.
  :
CH:
T :Welcome to the IEEE PILOT tutorial program.
  :
  :  This program will help you learn how to program in IEEE PILOT.  It is
  :arranged in topic sections which you can can browse through in whatever
  :order suits your skills and interests.  To learn the whole language, just
  :read them straight through like chapters and sections in a book.
  :
  :  Experienced PILOT users should have a look at main sections E, F, and G
  :(Special Features, Debugging PILOT programs, and Compiling PILOT) to learn
  :particulars of PILOT use with this implementation.  Wizards and hackers
  :who've somehow tripped over this questionable achievement should read
  :section B (PILOT from the Inside) first.
  :
  :  This tutorial and this implementation of the PILOT language were written,
  :purely for their hack value, by Eric S. Raymond <esr@snark.thyrsus.com>
  :working from IEEE Standard 1154-1991; formally, IEEE Standard for Programmed
  :Inquiry, Learning Or Teaching (PILOT) ISBN 1-55937-151-X, dated August 22
  :1991.  It is distributed under BSD terms.
  :
U :*MORE
R :---------------------- MAIN LOOP BEGINS --------------------------------
*RESTART
CH:
T :
  :Please select a topic:
  :
  :  A - PILOT from the Outside        --- an introduction for non-techies.
  :  B - PILOT from the Inside         --- an introduction for techies.
  :  C - Elementary PILOT              --- T:, A:, M:, Y:, N: and R:.
  :  D - Advanced PILOT programming.   --- C:, conditionals, J:, U: and E:.
  :  E - Screen Control                --- CA:, CH:, CL:, CE:.
  :  F - Special Features              --- PR:, PA:, L: JM:, TH:, XS:.
  :  G - Debugging PILOT programs      --- error messages and debug switches.
  :  H - Compiling PILOT               --- how to make PILOT programs faster.
  :
  :  X - Exit (leave this tutorial)
  :
  :Type <letter> or to go to a topic (for example, type `a' to go to the first
  :Introduction, or `c' to learn about elementary PILOT programming).
  :
TH:Topic? 
A :
T :
M :a
JY:*DUMBINTRO
M :b
JY:*SMARTINTRO
M :c
JY:*ELEMENTARY
M :d
JY:*ADVANCED
M :e
JY:*SCREENCTL
M :f
JY:*FEATURES
M :g
JY:*DEBUGGING
M :h
JY:*COMPILING
M :x
TY:Goodbye.
EY:
J :*RESTART
R :----------------------- MAIN LOOP ENDS ---------------------------------

R :This routine simply asks for a continuation prompt.
*MORE
TH:Press enter for more...
A :
E :

R :Ditto, with different emphasis
*FINISHED
TH:Press enter to continue...
A :
E :

R :This routine permits the user to experiment with a statement type
*EXPERIMENT
TH:Do you want to experiment with $EXPTYPE now? 
A :
M :y
TY:Entering the PILOT interpreter...type END: to exit.
XSY:pilot
TY:Exiting the PILOT interpreter, welcome back.
TY:
E :

*DUMBINTRO
CH:
T :This is the non-technical introduction to PILOT.
  :
  :  Welcome to PILOT (Programmed Inquiry, Learning, or Teaching).  The PILOT
  :language is designed for writing interactive courseware.  Its great virtue
  :is that can be learned quickly and easily;  by actual test, educators and
  :other non-techies can learn how to use PILOT effectively in less than an
  :hour.
  :
  :  Typical PILOT programs display information to the user, ask a question,
  :look at the response in various ways, and use the response to determine
  :which information should be shown next.  This PILOT program that you're
  :running now, to learn PILOT, is very typical.
  :
  :  This program will take you through a series of sections designed to
  :teach you about PILOT and how to program in it.  Some of the sections
  :have exercises in them so you can test your knowledge.  When you have
  :finished the tutorial, you can read the PILOT source for this program
  :(tutor.p) to learn "idioms", useful ways of doing common small tasks.
  :
U :*FINISHED
J :*RESTART

*SMARTINTRO
CH:
T :This is the hacker's introduction to PILOT.
  :
  :  Yes, PILOT is a simple language; the uncharitable might even call it
  :simple-minded, but it wasn't designed for hacking and it *was* designed in
  :1962.  It's served its purpose well enough to survive for thirty years,
  :which is more than a lot of grander but now-defunct languages can say.
  :
  :  PILOT is something like BASIC and something like a really, really dimwit
  :cousin of Bourne Shell.  The core language has only ten commands, two of
  :which are trivial variants of a third, and doesn't include file I/O.  There
  :are no named functions, only equivalents of GOTO and GOSUB.  The only two
  :data types are integer and string.  The arithmetic syntax resembles BASIC's.
  :The only string operations are assignment, concatenation, and a sort of weak
  :regular-expression match which you can only apply to user input.  Coding
  :in PILOT is tedious and limiting, but within its limits it *is* dead easy.
  :
  :  The only tricky thing about PILOT is its lexical rules, which are bizarre
  :by modern standards.  Like most other languages of its antiquity, it is
  :basically field-oriented rather than token-oriented.  But you won't find it
  :difficult.  Read on, holding your nose if necessary.
  :
U :*MORE
CH:
T :Here's a rough BNF of the core commands:
  :
  :TYPE    <cond> : <text>        -- type <text> followed by newline.
  :ACCEPT  <cond> : {<id>}        -- accept input to \%answer {assign to id}.
  :MATCH   <cond> : <text>        -- set \%matched, \%left, \%matched, and 
  :                                  \%right if <text> can be found in \%answer
  :JUMP    <cond> : <label>       -- jump to <label>.
  :USE     <cond> : <label>       -- jump to <label>, preparing to return on E.
  :COMPUTE <cond> : <id> = <expr> -- give <id> the value computed by <expr>.
  :REMARK  <cond> : <text>        -- no effect.
  :END     <cond> :               -- exit from current U.
  :YES     <cond> : <text>        -- display <text> if \%matched is TRUE.
  :NO      <cond> : <text>        -- display <text> if \%matched is FALSE
  :
  :  The lexical complexities are mainly in the <text> elements, which are --
  :get this -- strings delimited on the left by the colon and on the right by
  :newline.  In the C statement, <expr> may be a <text> if <id> is a string ID.
  :Also, the keywords may be abbreviated to their first letters, and it is not
  :always lucidly clear where the keyword stops and the condition-part begins.
  :
  :  The condition-parts are arithmetic and relational expressions with two
  :special read-only variables optionally present.  More about that later on.
  :
U :*FINISHED
J :*RESTART

*ELEMENTARY
CH:
T :This is the section on elementary PILOT programming.
  :
  :  S      - PILOT statements
  :  T      - The TYPE command
  :  A      - The ACCEPT command
  :  M      - The MATCH command
  :  Y or N - The YES command
  :  R      - The REMARK command
  :
  :  Please pick a command to learn about by typing its letter,
  :or type `x' to return to the main menu.
  :
TH:Topic? 
A :
T :
M :S
JY:*STATEMENTS
M :T
JY:*TYPE1
M :A
JY:*ACCEPT1
M :M
JY:*MATCH1
M :Y,N
JY:*YESNO
M :R
JY:*REMARK1
M :X
JY:*RESTART
J :*ELEMENTARY

R:             --------- ELEMENTARY PILOT ---------

*STATEMENTS
CH:
T :Pilot statement syntax.
  :
  : Every PILOT statement has a colon in the middle and contains up to three
  :parts; a keyword, a condition, and arguments.  The keyword and condition go
  :before the colon, the arguments after.  Usually, in elementary PILOT, the
  :condition part is empty.  So there are only two parts; keyword and
  :arguments, separated by a colon.
  :
  :  The ten core PILOT statements have the keywords TYPE, ACCEPT, MATCH, JUMP,
  :USE, COMPUTE, REMARK, YES, NO, END.  You don't have to remember these now;
  :you'll learn them as you continue the tutorial.
  :
  :  Notice that they all have unique first letters.  In fact, you need only
  :write the first letter in a keyword field, and PILOT will recognize it.
  :Also, PILOT doesn't care about uppercase versus lowercase except in some
  :special circumstances we'll get to later.  Thus, you can write `ACCEPT' or
  :`accept' or `A' or `a' or `Accept' in a keyword field and PILOT will see
  :them all as the keyword ACCEPT.
  :
  :  Arguments can come in several different flavors, or be omitted entirely
  :(that is, there's nothing to the right of the colon).  We'll discuss the
  :way PILOT interprets them under individual statements.
  :
U :*FINISHED
J :*ELEMENTARY

*TYPE1
CH:
T :The TYPE command displays a string to the user.
  :
  :  That's all, and it's that simple.  In fact, the sentence above was
  :produced by a PILOT command that looks like this:
  :
  :   T :The TYPE statement displays a string to the user.
  :
  :In fact, all the messages displayed by this program come from TYPE
  :statements.  You can experiment with writing your own; just type T,
  :followed by a colon, followed by text, followed by a newline, and
  :watch the text echo back at you.
  :
C :$EXPTYPE=TYPE statements
U :*EXPERIMENT
T :
  :  TYPE statements can also display the contents of string and numeric
  :variables.  There is more about string variables in the next frame, which
  :describes ACCEPT; you'll learn about numeric variables a bit later.
  :
U :*FINISHED
J :*ELEMENTARY

*ACCEPT1
CH:
T :The ACCEPT statement is used to get a line of input from the user.
  :
  :  The simplest form of ACCEPT is just A followed by a colon.  That is
  :
  :    A:
  :
  :  This accepts a line of input from the user and puts it in a string
  :variable called `\%answer'.  That is, when the program *runs*, executing A:
  :will stop, wait till the user has typed some input terminated by a newline,
  :and then put that input in the variable \%answer, and continue.
  :
  :  At the end of the TYPE frame, we said that TYPE can also display string
  :variables.  If you include a string variable name (like \%answer) in the
  :text argument of a T command, the value of that variable (whatever was last
  :put into it) is substituted when the TYPE is performed.
  :
U :*MORE
T :  Here's a simple program to illustrate how this works:
  :
  :    T:Type anything, ending with enter
  :    A:
  :    T:You said `\%answer'
  :
  :Here's how that looks in action:
  :
T:Type anything, ending with enter
A:
T:You said `%answer'
  :
C :$EXPTYPE=ACCEPT statements and \%answer
U :*EXPERIMENT
T :
  :  You can also give the name of a string variable as the argument to an
  :ACCEPT.  String variables are named with a `\$' followed by a letter
  :followed by up to nine numbers and letters.  If you do this, the
  :input will also be put in that variable.  To see this, do this:
  :
  :    T:Type anything, ending with enter
  :    A:\$myanswer
  :    T:You said `\$myanswer'
  :
  :Here's how that looks in action:
  :
T:Type anything, ending with enter
A:$myanswer
T:You said `$myanswer'
  :
  :  Now you might ask `Why do this if I have \%answer?'.  The answer is that
  :older PILOTs don't let you get at \%answer.  If your courseware is only
  :going to run on IEEE PILOT, use it by all means.
  :
C :$EXPTYPE=ACCEPT statements and string variables
U :*EXPERIMENT
T :
  :  String variables have many other uses.  We'll get to those soon.
  :
U :*FINISHED
J :*ELEMENTARY

*EXPECT1
A :
M :1
TY:That's right.
M :0
TY:No, that string would match "YES"; look again.
M :0,1
TN:I don't understand that answer; please type 0 or 1
JN:*EXPECT1
E :

*EXPECT0
A :
M :0
TY:That's right.
M :1
TY:No, that string would not match "YES"; look again.
M :0,1
TN:I don't understand that answer; please type 0 or 1
JN:*EXPECT0
E :

*MATCH1
CH:
T :The MATCH statement is used to look for patterns in input.
  :
  :  MATCH takes a text argument and looks in \%answer for a substring matching
  :it.  If such a match is found, the system variable \%matched is set to 1;
  :if a match is not found, it's set to 0.  Later, other commands can use
  :\%matched in various ways.
  :
  :  Suppose \%answer (set by a previous A:) has the value "foozle".  Then
  :
  :     M:foo
  :     M:o
  :     M:ZL
  :
  :would all set \%matched to 1.  PILOT doesn't care about uppercase versus
  :lowercase in matches, so "ZL" would match the "zl" in "foozle" (so would
  :"zL" or "Zl").
  :
U :*MORE
CH:
T :  On the other hand,
  :
  :    M:g
  :    M:fz
  :    M:ooo
  :
  :would all set \%matched to 0, because none of those strings occur in the
  :string "foozle" (the value of \%answer).
  :
U :*MORE
CH:
T :  Now, suppose that \%answer has the value "YES".  Will the following
  :strings match (1) or not match (0) that \%answer?  Type 1 or 0 in
  :reply to each question.
  :
TH:"y"? 
U :*EXPECT1
TH:"Y"? 
U :*EXPECT1
TH:"n"? 
U :*EXPECT0
TH:"ye"? 
U :*EXPECT1
TH:"es"? 
U :*EXPECT1
TH:"NO"? 
U :*EXPECT0
TH:"xxx"? 
U :*EXPECT0
T :
  :  This is a significant example, because you often want to ask yes or no
  :questions in PILOT programs.
  :
U :*MORE
T :  For examples of MATCH in action, see the next two frames (on YES and NO).
  :
  :  Some characters (* ? ! | and ,) have special functions in the MATCH
  :statement.  Also, MATCH sets three other special variables called \%left,
  :\%match, and \%right.  You don't need to worry about any of this yet, except
  :to avoid using the special characters in MATCH until you learn what they
  :mean.  That will be covered in the Advanced Programming frames.
  :
U :*FINISHED
J :*ELEMENTARY

*YESNO
CH:
T :The YES statement prints a string if the last match succeeded.
  :
  :  This statement uses the `condition code', \%matched, that is set by the
  :MATCH statement.  If \%matched is 1 (true) when the YES is executed,
  :YES displays its argument, the same way a T statement does.
  :
  :  The NO statement is the opposite of YES; it displays its text argument
  :only if \%matched is 0.
  :
  :  This little program illustrates how they work:
  :
  :    T :Is it usually colder in the summer or in the winter?
  :    A :
  :    M :winter
  :    Y :That's true most places.
  :    N :You must be thinking of an unusual place.
  :
  :Here's what it looks like in action:
  :
T:Is it usually colder in the summer or in the winter?
A:
M:winter
Y:That's true most places.
N:You must be thinking of an unusual place.
T :
  :  Just as with T, string variables named in the text argument of a YES or
  :NO have their values plugged in when the text is displayed.
  :
C :$EXPTYPE=YES and NO statements
U :*EXPERIMENT
J :*ELEMENTARY

*REMARK1
CH:
T :  The REMARK statement is used to add explanatory comments to
  :programs.  It has no effect on what the person running the program sees.
  :
  :  This is more important than it may sound.  Even very simple programs can
  :be very confusing for another person to read --- even if that person is the
  :program's author six months later!
  :
  :  The REMARK statement consists of R: followed by any text; everything up to
  :the end-of-line is simply ignored.  Here's a sample remark:
  :
  :    R: If the interpreter tried to parse *this*, it'd choke!
  :
C :$EXPTYPE=REMARK statements
U :*EXPERIMENT
T :
  :  Note: this implementation of PILOT includes an alternative to REMARK that
  :is more flexible and cheaper (less parsing overhead in the interpreter).
  :See "Intra-line Comments" in the "Features" section for details.
  :
TH:Do you want to go there now? 
M :y
JY:*COMMENTS
J :*ELEMENTARY

*ADVANCED
CH:
T :This is the section on advanced PILOT programming.
  :
  :  W - Advanced MATCH usage with wildcards
  :  C - The COMPUTE command
  :  I - Conditional parts
  :  J - The JUMP command
  :  U - The USE command
  :  E - The END command
  :  S - String substitution and special escape syntaxes
  :
  :  X - return to main menu
  :
TH:Topic? 
A :
T :
M :W
JY:*WILDCARDS
M :C
JY:*COMPUTE1
M :I
JY:*CONDPARTS
M :J
JY:*JUMP1
M :U
JY:*USE1
M :E
JY:*END1
M :S
JY:*XSTRINGS
M :X
JY:*RESTART
J :*ADVANCED

R:             ---------- ADVANCED PILOT ----------

*WILDCARDS
CH:
T :Some wildcards are available for `fuzzy' matching of patterns in MATCH.
  :
  :  Sometimes, when looking at what the user has entered, you don't care
  :whether or not the match is exact as long as it's close enough in some
  :sense.  PILOT provides some wildcards for expressing matches less obvious
  :than simple equality.
  :
  :   The first, and usually most important of these, is the `or-bar'
  :facility.  This allows a MATCH to accept any of several alternatives.  There
  :alternatives may be separates by any of the characters `|' (pipe), `,'
  :(comma) or `!' (exclamation point).  Thus, you might write:
  :
  :   T :Do you understand the Schleswig-Holstein Question?
  :   A :
  :   M :yes,yeah!sure|uh huh
  :   TY:Then you are either dead, mad, or Lord Palmerston.
  :
  :This code will accept any of the alternatives "yes", "yeah", "sure", or "uh
  :huh" as an affirmative answer.
  :
U :*MORE
CH:
T :More on string wildcards
  :
  :  The two other string wildcards are `?' and `*'.  The `?' wildcard matches
  :any single character; the `*' matches any number of characters.  Thus, for
  :example, the MATCH argument "b?d" would also match the \%answer values
  :`bed', `rebud', `bid', and `bod'.  The argument "b*d" would, additionally,
  :match `berthed', `breached', `bird', `board' and `beard'.
  :
  :  However, it would *not* match `budded'!  Why not?  Because, having
  :matched `bud', in the first three letters, it would stop and not see the
  :trailing "ed".  And this is significant, because when MATCH succeeds it sets
  :not just \%match (as we discussed before) but also the values of three
  :string system variables.  These are:
  :
  :   \%match  --- the part of the target string that matched the pattern
  :   \%left   --- all of the target string to the left of the match
  :   \%right  --- all of the target string to the right of the match
  :
  :Thus, in the above example ("b?d" against `rebudded'), \%left would get the
  :value "re", \%matched would become "bud", and \%right would become "ed".
  :In general, MATCH prefers shorter matches to longer ones.
  :
U :*MORE
CH:
T :Escaping string wildcards
  :
  :   What do you do, then, if you need to use one of the special characters
  :(comma, pipe, exclamation point, question mark, or asterisk) as a literal
  :part of a match?
  :
  :   The answer is simple.  Precede it with a backslash, or `escape
  :character'.  Thus, the string "b\\?d" matches *only* the exact characters
  :`b?d', not `bed', `bid' etc.  So, for example, you might write:
  :
  :     T:Please pick a punctuation character
  :     A:M\!,:,;\\,\,.\?
  :     Y:That's right.
  :     N:That's not punctuation, you silly person!
  :
  :Note how the backslash `literalizes' only the comma following it, leaving
  :all the other commas to do their normal job.
  :
  :   Now suppose you want to match against a pattern containing a literal
  :slash followed by any character?  You can't use simply "\\?", as you don't
  :want the slash to literalize the following question mark; so you must
  :backslash the slash!  You'd write "\\\\?".
  :
U :*FINISHED
J :*ADVANCED

*COMPUTE1
CH:
T :The COMPUTE statement is used to do arithmetic and string assignments.
  :
  :  All arithmetic in PILOT is done with the COMPUTE statement.  The COMPUTE
  :statement has two forms; one assigns a text value to a string variable, and
  :the other computes an arithmetic expression and assigns its value to a
  :numeric variable.
  :
  :  We have already touched on string variables in discussing ACCEPT; recall
  :that the name of a string variable is led with a $, and that when such a
  :name appears in a text (in a T statement or elsewhere) the value of that
  :variable is substituted for it.  Now we add that every string variable
  :starts with the value of the empty string (a string with nothing in it).
  :
  :  One of the two forms of COMPUTE gives a string variable the value of a
  :text.  Here are a few samples:
  :
  :    C:\$PREAMBLE=We the People of the United States
  :    C:\$DATE=\$DAY/\$MONTH/\$YEAR
  :    C:\$NUMBER=hundred \$NUMBER
  :
  :You might use the second one to assemble a date string out of day, month and
  :year strings already computed.  The third one splices the value of $NUMBER
  :into string preceded by "hundred " then gives $NUMBER that value.
U :*MORE
CH:
T :Numeric Variables and Assignments.
  :
  :  Numeric variables have names that begin with #, start with the value 0,
  :and are also expanded into texts when they appear there.  So, for example,
  :assuming \$user is a string variable with the value `Eric' and \#score is a
  :numeric variable with the value 5, the TYPE command
  :
  :   T:\$user's score is \$score
  :
  :will print "Eric's score is 5".  However, numeric variables are different in
  :one way; within an expression (that is, outside a text argument) PILOT
  :doesn't need a # prefix to recognize them.  String variables cannot appear
  :in an expression.
  :
  :  The other form of COMPUTE assigns the value of an expression to a numeric
  :variable.  An expression may be built up from numbers and other numeric
  :variables using normal arithmetic operations which we shall specify in the
  :next frame.  Meanwhile, here is an example to give you a feel for the
  :idea:
  :
  :  C:RESULT = (PARTIAL + 3) / 4
  :
U :*MORE
CH:
T :Numeric Expressions
  :
  :  The arithmetic operations available in numeric expressions are:
  :
  :  +  --- addition
  :  -  --- subtraction
  :  *  --- multiplication
  :  /  --- division
  :  %  --- modulo (remainder) (note: this is not in the IEEE Standard)
  :
  :  Division is integer division; the result is rounded down to the nearest
  :integer.  Multiplication and division `group' with respect to addition and
  :subtraction in the way you'd expect; 2 + 3 * 4 is 14, not 24.  Modulo groups
  :that way too; in computer science terminology, it has equal precedence with
  :* and /, and higher precedence than + or -.
  :
  :More examples (note how parentheses may be used for grouping):
  :
  :    C:COST = (SIZE * 3) + 16 
  :    C:AREA = (BASE * HEIGHT) / 2	\/\/ Compute area of triangle
  :    C:CLOCKTIME = CLOCKTIME % 12
  :
U :*FINISHED
J :*ADVANCED

*CONDPARTS
CH:
T :A conditional part can cause any statement to be skipped.
  :
  :   So far in this tutorial, all the PILOT example statements have consisted
  :of just two parts; keyword field and arguments, separated by a colon.
  :The frame on PILOT statement syntax mentioned that there is an optional
  :third part just before the colon; the conditional.
  :
  :   The conditional is a logical expression or test with a value of true or
  :false; if the value is false, the statement is skipped.  An omitted
  :conditional has the value true, so statements without conditionals are
  :always executed when the program's flow of control reaches them.
  :
  :   The simplest kind of conditional is simply the letter `Y' or `N'.  The
  :`Y' condition is true if \%matched is 1 (that is, if the last MATCH
  :statement succeeded) and false if \%matched is 0 (that is, if the last MATCH
  :failed).  The `N' is just the opposite; it is true if %matched is 0, false
  :if \%matched is true.
  :
U :*MORE
CH:
T :(conditions, continued)
  :
  :Thus, the program we used to illustrate the YES and NO commands could have
  :been written:
  :
  :    T :Is it usually colder in the summer or in the winter?
  :    A :
  :    M :winter
  :    TY:That's true most places.
  :    TN:You must be thinking of an unusual place.
  :
  :and, in fact, the Y and N statements are equivalent to TY and TN
  :respectively.
  :
  :  A condition can have other forms as well.  It can be a `relational
  :expression' in parentheses; that is, a comparison between two expressions
  :(as in the COMPUTE statements).  This kind of condition is true if the
  :relation is true.  For example,
  :
  :     T (N > 99):\#N has two or more decimal digits.
  :     T (N <= 99):\#N has only one digit.
  :
U :*MORE
CH:
T :(still more about conditions)
  :
  :Or a condition it can be an expression, alone, in parentheses; the value of
  :the expression is compared to 0, and if it is greater the condition is true.
  :Thus,
  :
  :     T (N):\#N is a positive number.
  :     T (N % 2):\#N is an odd number
  :
  :Actually, a condition may contain *both* a Y or N match condition *and* an
  :expression test in parentheses; but this is uncommon. You could write;
  :
  :     T :Isn't this quiz the most fun you've had with a computer?
  :     A :
  :     M :y
  :     TY (SCORE=20): Your last answer was correct and your score is perfect!
  :     TY (SCORE<>20):  What a good attitude!  Your score was \#N.
  :     TN: Hmmph.  You're no fun.  But you did score \#N.
  :
  :The next frame will describe the tests available in relational expressions.
  :
U :*MORE
CH:
T :Relational Expressions
  :
  :  The relations available in conditions are as follows:
  :
  :   =    --- equals
  :   <>   --- not equals
  :   <    --- less than
  :   >    --- greater than
  :   <=   --- greater than or equal to
  :   >=   --- less than or equal to
  :
  :Of course, these may only be applied to numeric (not string) variables.
  :
U :*FINISHED
J :*ADVANCED

*JUMP1
CH:
T :The JUMP statement is used to transfer control to the location of a label.
  :
  :   The JUMP statement permits you to move the point of execution in the
  :program, changing the sequence of actions it performs.  Here is an example
  :program that uses JUMP:
  :
  :  *JDEMO1
  :    T :Should I repeat myself?
  :    A :
  :    M :y
  :    JY:*JDEMO1
  :    T :I'm through repeating myself for now.
  :
  :Notice that the JUMP is abbreviated J, and uses a `Y' condition much as we
  :discussed in the frame on Conditional Parts.  Also notice the label, which
  :begins with a `*'.  That's how PILOT knows it's a label.  This program, as
  :you can probably tell, will repeat asking you if it should repeat itself
  :until you tell it no.
  :
U :*MORE
CH:
T :(JUMP, continued)
  :
  :Here's what the program looks like in action:
  :
*JDEMO1
T :Should I repeat myself?
A :
M :y
JY:*JDEMO1
T :I'm through repeating myself for now.
  :
  :  This kind of program is called a `loop'.  Of course, JDEMO1 is a silly and
  :fairly useless example, unless you have friends who are very easily
  :impressed.  But loops are useful for processing any number of somethings
  :until you decide to stop, and something like the simple program structure
  :above actually appears in many useful programs.
  :
  :  A JUMP can also be used to make a program branch to one of two courses of
  :action, depending on some test.  This is less common in PILOT than it is in
  :most other languages with JUMP-like features, because in PILOT conditional
  :parts do a lot of this job.
  :
  :  There are many examples of control structures involving JUMP in the
  :tutor.p source.  Study these for further enlightenment.  Also, bear in mind
  :that when you think of using two or more JUMPs in sequence that land program
  :control back where it started, you should consider replacing the outermost
  :two with a USE/END pair.  USE and END are discussed in the next two frames.
  :
U :*MORE
CH:
T :Special Features of JUMP in this PILOT
  :
  :  This PILOT supports some special JUMP features which are not included in
  :the core IEEE Standard, but are among the recommended extensions.  These
  :features let you jump to some pseudo-labels which do special things.
  :
  :    JUMP @M  --- JUMP forward to the next MATCH statement
  :
  :This may be useful if you're trying to do one of several different things
  :depending on which of several strings matches \%answer.
  :
  :    JUMP @A  --- JUMP backwards to the last ACCEPT statement
  :
  :This may be useful if you've tested and rejected some invalid inputfrom the
  :user, and want to have him/her enter input for another try.
  :
  :    JUMP @P  --- JUMP forward to the next PROBLEM statement
  :
  :This may be useful to skip to the next of several (unnamed) problem sets.
  :See the description of the PROBLEM statement under Features.
  :
TH:Do you want to go there now? 
M :y
JY:*PROBLEM1
T :
U :*FINISHED
J :*ADVANCED

*USE1
CH:
T :The USE statement is used to enter a subroutine.
  :
  :  The USE command gives PILOT a rudimentary subroutine facility.  It behaves
  :like JUMP, except that the location from which the JUMP was executed is
  :saved, and control is returned to the following statement when the next END
  :is encountered.
  :
  :  Here is a sample USE statement:
  :
  :    USE:*SUMSQUARES
  :
  :This command would call a routine named USESQUARES.  USE can be abbreviated
  :`U' and usually is.
  :
  :  Each USE executed bumps the value of the system variable \%uselevel up by
  :1.  The system variable \%maxuses gives the maximum number of nested USEs
  :the PILOT system will support.  You cannot set \%maxuses with a COMPUTE.
  :You can set \%uselevel, but doing so is likely to result in horrible
  :confusion and might even crash PILOT.
  :
U :*FINISHED
J :*ADVANCED

*END1
CH:
T :The END statement is used to leave PILOT or exit a subroutine.
  :
  :  The END statement returns control out of a USE.  If no USE is active (that
  :is, \%uselevel is 0) it exits PILOT.  Each END executes decrements
  :\%uselevel.  Here is a sample END statement:
  :
  :  END:
  :
  :  Now you know why all the `experiment' sections told you to return to the
  :tutor by typing :END!  The END statement may be abbreviated E:.
  :
  :  Under UNIX, END may take a numeric expression argument which is passed
  :back as the exit status of the PILOT program.  Warning: this feature is not
  :endorsed by the IEEE standard!
  :
  :  Thus, you may write
  :
  :   E:1
  :
  :to exit with status value 1.
  :
U :*FINISHED
J :*ADVANCED

*XSTRINGS
CH:
T :Advanced string features and special syntaxes.
  :
  :  In all the commands that take text arguments (TYPE, MATCH, the
  :string-assignment COMPUTE, REMARK, TYPEHANG, PROBLEM, LINK, and SYSTEM) you
  :can embed the values of variables in the text the program sees.
  :
  :  You do this simply by embedding the name of a numeric, string, or system
  :variable in the text.  Thus, if the string variable \$myname has the value
  :"George", the statement
  :
  :    T: My name is \$myname, pleased to meet you.
  :
  :will display
  :
  :    My name is George, pleased to meet you.
  :
  :This works for other kinds of variables as well.
  :
U :*MORE
CH:
T :If the numeric variable \#myscore has the value 20,
  :
  :    T:My score is \$myscore points.
  :
  :will display
  :
  :    My score is 20 points.
  :
  :This even works for system variables like \%answer.  You can write things
  :like
  :
  :    T:Your last answer, \%answer, was correct.
  :
  :and it will display a string composed partly of the user's last input.
  :
  :  But what if you actually want to include a $, # or \ in output?
  :
U :*MORE
CH:
T :  Suppose you wrote a program that contained the line
  :
  :  T:That's a \#big# problem!
  :
  :  This wouldn't work (you can try it in a bit and see).  The problem is that
  :PILOT is trying to interpret \#big as a numeric variable name!
  :
  :  You can prevent this by `escaping' the first #; that is, preceding it with
  :a backslash.  Escaping the second one wouldn't hurt, but isn't necessary
  :because PILOT knows that # followed by a space can't be a variable name.
  :
  :  You can also escape \$ and \% with a backslash --- in fact you *have* to,
  :if they're followed by a letter and you don't want them treated as the
  :lead-in to a variable name.
  :
  :  If you're really on top of things, you're asking yourself "O.K...but now,
  :suppose I want to type something that has an expanded variable name in it,
  :*preceded by a slash*?   See if you can guess the right answer before going
  :to the next frame.
  :
U :*MORE
CH:
T :  If you guessed that the right thing to do is *precede the slash with a
  :slash*, hand yourself a prize.
  :
  :  In other words, to print out the value of \$myname surrounded by
  :two backslashes pn either side, you have to code
  :
  :    T:\\\\$myname\\\\
  :
  :  There is one more wrinkle to the backslash story.  Backslash followed by
  :certain printable characters can be used to produce special non-printable
  :ASCII characters.  In particular:
  :
  :	\\b	-- backspace
  :	\\t	-- tab
  :	\\n	-- line feed
  :	\\r	-- carriage return
  :	\\a	-- bell
  :	\xdd	-- (for d two hex digits) produces ASCII dd
  :	\^	-- masks following char by 0x1f (thus \^c is control-C).
  :
  :Warning: this last feature is not in the IEEE standard!
  :
C :$EXPTYPE=string substitutions and special escapes
U :*EXPERIMENT
T :
U :*FINISHED
J :*ADVANCED

R:             ---------- SCREEN CONTROL ------------

*SCREENCTL
CH:
T :This section discusses some special features of this PILOT implementation
  :for working with video terminals.  These are modeled on the screen
  :facilities of the Nevada PILOT dialect for CP/M microcomputers.
  :
  :These features are NOT part of the 1991 IEEE PILOT Standard, although CH
  :and CA are included among the suggested extensions in section 4.
  :
  :  CH - The CLEARHOME command
  :  CA - The CURSADDR command
  :  CL - The CLEARLINE command
  :  CE - The CLEAREND command
  :
  :  X - return to main menu
  :
TH:Topic? 
A :
T :
M :CH
JY:*CLEARHOME1
M :CA
JY:*CURSADDR1
M :CL
JY:*CLEARLINE1
M :CE
JY:*CLEAREND1
M :X
JY:*RESTART
J :*SCREENCTL

*CLEARHOME1
CH:
T :The CLEARHOME statement is used to clear the screen and home the cursor.
  :
  :  This makes presentations look better and can actually help them update the
  :screen more quickly (on most terminals, screen clear followed by write is
  :faster than scrolling).
  :
  :  CLEARHOME syntax is very simple.
  :
  :    CH:
  :
TH:That's it.  And here's what it looks like....(press enter to continue)
A :
CH:
PA:2
T :That was a CH followed by a 2-second delay.
  :
  :   Under UNIX, CH is implemented through termcap(3) and will work on any
  :supported devices.  Under non-UNIX systems, CH is actually implemented by
  :sending a form feed (ASCII 12) to standard output.  This works on most
  :display *and hardcopy* terminals.
  :
C :$EXPTYPE=CH
U :*EXPERIMENT
T :
U :*FINISHED
J :*SCREENCTL

*CURSADDR1
CH:
T :The CURSADDR command is used to move the screen cursor.
  :
  :  If you're writing a PILOT program that you know will be used either under
  :UNIX or with a VT100 or ANSI-compatible display (which includes most modern
  :terminals and personal computers, including the IBM PC with the ANSI.SYS
  :driver enabled) you can use CA to write to arbitrary locations on the
  :screen.
  :
  :  To use CA, follow the colon with the screen row of the location,
  :followed by a comma, followed by the screen column of the location.
  :Column and row numbers are 1-origin; that is, cell (1,1) is the uppermost
  :and leftmost character position on the screen.  Here's an example:
  :
  :    CA: 5, 12                   \/\/ position cursor at row 5, column 12
  :
  :  Usually you'll follow a CA with a T or A statement, to either write
  :text at a given location or read it there.
  :
C :$EXPTYPE=CA
U :*EXPERIMENT
T :
U :*FINISHED
J :*SCREENCTL

*CLEARLINE1
CH:
T :The CLEARLINE command is used to clear to end of line.
  :
  :  If you're writing a PILOT program that you know will be used either under
  :UNIX or with a VT100 or ANSI-compatible display (which includes most modern
  :terminals and personal computers, including the IBM PC with the ANSI.SYS
  :driver enabled) you can use CL to clear from the current cursor location to
  :the right edge of the screen.
  :
U :*FINISHED
J :*SCREENCTL

*CLEAREND1
CH:
T :The CLEAREND command is used to clear to end of screen.
  :
  :  If you're writing a PILOT program that you know will be used either
  :under UNIX or with a VT100 or ANSI-compatible display (which includes
  :most modern terminals and personal computers, including the IBM PC with
  :the ANSI.SYS driver enabled) you can use CE to clear from the current
  :cursor location to the lowest rightmost corner of the screen.
  :
U :*FINISHED
J :*SCREENCTL

R:             ---------- IEEE PILOT FEATURES ----------

*FEATURES
CH:
T :This section discusses some special features of this PILOT implementation.
  :These are NOT part of the 1991 IEEE PILOT Standard, although all but 
  :JM and PA are included among the suggested extensions in section 4.
  :
  :  \/\/ - Intra-line comments
  :
  :  PR - The PROBLEM command
  :  PA - The PAUSE command
  :  L  - The LINK command
  :  JM - The JUMPMATCH command
  :  TH - The TYPEHANG command
  :  XS - The SYSTEM command
  :
  :  X - return to main menu
  :
TH:Topic? 
A :
T :
M :\/\/
JY:*COMMENTS
M :PR
JY:*PROBLEM1
M :PA
JY:*PAUSE1
M :L
JY:*LINK1
M :JM
JY:*JUMPMATCH1
M :TH
JY:*TYPEHANG1
M :XS
JY:*SYSTEM1
M :X
JY:*RESTART
J :*FEATURES

*COMMENTS
CH:
T :New syntax for intra-line comments
  :
  :  The new comment syntax delimits comments on the left with \/\/, and can be
  :used on a line with any statement.  Thus,
  :
  :   T: foo bar baz      \/\/ This is a silly TYPE statement
  :
  :is seen as if only "T: foo bar baz" had been typed.  To include the string
  :"\/\/" in a text part, write the string "\/\/"; the leading backslash "escapes"
  :the comment marker so it's treated as ordinary text.
  :
  :  (Note for wizards: the comment syntax actually eats not just the comment,
  :but all whitespace before it.  This is significant, given PILOT's funny
  :lexical rules for strings)
  :
C :$EXPTYPE=comments
U :*EXPERIMENT
T :
U :*FINISHED
J :*FEATURES

*PROBLEM1
CH:
T :The PROBLEM statement
  :
  :  The PROBLEM statement is intended to be used to lead off major problem
  :sets in courseware programs.
  :
  :  In this implementation of PILOT, a PROBLEM statement is treated exactly
  :like a remark, except that you can JUMP @P to it.
  :
  :  Here is a sample PROBLEM statement:
  :
  :    PR: Begin the elementary trigonometry quiz
  :
  :  Historically, some other implementations of PILOT have used PROBLEM as a
  :catch-all for setting options that modified the behavior of other commands. 
  :Any PILOT command containing a PROBLEM statement is quite likely to be 
  :non-portable and should be examined with particular care.  If the pedantic
  :(-p) option is on when this PILOT sees a PROBLEM statement, PILOT will
  :print an error message and abort.
  :
U :*FINISHED
J :*FEATURES

*PAUSE1
CH:
T :The PAUSE statement is used for timed pauses.
  :
  :  The PAUSE statement causes a timed delay.  It takes a numeric expression
  :as an argument.  This is interpreted as a delay time in seconds.
  :
  :  Here is a sample:
  :
  :    PAUSE:5
  :
  :This would delay execution for five seconds.  PAUSE can be abbreviated to
  :PA; thus
  :
  :    PA:5
  :
  :would be equivalent to the above.
  :
C :$EXPTYPE=the PAUSE statement
U :*EXPERIMENT
T :
U :*FINISHED
J :*FEATURES

*LINK1
CH:
T :The LINK statement is used for calling other PILOT programs.
  :
  :  A LINK statement interprets its text argument as a filename, assumes it's
  :a PILOT program or compiled PILOT binary, and tries to execute it as though
  :the text of the program had been inserted at the point of the LINK.
  :Variables set in the calling program will be available in the called
  :program, though neither may use labels from the other for JUMPs or USEs.
  :
  :  On termination of the called program, control moves to the statement
  :following the LINK.  The system variable \%status will contain the return
  :status of the called program, or -1 if the called program couldn't be found.
  :
  :  Here is a sample LINK statement:
  :
  :    L:myroutine.p
  :
  :  This tries to find and execute a PILOT program called "myroutine.p".  LINK
  :looks first in the current directory, then in the PILOT library directory.
  :Under UNIX, the location of this directory may be set via the environment
  :variable PILOTDIR.
  :
  :  Reality is actually just a little more complicated than this, though...
  :
U :*MORE
CH:
T :  The last frame told a small fib.  LINK isn't limited to searching for
  :PILOT sources; actually, it looks for binaries first, assuming that they're
  :compiled PILOT.
  :
  :  The LINK statement above would actually look first for a file named
  :`myroutine' in the current directory and try to execute that.  Then it would
  :look for `myroutine' in the PILOT library directory.  Only then would it go
  :back and look for PILOT sources (.p files).
  :
  :  The theory behind this is to have LINK prefer the faster, compiled
  :versions of PILOT programs whenever it can find them.
  :
  :  LINK interacts in some other slightly tricky ways with PILOT compilation.
  :For details, see main section G on "Compiling PILOT".
  :
U :*FINISHED
J :*FEATURES

*JUMPMATCH1
CH:
T :The JUMPMATCH statement jumps into a label list based on the last MATCH.
  :
  :  When you write PILOT programs, you will often find you want to jump to
  :one of a list of destinations, depending on what string an input matches.
  :In core PILOT, the only way to do this is with a tedious list of M/JY
  :statement pairs, looking like this:
  :
  :    M :<match-1>
  :    JY:<destination-1>
  :    M :<match-2>
  :    JY:<destination-2>
  :           :
  :    M :<match-n>
  :    JY:<destination-n>
  :
  :  This PILOT supports a more compact method, inherited from Nevada PILOT,
  :that looks like this:
  :
  :    M :<match-1>,<match-2>,...<match-n>
  :    JM:<destination-1>,<destination-2>,...<destination-n>
  :
U :*MORE
CH:
T :Details about JUMPMATCH
  :
  :  In detail, the JM or JUMPMATCH statement dispatches on the value of
  :the %matched system variable, which is set by the MATCH statement.
  :
  :  If the value of %matched is zero (last match failed) the JM statement is
  :ignored and control passes to the next statement.
  :
  :  If the value of %matched is nonzero and less than or equal to the number
  :of labels in the label list of the JM, the label indexed by it (counting
  :from the left) is jumped to.
  :
  :  If the value of %matched is out of range (greater than the number of
  :labels in the label list of the JM) the JM statement is ignored.
  :
  :  JM or JUMPMATCH is particularly useful for organizing large programs
  :containing menus.
  :
U :*FINISHED
J :*FEATURES

*TYPEHANG1
CH:
T :The TYPEHANG statement is used for doing prompt and input on one line.
  :
  :  TYPEHANG (which can be abbreviated TH) works exactly like TYPE, except
  :that it omits the line feed at the end of the output.  The statements
  :
  :    TY:Topic?
  :    A :
  :
  :were used to produce the topic prompt and input on the same line used in
  :this tutorial.  Here's how that looks again (just type anything to the
  :prompt to continue):
  :
TH:Topic?  
A :
T : Warning: this is hard to play with interactively!  When you experiment,
  :TYPEHANG will execute immediately, leaving your cursor hanging out there to
  :the right.  You can type A: and it will wait for input, but because you have
  :to type a newline to send the A:, it will take your input on the next line!
  :Don't be discouraged; done from a program, it works fine.
  :
C :$EXPTYPE=the TYPEHANG statement
U :*EXPERIMENT
T :
U :*FINISHED
J :*FEATURES

*SYSTEM1
CH:
T :The SYSTEM command is used to run non-PILOT commands under PILOT control.
  :
  :  The SYSTEM command takes a text argument.  This argument is executed as a
  :shell command to the underlying operating system.  Under UNIX, for example,
  :the PILOT command
  :
  :    SYSTEM:ls
  :
  :would execute ls(1), displaying a list of files in the current directory
  :on standard output.  The SYSTEM command may be abbreviated XS, so
  :
  :    XS:ls
  :
  :would have accomplished the same result.
  :
  :  The return status of the command is saved in the numeric system variable
  :\%status, and is thus available for later use in condition parts.  Usually a
  :return value of 0 signifies successful execution.
  :
C :$EXPTYPE=SYSTEM
U :*EXPERIMENT
T :
U :*FINISHED
J :*FEATURES

*DEBUGGING
CH:
T :Debugging PILOT programs.
  :
  :  It is a fact of life that if you write programs of any size, you will make
  :mistakes.  This implementation of PILOT tries to be helpful in pointing out
  :where they are, so you can fix them quickly.  None of what's in this section
  :is guaranteed by the IEEE Standard.
  :
  :  You will get error messages in one of two different formats; one if you
  :are typing PILOT text directly to the interpreter, another if you are
  :running a `canned' PILOT program from a file.
  :
  :  If you are typing PILOT directly to the interpreter and make an error, two
  :things will happen.  First, a line that is all blanks except for one caret
  :(uparrow) character will be emitted.  The uparrow tries to point you at the
  :place on the line where PILOT noticed the problem; under some circumstances
  :it may point off to the right of the real trouble, but is never to the left
  :of it.  Then, a one-line error message describing the problem will be
  :emitted.
  :
  :  This is useful for exploring the syntax and behavior of statements you are
  :unfamiliar with.  There are ways to make PILOT even more verbose about
  :errors which we'll get to shortly.
  :
U :*MORE
CH:
T :Error messages from canned programs.
  :
  :  If you are running a canned PILOT program from a file, the message will
  :be a single line that looks roughly like this:
  :
  :    "file.p", line dddd, char nnnn: arglebargle
  :
  :That is, it will contain the source file name in quotes, the line number
  :where the error occurred, and the character PILOT was at when it noticed
  :the problem (same caveat about that last as with the caret indicator).
  :
  :  This format is designed to be used with the get-next-error feature of
  :EMACS and kindred editors.  Granted, debugging PILOT with EMACS is something
  :like shifting dust-bunnies with a bulldozer, but you can do it if you need
  :to.  The author has found these buffer variable settings useful:
  :
  :    R: Local Variables:
  :    R: fill-prefix:"  :"
  :    R: fill-column:79
  :    R: End:
  :
  :A copy of these lives at the end of tutor.p.
  :
U :*MORE
CH:
T :PILOT debugging options: How To Set Them.
  :
  :  There are two ways to set PILOT's debugging options.  One is from the
  :command line, as option arguments to the PILOT command.  The other is by
  :using a directive line in program text.  Directive lines begin with a
  :`#' (pound sign).
  :
  :  Here are some sample option sets:
  :
  :    pilot -v2              ; run PILOT, setting verbosity to 2
  :
  :    #-v1                   ; set verbosity to 1
  :
  :    pilot -d               ; run PILOT, dumping system variables after
  :                           ; each statement.
  :
  :    #-vy                   ; Enable parser production reports
  :    U:BUGGYCODE            ; USE routine BUGGYCODE
  :    #+vy                   ; Disable parser production reports
  :
  :On an option line, + preceding an option unsets it.  Sorry, you can't do
  :this from the command line!  Next, some discussion of what these do...
  :
U :*MORE
CH:
T :PILOT debugging options: What They Do.
  :
  :  If your debug options include -d, the interpreter will dump all
  :relevant system variables after each statement.  This way, you get to
  :see exactly what the interpreter thinks it's doing.
  :
  :  PILOT has a verbosity level you can set to higher-than-normal levels to
  :get more information on what the interpreter/compiler is doing.  By default,
  :this verbosity level is 0.
  :
  :  At verbosity level 1, every line of the program is echoed as it executes
  :or compiles, with line number prepended.  In effect, this is a program trace
  :for interpreted programs.  Verbosity level one also generates a message
  :every time a seek is done in the source due to a JUMP, USE or END.
  :
  :  At verbosity level 2, the lexical analyzer generates a one-line report on
  :each token processed.  If you know enough to use this, you know enough to
  :read source to find out what the token classes mean.  Enough said.
  :
  :  If your debug option set includes the letter `y', the PILOT parser will
  :utter a detailed report on how it is operating as it munches source.  Used
  :with YACC's y.output for the parser grammar, this will enable the
  :sufficiently wizardly to grok *exactly* what is going on at any point.
  :
U :*FINISHED
J :*RESTART

*COMPILING
CH:
T :How to compile PILOT programs so they'll run faster.
  :
  :  This section assumes you're running Eric Raymond's IEEE PILOT reference
  :implementation on a UNIX machine, or a compatible port.
  :
  :  Normally, PILOT programs are interpreted step-by-step by PILOT itself.
  :When you typed `pilot tutor' to the shell, you told the PILOT interpreter to
  :look for and execute a PILOT program called `tutor' --- this one.
  :
  :  This version of PILOT can also translate a PILOT program into C and
  :compile it from C to an executable binary.  Binaries run faster, and may be
  :portable to machines where you don't have PILOT up and running.
  :
  :  To compile a PILOT program, simply add the switch `-c' to the command line
  :you would use to run it.  For example, to compile this tutor program, you'd
  :execute the following command:
  :
  :    pilot -c tutor
  :
  :  PILOT will chug away silently for a bit; when it returns, there should be
  :an executable binary called `tutor' sitting in your directory that behaves
  :in all ways like the interpreted tutor.p.
  :
U :*MORE
CH:
T :  Well...not *quite* in all ways.  In interpreted PILOT, when you call
  :another PILOT program with LINK, any variables set in the `outer' PILOT
  :program are also set for the `inner' one; in effect, the text of the called
  :program is inserted at the point of the LINK.  A compiled program neither
  :makes its variables available to a program it calls nor picks up variables
  :from a calling program.
  :
  :  In theory, the translated C of any syntactically correct PILOT program
  :should compile without errors.  If your C compiler emits errors, first check
  :to see that the PILOT source is valid by running it through the interpreter.
  :If they persist, you may be able to track them down by looking at the error
  :line numbers, which will correspond not to the C but to the PILOT source (C
  :wizards will grok that the PILOT compiler emits \#line declarations).
  :
  :  If a PILOT program that appears syntactically valid still doesn't compile
  :correctly, the -k option will prevent it from deleting the generated source.
  :You can look at that to try to figure out what's gone wrong.  The -k option
  :also suppresses the \#line declarations, so the error line numbers will be
  :correct for the generated C.
  :
U :*FINISHED
J :*RESTART

R :                     --- NOTE TO THE PERSISTENT ---
  :
  :This tutorial implies one fib about the Standard.  In the Standard,
  :FILE and GRAPHIC are described as part of the `core language', in spite of
  :the fact that *no semantics is specified for them*.  I have refused to
  :propagate this bletcherousness, which should avoid confusion both to
  :students and (possibly) further embarrassment to the 1154 committee.  

R: The following sets edit modes for GNU EMACS
R: Local Variables:
R: fundamental-mode
R: fill-prefix:"  :"
R: fill-column:79
R: End:
