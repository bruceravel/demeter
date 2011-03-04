/*************************
 * C header file Ifeffit *
 *************************/

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32__)
#define IFF_EXPORT(a) __declspec(dllexport) a _stdcall
#define IFF_INTERN(a) a _stdcall
#else
#define IFF_EXPORT(a) a
#define IFF_INTERN(a) a
#endif

/* main interface routines */

IFF_EXPORT(int) iff_exec(char *);
IFF_EXPORT(int) ifeffit(char *);
IFF_EXPORT(int) iff_get_string(char *, char *);
IFF_EXPORT(int) iff_put_string(char *, char *);
IFF_EXPORT(int) iff_get_scalar(char *, double *);
IFF_EXPORT(int) iff_put_scalar(char *, double *);
IFF_EXPORT(int) iff_get_array(char *, double *);
IFF_EXPORT(int) iff_put_array(char *, int *, double *);
IFF_EXPORT(int) iff_get_echo(char *);
IFF_EXPORT(char*)  iff_strval(char *);
IFF_EXPORT(double) iff_scaval(char *);

/* raw interfaces to the fortran functions: these 
   may need system level alterations as they assume
    1.trailing underscore
    2.char lengths as int at end of argument list
   these appear to be the unix norm.
*/

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32__)

int     _stdcall IFFEXECF(char *, int);
int     _stdcall IFFGETSTR(char *, int, char *, int);
int     _stdcall IFFGETSCA(char *, int, double *);
int     _stdcall IFFGETARR(char *, int, double *);
int     _stdcall IFFPUTARR(char *, int, int *, double *);
int     _stdcall IFFGETECHO(char *, int);
char*   _stdcall IFF_STRVAL(char *);
double  _stdcall IFF_SCAVAL(char *);

#else

int ifeffit_(char *, int);
int iffgetstr_(char *, char *, int, int);
int iffgetsca_(char *, double *, int);
int iffgetarr_(char *, double *, int);
int iffputarr_(char *, int *, double *, int);
int iffgetecho_(char *, int);

#endif


/* end */

