/* Override any GCC internal prototype to avoid an error.
   Use char because int might match the return type of a GCC
   builtin and then its argument prototype would still apply.
   The 'extern "C"' is for builds by C++ compilers;
   although this is not generally supported in C code supporting it here
   has little cost and some practical benefit (sr 110532).  */
#ifdef __cplusplus
extern "C"
#endif
char __gmpz_init (void);
int
main (void)
{
return __gmpz_init ();
  ;
  return 0;
}
