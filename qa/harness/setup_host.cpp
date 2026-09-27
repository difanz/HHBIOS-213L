/* Host ABI only: all decisions and emitted bytes come from production code. */
#include "setup.h"
extern "C" {
void hh_recommend(Machine *m,Files *f,Choices *c) {recommend(m,f,c);}
const char *hh_validate(Machine *m,Files *f,Choices *c) {return validate(m,f,c);}
int hh_batch(const char *p,Choices *c,char *out) {return make_batch(p,c,out);}
int hh_ini(const char *p,Choices *c,char *out) {return make_ini(p,c,out);}
const char *hh_save(const char *batch,const char *ini) {return save_pair(batch,ini);}
}
